import 'package:flutter/material.dart';

import '../../models/mediatheque_view.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../app_card.dart';
import 'teaching_cover.dart';

/// Ligne d'enseignement (médiathèque, derniers enseignements).
///
/// Prend le **modèle de lecture**, pas la ligne : couleur résolue, libellé
/// replié, URL absolues. Le visuel passe donc par [TeachingCover], qui sait
/// replier sur la couleur de l'enseignement — la vignette dégradée tirée d'une
/// graine (`Teaching.seed`) n'avait plus rien à faire ici dès lors que le
/// serveur sert deux images et une couleur.
class TeachingTile extends StatelessWidget {
  const TeachingTile({super.key, required this.teaching, this.onTap});

  final TeachingView teaching;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    // **L'absence s'affiche comme une absence** (règle 4 du modèle de lecture) :
    // tant que la collection `contributors` n'a pas livré l'intervenant, la
    // ligne ne se rend pas. Ni « Auteur inconnu », qui serait pris pour une
    // erreur de saisie, ni la durée d'autrefois — le serveur n'en sert aucune.
    final author = teaching.authorName;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          SizedBox(
            width: 76,
            height: 64,
            child: TeachingCover(
              teaching: teaching,
              radius: 12,
              orientation: CoverOrientation.landscape,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(teaching.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyStrong),
                if (author != null) ...[
                  const SizedBox(height: 4),
                  Text(author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption
                          .copyWith(color: palette.textSecondary)),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Icon(Icons.play_circle_fill, color: palette.primary, size: 30),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
    );
  }
}
