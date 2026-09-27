import 'package:flutter/material.dart';

import '../../l10n/l10n_extension.dart';
import '../../models/models.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../app_avatar.dart';

/// Carte de **découverte** d'un groupe à rejoindre : visuel de couverture, nom
/// du groupe, puis l'animateur. Largeur fixe pour la rangée horizontale du hub
/// « Échanges ».
///
/// Le tap ouvre le **profil de l'animateur** — la porte d'entrée vers une
/// conversation directe (décision D10).
class JoinGroupCard extends StatelessWidget {
  const JoinGroupCard({super.key, required this.group, this.onTap});

  final DiscoverGroup group;
  final VoidCallback? onTap;

  static const double width = 156;
  static const double coverHeight = 116;

  /// Hauteur totale de la carte (couverture + nom sur **2 lignes** + ligne
  /// animateur). Utilisée pour dimensionner la rangée horizontale : trop juste,
  /// un nom qui passe à la ligne fait déborder la carte (RenderFlex overflow).
  static const double rowHeight = coverHeight + 84;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadius.card,
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Cover(group: group),
              const SizedBox(height: AppSpacing.sm),
              Text(
                group.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodyStrong
                    .copyWith(color: palette.textPrimary),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  AppAvatar(name: group.host, size: 22),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      context.l10n.echangesHostedBy(group.host),
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
      ),
    );
  }
}

/// Couverture : image réseau avec repli coloré (jamais d'échec hors ligne).
class _Cover extends StatelessWidget {
  const _Cover({required this.group});

  final DiscoverGroup group;

  @override
  Widget build(BuildContext context) {
    // Teinte de repli stable, dérivée du nom (comme [AppAvatar]).
    final fallback =
        _fallbackColors[group.name.length % _fallbackColors.length];
    return ClipRRect(
      borderRadius: AppRadius.card,
      child: SizedBox(
        height: JoinGroupCard.coverHeight,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(decoration: BoxDecoration(color: fallback)),
            if (group.imageUrl != null)
              Image.network(
                group.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            // Voile bas pour asseoir un éventuel texte et adoucir l'image.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0x66000000)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const List<Color> _fallbackColors = [
    AppColors.primary,
    AppColors.secondary,
    Color(0xFF7A5AF8),
    Color(0xFF0F766E),
  ];
}
