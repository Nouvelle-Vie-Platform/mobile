import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/mediatheque_view.dart';
import '../../state/player_providers.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../app_card.dart';
import 'content_cover.dart';
import 'playing_indicator.dart';

/// Ligne d'enseignement (médiathèque, derniers enseignements).
///
/// Prend le **modèle de lecture**, pas la ligne : couleur résolue, libellé
/// replié, URL absolues. Le visuel passe donc par [ContentCover], qui sait
/// replier sur la couleur de l'enseignement — la vignette dégradée tirée d'une
/// graine (`Teaching.seed`) n'avait plus rien à faire ici dès lors que le
/// serveur sert deux images et une couleur.
///
/// L'icône de lecture reflète l'état global du lecteur : si cet enseignement
/// est en cours de lecture, une animation de barres animées remplace le
/// play statique — l'utilisateur voit immédiatement que quelque chose tourne.
class TeachingTile extends ConsumerWidget {
  const TeachingTile({super.key, required this.teaching, this.onTap});

  final TeachingView teaching;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    // **L'absence s'affiche comme une absence** (règle 4 du modèle de lecture) :
    // tant que la collection `contributors` n'a pas livré l'intervenant, la
    // ligne ne se rend pas. Ni « Auteur inconnu », qui serait pris pour une
    // erreur de saisie, ni la durée d'autrefois — le serveur n'en sert aucune.
    final author = teaching.authorName;

    final playback = ref.watch(
      contentPlaybackProvider.select(
        (p) => (contentId: p.contentId, isPlaying: p.isPlaying),
      ),
    );
    final isThisPlaying =
        playback.contentId == teaching.id && playback.isPlaying;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          SizedBox(
            width: 76,
            height: 64,
            child: ContentCover(
              content: teaching,
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
          // Indicateur de lecture en cours : barres animées si cet enseignement
          // joue, icône play statique sinon.
          if (isThisPlaying)
            PlayingIndicator(color: palette.primary)
          else
            Icon(Icons.play_circle_fill, color: palette.primary, size: 30),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
    );
  }
}
