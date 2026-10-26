/// **Les emplacements de la tranche M2 — sélection, menu d'action, Favori, marges du lecteur.**
///
/// Cette tranche n'édite **que** ce fichier pour se brancher sur la coquille
/// et le lecteur ; voir `../README.md`. Le menu flottant lui-même
/// (`bible_verse_menu.dart`) est posé par le lecteur, et la palette de
/// surlignage y vit ; M4 ajoute ses actions (écouter, studio) par
/// `verseActions`, à l'ordre de son choix (M2 occupe 10 à 40).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_extension.dart';
import '../shell/bible_slots.dart';
import 'bible_favorites_list.dart';
import 'bible_marks_store.dart';
import 'bible_verse_actions.dart';

final BibleSlots marksSlots = BibleSlots(
  // L'ordre est celui des références de #250 : note, signet, partage, copie.
  // Le favori les suit — il n'y figure pas, mais personne n'a demandé de le
  // retirer, et il est la seule porte d'entrée de l'onglet Favoris.
  verseActions: [
    BibleVerseAction(
      id: 'note',
      order: 10,
      icon: Icons.edit_note,
      label: (c) => c.l10n.bibleM2Note,
      run: noteOnVerses,
    ),
    // Le signet reste ce qu'il est dans notre modèle : celui du **chapitre**,
    // le même que l'icône de l'en-tête (les deux se reflètent).
    BibleVerseAction(
      id: 'bookmark',
      order: 20,
      icon: Icons.bookmark_border,
      label: (c) => c.l10n.bibleM2Bookmark,
      run: (_, ref, link, __) => toggleChapterBookmark(ref, link),
    ),
    BibleVerseAction(
      id: 'share',
      order: 30,
      icon: Icons.ios_share,
      label: (c) => c.l10n.bibleM2Share,
      run: shareVerses,
    ),
    BibleVerseAction(
      id: 'copy',
      order: 40,
      icon: Icons.copy_outlined,
      label: (c) => c.l10n.bibleM2Copy,
      run: copyVerses,
    ),
    BibleVerseAction(
      id: 'favorite',
      order: 50,
      icon: Icons.favorite_border,
      label: (c) => c.l10n.bibleM2Favorite,
      run: (_, ref, link, __) => toggleFavorite(ref, link),
    ),
  ],
  favoriteFilters: [
    BibleFavoriteFilter(
      id: 'all',
      order: 0,
      label: (c) => c.l10n.bibleM2FilterAll,
      builder: (_) => const BibleFavoritesList(),
    ),
    BibleFavoriteFilter(
      id: 'verses',
      order: 10,
      label: (c) => c.l10n.bibleM2FilterVerses,
      builder: (_) => const BibleFavoritesList(kind: BibleMarkKind.favorite),
    ),
    BibleFavoriteFilter(
      id: 'chapters',
      order: 20,
      label: (c) => c.l10n.bibleM2FilterChapters,
      builder: (_) => const BibleFavoritesList(kind: BibleMarkKind.bookmark),
    ),
    BibleFavoriteFilter(
      id: 'highlights',
      order: 30,
      label: (c) => c.l10n.bibleM2FilterHighlights,
      builder: (_) => const BibleFavoritesList(kind: BibleMarkKind.highlight),
    ),
  ],
  chapterDecorators: [decorateBibleChapter],
);

/// Fond du surlignage le plus récent, cœur d'un favori, icône d'une note.
Map<int, BibleVerseDecoration> decorateBibleChapter(
  WidgetRef ref,
  String book,
  int chapter,
) {
  final key = (book: book, chapter: chapter);
  // Les plus récentes d'abord : le premier surlignage trouvé gagne.
  final marks = [
    for (final m in ref.watch(bibleChapterMarksProvider(key)).value ??
        const <BibleMark>[])
      if (m.verseFrom != null) m,
  ];
  final noted = ref.watch(bibleNotedVersesProvider(key)).value ?? const {};
  final verses = <int>{
    for (final m in marks)
      for (var v = m.verseFrom!; v <= (m.verseTo ?? m.verseFrom!); v++) v,
    ...noted,
  };
  BibleVerseDecoration decorate(int v) {
    final here = marks.where((m) => m.covers(v));
    final highlight =
        here.where((m) => m.kind == BibleMarkKind.highlight).firstOrNull;
    return BibleVerseDecoration(
      background:
          highlight == null ? null : bibleHighlightBackground(highlight.color),
      marginIcons: [
        if (here.any((m) => m.kind == BibleMarkKind.favorite)) Icons.favorite,
        if (noted.contains(v)) Icons.sticky_note_2_outlined,
      ],
    );
  }

  return {for (final v in verses) v: decorate(v)};
}
