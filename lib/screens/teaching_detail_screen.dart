import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/l10n_extension.dart';
import '../models/models.dart';
import '../router/app_router.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/media_url.dart';

/// Écran de détail d'un enseignement, façon **lecteur plein écran**.
///
/// L'habillage (dégradé, accents) est piloté par les données : la couleur
/// [Teaching.color] et l'image optionnelle [Teaching.image].
class TeachingDetailScreen extends StatefulWidget {
  const TeachingDetailScreen({super.key, required this.teaching});

  final Teaching teaching;

  @override
  State<TeachingDetailScreen> createState() => _TeachingDetailScreenState();
}

class _TeachingDetailScreenState extends State<TeachingDetailScreen> {
  bool _playing = true;
  bool _liked = false;
  double _progress = 0.35;

  Teaching get _t => widget.teaching;

  /// Ouvre une demi-feuille native (glissable vers le bas) : description,
  /// versets et infos de l'enseignement.
  void _showInfoSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: context.palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _TeachingInfoSheet(teaching: _t),
    );
  }

  @override
  Widget build(BuildContext context) {
    final base = Color(_t.color);
    final dark = Color.lerp(base, Colors.black, 0.55)!;
    final total = _durationToSeconds(_t.duration);
    final current = (_progress * total).round();

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [base, dark],
            stops: const [0.15, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PlayerTopBar(
                  title: context.l10n.teachingAppBarTitle,
                  onInfo: () => _showInfoSheet(context),
                ),
                Expanded(child: Center(child: _Artwork(teaching: _t))),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  _t.title,
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
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _t.author,
                  style: AppTypography.h4.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.verified, color: Colors.white70, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      _t.duration,
                      style: AppTypography.caption
                          .copyWith(color: Colors.white.withValues(alpha: 0.7)),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                _Controls(
                  progress: _progress,
                  timeLabel: '${_format(current)} / ${_t.duration}',
                  playing: _playing,
                  liked: _liked,
                  accent: base,
                  onSeek: (v) => setState(() => _progress = v),
                  onPlayPause: () => setState(() => _playing = !_playing),
                  onLike: () => setState(() => _liked = !_liked),
                  onNotes: () => context.pushNamed(AppRoute.notes),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Barre supérieure du lecteur (retour, libellé, accès aux détails).
class _PlayerTopBar extends StatelessWidget {
  const _PlayerTopBar({required this.title, this.onInfo});
  final String title;
  final VoidCallback? onInfo;

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
        IconButton(
          icon: const Icon(Icons.menu_book_outlined, color: Colors.white),
          onPressed: onInfo,
        ),
      ],
    );
  }
}

/// Visuel central : image d'habillage si fournie, sinon placeholder coloré.
class _Artwork extends StatelessWidget {
  const _Artwork({required this.teaching});
  final Teaching teaching;

  @override
  Widget build(BuildContext context) {
    // En-tête pleine largeur : le cadrage paysage. Le portrait prend le relais
    // s'il est seul, plutôt que de renoncer à toute image.
    final image = _imageProvider(
      resolveMediaUrl(teaching.imageLandscapeUrl ?? teaching.imagePortraitUrl),
    );

    // Pas d'image : grande icône flottant sur le dégradé.
    if (image == null) {
      return Center(
        child: Icon(
          Icons.auto_stories_rounded,
          size: 110,
          color: Colors.white.withValues(alpha: 0.85),
        ),
      );
    }

    // Image fondue dans le dégradé : opaque en haut, transparente en bas
    // (et léger fondu en haut) via un masque d'opacité.
    return Hero(
      tag: 'teaching_art_${teaching.title}',
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
}

/// Bloc de contrôles : progression, temps, actions et lecture/pause.
class _Controls extends StatelessWidget {
  const _Controls({
    required this.progress,
    required this.timeLabel,
    required this.playing,
    required this.liked,
    required this.accent,
    required this.onSeek,
    required this.onPlayPause,
    required this.onLike,
    required this.onNotes,
  });

  final double progress;
  final String timeLabel;
  final bool playing;
  final bool liked;
  final Color accent;
  final ValueChanged<double> onSeek;
  final VoidCallback onPlayPause;
  final VoidCallback onLike;
  final VoidCallback onNotes;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Ligne de lecture + bouton play centré verticalement dessus.
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 3,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 14),
                  activeTrackColor: Colors.white,
                  inactiveTrackColor: Colors.white.withValues(alpha: 0.3),
                  thumbColor: Colors.white,
                ),
                child: Slider(value: progress, onChanged: onSeek),
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            _PlayButton(
                playing: playing, accent: accent, onPressed: onPlayPause),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            timeLabel,
            style: AppTypography.caption.copyWith(color: Colors.white),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            const SizedBox(width: AppSpacing.md),
            _GlassCircleButton(
              icon: liked ? Icons.favorite : Icons.favorite_border,
              onPressed: onLike,
            ),
            const SizedBox(width: AppSpacing.md),
            _GlassCircleButton(
              icon: Icons.edit_note_rounded,
              onPressed: onNotes,
            ),
          ],
        ),
      ],
    );
  }
}

/// Gros bouton lecture/pause (cercle blanc, icône à la couleur d'accent).
class _PlayButton extends StatelessWidget {
  const _PlayButton({
    required this.playing,
    required this.accent,
    required this.onPressed,
  });

  final bool playing;
  final Color accent;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
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

/// Petit bouton circulaire translucide (glassmorphisme).
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

/// Demi-feuille de détails : description, versets et infos.
class _TeachingInfoSheet extends StatelessWidget {
  const _TeachingInfoSheet({required this.teaching});
  final Teaching teaching;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final palette = context.palette;

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
            Text(teaching.title, style: AppTypography.h3),
            const SizedBox(height: 2),
            Text(
              '${teaching.author} • ${teaching.duration}',
              style: AppTypography.body.copyWith(color: palette.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(l.tabDescription, style: AppTypography.h5),
            const SizedBox(height: AppSpacing.sm),
            Text(
              teaching.description,
              style: AppTypography.bodyLarge
                  .copyWith(color: palette.textSecondary, height: 1.4),
            ),
            if (teaching.verse != null) ...[
              const SizedBox(height: AppSpacing.xl),
              Text(l.teachingVerses, style: AppTypography.h5),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Icon(Icons.menu_book_outlined,
                      size: 18, color: palette.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    teaching.verse!,
                    style: AppTypography.bodyStrong
                        .copyWith(color: palette.primary),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

int _durationToSeconds(String mmss) {
  final parts = mmss.split(':');
  if (parts.length != 2) return 0;
  return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
}

String _format(int seconds) =>
    '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
