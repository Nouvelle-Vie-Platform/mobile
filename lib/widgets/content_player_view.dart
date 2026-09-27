import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:go_router/go_router.dart';

import '../data/local/app_database.dart';
import '../data/local/tables/download_tables.dart';
import '../data/players/content_player.dart';
import '../data/repositories/playback_progress_recorder.dart';
import '../l10n/l10n_extension.dart';
import '../models/content_view.dart';
import '../router/app_router.dart';
import '../state/downloads_providers.dart';
import '../state/playback_progress_providers.dart';
import '../state/player_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_error_state.dart';
import 'content_absence.dart';
import '../core/config/live_stream_config.dart';

const _fallbackBase = Color(kBrandFallbackColor);

/// Le lecteur plein écran d'un contenu de médiathèque ou d'un flux direct.
class ContentPlayerView extends ConsumerStatefulWidget {
  const ContentPlayerView({
    super.key,
    required this.content,
    required this.chromeTitle,
    required this.retractedTitle,
    required this.retractedMessage,
    required this.onRetry,
    this.downloadContentType,
    this.isLive = false,
    this.onStop,
    this.backgroundImage,
  });

  final String? backgroundImage;

  final ProviderListenable<AsyncValue<ContentView?>> content;
  final String chromeTitle;
  final String retractedTitle;
  final String retractedMessage;
  final VoidCallback onRetry;
  final String? downloadContentType;

  /// Mode live : masque les options secondaires et adapte les contrôles.
  final bool isLive;

  /// Rappel pour arrêter la lecture du live.
  final VoidCallback? onStop;

  static const Key bufferingKey = Key('content_player_buffering');
  static const Key downloadButtonKey = Key('content_player_download');

  @override
  ConsumerState<ContentPlayerView> createState() => _ContentPlayerViewState();
}

class _ContentPlayerViewState extends ConsumerState<ContentPlayerView>
    with WidgetsBindingObserver {
  bool _liked = false;
  String? _requested;
  bool _stoppedByRetraction = false;
  PlaybackProgressRecorder? _recorder;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fireAndForget(_recorder?.onLeft());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.paused) return;
    _fireAndForget(_recorder?.onAppPaused());
  }

  void _showInfoSheet(BuildContext context, ContentView content) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: context.palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _ContentInfoSheet(content: content),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<ContentView?>>(widget.content, (_, next) {
      if (next.hasValue && next.value == null) _stopForRetraction();
    });

    ref.listen<ContentPlayback>(contentPlaybackProvider, _onPlayback);

    return ref.watch(widget.content).when(
          loading: () => _buildLoading(context),
          error: (_, __) => _buildError(context),
          data: (content) => switch (content) {
            null => _buildAbsent(context),
            final found when found.playlistUrl == null =>
              _buildNoMedia(context, found),
            final found => _buildPlayer(context, found),
          },
        );
  }

  Widget _buildLoading(BuildContext context) {
    return _PlayerScaffold(
      base: _fallbackBase,
      backgroundImage: widget.backgroundImage,
      child: Column(
        children: [
          _PlayerTopBar(
            title: widget.chromeTitle,
            isLive: widget.isLive,
          ),
          const Expanded(
            child: Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    return _PlayerScaffold(
      base: _fallbackBase,
      backgroundImage: widget.backgroundImage,
      child: Column(
        children: [
          _PlayerTopBar(
            title: widget.chromeTitle,
            isLive: widget.isLive,
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: AppSpacing.screenPadding,
                child: AppErrorState(
                  message: context.l10n.stateErrorMessage,
                  onRetry: widget.onRetry,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAbsent(BuildContext context) {
    return _PlayerScaffold(
      base: _fallbackBase,
      backgroundImage: widget.backgroundImage,
      child: Column(
        children: [
          _PlayerTopBar(
            title: widget.chromeTitle,
            isLive: widget.isLive,
          ),
          Expanded(
            child: ContentAbsenceView(
              absence: ContentAbsence.retracted,
              onDark: true,
              title: widget.retractedTitle,
              message: widget.retractedMessage,
              onBack: () => context.pop(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoMedia(BuildContext context, ContentView content) {
    return _PlayerScaffold(
      base: Color(content.color),
      backgroundImage: widget.backgroundImage,
      child: Column(
        children: [
          _PlayerTopBar(
            title: widget.chromeTitle,
            isLive: widget.isLive,
            onInfo: widget.isLive ? null : () => _showInfoSheet(context, content),
          ),
          Expanded(
            child: ContentAbsenceView(
              absence: ContentAbsence.noMedia,
              onDark: true,
              onBack: () => context.pop(),
            ),
          ),
        ],
      ),
    );
  }

  void _loadOnce(ContentView content) {
    if (_stoppedByRetraction || _requested == content.id) return;
    _requested = content.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_open(content));
    });
  }

  Future<void> _open(ContentView content) async {
    final url = content.playlistUrl;
    if (url == null) return;

    final player = ref.read(contentPlayerProvider);
    await _openRecorder(content.id);
    if (!mounted) return;

    if (player.value.contentId == content.id) return;

    final resolution = await ref
        .read(downloadResolverProvider)
        .resolve(contentId: content.id, hlsUrl: url);
    if (!mounted) return;

    await player.load(
      contentId: content.id,
      url: url,
      localFilePath: resolution.localFilePath,
      title: content.title,
      author: content.authorName,
      artUrl: content.squareOrLandscape,
    );
    if (!mounted) return;

    final resume = _recorder?.resume;
    if (resume != null &&
        !resume.completed &&
        resume.position > Duration.zero) {
      player.seek(resume.position);
    }

    // --- MODIFICATION ICI ---
    // Ne démarrer automatiquement la lecture QUE pour le flux Live
    if (widget.isLive) {
      player.play();
    }
  }

  Future<void> _openRecorder(String contentId) async {
    if (_recorder?.contentId == contentId) return;
    final open = ref.read(playbackProgressRecorderProvider);
    try {
      final recorder = await open(contentId);
      if (mounted) _recorder = recorder;
    } catch (error, stack) {
      debugPrint('[progression] enregistreur indisponible pour $contentId : $error');
      debugPrintStack(stackTrace: stack, maxFrames: 4);
    }
  }

  void _stopForRetraction() {
    if (_stoppedByRetraction) return;
    _stoppedByRetraction = true;
    final player = ref.read(contentPlayerProvider);
    if (player.value.contentId != _requested) return;
    player.stop();
  }

  void _onPlayback(ContentPlayback? previous, ContentPlayback next) {
    final recorder = _recorder;
    if (recorder == null || next.contentId != recorder.contentId) return;

    if (next.isCompleted && !(previous?.isCompleted ?? false)) {
      _fireAndForget(recorder.onTerminated());
      final player = ref.read(contentPlayerProvider);
      player.pause();
      player.seek(Duration.zero);
      return;
    }

    _fireAndForget(
      recorder.onPosition(
        next.position,
        duration: next.duration,
        isPlaying: next.isPlaying,
      ),
    );
    if ((previous?.isPlaying ?? false) && !next.isPlaying) {
      _fireAndForget(recorder.onPaused());
    }
  }

  void _fireAndForget(Future<void>? work) {
    if (work == null) return;
    unawaited(
      work.catchError((Object error) {
        debugPrint('[progression] déclencheur abandonné : $error');
      }),
    );
  }

  void _togglePlayback(ContentView content) {
    final player = ref.read(contentPlayerProvider);
    if (player.value.contentId != content.id) {
      _stoppedByRetraction = false;
      _requested = content.id;
      unawaited(_open(content));
      return;
    }
    player.value.isPlaying ? player.pause() : player.play();
  }

  Widget _buildPlayer(BuildContext context, ContentView content) {
    _loadOnce(content);

    final base = Color(content.color);
    final author = content.authorName;

    return _PlayerScaffold(
      base: base,
      backgroundImage: widget.backgroundImage,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PlayerTopBar(
              title: widget.chromeTitle,
              isLive: widget.isLive,
              onInfo: widget.isLive ? null : () => _showInfoSheet(context, content),
            ),
            Expanded(
              child: _PlayerStage(
                content: content,
                onResume: () =>
                    unawaited(ref.read(contentPlayerProvider).resume()),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              content.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.w800,
                height: 1.1,
                letterSpacing: -0.5,
              ),
            ),
            if (author != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                author,
                style: AppTypography.h4.copyWith(color: Colors.white),
              ),
            ],
            if (content.typeLabel.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.sell_outlined,
                      color: Colors.white70, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    content.typeLabel,
                    style: AppTypography.caption
                        .copyWith(color: Colors.white.withValues(alpha: 0.7)),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            _Controls(
              isLive: widget.isLive,
              onStop: widget.onStop,
              liked: _liked,
              accent: base,
              onSeek: (position) =>
                  ref.read(contentPlayerProvider).seek(position),
              onPlayPause: () => _togglePlayback(content),
              onLike: () => setState(() => _liked = !_liked),
              onNotes: () => context.pushNamed(AppRoute.notes),
              downloadButton: widget.downloadContentType == null || widget.isLive
                  ? null
                  : _DownloadButton(
                      contentId: content.id,
                      contentType: widget.downloadContentType!,
                    ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}

class _PlayerScaffold extends StatelessWidget {
  const _PlayerScaffold({
    required this.base,
    required this.child,
    this.backgroundImage,
  });

  final Color base;
  final Widget child;
  final String? backgroundImage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Image de fond (si fournie) ou fond de couleur
          if (backgroundImage != null)
            Image.asset(
              backgroundImage!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: base),
            )
          else
            Container(color: base),

          // 2. Dégradé sombre par-dessus l'image pour garder la lisibilité des textes/boutons
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.35), // Légèrement sombre en haut
                  Colors.black.withValues(alpha: 0.65), // Plus sombre au milieu
                  Color.lerp(base, Colors.black, 0.85)!, // Très sombre en bas
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),

          // 3. Contenu du lecteur
          SafeArea(child: child),
        ],
      ),
    );
  }
}

class _PlayerTopBar extends StatelessWidget {
  const _PlayerTopBar({
    required this.title,
    this.onInfo,
    this.isLive = false,
  });

  final String title;
  final VoidCallback? onInfo;
  final bool isLive;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.white, size: 20),
          onPressed: () => context.pop(),
        ),
        Text(
          title.toUpperCase(),
          style: AppTypography.caption.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        if (!isLive && onInfo != null)
          IconButton(
            icon: const Icon(Icons.menu_book_outlined, color: Colors.white),
            onPressed: onInfo,
          )
        else
          const SizedBox(width: 48),
      ],
    );
  }
}

class _Artwork extends StatelessWidget {
  const _Artwork({required this.content});
  final ContentView content;

  @override
  Widget build(BuildContext context) {
    final image = _imageProvider(content.squareOrLandscape);

    if (image == null) return _placeholder();

    return Hero(
      tag: 'content_art_${content.id}',
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (rect) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.white,
            Colors.white,
            Colors.transparent,
          ],
          stops: [0.0, 0.12, 0.6, 1.0],
        ).createShader(rect),
        child: Image(
          image: image,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholder(),
        ),
      ),
    );
  }

  static ImageProvider? _imageProvider(String? source) {
    if (source == null) return null;
    return source.startsWith('http')
        ? NetworkImage(source)
        : AssetImage(source);
  }

  Widget _placeholder() => Center(
        child: Icon(
          Icons.auto_stories_rounded,
          size: 110,
          color: Colors.white.withValues(alpha: 0.85),
        ),
      );
}

enum _Stage {
  artwork,
  buffering,
  interrupted,
  needsNetwork;

  static _Stage of(ContentPlayback playback, String contentId) {
    if (playback.contentId != contentId) return _Stage.artwork;
    if (playback.hasError) {
      return playback.hasStarted ? _Stage.interrupted : _Stage.needsNetwork;
    }
    return playback.isBuffering ? _Stage.buffering : _Stage.artwork;
  }
}

class _PlayerStage extends ConsumerWidget {
  const _PlayerStage({required this.content, required this.onResume});

  final ContentView content;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stage = ref.watch(
      contentPlaybackProvider.select((p) => _Stage.of(p, content.id)),
    );
    final l10n = context.l10n;

    // Si c'est le flux direct, on masque l'illustration centrale pour laisser voir l'image de fond
    final isLiveContent = content.id == LiveStreamConfig.liveContentId;
    final Widget artworkWidget = isLiveContent
        ? const SizedBox.shrink()
        : _Artwork(content: content);

    return switch (stage) {
      _Stage.artwork => Center(child: artworkWidget),
      _Stage.buffering => Stack(
          fit: StackFit.expand,
          children: [
            Center(child: artworkWidget),
            const Center(child: _BufferingBadge()),
          ],
        ),
      _Stage.interrupted => _room(
          AppErrorState(
            title: l10n.playerErrorTitle,
            message: l10n.playerErrorMessage,
            retryLabel: l10n.playerErrorRetry,
            onRetry: onResume,
          ),
        ),
      _Stage.needsNetwork => ContentAbsenceView(
          absence: ContentAbsence.offlineMedia,
          onDark: true,
          onBack: () => context.pop(),
        ),
    };
  }

  static Widget _room(Widget child) =>
      Center(child: SingleChildScrollView(child: child));
}

class _BufferingBadge extends StatelessWidget {
  const _BufferingBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ContentPlayerView.bufferingKey,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        shape: BoxShape.circle,
      ),
      child: const SizedBox(
        width: 26,
        height: 26,
        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.liked,
    required this.accent,
    required this.onSeek,
    required this.onPlayPause,
    required this.onLike,
    required this.onNotes,
    this.downloadButton,
    this.isLive = false,
    this.onStop,
  });

  final bool liked;
  final Color accent;
  final ValueChanged<Duration> onSeek;
  final VoidCallback onPlayPause;
  final VoidCallback onLike;
  final VoidCallback onNotes;
  final Widget? downloadButton;
  final bool isLive;
  final VoidCallback? onStop;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Ligne de progression + grand bouton Play/Pause (identique à l'Image 1)
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: _ProgressLine(onSeek: onSeek)),
            const SizedBox(width: AppSpacing.lg),
            _PlayButton(accent: accent, onPressed: onPlayPause),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        // Rangée d'icônes inférieures (Bouton Stop en mode Live)
        Row(
          children: [
            const SizedBox(width: AppSpacing.md),
            if (isLive) ...[
              if (onStop != null)
                _GlassCircleButton(
                  icon: Icons.stop_rounded,
                  onPressed: onStop!,
                ),
            ] else ...[
              _GlassCircleButton(
                icon: liked ? Icons.favorite : Icons.favorite_border,
                onPressed: onLike,
              ),
              const SizedBox(width: AppSpacing.md),
              _GlassCircleButton(
                icon: Icons.edit_note_rounded,
                onPressed: onNotes,
              ),
              if (downloadButton != null) ...[
                const SizedBox(width: AppSpacing.md),
                downloadButton!,
              ],
            ],
          ],
        ),
      ],
    );
  }
}

class _ProgressLine extends ConsumerStatefulWidget {
  const _ProgressLine({required this.onSeek});

  final ValueChanged<Duration> onSeek;

  @override
  ConsumerState<_ProgressLine> createState() => _ProgressLineState();
}

class _ProgressLineState extends ConsumerState<_ProgressLine> {
  double? _dragged;

  @override
  Widget build(BuildContext context) {
    final position =
        ref.watch(contentPlaybackProvider.select((p) => p.position));
    final duration =
        ref.watch(contentPlaybackProvider.select((p) => p.duration));
    final progress =
        ContentPlayback(position: position, duration: duration).progress;
    final dragged = _dragged;
    final elapsed =
        dragged != null && duration != null ? duration * dragged : position;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            activeTrackColor: Colors.white,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.3),
            thumbColor: Colors.white,
            disabledActiveTrackColor: Colors.white.withValues(alpha: 0.5),
            disabledInactiveTrackColor: Colors.white.withValues(alpha: 0.2),
            disabledThumbColor: Colors.white.withValues(alpha: 0.5),
          ),
          child: Slider(
            value: dragged ?? progress ?? 0,
            onChanged: duration == null
                ? null
                : (value) => setState(() => _dragged = value),
            onChangeEnd: duration == null
                ? null
                : (value) {
                    setState(() => _dragged = null);
                    widget.onSeek(duration * value);
                  },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_clock(elapsed), style: _clockStyle),
              if (duration != null) Text(_clock(duration), style: _clockStyle),
            ],
          ),
        ),
      ],
    );
  }

  static final TextStyle _clockStyle = AppTypography.caption.copyWith(
    color: Colors.white.withValues(alpha: 0.7),
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  static String _clock(Duration value) {
    final seconds = value.inSeconds;
    final minutes = (seconds ~/ 60) % 60;
    final rest = seconds % 60;
    final hours = seconds ~/ 3600;
    final body = '${minutes.toString().padLeft(2, '0')}:'
        '${rest.toString().padLeft(2, '0')}';
    return hours > 0 ? '$hours:$body' : body;
  }
}

class _PlayButton extends ConsumerWidget {
  const _PlayButton({required this.accent, required this.onPressed});

  final Color accent;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playing =
        ref.watch(contentPlaybackProvider.select((p) => p.isPlaying));
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(playing ? Icons.pause : Icons.play_arrow, size: 36),
        color: accent,
        onPressed: onPressed,
      ),
    );
  }
}

class _GlassCircleButton extends StatelessWidget {
  const _GlassCircleButton({required this.icon, required this.onPressed});
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 22),
        onPressed: onPressed,
      ),
    );
  }
}

class _DownloadButton extends ConsumerWidget {
  const _DownloadButton({required this.contentId, required this.contentType});

  final String contentId;
  final String contentType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final row = ref.watch(downloadForContentProvider(contentId)).value;
    final state = row?.state;

    if (row == null || state == null) {
      return _glass(
        icon: Icons.download_outlined,
        semantics: l10n.actionDownload,
        onTap: () => _start(ref),
      );
    }

    return switch (state) {
      DownloadState.queued ||
      DownloadState.running =>
        _progress(context, ref, row),
      DownloadState.paused => _glass(
          icon: Icons.download,
          semantics: l10n.downloadActionResume,
          onTap: () => ref.read(downloadManagerProvider).resume(contentId),
        ),
      DownloadState.waitingWifi => _glass(
          icon: Icons.wifi_off_rounded,
          semantics: l10n.downloadStateWaitingWifi,
          onTap: () => ref.read(downloadManagerProvider).resume(contentId),
        ),
      DownloadState.complete => _glass(
          icon: Icons.download_done_rounded,
          semantics: l10n.downloadStateComplete,
          onTap: () => _confirmDelete(context, ref),
        ),
      DownloadState.outdated => _outdated(context, ref),
      DownloadState.failed => _glass(
          icon: Icons.refresh_rounded,
          semantics: l10n.downloadActionRetry,
          onTap: () => _start(ref),
        ),
    };
  }

  void _start(WidgetRef ref) {
    unawaited(
      ref.read(downloadManagerProvider).download(
            contentId: contentId,
            contentType: contentType,
            quality: ref.read(downloadQualityProvider),
          ),
    );
  }

  Widget _progress(BuildContext context, WidgetRef ref, DownloadRow row) {
    final l10n = context.l10n;
    final total = row.bytesTotal;
    final fraction =
        total > 0 ? (row.bytesReceived / total).clamp(0.0, 1.0) : null;
    final percent = fraction == null ? null : (fraction * 100).round();

    return Semantics(
      button: true,
      label: l10n.downloadStateDownloading,
      child: InkResponse(
        key: ContentPlayerView.downloadButtonKey,
        onTap: () =>
            unawaited(ref.read(downloadManagerProvider).pause(contentId)),
        radius: 28,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: fraction,
                strokeWidth: 2.5,
                color: Colors.white,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
              ),
              if (percent != null)
                Text(
                  '$percent',
                  style: AppTypography.caption.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                )
              else
                const Icon(Icons.pause, color: Colors.white, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.downloadDeleteConfirmTitle),
        content: Text(l10n.downloadDeleteConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.downloadDeleteConfirmAction),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(downloadManagerProvider).cancel(contentId);
    }
  }

  Widget _outdated(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _glass(
          icon: Icons.download_done_rounded,
          semantics: l10n.downloadUpdateAvailable,
          onTap: () => _outdatedMenu(context, ref),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _outdatedMenu(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.system_update_alt),
              title: Text(l10n.downloadActionUpdate),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _start(ref);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text(l10n.downloadActionDelete),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _confirmDelete(context, ref);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _glass({
    required IconData icon,
    required String semantics,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: semantics,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          key: ContentPlayerView.downloadButtonKey,
          icon: Icon(icon, color: Colors.white, size: 22),
          tooltip: semantics,
          onPressed: onTap,
        ),
      ),
    );
  }
}

class _ContentInfoSheet extends StatelessWidget {
  const _ContentInfoSheet({required this.content});
  final ContentView content;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final palette = context.palette;
    final subtitle = [content.authorName, content.typeLabel]
        .where((part) => part != null && part.isNotEmpty)
        .join(' • ');
    final description = content.description;

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.5,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          MediaQuery.paddingOf(context).bottom + AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(content.title, style: AppTypography.h3),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                style:
                    AppTypography.body.copyWith(color: palette.textSecondary),
              ),
            ],
            if (description != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(l.tabDescription, style: AppTypography.h5),
              const SizedBox(height: AppSpacing.sm),
              Text(
                description,
                style: AppTypography.bodyLarge
                    .copyWith(color: palette.textSecondary, height: 1.4),
              ),
            ],
          ],
        ),
      ),
    );
  }
}