import 'package:flutter/material.dart';

import '../../l10n/l10n_extension.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../app_avatar.dart';

/// En-tête du hub « Échanges » : **bandeau diagonal**, repris de la structure de
/// la maquette mais **habillé aux couleurs New Life** (bleu de marque, avec des
/// diagonales teal et jaune) — jamais le rose Dribbble (décision D4).
///
/// Contenu (décision D5) : le titre « Échanges » à gauche ; à droite une **pile
/// d'avatars décorative** (fictive) suivie du **bouton Requêtes**. Pas de
/// hamburger, pas d'avatar central.
class CommunityHeader extends StatelessWidget {
  const CommunityHeader({super.key, required this.onRequests});

  /// Ouvre l'écran Requêtes (bouton tout à droite du bandeau).
  final VoidCallback onRequests;

  /// Noms de la pile d'avatars — purement **décoratifs** : ils illustrent la
  /// communauté, ils ne désignent personne et ne sont pas interactifs.
  static const List<String> _decorativeAvatars = [
    'Estelle',
    'David',
    'Sarah',
  ];

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return ClipRect(
      child: CustomPaint(
        painter: _DiagonalBandsPainter(),
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(gradient: AppColors.gradientPrimary),
          padding: EdgeInsets.only(
            top: topInset + AppSpacing.md,
            left: AppSpacing.lg,
            right: AppSpacing.sm,
            bottom: AppSpacing.lg,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  // Titre de **page** : `communityTitle` (« Échanges »).
                  // `navGroups`, même mot, ne sert plus que la barre de nav.
                  context.l10n.communityTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.h2.copyWith(color: Colors.white),
                ),
              ),
              const _AvatarStack(names: _decorativeAvatars),
              IconButton(
                onPressed: onRequests,
                tooltip: context.l10n.requestsTitle,
                icon:
                    const Icon(Icons.assignment_outlined, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pile d'avatars qui se chevauchent, close par une pastille « N+ ».
class _AvatarStack extends StatelessWidget {
  const _AvatarStack({required this.names});

  final List<String> names;

  @override
  Widget build(BuildContext context) {
    const double size = 32;
    const double overlap = 20;
    final children = <Widget>[];
    for (var i = 0; i < names.length; i++) {
      children.add(Positioned(
        left: i * overlap,
        child: Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            border: Border.fromBorderSide(
              BorderSide(color: Colors.white, width: 1.5),
            ),
          ),
          child: AppAvatar(name: names[i], size: size),
        ),
      ));
    }
    children.add(Positioned(
      left: names.length * overlap,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.secondary,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: Text(
          '5+',
          style: AppTypography.caption.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ));
    return SizedBox(
      width: names.length * overlap + size,
      height: size,
      child: Stack(clipBehavior: Clip.none, children: children),
    );
  }
}

/// Peint deux diagonales — teal puis jaune — par-dessus le dégradé bleu, pour
/// reprendre le rythme graphique de la maquette **aux couleurs New Life**.
class _DiagonalBandsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // Inclinaison des bandes : un décalage horizontal égal à la hauteur donne
    // une pente proche de 45°, comme sur la maquette.
    final slant = h;

    Path band(double topLeftX, double bandWidth) => Path()
      ..moveTo(topLeftX, 0)
      ..lineTo(topLeftX + bandWidth, 0)
      ..lineTo(topLeftX + bandWidth - slant, h)
      ..lineTo(topLeftX - slant, h)
      ..close();

    final teal = Paint()..color = AppColors.secondary.withValues(alpha: 0.90);
    final yellow = Paint()..color = AppColors.accent.withValues(alpha: 0.95);

    canvas.drawPath(band(w * 0.52, w * 0.16), teal);
    canvas.drawPath(band(w * 0.68, w * 0.20), yellow);
  }

  @override
  bool shouldRepaint(covariant _DiagonalBandsPainter oldDelegate) => false;
}
