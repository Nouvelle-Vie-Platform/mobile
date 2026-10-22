/// **La versification** (C3, #240, décision 2 de server-portal#605) : combien
/// de versets porte chaque chapitre, **dans une version donnée**.
///
/// Les traductions ne sont pas d'accord entre elles — mesuré sur les huit
/// sources du chantier, contre la KJV : éwé 1913 146 chapitres renumérotés,
/// S21 140, Darby anglaise 62, éwé 2020 1, Darby française 0. Un canon figé
/// jugeait donc **invalides** les versets que la traduction ouverte a en plus
/// (Exode 7 en éwé 1913 : 29 versets là où le canon en compte 25).
///
/// D'où ce type : une versification est une **valeur**, portée par la version
/// installée (`bible_installed_versions.versification`). Le canon figé en est
/// une aussi ([kCanonVersification], `canon.dart`), et reste le repli de la
/// Bible factice et de toute version qui n'en déclare pas.
///
/// Un chapitre à **0 verset n'existe pas** dans cette version — la S21 n'a pas
/// de Malachie 4, elle suit la Bible hébraïque (vérifié : sa Malachie 3 compte
/// 24 versets, les 18 + 6 de la KJV). Il ne paraît alors ni dans [chaptersOf],
/// ni dans [chapters], ni dans [chapterCount] : la grille ne le propose pas.
/// Pur Dart.
library;

import 'dart:convert';

import '../../notes_editor/links/note_link.dart';

final class BibleVersification {
  BibleVersification._(this._counts);

  /// Une versification relevée : `{ "<OSIS>": [versets du chapitre 1, …] }`.
  /// Les livres inconnus du canon sont ignorés, et l'ordre rendu est toujours
  /// celui du canon — jamais celui des clés.
  factory BibleVersification.of(Map<String, List<int>> counts) =>
      BibleVersification._({
        for (final osis in osisBooksFr.keys)
          if (counts[osis] != null) osis: List.unmodifiable(counts[osis]!),
      });

  /// La versification stockée avec une version installée, ou `null` si la
  /// colonne est vide ou illisible — l'appelant retombe alors sur le canon.
  static BibleVersification? tryParse(String? json) {
    if (json == null || json.isEmpty) return null;
    try {
      final decoded = jsonDecode(json);
      if (decoded is! Map) return null;
      final counts = <String, List<int>>{};
      for (final e in decoded.entries) {
        final key = e.key;
        final value = e.value;
        if (key is! String || value is! List) return null;
        final chapters = <int>[];
        for (final n in value) {
          if (n is! int) return null;
          chapters.add(n);
        }
        counts[key] = chapters;
      }
      final v = BibleVersification.of(counts);
      return v.books.isEmpty ? null : v;
    } on FormatException {
      return null;
    }
  }

  final Map<String, List<int>> _counts;

  /// Les livres de cette version, dans l'ordre du canon : ceux qui ont au
  /// moins un chapitre. L'éwé 2014 n'a ni Esther ni Daniel (décision 3 du
  /// PRD : comblés depuis l'éwé 1913, tranche C5).
  late final List<String> books = List.unmodifiable([
    for (final e in _counts.entries)
      if (e.value.any((n) => n > 0)) e.key,
  ]);

  /// Les chapitres **existants** de [book], dans l'ordre.
  List<int> chaptersOf(String book) {
    final counts = _counts[book];
    if (counts == null) return const [];
    return [
      for (final (i, n) in counts.indexed)
        if (n > 0) i + 1,
    ];
  }

  /// Combien de chapitres [book] a **dans cette version** (0 s'il n'y est
  /// pas). Un chapitre vide ne compte pas : « Malachie — 3 chapitres » en S21.
  int chapterCount(String book) =>
      _counts[book]?.where((n) => n > 0).length ?? 0;

  /// Versets de [book] [chapter] (1-indexé) ; 0 si le chapitre n'existe pas.
  int versesIn(String book, int chapter) {
    final counts = _counts[book];
    if (counts == null || chapter < 1 || chapter > counts.length) return 0;
    return counts[chapter - 1];
  }

  /// **Tous les chapitres de cette version par leur rang global** : c'est ce
  /// qui permet au lecteur de glisser d'un livre à l'autre sans rupture.
  late final List<({String book, int chapter})> chapters = List.unmodifiable([
    for (final b in books)
      for (final c in chaptersOf(b)) (book: b, chapter: c),
  ]);

  late final Map<String, int> _firstChapterIndex = () {
    final firsts = <String, int>{};
    for (final (i, c) in chapters.indexed) {
      firsts.putIfAbsent(c.book, () => i);
    }
    return firsts;
  }();

  /// Le rang global de [book] [chapter] dans cette version, ou `-1`.
  int chapterIndex(String book, int chapter) {
    final first = _firstChapterIndex[book];
    if (first == null) return -1;
    final rank = chaptersOf(book).indexOf(chapter);
    return rank < 0 ? -1 : first + rank;
  }

  /// Une référence tient-elle dans cette version ? (livre connu, chapitre
  /// existant, versets dans les bornes, `from ≤ to`).
  bool isValid(BibleLink ref) {
    final verses = versesIn(ref.book, ref.chapter);
    if (verses == 0) return false;
    final from = ref.from;
    final to = ref.to ?? from;
    if (from == null) return true;
    return from >= 1 && to! >= from && to <= verses;
  }

  /// Ce que cette versification dit, en une chaîne : deux versifications qui
  /// disent la même chose sont **égales**, et le provider ne prévient
  /// personne — sinon chaque émission du magasin remonterait le lecteur au
  /// chapitre courant (même règle que la signature de `MergedBibleCatalog`).
  late final String signature =
      jsonEncode({for (final b in books) b: _counts[b]});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BibleVersification && other.signature == signature;

  @override
  int get hashCode => signature.hashCode;
}
