/// **L'index plein texte de la Bible** (M3, #201, décision 18) : le
/// remplissage de `bible_fts` et la recherche dedans.
///
/// - [BibleSearchIndex.ensureIndexed] construit l'index d'une version
///   installée, **un livre par transaction** (la boucle d'événements respire
///   entre deux livres), et ne refait rien quand il est déjà complet. M4
///   l'appelle après une installation ; l'écran de recherche l'appelle pour
///   chaque version installée à son ouverture (c'est ce qui indexe les deux
///   versions factices, qui n'ont pas de ligne `bible_installed_versions`).
/// - **Complet** = le premier et le dernier verset du canon sont indexés avec
///   le texte que la source rend aujourd'hui, et, si la version a une ligne
///   `bible_installed_versions`, son drapeau `indexed` est levé. Une version
///   réinstallée (M4 réécrit la ligne, `indexed` retombe à `false`) ou dont le
///   texte a changé est donc reconstruite.
/// - [BibleSearchIndex.search] : mots dans une ou plusieurs versions, filtre
///   par testament ou par livre, résultats **regroupés par verset** dans
///   l'ordre du canon, paginés. Le mot trouvé est encadré par
///   [kHitStart] / [kHitEnd] (`highlight()` de FTS5).
library;

import 'dart:math' show min;

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/app_database.dart';
import '../../../state/sync_providers.dart';
import '../data/bible_providers.dart';
import '../data/bible_source.dart';
import '../data/canon.dart';

/// Les marques qui encadrent un mot trouvé dans [BibleSearchText.text].
const String kHitStart = '\u0001';
const String kHitEnd = '\u0002';

/// Où chercher : toute la Bible, un testament, ou un livre.
final class BibleSearchScope {
  const BibleSearchScope._(this.testament, this.book);
  static const all = BibleSearchScope._(null, null);
  static const oldTestament = BibleSearchScope._(Testament.old, null);
  static const newTestament = BibleSearchScope._(Testament.newT, null);
  const BibleSearchScope.book(String osis) : this._(null, osis);

  final Testament? testament;
  final String? book;

  /// Les livres couverts, ou `null` pour toute la Bible.
  List<String>? get books => book != null
      ? [book!]
      : testament == null
          ? null
          : [
              for (final b in bibleCanon)
                if (b.testament == testament) b.osis,
            ];

  @override
  bool operator ==(Object other) =>
      other is BibleSearchScope &&
      other.testament == testament &&
      other.book == book;

  @override
  int get hashCode => Object.hash(testament, book);
}

/// Le texte d'un verset trouvé, dans une version.
typedef BibleSearchText = ({String version, String text});

/// Un verset trouvé, avec son texte dans chaque version où il l'a été.
final class BibleSearchHit {
  const BibleSearchHit(this.link, this.texts);
  final BibleLink link;
  final List<BibleSearchText> texts;
}

/// Une page de résultats ; [total] compte les **versets** (pas les lignes).
final class BibleSearchPage {
  const BibleSearchPage(this.total, this.hits);
  static const empty = BibleSearchPage(0, []);
  final int total;
  final List<BibleSearchHit> hits;
}

/// La requête FTS5 d'une saisie : chaque mot entre guillemets, en préfixe
/// (« berg » trouve « berger »), tous exigés. `null` s'il n'y a aucun mot.
String? ftsQueryOf(String input) {
  final words = RegExp(r'[\p{L}\p{N}]+', unicode: true)
      .allMatches(input)
      .map((m) => '"${m.group(0)}"*')
      .toList();
  return words.isEmpty ? null : words.join(' ');
}

/// Versets par `INSERT` : 200 × 5 variables, sous la borne de SQLite (32 766).
const int _chunk = 200;

final _canonOrder = '|${bibleCanon.map((b) => b.osis).join('|')}|';

class BibleSearchIndex {
  BibleSearchIndex(this._db, this._catalog);

  final AppDatabase _db;
  final BibleCatalog _catalog;
  final Map<String, Future<void>> _building = {};

  /// Construit l'index de [versionCode] s'il n'est pas complet. Deux appels
  /// simultanés partagent la même construction. Sans effet pour une version
  /// non installée.
  Future<void> ensureIndexed(String versionCode) => _building[versionCode] ??=
          // Corps en bloc, exprès : `=> _building.remove(…)` rendrait ce futur
          // lui-même, que `whenComplete` attendrait — il ne finirait jamais.
          _ensure(versionCode).whenComplete(() {
        _building.remove(versionCode);
      });

  Future<void> _ensure(String code) async {
    final source = _catalog.sourceFor(code);
    if (source == null) return;
    if (await isIndexed(code)) return;
    await _db.customStatement(
      'DELETE FROM bible_fts WHERE version_code = ?',
      [code],
    );
    for (final book in bibleCanon) {
      final rows = <List<Object>>[
        for (var c = 1; c <= book.chapterCount; c++)
          for (final v in await source.chapter(book.osis, c))
            [code, book.osis, '$c', '${v.number}', v.text],
      ];
      // Un `INSERT` à plusieurs lignes : dix fois plus rapide qu'un `batch`
      // ligne à ligne (mesuré : 1 533 versets, 70 ms contre 840 ms).
      await _db.transaction(() async {
        for (var i = 0; i < rows.length; i += _chunk) {
          final chunk = rows.sublist(i, min(i + _chunk, rows.length));
          await _db.customStatement(
            'INSERT INTO bible_fts '
            '(version_code, book, chapter, verse, verse_text) VALUES '
            '${List.filled(chunk.length, '(?, ?, ?, ?, ?)').join(', ')}',
            [for (final r in chunk) ...r],
          );
        }
      });
    }
    await (_db.update(_db.bibleInstalledVersions)
          ..where((t) => t.code.equals(code)))
        .write(const BibleInstalledVersionsCompanion(indexed: Value(true)));
  }

  /// L'index de [versionCode] est-il complet et à jour ?
  Future<bool> isIndexed(String versionCode) async {
    final source = _catalog.sourceFor(versionCode);
    if (source == null) return false;
    final row = await (_db.select(_db.bibleInstalledVersions)
          ..where((t) => t.code.equals(versionCode)))
        .getSingleOrNull();
    if (row != null && !row.indexed) return false;
    final first = bibleCanon.first;
    final last = bibleCanon.last;
    for (final (book, chapter) in [
      (first, 1),
      (last, last.chapterCount),
    ]) {
      final verses = await source.chapter(book.osis, chapter);
      if (verses.isEmpty) return false;
      final verse = chapter == 1 ? verses.first : verses.last;
      final stored = await _db.customSelect(
        'SELECT verse_text FROM bible_fts WHERE version_code = ? '
        'AND book = ? AND chapter = ? AND verse = ? LIMIT 1',
        variables: [
          Variable.withString(versionCode),
          Variable.withString(book.osis),
          Variable.withString('$chapter'),
          Variable.withString('${verse.number}'),
        ],
      ).getSingleOrNull();
      if (stored?.read<String>('verse_text') != verse.text) return false;
    }
    return true;
  }

  /// Cherche [text] dans [versions] ; une page de [limit] versets à partir de
  /// [offset], dans l'ordre du canon. Le texte de chaque version suit l'ordre
  /// de [versions].
  Future<BibleSearchPage> search(
    String text, {
    required List<String> versions,
    BibleSearchScope scope = BibleSearchScope.all,
    int offset = 0,
    int limit = 20,
  }) async {
    final match = ftsQueryOf(text);
    if (match == null || versions.isEmpty) return BibleSearchPage.empty;
    final books = scope.books;
    String marks(int n) => List.filled(n, '?').join(', ');
    final where = 'bible_fts MATCH ? '
        'AND version_code IN (${marks(versions.length)})'
        '${books == null ? '' : ' AND book IN (${marks(books.length)})'}';
    final args = <Variable<Object>>[
      Variable.withString(match),
      for (final v in versions) Variable.withString(v),
      for (final b in books ?? const <String>[]) Variable.withString(b),
    ];

    final total = await _db
        .customSelect(
          'SELECT count(*) AS n FROM (SELECT 1 FROM bible_fts WHERE $where '
          'GROUP BY book, chapter, verse)',
          variables: args,
        )
        .getSingle();

    final rows = await _db.customSelect(
      'WITH m AS (SELECT version_code AS v, book AS b, '
      'CAST(chapter AS INTEGER) AS c, CAST(verse AS INTEGER) AS n, '
      "highlight(bible_fts, 4, char(1), char(2)) AS t, "
      "instr(?, '|' || book || '|') AS o FROM bible_fts WHERE $where), "
      'p AS (SELECT b, c, n, min(o) AS o FROM m GROUP BY b, c, n '
      'ORDER BY o, c, n LIMIT ? OFFSET ?) '
      'SELECT m.v, m.b, m.c, m.n, m.t FROM m JOIN p USING (b, c, n) '
      'ORDER BY p.o, p.c, p.n',
      variables: [
        Variable.withString(_canonOrder),
        ...args,
        Variable.withInt(limit),
        Variable.withInt(offset),
      ],
    ).get();

    final hits = <BibleSearchHit>[];
    for (final r in rows) {
      final link = BibleLink(
        r.read<String>('b'),
        r.read<int>('c'),
        from: r.read<int>('n'),
      );
      final last = hits.isEmpty ? null : hits.last.link;
      if (last == null ||
          last.book != link.book ||
          last.chapter != link.chapter ||
          last.from != link.from) {
        hits.add(BibleSearchHit(link, []));
      }
      hits.last.texts.add((version: r.read<String>('v'), text: r.read('t')));
    }
    for (final h in hits) {
      h.texts.sort(
        (a, b) =>
            versions.indexOf(a.version).compareTo(versions.indexOf(b.version)),
      );
    }
    return BibleSearchPage(total.read<int>('n'), hits);
  }
}

final bibleSearchIndexProvider = Provider<BibleSearchIndex>(
  (ref) => BibleSearchIndex(
    ref.watch(appDatabaseProvider),
    ref.watch(bibleCatalogProvider),
  ),
);
