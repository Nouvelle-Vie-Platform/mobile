import 'package:flutter/material.dart';

import '../../l10n/l10n_extension.dart';
import '../../models/models.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/relative_time.dart';
import '../app_avatar.dart';

/// Contenu d'un statut, empilé sur son fond.
///
/// Ne fait **aucun `switch` sur le type** : il empile ce qui existe — en-tête,
/// pastille, titre, corps, puis la [waveform] fournie par l'appelant. C'est ce
/// qui rend « vocal + texte » gratuit, sans cas particulier.
///
/// Composant de présentation pur : il ne connaît pas le lecteur. La progression
/// audio lui arrive déjà construite, via le slot [waveform].
class StatusContent extends StatelessWidget {
  const StatusContent({
    super.key,
    required this.announcement,
    required this.foreground,
    this.waveform,
    this.bottomInset = 0,
    this.onBodyScroll,
  });

  final Announcement announcement;

  /// Couleur de texte résolue pour ce fond (garantie de contraste, cf. §8).
  final Color foreground;

  /// Waveform à poser **sous le texte** quand le statut porte de l'audio.
  final Widget? waveform;

  /// Hauteur réservée en bas pour la barre de navigation et son encoche.
  final double bottomInset;

  /// Notifié quand le corps commence (`true`) ou cesse (`false`) de défiler :
  /// l'auto-avance doit se suspendre tant qu'on lit.
  final ValueChanged<bool>? onBodyScroll;

  /// Taille du corps par paliers de longueur : un statut court s'affiche en
  /// très gros et centré, un long se resserre et s'aligne en haut.
  double get _bodySize {
    final length = (announcement.body ?? '').characters.length;
    if (length <= 60) return 32;
    if (length <= 140) return 26;
    if (length <= 280) return 21;
    return 17;
  }

  bool get _hasText {
    final body = announcement.body;
    return announcement.title != null || (body != null && body.isNotEmpty);
  }

  bool get _isCompact {
    final length = (announcement.body ?? '').characters.length;
    return announcement.title == null && length <= 140;
  }

  @override
  Widget build(BuildContext context) {
    final muted = foreground.withValues(alpha: 0.75);

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          bottomInset + AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(
              announcement: announcement,
              foreground: foreground,
              muted: muted,
            ),
            if (announcement.tag != null || announcement.video != null) ...[
              const SizedBox(height: AppSpacing.sm),
              _Badges(announcement: announcement, foreground: foreground),
            ],
            const SizedBox(height: AppSpacing.md),
            // Sans texte, la waveform occupe le centre : la reléguer en bas
            // d'un écran vide donnerait une page inachevée. Avec du texte, elle
            // se range dessous, comme demandé.
            Expanded(
              child: _hasText
                  ? _body(context)
                  : Center(child: waveform ?? const SizedBox.expand()),
            ),
            if (_hasText && waveform != null) ...[
              const SizedBox(height: AppSpacing.lg),
              waveform!,
            ],
            // Emplacement réservé au bouton d'action (`actionLabel` /
            // `actionRoute`) : les champs existent déjà côté modèle, le bouton
            // n'est pas rendu en phase 1.
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final title = announcement.title;
    final body = announcement.body;
    if (title == null && (body == null || body.isEmpty)) {
      // Statut image seule : rien à poser, le fond porte tout.
      return const SizedBox.expand();
    }

    final align = _isCompact ? TextAlign.center : TextAlign.start;
    final content = Column(
      crossAxisAlignment:
          _isCompact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title != null)
          Text(
            title,
            textAlign: align,
            style: AppTypography.h1.copyWith(color: foreground, height: 1.2),
          ),
        if (title != null && body != null && body.isNotEmpty)
          const SizedBox(height: AppSpacing.md),
        if (body != null && body.isNotEmpty)
          Text(
            body,
            textAlign: align,
            style: AppTypography.bodyLarge.copyWith(
              color: foreground,
              fontSize: _bodySize,
              height: 1.45,
            ),
          ),
      ],
    );

    // Centré tant que ça tient, défilant au-delà : c'est pour ça que l'axe
    // vertical a été laissé libre (le pager est horizontal).
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollStartNotification) onBodyScroll?.call(true);
        if (notification is ScrollEndNotification) onBodyScroll?.call(false);
        return false;
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(child: content),
            ),
          );
        },
      ),
    );
  }
}

/// En-tête : auteur, horodatage relatif localisé, pastille de catégorie et
/// badge « vidéo » le cas échéant.
class _Header extends StatelessWidget {
  const _Header({
    required this.announcement,
    required this.foreground,
    required this.muted,
  });

  final Announcement announcement;
  final Color foreground;
  final Color muted;

  /// Largeur occupée par les deux boutons d'action posés en surimpression.
  static const double actionsWidth = 96;

  @override
  Widget build(BuildContext context) {
    final author = announcement.author;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (author != null) ...[
          AppAvatar(name: author, size: 36),
          const SizedBox(width: AppSpacing.sm),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (author != null)
                Text(
                  author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyStrong.copyWith(color: foreground),
                ),
              Text(
                relativeTime(context.l10n, announcement.publishedAt),
                style: AppTypography.caption.copyWith(color: muted),
              ),
            ],
          ),
        ),
        // Place réservée aux actions (son, liste) posées en surimpression par
        // l'écran : sans ça, l'en-tête passerait dessous.
        const SizedBox(width: _Header.actionsWidth),
      ],
    );
  }
}

/// Pastilles du statut, sur leur propre ligne **sous** l'en-tête — jamais dans
/// la ligne de l'auteur, dont la droite appartient aux boutons d'action.
class _Badges extends StatelessWidget {
  const _Badges({required this.announcement, required this.foreground});

  final Announcement announcement;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        if (announcement.video != null)
          _Badge(
            icon: Icons.videocam_rounded,
            label: context.l10n.statusVideoBadge,
            foreground: foreground,
          ),
        if (announcement.tag != null)
          _Badge(label: announcement.tag!, foreground: foreground),
      ],
    );
  }
}

/// Pastille translucide lisible sur n'importe quel fond : on ne peut pas
/// réutiliser `AppChip`, dont les tons sont pensés pour un fond de carte.
class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.foreground, this.icon});

  final String label;
  final Color foreground;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: foreground.withValues(alpha: 0.18),
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.pill)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            label,
            style: AppTypography.caption.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}
