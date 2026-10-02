/// Les trois dessins d'un contenu de médiathèque à l'accueil.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n_extension.dart';
import '../../models/content_view.dart';
import '../../state/player_providers.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../cards/content_cover.dart';
import 'home_section_layout.dart';

/// Grande carte paysage : le visuel porte le texte.
class HomeHeroCard extends StatelessWidget {
  const HomeHeroCard({super.key, required this.content, this.onTap});

  final ContentView content;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final author = content.authorName;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: kHeroCoverSize.width,
        height: kHeroCoverSize.height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            boxShadow: AppShadows.elevation1,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ContentCover(
                content: content,
                radius: AppRadius.xl,
                orientation: CoverOrientation.landscape,
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.xl),
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Color(0xD9000000), Color(0x00000000)],
                      stops: [0.05, 0.75],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (author != null) ...[
                      Text(
                        author.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                    ],
                    Text(
                      content.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.h4.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Carte portrait : le tap sur le contenu ouvre la fiche, le bouton joue sur place.
class HomeCarouselCard extends ConsumerWidget {
  const HomeCarouselCard({
    super.key,
    required this.content,
    this.onTap,
    this.onPlay,
  });

  final ContentView content;
  final VoidCallback? onTap;
  final Future<void> Function()? onPlay;

  static const double width = 264;

  static Key playButtonKey(String contentId) =>
      ValueKey('home_content_play_$contentId');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final author = content.authorName;
    final playback = ref.watch(
      contentPlaybackProvider.select(
        (state) => (
          contentId: state.contentId,
          isPlaying: state.isPlaying,
          isBuffering: state.isBuffering,
        ),
      ),
    );
    final isThisPlaying =
      playback.contentId == content.id && playback.isPlaying;
    final isThisBuffering =
      playback.contentId == content.id && playback.isBuffering;

    return Container(
      width: width,
      height: kCarouselCoverSize.height,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: palette.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          InkWell(
            onTap: onTap,
            child: SizedBox(
              width: kCarouselCoverSize.width,
              child: ContentCover(content: content, radius: 0),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: onTap,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              content.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.bodyStrong
                                  .copyWith(color: palette.textPrimary),
                            ),
                            if (author != null) ...[
                              const SizedBox(height: AppSpacing.sm),
                              Row(
                                children: [
                                  Icon(Icons.person_outline,
                                      size: 13, color: palette.textSecondary),
                                  const SizedBox(width: AppSpacing.xs),
                                  Expanded(
                                    child: Text(
                                      author,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.caption.copyWith(
                                        color: palette.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _HomeListenButton(
                    key: playButtonKey(content.id),
                    onPlay: onPlay,
                    isPlaying: isThisPlaying,
                    isBuffering: isThisBuffering,
                    listenLabel: context.l10n.actionListen,
                    pauseLabel: context.l10n.actionPause,
                    loadingLabel: context.l10n.actionLoading,
                    color: palette.primary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ligne de liste : le contenu ouvre la fiche, le bouton agit sur la lecture.
class HomeListRow extends ConsumerWidget {
  const HomeListRow({
    super.key,
    required this.content,
    this.onTap,
    this.onPlay,
  });

  final ContentView content;
  final VoidCallback? onTap;
  final Future<void> Function()? onPlay;

  static Key playButtonKey(String contentId) =>
      ValueKey('home_content_play_$contentId');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final author = content.authorName;
    final playback = ref.watch(
      contentPlaybackProvider.select(
        (state) => (
          contentId: state.contentId,
          isPlaying: state.isPlaying,
          isBuffering: state.isBuffering,
        ),
      ),
    );
    final isThisPlaying =
      playback.contentId == content.id && playback.isPlaying;
    final isThisBuffering =
      playback.contentId == content.id && playback.isBuffering;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onTap,
              child: Row(
                children: [
                  SizedBox(
                    width: kListCoverSize.width,
                    height: kListCoverSize.height,
                    child: ContentCover(content: content, radius: AppRadius.md),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          content.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodyStrong
                              .copyWith(color: palette.textPrimary),
                        ),
                        if (author != null) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            author,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption
                                .copyWith(color: palette.textSecondary),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _HomeListenButton(
            key: playButtonKey(content.id),
            onPlay: onPlay,
            isPlaying: isThisPlaying,
            isBuffering: isThisBuffering,
            listenLabel: context.l10n.actionListen,
            pauseLabel: context.l10n.actionPause,
            loadingLabel: context.l10n.actionLoading,
            color: palette.primary,
            iconOnly: true,
          ),
        ],
      ),
    );
  }
}

class _HomeListenButton extends StatefulWidget {
  const _HomeListenButton({
    super.key,
    required this.onPlay,
    required this.isPlaying,
    required this.isBuffering,
    required this.listenLabel,
    required this.pauseLabel,
    required this.loadingLabel,
    required this.color,
    this.iconOnly = false,
  });

  final Future<void> Function()? onPlay;
  final bool isPlaying;
  final bool isBuffering;
  final String listenLabel;
  final String pauseLabel;
  final String loadingLabel;
  final Color color;
  final bool iconOnly;

  @override
  State<_HomeListenButton> createState() => _HomeListenButtonState();
}

class _HomeListenButtonState extends State<_HomeListenButton> {
  bool _requestPending = false;

  Future<void> _play() async {
    final action = widget.onPlay;
    if (action == null || _requestPending || widget.isBuffering) return;

    setState(() => _requestPending = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _requestPending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = _requestPending || (widget.isBuffering && !widget.isPlaying);
    final label = widget.isPlaying ? widget.pauseLabel : widget.listenLabel;
    final Widget icon = loading
        ? SizedBox.square(
            dimension: widget.iconOnly ? 22 : 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: widget.color,
            ),
          )
        : Icon(
            widget.isPlaying
                ? widget.iconOnly
                    ? Icons.pause_circle_filled_rounded
                    : Icons.pause_rounded
                : widget.iconOnly
                    ? Icons.play_circle_fill
                    : Icons.play_arrow_rounded,
            size: widget.iconOnly ? 30 : 18,
          );

    if (widget.iconOnly) {
      return IconButton(
        tooltip: loading ? widget.loadingLabel : label,
        onPressed: loading ? null : _play,
        color: widget.color,
        icon: icon,
      );
    }

    return OutlinedButton.icon(
      onPressed: loading ? null : _play,
      style: OutlinedButton.styleFrom(
        foregroundColor: widget.color,
        side: BorderSide(color: widget.color.withValues(alpha: 0.45)),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        visualDensity: VisualDensity.compact,
      ),
      icon: icon,
      label: Text(label),
    );
  }
}
