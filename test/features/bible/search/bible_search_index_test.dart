/// **L'index plein texte** (M3, #201) : construction idempotente et
/// reconstruction, recherche simple (filtres, surlignage, pagination),
/// croisée, et l'historique.
///
/// Construire l'index d'une version prend quelques secondes sous `flutter
/// test` (31 102 versets) : délai élargi.
@Timeout(Duration(minutes: 3))
library;

import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/features/bible/data/canon.dart';
import 'package:maison_du_miracle/features/bible/data/placeholder_bible.dart';
import 'package:maison_du_miracle/features/bible/search/bible_search_history.dart';
import 'package:maison_du_miracle/features/bible/search/bible_search_index.dart';

import '../../../data/local/local_database_fixtures.dart';

const _catalog = PlaceholderBibleCatalog();

Future<int> _rows(AppDatabase db, String code) async => (await db.customSelect(
      'SELECT count(*) AS n FROM bible_fts WHERE version_code = ?',
      variables: [Variable.withString(code)],
    ).getSingle())
        .read<int>('n');

void main() {
  late AppDatabase db;
  late BibleSearchIndex index;

  // Un seul index pour tout le fichier : le construire coûte quelques
  // secondes par version.
  setUpAll(() async {
    db = openTestDatabase();
    index = BibleSearchIndex(db, _catalog);
    await Future.wait([index.ensureIndexed('EXA'), index.ensureIndexed('EXA')]);
    await index.ensureIndexed('EXB');
  });
  tearDownAll(() => db.close());

  group('L\'index', () {
    test('une ligne par verset du canon, et un second appel ne refait rien',
        () async {
      expect(await _rows(db, 'EXA'), 31102);
      expect(await index.isIndexed('EXA'), isTrue);
      await index.ensureIndexed('EXA');
      expect(await _rows(db, 'EXA'), 31102);
    });

    test('une version inconnue n\'indexe rien', () async {
      await index.ensureIndexed('ZZZ');
      expect(await _rows(db, 'ZZZ'), 0);
      expect(await index.isIndexed('ZZZ'), isFalse);
    });

    test('reconstruit si le texte a changé ou si la version est réinstallée',
        () async {
      await db.customStatement(
        "UPDATE bible_fts SET verse_text = 'ancien' WHERE version_code = 'EXB' "
        "AND book = 'Rev' AND chapter = '22' AND verse = '21'",
      );
      expect(await index.isIndexed('EXB'), isFalse);
      await index.ensureIndexed('EXB');
      expect(await index.isIndexed('EXB'), isTrue);
      expect(await _rows(db, 'EXB'), 31102);

      // M4 réinstalle : la ligne revient avec `indexed = false`.
      await db.into(db.bibleInstalledVersions).insert(
            BibleInstalledVersionsCompanion.insert(
              code: 'EXB',
              name: 'B',
              installedAt: DateTime(2026),
            ),
          );
      expect(await index.isIndexed('EXB'), isFalse);
      await index.ensureIndexed('EXB');
      final row = await db.select(db.bibleInstalledVersions).getSingle();
      expect(row.indexed, isTrue);
      expect(await _rows(db, 'EXB'), 31102);
    });
  });

  group('La recherche', () {
    test('mots sans accents ni casse, surlignés, dans l\'ordre du canon',
        () async {
      final page = await index.search('eternel', versions: ['EXA']);
      expect(page.total, greaterThan(20));
      expect(page.hits, hasLength(20));
      final first = page.hits.first;
      expect(first.texts.single.version, 'EXA');
      expect(first.texts.single.text, contains("$kHitStartÉternel$kHitEnd"));
      final ranks = [
        for (final h in page.hits)
          bibleChapterIndex(h.link.book, h.link.chapter) * 1000 + h.link.from!,
      ];
      expect(ranks, [...ranks]..sort());
    });

    test('le texte trouvé est bien celui du verset', () async {
      final page = await index.search('parole', versions: ['EXA']);
      final hit = page.hits.first;
      final text = const PlaceholderBibleSource('EXA')
          .verseText(hit.link.book, hit.link.chapter, hit.link.from!);
      expect(
        hit.texts.single.text.replaceAll(RegExp('[$kHitStart$kHitEnd]'), ''),
        text,
      );
    });

    test('préfixe et plusieurs mots : tous exigés', () async {
      final one = await index.search('paro', versions: ['EXA']);
      final two = await index.search('parole orphelin', versions: ['EXA']);
      expect(one.total, greaterThan(two.total));
      expect(two.total, greaterThan(0));
      for (final h in two.hits) {
        expect(h.texts.single.text, contains('parole'));
        expect(h.texts.single.text, contains('orphelin'));
      }
    });

    test('filtres : AT, NT, livre ; et le total se partage', () async {
      final all = await index.search('ame', versions: ['EXA']);
      final ot = await index.search('ame',
          versions: ['EXA'], scope: BibleSearchScope.oldTestament);
      final nt = await index.search('ame',
          versions: ['EXA'], scope: BibleSearchScope.newTestament);
      expect(ot.total + nt.total, all.total);
      expect(ot.hits.every((h) => bibleBook(h.link.book)!.index < 39), isTrue);
      expect(nt.hits.every((h) => bibleBook(h.link.book)!.index >= 39), isTrue);
      final john = await index.search('ame',
          versions: ['EXA'], scope: const BibleSearchScope.book('John'));
      expect(john.total, greaterThan(0));
      expect(john.hits.every((h) => h.link.book == 'John'), isTrue);
    });

    test('pagination : pages disjointes qui se suivent', () async {
      final p1 = await index.search('croit', versions: ['EXA'], limit: 5);
      final p2 =
          await index.search('croit', versions: ['EXA'], offset: 5, limit: 5);
      expect(p1.total, p2.total);
      expect(p2.hits, hasLength(5));
      expect(
        p2.hits.first.link.toUrl(),
        isNot(p1.hits.last.link.toUrl()),
      );
    });

    test('rien à chercher, ou une ponctuation seule : page vide', () async {
      expect((await index.search('  ', versions: ['EXA'])).total, 0);
      expect((await index.search('"*', versions: ['EXA'])).total, 0);
      expect((await index.search('paix', versions: const [])).total, 0);
    });

    test('croisée : regroupée par verset, une ligne par version', () async {
      // « jour » est dans les deux versions ; « Dieu » dans B seulement.
      final a = await index.search('jour', versions: ['EXA']);
      final b = await index.search('jour', versions: ['EXB']);
      final both =
          await index.search('jour', versions: ['EXB', 'EXA'], limit: 100000);
      final union = {
        for (final h
            in (await index.search('jour', versions: ['EXA'], limit: 100000))
                .hits)
          h.link.toUrl(),
        for (final h
            in (await index.search('jour', versions: ['EXB'], limit: 100000))
                .hits)
          h.link.toUrl(),
      };
      expect(both.total, union.length);
      expect(both.total, lessThanOrEqualTo(a.total + b.total));
      final shared = both.hits.where((h) => h.texts.length == 2);
      expect(shared, isNotEmpty);
      for (final h in shared) {
        expect(h.texts.map((t) => t.version), ['EXB', 'EXA']);
      }
      final dieu = await index.search('dieu', versions: ['EXA', 'EXB']);
      expect(dieu.hits.every((h) => h.texts.single.version == 'EXB'), isTrue);
    });
  });

  test('l\'historique : 10 au plus, le plus récent en tête, sans doublon',
      () async {
    final history = BibleSearchHistory(db);
    for (var i = 0; i < 12; i++) {
      await history.add('mot $i');
    }
    await history.add('MOT 5');
    final list = await history.read();
    expect(list, hasLength(10));
    expect(list.first, 'MOT 5');
    expect(list.where((e) => e.toLowerCase() == 'mot 5'), hasLength(1));
    await history.clear();
    expect(await history.read(), isEmpty);
  });
}
