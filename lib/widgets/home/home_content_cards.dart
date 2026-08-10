/// Les trois dessins d'un **contenu de médiathèque** à l'accueil — un par
/// [HomeSectionLayout], et les mêmes pour un enseignement et un rassemblement.
///
/// Ils reçoivent un [ContentView] et **n'appliquent aucune règle** : la
/// couleur est déjà en bout de cascade, le libellé de rubrique déjà replié dans
/// la langue courante, les deux URL déjà absolues, et `authorName` déjà `null`
/// quand l'intervenant manque. Ce qui leur reste est du dessin : un cadre, un
/// cadrage, une hiérarchie de texte — et c'est précisément ce qui n'a aucune
/// raison de différer d'une famille à l'autre. La famille se décide en amont,
/// dans le provider et la route ; ici il n'y a plus qu'un contenu à dessiner.
///
/// La seule règle qu'ils portent est celle de la **quatrième absence** : une
/// ligne d'auteur nulle ne se rend pas du tout. Jamais d'« Auteur inconnu » —
/// ça ressemble à une donnée et sera pris pour une erreur de saisie.
library;

import 'package:flutter/material.dart';

import '../../l10n/l10n_extension.dart';
import '../../models/content_view.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../cards/content_cover.dart';
import 'home_section_layout.dart';

/// Grande carte **paysage** ([kHeroCoverSize]) : le visuel porte le texte.
class HomeHeroCard extends StatelessWidget {
  const HomeHeroCard({super.key, required this.content, this.onTap});

  final ContentView content;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final author = content.authorName;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: kHeroCoverSize.width,
        height: kHeroCoverSize.height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            boxShadow: AppShadows.elevation1,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Cadrage **paysage** : c'est l'unique décision de ce widget sur
              // l'image, et elle est portée par `TeachingCover`.
              ContentCover(
                content: content,
                radius: AppRadius.xl,
                orientation: CoverOrientation.landscape,
              ),
              // Voile du bas : sans lui, un titre blanc posé sur une photo
              // claire disparaît. Il ne teinte pas la moitié haute du visuel.
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.xl),
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Color(0xD9000000), Color(0x00000000)],
                      stops: [0.05, 0.75],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (author != null) ...[
                      Text(
                        author.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                    ],
                    Text(
                      content.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.h4.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Carte d'étagère : vignette **portrait** ([kCarouselCoverSize]) à gauche,
/// texte et bouton d'écoute à droite.
class HomeCarouselCard extends StatelessWidget {
  const HomeCarouselCard({super.key, required this.content, this.onTap});

  final ContentView content;
  final VoidCallback? onTap;

  /// Largeur totale : la vignette plus la colonne de texte.
  static const double width = 264;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final author = content.authorName;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: kCarouselCoverSize.height,
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: palette.divider),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            SizedBox(
              width: kCarouselCoverSize.width,
              child: ContentCover(content: content, radius: 0),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      content.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyStrong
                          .copyWith(color: palette.textPrimary),
                    ),
                    if (author != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Icon(Icons.person_outline,
                              size: 13, color: palette.textSecondary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              author,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.caption
                                  .copyWith(color: palette.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    // Pilule « Écouter » contournée (façon maquette).
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(
                          color: palette.primary.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.play_arrow_rounded,
                              size: 16, color: palette.primary),
                          const SizedBox(width: 4),
                          Text(
                            context.l10n.actionListen,
                            style: AppTypography.caption.copyWith(
                              color: palette.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ligne de liste : vignette **portrait** réduite ([kListCoverSize]), titre,
/// intervenant, et le bouton de lecture au bout.
class HomeListRow extends StatelessWidget {
  const HomeListRow({super.key, required this.content, this.onTap});

  final ContentView content;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final author = content.authorName;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            SizedBox(
              width: kListCoverSize.width,
              height: kListCoverSize.height,
              child: ContentCover(content: content, radius: AppRadius.md),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    content.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyStrong
                        .copyWith(color: palette.textPrimary),
                  ),
                  if (author != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption
                          .copyWith(color: palette.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(Icons.play_circle_fill, color: palette.primary, size: 30),
          ],
        ),
      ),
    );
  }
}
