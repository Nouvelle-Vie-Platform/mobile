import 'package:flutter/material.dart';

import '../../l10n/l10n_extension.dart';
import '../../models/models.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../theme/status_palette.dart';
import '../../utils/relative_time.dart';
import '../app_card.dart';
import '../app_chip.dart';

/// Carte d'une annonce de l'église (catégorie, date, titre, contenu).
///
/// En mode [compact], elle sert de vignette dans la feuille listant tous les
/// statuts : miniature du fond à gauche, libellé et date à droite.
class AnnouncementCard extends StatelessWidget {
  const AnnouncementCard({
    super.key,
    required this.announcement,
    this.onTap,
    this.compact = false,
  });

  final Announcement announcement;
  final VoidCallback? onTap;

  /// Vignette de liste plutôt que carte pleine.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final title = announcement.title;
    final body = announcement.body;
    if (compact) return _CompactTile(announcement: announcement, onTap: onTap);
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (announcement.tag != null)
                AppChip(announcement.tag!, tone: AppChipTone.info),
              const Spacer(),
              Text(
                relativeTime(context.l10n, announcement.publishedAt),
                style: AppTypography.caption
                    .copyWith(color: palette.textSecondary),
              ),
            ],
          ),
          if (title != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(title, style: AppTypography.h5),
          ],
          if (body != null) ...[
            SizedBox(height: title == null ? AppSpacing.sm : 4),
            Text(
              body,
              style: AppTypography.body.copyWith(color: palette.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

/// Vignette compacte : miniature du fond, libellé, catégorie et date.
///
/// Le libellé retombe sur un extrait du corps quand le statut n'a pas de titre
/// — un statut court façon WhatsApp n'en a pas.
class _CompactTile extends StatelessWidget {
  const _CompactTile({required this.announcement, this.onTap});

  final Announcement announcement;
  final VoidCallback? onTap;

  static const double _thumbSize = 52;

  IconData? get _kindIcon {
    switch (announcement.kind) {
      case StatusKind.video:
        return Icons.play_arrow_rounded;
      case StatusKind.audio:
        return Icons.mic_rounded;
      case StatusKind.image:
      case StatusKind.text:
        return null;
    }
  }

  String get _label {
    final title = announcement.title;
    if (title != null && title.isNotEmpty) return title;
    final body = announcement.body ?? '';
    return body.isEmpty ? '—' : body;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.card,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            _Thumbnail(announcement: announcement, icon: _kindIcon),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyStrong,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (announcement.tag != null) ...[
                        AppChip(announcement.tag!, tone: AppChipTone.info),
                        const SizedBox(width: AppSpacing.sm),
                      ],
                      Flexible(
                        child: Text(
                          relativeTime(context.l10n, announcement.publishedAt),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption
                              .copyWith(color: palette.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (announcement.isPinned)
              Icon(
                Icons.push_pin_rounded,
                size: 16,
                color: palette.textSecondary,
              ),
          ],
        ),
      ),
    );
  }
}

/// Miniature du fond du statut : même dégradé déterministe que la visionneuse,
/// avec l'image en surcouche quand il y en a une.
class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.announcement, this.icon});

  final Announcement announcement;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final base = statusBaseColor(
      announcement.id,
      backgroundColor: announcement.backgroundColor,
    );
    final imageUrl = announcement.video?.poster ?? announcement.backgroundImage;

    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(AppRadius.sm)),
      child: SizedBox(
        width: _CompactTile._thumbSize,
        height: _CompactTile._thumbSize,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(gradient: statusGradient(base)),
            ),
            // Repli obligatoire : hors-ligne comme en test (le réseau renvoie
            // 400), l'échec doit retomber sur le dégradé sans bruit.
            if (imageUrl != null)
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            if (icon != null)
              Center(
                child: Icon(
                  icon,
                  size: 20,
                  color: statusForegroundOn(base),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
