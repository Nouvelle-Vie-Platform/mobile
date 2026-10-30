/// **La versification propre à chaque version** (C3, #240, décision 2 de
/// server-portal#605) : le relevé stocké avec la version installée, la grille
/// qui le suit, la référence jugée dans la version ouverte, et l'index plein
/// texte jugé « complet » selon **sa** versification.
///
/// Les deux versifications des tests sont celles que le PRD a mesurées : le
/// canon figé (KJV / Segond, Exode 7 = 25 versets, Malachie = 4 chapitres) et
/// une « éwé 1913 / S21 » qui en diverge sur les deux points — Exode 7 = 29
/// versets, et **pas de Malachie 4** (la S21 suit la Bible hébraïque ; sa
/// Malachie 3 compte 24 versets, les 18 + 6 de la KJV).
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/features/bible/data/bible_providers.dart';
import 'package:maison_du_miracle/features/bible/data/bible_source.dart';
import 'package:maison_du_miracle/features/bible/data/canon.dart';
import 'package:maison_du_miracle/features/bible/data/placeholder_bible.dart';
import 'package:maison_du_miracle/features/bible/personalize/bible_catalog.dart';
import 'package:maison_du_miracle/features/bible/search/bible_reference_parser.dart';
import 'package:maison_du_miracle/features/bible/search/bible_search_index.dart';
import 'package:maison_du_miracle/features/bible/personalize/reader_appearance.dart';
import 'package:maison_du_miracle/features/bible/shell/bible_browser.dart';
import 'package:maison_du_miracle/theme/app_typography.dart';

import '../../data/local/local_database_fixtures.dart';
import '../../helpers/pump_screen.dart';

/// Le canon figé, Exode 7 porté à 29 versets et Malachie 4 **retiré**.
final BibleVersification _divergente = BibleVersification.of({
  for (final b in bibleCanon)
    b.osis: switch (b.osis) {
      'Exod' => [
          for (final (i, n) in b.verseCounts.indexed) i == 6 ? 29 : n,
        ],
      // Un 0 : « ce chapitre n'existe pas dans cette version ».
      'Mal' => [b.verseCounts[0], b.verseCounts[1], 24, 0],
      _ => b.verseCounts,
    },
});

String _json(BibleVersification v) => v.signature;

BibleInstalledVersionRow _installed(String code, {String? versification}) =>
    BibleInstalledVersionRow(
      code: code,
      name: code,
      installedAt: DateTime.utc(2026, 10, 22),
      indexed: false,
      versification: versification,
    );

BibleVersionRow _served(int id, String code) => BibleVersionRow(
      syncStamp: 0,
      id: id,
      code: code,
      name: 'Version $code',
      language: 'ee',
      sortOrder: id,
      publishedAt: DateTime.utc(2026, 10),
    );

/// Une petite versification complète : deux livres, trois chapitres, sept
/// versets — et **pas d'Apocalypse 22**, le dernier chapitre du canon.
final BibleVersification _tiny = BibleVersification.of({
  'Gen': [3, 2],
  'Mal': [2, 0],
});

/// Le texte qu'une versification décrit, et rien d'autre.
final class _FakeSource implements BibleSource {
  const _FakeSource(this.versionCode, this.versification);

  @override
  final String versionCode;
  final BibleVersification versification;

  @override
  Future<List<BibleVerse>> chapter(String book, int chapter) async => [
        for (var v = 1; v <= versification.versesIn(book, chapter); v++)
          BibleVerse(v, '$book $chapter:$v amen'),
      ];
}

/// Un catalogue d'une seule version, dont la versification est **dite** par le
/// test : `_tiny` pour juger dans la version, le canon figé pour montrer ce
/// que l'ancien jugement répondait.
final class _OneVersion implements BibleCatalog {
  _OneVersion(this.code, this.declared, {this.source});

  final String code;
  final BibleVersification declared;
  final BibleVersification? source;

  @override
  Future<List<BibleVersion>> versions() async =>
      [BibleVersion(code: code, name: code, language: 'fr', installed: true)];

  @override
  String get defaultVersionCode => code;

  @override
  BibleSource? sourceFor(String versionCode) =>
      versionCode == code ? _FakeSource(code, source ?? declared) : null;

  @override
  BibleVersification versificationFor(String versionCode) => declared;

  @override
  String languageFor(String versionCode) => 'fr';
}

/// Deux versions installées, de versifications différentes : ce que le lecteur
/// a sous les yeux quand il bascule de l'une à l'autre.
final class _TwoVersions implements BibleCatalog {
  const _TwoVersions(this.defaultVersionCode);

  @override
  final String defaultVersionCode;

  @override
  Future<List<BibleVersion>> versions() async => const [
        BibleVersion(code: 'KJV', name: 'KJV', language: 'en', installed: true),
        BibleVersion(code: 'EWE', name: 'Éwé', language: 'ee', installed: true),
      ];

  @override
  BibleSource? sourceFor(String versionCode) =>
      PlaceholderBibleSource(versionCode);

  @override
  BibleVersification versificationFor(String versionCode) =>
      versionCode == 'EWE' ? _divergente : kCanonVersification;

  @override
  String languageFor(String versionCode) => versionCode == 'EWE' ? 'ee' : 'fr';
}

Future<int> _rows(AppDatabase db, String where) async => (await db
        .customSelect('SELECT count(*) AS n FROM bible_fts WHERE $where')
        .getSingle())
    .read<int>('n');

void main() {
  group('Une versification', () {
    test('le canon figé reste ce qu\'il était', () {
      expect(kCanonVersification.books, hasLength(66));
      expect(kCanonVersification.chapters, hasLength(1189));
      expect(
        kCanonVersification.chapters.fold<int>(
          0,
          (n, c) => n + kCanonVersification.versesIn(c.book, c.chapter),
        ),
        31102,
      );
      expect(kCanonVersification.versesIn('Exod', 7), 25);
      expect(kCanonVersification.chapterCount('Mal'), 4);
      expect(kCanonVersification.chapters.last, (book: 'Rev', chapter: 22));
    });

    test('un chapitre à 0 verset n\'existe pas : ni compté, ni proposé', () {
      expect(_divergente.versesIn('Mal', 4), 0);
      expect(_divergente.chapterCount('Mal'), 3);
      expect(_divergente.chaptersOf('Mal'), [1, 2, 3]);
      expect(_divergente.versesIn('Mal', 3), 24, reason: '18 + 6 de la KJV');
      // La suite des pages du lecteur saute donc de Malachie 3 à Matthieu 1.
      final i = _divergente.chapterIndex('Mal', 3);
      expect(_divergente.chapters[i + 1], (book: 'Matt', chapter: 1));
      expect(_divergente.chapterIndex('Mal', 4), -1);
      expect(_divergente.chapters, hasLength(1188));
      // Le canon, lui, le propose toujours.
      expect(bibleChapterIndex('Mal', 4), greaterThan(0));
    });

    test('un livre absent de la version n\'est pas dans ses livres', () {
      expect(_tiny.books, ['Gen', 'Mal']);
      expect(_tiny.chapterCount('Rev'), 0);
      expect(_tiny.chaptersOf('Rev'), isEmpty);
      expect(_tiny.chapterIndex('Rev', 1), -1);
      expect(_tiny.chapters, [
        (book: 'Gen', chapter: 1),
        (book: 'Gen', chapter: 2),
        (book: 'Mal', chapter: 1),
      ]);
    });

    test('la même référence, jugée dans chaque version', () {
      const exode729 = BibleLink('Exod', 7, from: 29);
      const exode725 = BibleLink('Exod', 7, from: 25);
      expect(_divergente.isValid(exode729), isTrue);
      expect(kCanonVersification.isValid(exode729), isFalse);
      expect(_divergente.isValid(exode725), isTrue);
      expect(kCanonVersification.isValid(exode725), isTrue);
      // Et dans l'autre sens : Malachie 4 n'existe pas en S21.
      const mal4 = BibleLink('Mal', 4, from: 1);
      expect(kCanonVersification.isValid(mal4), isTrue);
      expect(_divergente.isValid(mal4), isFalse);
      // La garde d'origine tient toujours (chapitre hors bornes, plage).
      expect(_divergente.isValid(const BibleLink('John', 22)), isFalse);
      expect(
        _divergente.isValid(const BibleLink('Exod', 7, from: 28, to: 30)),
        isFalse,
      );
    });

    test('une référence tapée suit la version ouverte', () {
      expect(parseBibleReference('Exode 7:29'), isNull, reason: 'canon');
      expect(
        parseBibleReference('Exode 7:29', versification: _divergente)?.toUrl(),
        'nv://bible/Exod/7/29',
      );
      expect(
        parseBibleReference('Malachie 4:1', versification: _divergente),
        isNull,
      );
      expect(
          parseBibleReference('Malachie 4:1')?.toUrl(), 'nv://bible/Mal/4/1');
    });

    test('se relit telle quelle, et se compare par ce qu\'elle dit', () {
      final relue = BibleVersification.tryParse(_json(_divergente));
      expect(relue, _divergente);
      expect(relue, isNot(kCanonVersification));
      expect(relue!.versesIn('Exod', 7), 29);
      expect(relue.chapterCount('Mal'), 3);
      // Les clés hors du canon et l'ordre des clés ne comptent pas.
      expect(
        BibleVersification.tryParse('{"Mal":[1],"Gen":[1],"Zzz":[1]}')!.books,
        ['Gen', 'Mal'],
      );
      // Illisible ou vide : le canon figé reprendra la main.
      expect(BibleVersification.tryParse(null), isNull);
      expect(BibleVersification.tryParse(''), isNull);
      expect(BibleVersification.tryParse('['), isNull);
      expect(BibleVersification.tryParse('[1,2]'), isNull);
      expect(BibleVersification.tryParse('{"Gen":["x"]}'), isNull);
      expect(BibleVersification.tryParse('{"Zzz":[1]}'), isNull);
      expect(BibleVersification.tryParse(jsonEncode({'Gen': <int>[]})), isNull);
    });
  });

  group('Le catalogue', () {
    test('chaque version installée rend la versification de sa ligne', () {
      final catalog = MergedBibleCatalog(
        remote: [_served(1, 'KJV'), _served(2, 'EWE'), _served(3, 'LSG')],
        installed: [
          _installed('KJV'),
          _installed('EWE', versification: _json(_divergente)),
          _installed('LSG', versification: 'ceci n\'est pas du JSON'),
        ],
      );
      // Celle qui en porte une impose la sienne…
      expect(catalog.versificationFor('EWE'), _divergente);
      expect(catalog.versificationFor('EWE').versesIn('Exod', 7), 29);
      // …les autres retombent sur le canon figé : ligne sans relevé, relevé
      // illisible, version non installée, et les deux factices.
      for (final code in ['KJV', 'LSG', 'ZZZ', 'EXA', 'EXB']) {
        expect(catalog.versificationFor(code), kCanonVersification,
            reason: code);
      }
      expect(
        const PlaceholderBibleCatalog().versificationFor('EXA'),
        kCanonVersification,
      );
    });

    test('un relevé qui change change le catalogue (le lecteur le voit)', () {
      final avant = MergedBibleCatalog(
        remote: [_served(1, 'EWE')],
        installed: [_installed('EWE')],
      );
      final apres = MergedBibleCatalog(
        remote: [_served(1, 'EWE')],
        installed: [_installed('EWE', versification: _json(_divergente))],
      );
      expect(apres, isNot(avant));
      expect(
        MergedBibleCatalog(
          remote: [_served(1, 'EWE')],
          installed: [_installed('EWE', versification: _json(_divergente))],
        ),
        apres,
        reason: 'même relevé, même catalogue : rien ne se recharge',
      );
    });
  });

  group('La grille', () {
    // Un seul montage par test : deux `pumpScreen` dans le même test ouvrent
    // deux bases Drift, et la minuterie d'annulation de la première reste
    // pendante au démontage.
    Future<void> open(WidgetTester tester, String version, String book) =>
        pumpScreen(
          tester,
          // Le mode sélection : depuis le 28/10/2026, c'est le seul qui
          // montre la grille des versets — l'onglet Bible ouvre le texte.
          Scaffold(
            body: BibleBrowser(
              initialBook: book,
              mode: BibleBrowserMode.select,
            ),
          ),
          overrides: [
            bibleCatalogProvider.overrideWithValue(_TwoVersions(version)),
            // Un flux nu : lue depuis le magasin, ma position ouvrirait un
            // flux Drift que l'horloge factice fige au démontage.
            bibleReadingStateProvider.overrideWith((ref) => Stream.value(null)),
          ],
        );

    /// Ouvre la grille des versets du chapitre [chapter]. Pas de
    /// `pumpAndSettle` : le fond de l'appli anime à l'infini.
    Future<void> tapChapter(WidgetTester tester, int chapter) async {
      await tester.tap(find.byKey(BibleBrowser.chapterKey(chapter)));
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('le canon figé propose les quatre chapitres de Malachie',
        (tester) async {
      await open(tester, 'KJV', 'Mal');
      expect(find.byKey(BibleBrowser.chapterKey(3)), findsOneWidget);
      expect(find.byKey(BibleBrowser.chapterKey(4)), findsOneWidget);
    });

    /*
     * **Le titre suit la version ouverte**, demandé le 30/10/2026. Ce test
     * garde le *branchement* : `labelIn` et `languageFor` sont couverts à
     * part, mais rien ne disait que l'écran les lisait — et un écran branché
     * sur la langue de l'application aurait passé tous les autres verts.
     */
    testWidgets('en éwé le livre s\'intitule « Malaki », pas « Malachie »',
        (tester) async {
      await open(tester, 'EWE', 'Mal');
      expect(find.text('Malaki'), findsOneWidget);
      expect(find.text('Malachie'), findsNothing);
    });

    testWidgets('et la version française garde « Malachie »', (tester) async {
      await open(tester, 'KJV', 'Mal');
      expect(find.text('Malachie'), findsOneWidget);
    });

    /*
     * **Et le titre est écrit dans une police qui sait l'écrire.** « Malaki »
     * n'a aucune lettre particulière, mais « 1 Mɔse » si : un écran qui rend le
     * bon nom dans la mauvaise police affiche un carré vide, et le test du nom
     * ci-dessus passerait au vert sans rien voir.
     */
    testWidgets('en éwé le titre passe dans la police de l\'écriture',
        (tester) async {
      await open(tester, 'EWE', 'Mal');
      final titre = tester.widget<Text>(find.text('Malaki'));
      expect(titre.style?.fontFamily, kScriptFontFamily);
    });

    testWidgets('en français il garde la police de l\'application',
        (tester) async {
      await open(tester, 'KJV', 'Mal');
      final titre = tester.widget<Text>(find.text('Malachie'));
      expect(titre.style?.fontFamily, AppTypography.fontFamily);
    });

    testWidgets('la version qui n\'a pas Malachie 4 ne le propose pas',
        (tester) async {
      await open(tester, 'EWE', 'Mal');
      expect(find.byKey(BibleBrowser.chapterKey(3)), findsOneWidget);
      expect(find.byKey(BibleBrowser.chapterKey(4)), findsNothing);
      // Et le livre s'annonce avec trois chapitres, pas quatre.
      expect(_divergente.chapterCount('Mal'), 3);
    });

    testWidgets('les versets sont ceux de la version : Exode 7 en a 29',
        (tester) async {
      await open(tester, 'EWE', 'Exod');
      await tapChapter(tester, 7);
      await tester.scrollUntilVisible(
        find.byKey(BibleBrowser.verseKey(29)),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.byKey(BibleBrowser.verseKey(29)), findsOneWidget);
    });

    testWidgets('le canon figé, lui, s\'arrête au 25e', (tester) async {
      await open(tester, 'KJV', 'Exod');
      await tapChapter(tester, 7);
      await tester.scrollUntilVisible(
        find.byKey(BibleBrowser.verseKey(25)),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.byKey(BibleBrowser.verseKey(25)), findsOneWidget);
      expect(find.byKey(BibleBrowser.verseKey(26)), findsNothing);
    });
  });

  group('L\'index plein texte', () {
    late AppDatabase db;

    setUp(() => db = openTestDatabase());
    tearDown(() => db.close());

    test('complet selon la versification de la version, pas celle du canon',
        () async {
      final catalog = _OneVersion('TINY', _tiny);
      final index = BibleSearchIndex(db, catalog);
      await index.ensureIndexed('TINY');

      // Sept versets : Genèse 1 (3), Genèse 2 (2), Malachie 1 (2).
      expect(await _rows(db, "version_code = 'TINY'"), 7);
      expect(await index.isIndexed('TINY'), isTrue);

      // Rien d'Apocalypse 22, le dernier chapitre du canon — un jugement
      // fondé sur le canon aurait donc répondu « incomplet », et reconstruit
      // l'index à chaque ouverture de la recherche. La mesure :
      expect(await _rows(db, "version_code = 'TINY' AND book = 'Rev'"), 0);
      expect(
        await BibleSearchIndex(
          db,
          _OneVersion('TINY', kCanonVersification, source: _tiny),
        ).isIndexed('TINY'),
        isFalse,
        reason: 'le même index, jugé sur le canon : incomplet pour toujours',
      );

      // Un second appel ne refait rien, et le chapitre que la version n'a pas
      // n'est pas indexé.
      await index.ensureIndexed('TINY');
      expect(await _rows(db, "version_code = 'TINY'"), 7);
      expect(
        await _rows(db, "version_code = 'TINY' AND book = 'Mal'"),
        2,
        reason: 'Malachie 2 est à 0 verset dans cette version',
      );
      final hits = await index.search('amen', versions: ['TINY']);
      expect(hits.total, 7);
    });
  });
}
