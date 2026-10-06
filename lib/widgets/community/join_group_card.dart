import 'package:flutter/material.dart';

import '../../l10n/l10n_extension.dart';
import '../../models/echanges_view.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../app_avatar.dart';

/// Carte de **découverte** d'un groupe à rejoindre : un aplat de marque, le nom du
/// groupe, l'effectif, puis l'animateur. Largeur fixe pour la rangée horizontale
/// du hub « Échanges ».
///
/// ## L'image de couverture **a disparu** (#96, décision 10)
///
/// Elle était une `picsum.photos` tirée du nom : un visuel de maquette, qui ne
/// désignait rien. Le serveur ne sert **aucune** image de groupe — ni dans
/// `GroupTransformer`, ni ailleurs —, et garder la place en la remplissant d'une
/// image inventée aurait fait passer pour une donnée ce qui n'en est pas une.
/// L'aplat est dérivé du nom, comme la teinte d'un [AppAvatar] : c'est un
/// habillage, et il se lit comme tel.
///
/// ## La politique d'adhésion se dit, et l'état d'une demande aussi
///
/// `open` = on entre, `request` = on demande. Et si j'ai **déjà** demandé, la
/// carte le dit au lieu de proposer un geste déjà fait — c'est tout l'usage que
/// cette tranche a de `group_join_requests`.
///
/// ## Le geste est sur la carte (#145)
///
/// « Rejoindre » (`open`) ou « Demander » (`request`), selon la politique ; rien
/// quand ma demande est en attente. [onJoin] nul = pas de bouton (un écran qui
/// ne fait que montrer la carte).
class JoinGroupCard extends StatelessWidget {
  const JoinGroupCard(
      {super.key, required this.group, this.onTap, this.onJoin});

  final DiscoverGroupView group;
  final VoidCallback? onTap;

  /// Rejoindre ou demander, selon `group.joinPolicy` (#145).
  final VoidCallback? onJoin;

  /// Le bouton de la carte — pour les tests.
  static ValueKey<String> joinKey(String groupId) =>
      ValueKey('join-card-$groupId');

  /// La hauteur du bouton de la carte (#145), comptée dans [rowHeight].
  static const double actionHeight = 40;

  static const double width = 156;
  static const double coverHeight = 116;

  /// Hauteur totale de la carte (aplat + nom sur **2 lignes** + ligne animateur).
  /// Utilisée pour dimensionner la rangée horizontale : trop juste, un nom qui
  /// passe à la ligne fait déborder la carte (RenderFlex overflow).
  static const double rowHeight =
      coverHeight + 84 + actionHeight + AppSpacing.sm;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l = context.l10n;
    final host = group.hostName;

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
                group.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodyStrong
                    .copyWith(color: palette.textPrimary),
              ),
              const SizedBox(height: 6),
              // L'animateur **si on le connaît** : la ligne ne se rend pas en son
              // absence, jamais un « Animé par Inconnu ».
              if (host != null && host.isNotEmpty)
                Row(
                  children: [
                    AppAvatar(name: host, size: 22),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        l.echangesHostedBy(host),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption
                            .copyWith(color: palette.textSecondary),
                      ),
                    ),
                  ],
                )
              else
                Text(
                  l.groupMembers(group.memberCount),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption
                      .copyWith(color: palette.textSecondary),
                ),
              // #145 : le geste, sauf si ma demande attend déjà.
              if (onJoin != null && group.requestStatus != 'pending') ...[
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  height: actionHeight,
                  width: double.infinity,
                  child: FilledButton.tonal(
                    key: joinKey(group.groupId),
                    onPressed: onJoin,
                    child: Text(
                      group.joinPolicy == 'open' ? l.m6Join : l.m6RequestJoin,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// L'aplat de tête : une teinte stable dérivée du nom, et l'état d'adhésion.
class _Cover extends StatelessWidget {
  const _Cover({required this.group});

  final DiscoverGroupView group;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fallback =
        _fallbackColors[group.title.length % _fallbackColors.length];
    final pending = group.requestStatus == 'pending';

    return ClipRRect(
      borderRadius: AppRadius.card,
      child: SizedBox(
        height: JoinGroupCard.coverHeight,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(decoration: BoxDecoration(color: fallback)),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0x66000000)],
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Text(
                  pending
                      ? l.echangesJoinPending
                      : (group.joinPolicy == 'open'
                          ? l.echangesJoinOpen
                          : l.echangesJoinOnRequest),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
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
