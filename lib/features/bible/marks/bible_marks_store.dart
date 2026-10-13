/// **Mes marques** (M2, #200) : favoris, surlignages, marque-pages.
///
/// Écrit **seulement** `local_bible_marks` (ADR-0026 : le miroir `bible_marks`
/// appartient à la synchronisation). Lecture fusionnée : la ligne locale si elle
/// existe — une tombstone locale masque la ligne du miroir —, sinon (membre
/// seulement) le miroir. Un invité ne lit jamais le miroir.
library;

import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../data/local/app_database.dart';
import '../../../state/sync_providers.dart';
import '../data/bible_providers.dart';
import '../data/canon.dart';

/// `favorite | highlight | bookmark` — les valeurs du fil.
enum BibleMarkKind { favorite, highlight, bookmark }

/// La palette fixe des surlignages (décision 13), dans l'ordre du menu.
const Map<String, Color> bibleHighlightColors = {
  'yellow': Color(0xFFFFD54F),
  'green': Color(0xFF81C784),
  'blue': Color(0xFF64B5F6),
  'pink': Color(0xFFF48FB1),
  'purple': Color(0xFFB39DDB),
};

/// Le fond d'un verset surligné : la teinte, adoucie (lisible clair et sombre).
Color bibleHighlightBackground(String? color) =>
    (bibleHighlightColors[color] ?? bibleHighlightColors['yellow']!).withValues(
      alpha: 0.4,
    );

@immutable
class BibleMark {
  const BibleMark({
    required this.id,
    required this.kind,
    required this.book,
    required this.chapter,
    this.verseFrom,
    this.verseTo,
    this.color,
    required this.updatedAt,
  });

  final String id;
  final BibleMarkKind kind;
  final String book;
  final int chapter;
  final int? verseFrom;
  final int? verseTo;
  final String? color;
  final DateTime updatedAt;

  BibleLink get link => BibleLink(
        book,
        chapter,
        from: verseFrom,
        to: verseTo == verseFrom ? null : verseTo,
      );

  /// Le verset [v] est-il couvert ? Une marque sans verset couvre le chapitre.
  bool covers(int v) =>
      verseFrom == null || (v >= verseFrom! && v <= (verseTo ?? verseFrom!));

  /// La plage touche-t-elle `from..to` ?
  bool overlaps(int from, int to) =>
      verseFrom == null ||
      (verseFrom! <= to && (verseTo ?? verseFrom!) >= from);
}

class BibleMarksStore {
  BibleMarksStore(this._db, {DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _now;

  /// Les marques vivantes, les plus récentes d'abord. [book]/[chapter]
  /// restreignent à un chapitre.
  Stream<List<BibleMark>> watch({
    required bool member,
    String? book,
    int? chapter,
  }) {
    final where = book == null ? '' : 'WHERE book = ? AND chapter = ? ';
    final mirror = member
        ? 'UNION ALL SELECT s.id, s.kind, s.book, s.chapter, s.verse_from, '
            's.verse_to, s.color, coalesce(s.updated_at, s.client_updated_at) '
            'AS at, NULL AS deleted_at FROM bible_marks s '
            'WHERE NOT EXISTS (SELECT 1 FROM local_bible_marks l '
            'WHERE l.id = s.id) '
        : '';
    return _db
        .customSelect(
          'SELECT * FROM (SELECT id, kind, book, chapter, verse_from, '
          'verse_to, color, client_updated_at AS at, deleted_at '
          'FROM local_bible_marks $mirror) '
          '${where.isEmpty ? 'WHERE' : '${where}AND'} deleted_at IS NULL '
          'ORDER BY at DESC, id DESC',
          variables: [
            if (book != null) Variable.withString(book),
            if (chapter != null) Variable.withInt(chapter),
          ],
          readsFrom: {_db.localBibleMarks, _db.bibleMarks},
        )
        .watch()
        .map(
          (rows) => [
            for (final r in rows)
              if (BibleMarkKind.values.asNameMap()[r.read<String>('kind')]
                  case final kind?)
                BibleMark(
                  id: r.read<String>('id'),
                  kind: kind,
                  book: r.read<String>('book'),
                  chapter: r.read<int>('chapter'),
                  verseFrom: r.readNullable<int>('verse_from'),
                  verseTo: r.readNullable<int>('verse_to'),
                  color: r.readNullable<String>('color'),
                  updatedAt: DateTime.fromMillisecondsSinceEpoch(
                    (r.readNullable<int>('at') ?? 0) * 1000,
                    isUtc: true,
                  ),
                ),
          ],
        );
  }

  Future<List<BibleMark>> _chapter(bool member, String book, int chapter) =>
      watch(member: member, book: book, chapter: chapter).first;

  /// Favori sur [link] : posé s'il n'existe pas à cet endroit, retiré sinon.
  Future<void> toggleFavorite({
    required bool member,
    required BibleLink link,
  }) =>
      _toggle(member, BibleMarkKind.favorite, link);

  /// Marque-page du chapitre : posé ou retiré.
  Future<void> toggleBookmark({
    required bool member,
    required String book,
    required int chapter,
  }) =>
      _toggle(member, BibleMarkKind.bookmark, BibleLink(book, chapter));

  Future<void> _toggle(bool member, BibleMarkKind kind, BibleLink link) async {
    final from = link.from;
    final to = link.to ?? from;
    final same = (await _chapter(member, link.book, link.chapter)).where(
      (m) =>
          m.kind == kind &&
          m.verseFrom == from &&
          (m.verseTo ?? m.verseFrom) == to,
    );
    if (same.isNotEmpty) {
      for (final m in same) {
        await remove(member: member, mark: m);
      }
      return;
    }
    await _add(kind, link);
  }

  /// Surligne [link] en [color] ; `null` efface. Les surlignages qui touchent
  /// la sélection sont retirés d'abord : un verset n'a qu'une couleur.
  Future<void> highlight({
    required bool member,
    required BibleLink link,
    String? color,
  }) async {
    assert(color == null || bibleHighlightColors.containsKey(color));
    final from = link.from ?? 1;
    final to = link.to ?? from;
    for (final m in await _chapter(member, link.book, link.chapter)) {
      if (m.kind == BibleMarkKind.highlight && m.overlaps(from, to)) {
        await remove(member: member, mark: m);
      }
    }
    if (color != null) await _add(BibleMarkKind.highlight, link, color: color);
  }

  Future<void> _add(BibleMarkKind kind, BibleLink link, {String? color}) {
    final now = _now().toUtc();
    return _db.into(_db.localBibleMarks).insert(
          LocalBibleMarksCompanion.insert(
            id: const Uuid().v7(),
            kind: kind.name,
            book: link.book,
            chapter: link.chapter,
            verseFrom: Value(link.from),
            verseTo: Value(link.from == null ? null : (link.to ?? link.from)),
            color: Value(color),
            clientCreatedAt: now,
            clientUpdatedAt: now,
          ),
        );
  }

  /// Retire [mark]. Invité : la ligne locale disparaît. Membre : tombstone
  /// locale, que la file d'envoi transforme en `DELETE`.
  Future<void> remove({required bool member, required BibleMark mark}) {
    final t = _db.localBibleMarks;
    if (!member) {
      return (_db.delete(t)..where((r) => r.id.equals(mark.id))).go();
    }
    final now = _now().toUtc();
    return _db.into(t).insertOnConflictUpdate(
          LocalBibleMarksCompanion.insert(
            id: mark.id,
            kind: mark.kind.name,
            book: mark.book,
            chapter: mark.chapter,
            verseFrom: Value(mark.verseFrom),
            verseTo: Value(mark.verseTo),
            color: Value(mark.color),
            clientCreatedAt: now,
            clientUpdatedAt: now,
            deletedAt: Value(now),
            dirty: const Value(true),
          ),
        );
  }

  /// Les versets de [book] [chapter] cités par une de mes notes (lien
  /// `nv://bible/<livre>/<chapitre>/<de>[-<à>]` dans le contenu). Un lien de
  /// chapitre entier ne marque aucun verset.
  Stream<Set<int>> watchNotedVerses(String book, int chapter) {
    final prefix = 'nv://bible/$book/$chapter/';
    final like = '%$prefix%';
    final pattern = RegExp('${RegExp.escape(prefix)}(\\d+)(?:-(\\d+))?');
    return _db
        .customSelect(
          'SELECT content FROM local_notes WHERE content LIKE ? '
          'UNION ALL SELECT s.content FROM spiritual_notes s '
          'WHERE s.content LIKE ? AND NOT EXISTS '
          '(SELECT 1 FROM local_notes l WHERE l.id = s.id)',
          variables: [Variable.withString(like), Variable.withString(like)],
          readsFrom: {_db.localNotes, _db.spiritualNotes},
        )
        .watch()
        .map(
          (rows) => {
            for (final r in rows)
              for (final m in pattern.allMatches(
                r.readNullable<String>('content') ?? '',
              ))
                for (var v = int.parse(m.group(1)!);
                    v <= int.parse(m.group(2) ?? m.group(1)!);
                    v++)
                  v,
          },
        );
  }
}

final bibleMarksStoreProvider = Provider<BibleMarksStore>(
  (ref) => BibleMarksStore(ref.watch(appDatabaseProvider)),
);

/// Toutes mes marques vivantes (onglet Favori).
final bibleMarksProvider = StreamProvider<List<BibleMark>>(
  (ref) => ref
      .watch(bibleMarksStoreProvider)
      .watch(member: ref.watch(bibleIsMemberProvider)),
);

/// Mes marques d'un chapitre (lecteur).
final bibleChapterMarksProvider =
    StreamProvider.family<List<BibleMark>, ({String book, int chapter})>(
  (ref, c) => ref.watch(bibleMarksStoreProvider).watch(
        member: ref.watch(bibleIsMemberProvider),
        book: c.book,
        chapter: c.chapter,
      ),
);

/// Les versets d'un chapitre cités par une note — membres seulement (un
/// invité n'a pas de notes).
final bibleNotedVersesProvider =
    StreamProvider.family<Set<int>, ({String book, int chapter})>(
  (ref, c) => ref.watch(bibleIsMemberProvider)
      ? ref.watch(bibleMarksStoreProvider).watchNotedVerses(c.book, c.chapter)
      : Stream.value(const {}),
);
