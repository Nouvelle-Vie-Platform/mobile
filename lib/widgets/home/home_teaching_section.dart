import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n_extension.dart';
import '../../models/mediatheque_view.dart';
import '../../router/app_router.dart';
import '../../state/mediatheque_providers.dart';
import '../../theme/app_spacing.dart';
import '../app_error_state.dart';
import '../app_list_skeleton.dart';
import '../section_header.dart';
import 'home_section_layout.dart';
import 'home_teaching_cards.dart';

/// **Une rubrique du référentiel, rendue à l'accueil.**
///
/// Tout ce qui la décrit vient du serveur et rien n'est décidé ici : son rang
/// (`position`, appliqué par [homeSectionsProvider]), son titre (`label`, déjà
/// replié dans la langue courante), sa teinte (`color`, déjà en bout de
/// cascade) et sa forme (`layout`, traduite en dessin par
/// [HomeSectionLayout.of]). Un administrateur crée une rubrique, la place,
/// choisit sa mise en page — et l'accueil suit, sans livraison.
///
/// **Une rubrique sans enseignement ne se rend pas du tout**, en-tête compris.
/// `MediathequeDao.homeSections()` applique déjà la règle en amont
/// (`teachingCount` est toujours strictement positif) et cet écran ne la
/// contourne pas : c'est elle qui fait disparaître d'elle-même une rubrique
/// **supprimée côté serveur**. `teaching_types` se supprime durement et sans
/// tombstone — aucun message de retrait ne voyage jamais — et sans cette règle
/// l'accueil garderait une section fantôme définitivement vide. Elle couvre au
/// passage la rubrique fraîchement créée mais pas encore remplie.
class HomeTeachingSection extends ConsumerWidget {
  const HomeTeachingSection({super.key, required this.section});

  /// La rubrique telle que le magasin la rend : déjà filtrée sur
  /// `visibleOnHome`, déjà rangée, déjà repliée.
  final HomeSectionView section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teachings =
        ref.watch(teachingsOfTypeProvider(section.teachingTypeId));

    return teachings.when(
      // La rubrique est **connue non vide** (le magasin ne l'aurait pas rendue
      // sinon) : annoncer son titre pendant la lecture ne promet rien de faux.
      loading: () => _framed(
        context,
        const AppListSkeleton(
          itemCount: 1,
          padding: AppSpacing.screenPadding,
        ),
      ),
      error: (_, __) => _framed(
        context,
        Padding(
          padding: AppSpacing.screenPadding,
          child: AppErrorState(
            message: context.l10n.stateErrorMessage,
            onRetry: () => ref.invalidate(
              teachingsOfTypeProvider(section.teachingTypeId),
            ),
          ),
        ),
      ),
      data: (list) {
        // Le compte du magasin et la liste se lisent dans deux flux : entre les
        // deux, une rétractation a pu vider la rubrique. Elle disparaît alors
        // entièrement, comme si elle n'avait jamais été rendue.
        if (list.isEmpty) return const SizedBox.shrink();
        return _framed(context, _body(context, list));
      },
    );
  }

  /// En-tête de la rubrique + corps, avec les respirations de l'accueil.
  Widget _framed(BuildContext context, Widget body) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.xl),
        Padding(
          padding: AppSpacing.screenPadding,
          child: SectionHeader(
            title: section.label,
            // La teinte du référentiel, portée par une **pastille pleine** et
            // non par le texte du titre : une couleur administrable est sûre en
            // aplat (la forme la porte) et ne l'est pas en texte, où le fond
            // adaptatif clair/sombre en avalerait la moitié.
            accent: Color(section.color),
            actionLabel: context.l10n.actionSeeAll,
            onAction: () => context.pushNamed(AppRoute.media),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        body,
      ],
    );
  }

  Widget _body(BuildContext context, List<TeachingView> teachings) {
    void open(TeachingView teaching) => context.pushNamed(
          AppRoute.teachingDetail,
          pathParameters: {'id': teaching.id},
        );

    switch (HomeSectionLayout.of(section.layout)) {
      case HomeSectionLayout.hero:
        return _Shelf(
          height: kHeroCoverSize.height,
          itemCount: teachings.length,
          itemBuilder: (_, i) => HomeHeroCard(
            teaching: teachings[i],
            onTap: () => open(teachings[i]),
          ),
        );
      case HomeSectionLayout.carousel:
        return _Shelf(
          height: kCarouselCoverSize.height,
          itemCount: teachings.length,
          itemBuilder: (_, i) => HomeCarouselCard(
            teaching: teachings[i],
            onTap: () => open(teachings[i]),
          ),
        );
      case HomeSectionLayout.list:
        // Plafonnée : l'accueil est une vitrine, et une liste verticale non
        // bornée chasserait les sections suivantes hors de portée du pouce.
        final shown = teachings.length > kHomeSectionListLimit
            ? teachings.sublist(0, kHomeSectionListLimit)
            : teachings;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final teaching in shown)
              HomeListRow(teaching: teaching, onTap: () => open(teaching)),
          ],
        );
    }
  }
}

/// Étagère horizontale à hauteur fixe — la forme commune de `hero` et
/// `carousel`, qui ne diffèrent que par la carte et sa taille.
class _Shelf extends StatelessWidget {
  const _Shelf({
    required this.height,
    required this.itemCount,
    required this.itemBuilder,
  });

  final double height;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: AppSpacing.screenPadding,
        itemCount: itemCount,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
        itemBuilder: itemBuilder,
      ),
    );
  }
}
