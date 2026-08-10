import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/l10n_extension.dart';
import '../models/mediatheque_view.dart';
import '../router/app_router.dart';
import '../state/mediatheque_providers.dart';
import '../state/sync_providers.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_error_state.dart';
import '../widgets/app_list_skeleton.dart';
import '../widgets/cards/content_cover.dart';

/// Accent chaud (pêche) propre à l'écran « Découverte ».
const Color _peach = Color(0xFFF1A895);

/// Dégradé d'arrière-plan « Découverte » : bleu des en-têtes → mauve.
///
/// Le bleu du haut reprend le départ de [AppColors.gradientPrimary] utilisé
/// par les en-têtes de toutes les pages.
const LinearGradient _discoverGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFF2A4AA8), Color(0xFF7E6A8E)],
  stops: [0.1, 0.9],
);

/// Écran « Médiathèque » façon Découverte : carrousel phare, cartes
/// horizontales et liste de recommandations, habillés par les données.
///
/// Sa source est désormais un `AsyncValue` : le catalogue vient du magasin
/// local, et une lecture de base n'est pas instantanée. Les trois états sont
/// donc dessinés, et **distincts** — un catalogue vide (`AppEmptyState`,
/// neutre) ne doit jamais ressembler à une lecture qui a échoué
/// (`AppErrorState`, teinté, avec « Réessayer »). Sur un premier lancement, le
/// vide est la réponse normale : la synchronisation n'a pas encore rempli le
/// magasin.
class MediaLibraryScreen extends ConsumerStatefulWidget {
  const MediaLibraryScreen({super.key});

  @override
  ConsumerState<MediaLibraryScreen> createState() => _MediaLibraryScreenState();
}

class _MediaLibraryScreenState extends ConsumerState<MediaLibraryScreen> {
  int _tab = 0;

  /// Ouvre l'enseignement **par son identifiant** : l'écran de détail le
  /// relira dans la source de vérité, il n'en reçoit pas une copie.
  void _openTeaching(TeachingView t) => context.pushNamed(
        AppRoute.teachingDetail,
        pathParameters: {'id': t.id},
      );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tabs = [
      l.filterAll,
      l.filterSermons,
      l.filterTeachings,
      l.filterMusic,
    ];

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: _discoverGradient),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // En-tête fixe (ne défile pas avec le contenu).
              _Header(title: l.mediaTitle),
              // Les onglets restent visibles dans les trois états : ils
              // appartiennent au chrome de l'écran, pas au catalogue.
              _CategoryTabs(
                tabs: tabs,
                selected: _tab,
                onSelect: (i) => setState(() => _tab = i),
              ),
              Expanded(
                // **Tirer-pour-rafraîchir** — le troisième déclencheur
                // d'ADR-0017, et le seul que l'utilisateur commande. Il enrobe
                // les trois états, pas seulement le catalogue rempli : c'est
                // sur un magasin **vide** qu'on tire, au premier lancement,
                // quand la synchronisation d'ouverture est tombée sur un
                // réseau absent.
                child: RefreshIndicator(
                  onRefresh: ref.watch(pullToRefreshProvider),
                  child: ref.watch(allTeachingsProvider).when(
                        loading: _buildLoading,
                        error: (_, __) => _buildError(),
                        data: _buildCatalogue,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() => const Padding(
        padding: EdgeInsets.only(top: AppSpacing.xl),
        child: AppListSkeleton(itemCount: 4, padding: AppSpacing.screenPadding),
      );

  /// Une lecture du magasin qui échoue est une **panne**, jamais un catalogue
  /// vide : teintée, et avec quelque chose à faire.
  Widget _buildError() => _pullable(
        AppErrorState(
          message: context.l10n.stateErrorMessage,
          onRetry: () => ref.invalidate(allTeachingsProvider),
        ),
      );

  /// Le magasin a répondu, et il n'a rien : c'est la réponse normale d'un
  /// premier lancement, avant que la synchronisation ne l'ait rempli. Neutre,
  /// sans bouton — il n'y a rien à réessayer.
  Widget _buildEmpty() => _pullable(
        AppEmptyState(
          icon: Icons.library_music_outlined,
          title: context.l10n.stateEmptyTitle,
          message: context.l10n.stateEmptyMessage,
        ),
      );

  /// Centre un état de liste **sans le rendre immobile**.
  ///
  /// Un `Center` seul n'est pas défilable, et `RefreshIndicator` ne réagit
  /// qu'à un défilement : sans cette enveloppe, le geste n'existerait pas
  /// exactement là où il sert — sur un catalogue vide ou après une lecture
  /// ratée. D'où l'`AlwaysScrollableScrollPhysics` : il faut pouvoir tirer un
  /// contenu plus court que l'écran.
  Widget _pullable(Widget child) => LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: AppSpacing.screenPadding,
                child: child,
              ),
            ),
          ),
        ),
      );

  Widget _buildCatalogue(List<TeachingView> teachings) {
    if (teachings.isEmpty) return _buildEmpty();
    final l = context.l10n;

    return CustomScrollView(
      // Le catalogue est plus long que l'écran, mais le geste ne doit pas
      // dépendre de sa longueur : on tire aussi sur trois enseignements.
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
        // Carrousel phare.
        SliverToBoxAdapter(
          child: SizedBox(
            height: 210,
            child: PageView.builder(
              controller: PageController(viewportFraction: 0.86),
              itemCount: teachings.length,
              itemBuilder: (_, i) => _HeroCard(
                teaching: teachings[i],
                onTap: () => _openTeaching(teachings[i]),
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
        // Derniers enseignements (cartes horizontales).
        SliverToBoxAdapter(
          child: Padding(
            padding: AppSpacing.screenPadding,
            child: _SectionHeader(title: l.sectionLatestTeachings),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 176,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: AppSpacing.screenPadding,
              itemCount: teachings.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
              itemBuilder: (_, i) => _AlbumCard(
                teaching: teachings[i],
                onTap: () => _openTeaching(teachings[i]),
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
        // Recommandés (liste verticale).
        SliverToBoxAdapter(
          child: Padding(
            padding: AppSpacing.screenPadding,
            child: _SectionHeader(title: l.mediaRecommended),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.sm)),
        SliverList.builder(
          itemCount: teachings.length,
          itemBuilder: (_, i) => _PlaylistItem(
            teaching: teachings[i],
            onTap: () => _openTeaching(teachings[i]),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: MediaQuery.paddingOf(context).bottom + AppSpacing.xl,
          ),
        ),
      ],
    );
  }
}

/// En-tête : retour, titre et recherche.
class _Header extends StatelessWidget {
  const _Header({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new,
                color: Colors.white, size: 20),
            onPressed: () => context.pop(),
          ),
          Expanded(
            child: Text(
              title,
              style: AppTypography.h2.copyWith(color: Colors.white),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white, size: 26),
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}

/// Onglets horizontaux avec soulignement pêche.
class _CategoryTabs extends StatelessWidget {
  const _CategoryTabs({
    required this.tabs,
    required this.selected,
    required this.onSelect,
  });

  final List<String> tabs;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: tabs.length,
        itemBuilder: (_, i) {
          final isSel = i == selected;
          return GestureDetector(
            onTap: () => onSelect(i),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Column(
                children: [
                  Text(
                    tabs[i],
                    style: AppTypography.bodyLarge.copyWith(
                      color: isSel
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.55),
                      fontWeight: isSel ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (isSel)
                    Container(
                      height: 3,
                      width: 36,
                      decoration: BoxDecoration(
                        color: _peach,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// En-tête de section : barre pêche + titre + chevron.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 18,
          decoration: BoxDecoration(
            color: _peach,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(title, style: AppTypography.h4.copyWith(color: Colors.white)),
        const Spacer(),
        Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.6)),
      ],
    );
  }
}

/// Grande carte du carrousel phare.
class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.teaching, this.onTap});
  final TeachingView teaching;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final author = teaching.authorName;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ContentCover(content: teaching),
            // Voile dégradé pour la lisibilité du texte.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.black.withValues(alpha: 0.55),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Intervenant manquant : **la ligne ne se rend pas**. Un
                  // « Auteur inconnu » ressemblerait à une donnée et serait
                  // pris pour une erreur de saisie ; l'enseignement, lui,
                  // s'affiche quand même et le nom paraîtra au cycle suivant.
                  if (author != null) ...[
                    Text(
                      author.toUpperCase(),
                      style: AppTypography.caption.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    teaching.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.h3.copyWith(
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
    );
  }
}

/// Carte carrée (enseignement récent).
class _AlbumCard extends StatelessWidget {
  const _AlbumCard({required this.teaching, this.onTap});
  final TeachingView teaching;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final author = teaching.authorName;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 124,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 124,
              height: 120,
              child: ContentCover(content: teaching, radius: AppRadius.lg),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              teaching.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodyStrong.copyWith(color: Colors.white),
            ),
            // Rien à la place de l'intervenant manquant : la carte se
            // referme d'un cran, elle ne porte pas de nom inventé.
            if (author != null) ...[
              const SizedBox(height: 2),
              Text(
                author,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption
                    .copyWith(color: Colors.white.withValues(alpha: 0.6)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Ligne verticale (recommandation).
class _PlaylistItem extends StatelessWidget {
  const _PlaylistItem({required this.teaching, this.onTap});
  final TeachingView teaching;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final author = teaching.authorName;
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
              width: 56,
              height: 56,
              child: ContentCover(content: teaching, radius: AppRadius.md),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    teaching.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        AppTypography.bodyStrong.copyWith(color: Colors.white),
                  ),
                  if (author != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      author,
                      style: AppTypography.caption
                          .copyWith(color: Colors.white.withValues(alpha: 0.6)),
                    ),
                  ],
                ],
              ),
            ),
            // Le libellé de la rubrique remplace la durée, que le serveur ne
            // sert pas. Il est **déjà replié** dans la langue courante par le
            // modèle de lecture — chaîne vide si la rubrique manque.
            if (teaching.typeLabel.isNotEmpty)
              Text(
                teaching.typeLabel,
                style: AppTypography.caption
                    .copyWith(color: Colors.white.withValues(alpha: 0.6)),
              ),
          ],
        ),
      ),
    );
  }
}
