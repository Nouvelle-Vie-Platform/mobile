import 'package:flutter/material.dart';

import '../../l10n/l10n_extension.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

/// En-tête du hub « Échanges » : **bandeau diagonal**, repris de la structure de
/// la maquette mais **habillé aux couleurs New Life** (bleu de marque, avec des
/// diagonales teal et jaune) — jamais le rose Dribbble (décision D4).
///
/// Contenu : le titre « Échanges » à gauche, le **bouton Requêtes** à droite. Pas
/// de hamburger, pas d'avatar central (décision D5).
///
/// ## La pile d'avatars **a disparu** (#96, décision 10 du cadrage)
///
/// Elle portait trois prénoms écrits en dur — « Estelle », « David », « Sarah » —
/// et une pastille « 5+ » qui ne comptait rien. Trois personnes qui n'existaient
/// pas, sur l'écran d'une église où tout le monde se connaît : la seule chose
/// qu'un fidèle pouvait en conclure était fausse. Et il n'y avait rien à mettre à
/// la place — `profiles` nomme mes co-membres, pas « la communauté », et faire la
/// somme de mes groupes pour en tirer une pile de visages serait inventer une
/// statistique que personne n'a demandée.
///
/// C'est la règle de la décision 10 : **on retire ce qui ne peut pas être vrai**.
class CommunityHeader extends StatelessWidget {
  const CommunityHeader({super.key, required this.onRequests});

  /// Ouvre l'écran Requêtes (bouton tout à droite du bandeau).
  final VoidCallback onRequests;

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
