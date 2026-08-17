import 'package:flutter/material.dart';

import '../../l10n/l10n_extension.dart';
import '../../models/models.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../app_avatar.dart';

/// Carte de **découverte** d'un groupe à rejoindre : visuel de couverture, nom
/// du groupe, puis l'action d'adhésion. Largeur fixe pour la rangée horizontale
/// du hub « Échanges ».
///
/// **Action selon la politique d'accès** (décision D11/adhésion) :
/// - `open` → bouton « Rejoindre » (immédiat, [onJoin]) ;
/// - `request` → « Demander à rejoindre » ([onRequest]) ;
/// - demande déjà envoyée → « En attente », désactivé.
///
/// Le tap sur la carte ouvre la **fiche du groupe** (un non-membre peut la
/// consulter avant de décider — décision D13).
class JoinGroupCard extends StatelessWidget {
  const JoinGroupCard({
    super.key,
    required this.group,
    this.onTap,
    this.onJoin,
    this.onRequest,
  });

  final DiscoverGroup group;

  /// Ouvre la fiche du groupe.
  final VoidCallback? onTap;

  /// Rejoindre un groupe `open`.
  final VoidCallback? onJoin;

  /// Demander à rejoindre un groupe `request`.
  final VoidCallback? onRequest;

  static const double width = 168;
  static const double coverHeight = 108;

  /// Hauteur totale : couverture + nom sur **2 lignes** + bouton d'action.
  /// Généreuse à dessein — un nom qui passe à la ligne ne doit pas faire déborder
  /// la carte (RenderFlex overflow).
  static const double rowHeight = coverHeight + 108;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
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
                // Ligne « animé par » — n'apparaît qu'en mode maquette (au réel,
                // pas de nom d'animateur, ADR-0029).
                if (group.host.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      AppAvatar(name: group.host, size: 20),
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
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _JoinAction(group: group, onJoin: onJoin, onRequest: onRequest),
        ],
      ),
    );
  }
}

/// Le bouton d'adhésion, dont l'intitulé et l'état dépendent de la politique.
class _JoinAction extends StatelessWidget {
  const _JoinAction({required this.group, this.onJoin, this.onRequest});

  final DiscoverGroup group;
  final VoidCallback? onJoin;
  final VoidCallback? onRequest;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    if (group.pendingRequest) {
      return _Pill(
        label: l.joinGroupPending,
        icon: Icons.hourglass_top,
        onTap: null,
      );
    }
    if (group.joinPolicy == GroupJoinPolicy.request) {
      return _Pill(
        label: l.joinGroupRequest,
        icon: Icons.person_add_alt,
        onTap: onRequest,
      );
    }
    return _Pill(
      label: l.joinGroupOpen,
      icon: Icons.add,
      onTap: onJoin,
      filled: true,
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.icon,
    this.onTap,
    this.filled = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final enabled = onTap != null;
    final bg = filled ? AppColors.primary : palette.surface;
    final fg = filled ? Colors.white : palette.textPrimary;
    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.xs,
              horizontal: AppSpacing.sm,
            ),
            decoration: filled
                ? null
                : BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(color: palette.divider),
                  ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: fg),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption
                        .copyWith(color: fg, fontWeight: FontWeight.w700),
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
