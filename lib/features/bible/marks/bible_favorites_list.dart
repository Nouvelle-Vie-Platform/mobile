/// **L'écran Favoris** (M2, #200, décision 4) : une liste filtrable — versets
/// favoris, chapitres marqués, passages surlignés. Carte : référence, extrait
/// dans la version active, couleur, date. Toucher ouvre le lecteur, glisser
/// retire.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../l10n/l10n_extension.dart';
import '../../../router/app_router.dart';
import '../../../theme/app_palette.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/app_empty_state.dart';
import '../data/bible_providers.dart';
import '../reader/bible_reader_screen.dart';
import 'bible_marks_store.dart';

class BibleFavoritesList extends ConsumerWidget {
  const BibleFavoritesList({super.key, this.kind});

  /// `null` : toutes les marques.
  final BibleMarkKind? kind;

  static Key cardKey(String id) => Key('bible_mark_$id');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final marks = [
      for (final m
          in ref.watch(bibleMarksProvider).value ?? const <BibleMark>[])
        if (kind == null || m.kind == kind) m,
    ];
    if (marks.isEmpty) {
      return ListView(
        padding: AppSpacing.screenPadding.copyWith(top: AppSpacing.xxl),
        children: [
          AppEmptyState(
            title: context.l10n.bibleM2EmptyTitle,
            message: context.l10n.bibleM2Empty,
            icon: Icons.star_outline,
          ),
        ],
      );
    }
    return ListView.separated(
      padding: AppSpacing.screenPadding.copyWith(bottom: AppSpacing.xxl),
      itemCount: marks.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, i) => _MarkCard(mark: marks[i]),
    );
  }
}

class _MarkCard extends ConsumerWidget {
  const _MarkCard({required this.mark});

  final BibleMark mark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final version = ref.watch(activeBibleVersionProvider);
    final verses = ref
            .watch(
              bibleChapterProvider((
                version: version,
                book: mark.book,
                chapter: mark.chapter,
              )),
            )
            .value ??
        const [];
    final excerpt = [
      for (final v in verses)
        if (mark.covers(v.number)) v.text,
    ].join(' ');
    final tint = switch (mark.kind) {
      BibleMarkKind.highlight => bibleHighlightColors[mark.color],
      BibleMarkKind.favorite => Colors.redAccent,
      BibleMarkKind.bookmark => palette.primary,
    };
    final icon = switch (mark.kind) {
      BibleMarkKind.highlight => Icons.format_color_fill,
      BibleMarkKind.favorite => Icons.favorite,
      BibleMarkKind.bookmark => Icons.bookmark,
    };
    final date = DateFormat.yMd(context.l10n.intlLocale)
        .format(mark.updatedAt.toLocal());
    return Dismissible(
      key: BibleFavoritesList.cardKey(mark.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        color: Colors.red.shade400,
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => unawaited(
        ref
            .read(bibleMarksStoreProvider)
            .remove(member: ref.read(bibleIsMemberProvider), mark: mark),
      ),
      child: Card(
        margin: EdgeInsets.zero,
        color: mark.kind == BibleMarkKind.highlight
            ? bibleHighlightBackground(mark.color)
            : palette.surface,
        child: InkWell(
          onTap: () => unawaited(
            BibleReaderScreen.push(ref.read(routerProvider), mark.link),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: tint, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(mark.link.labelFr, style: AppTypography.bodyStrong),
                      if (excerpt.isNotEmpty)
                        Text(
                          excerpt,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.body.copyWith(
                            color: palette.textSecondary,
                          ),
                        ),
                      Text(
                        date,
                        style: AppTypography.caption.copyWith(
                          color: palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
