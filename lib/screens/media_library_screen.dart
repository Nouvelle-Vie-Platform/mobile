import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/l10n_extension.dart';
import '../models/models.dart';
import '../router/app_router.dart';
import '../state/repository_providers.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/cards/teaching_cover.dart';

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
class MediaLibraryScreen extends ConsumerStatefulWidget {
  const MediaLibraryScreen({super.key});

  @override
  ConsumerState<MediaLibraryScreen> createState() => _MediaLibraryScreenState();
}

class _MediaLibraryScreenState extends ConsumerState<MediaLibraryScreen> {
  int _tab = 0;

  /// Ouvre l'enseignement **par son identifiant** : l'écran de détail le
  /// relira dans la source de vérité, il n'en reçoit pas une copie.
  void _openTeaching(Teaching t) => context.pushNamed(
        AppRoute.teachingDetail,
        pathParameters: {'id': t.id},
      );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final teachings = ref.watch(teachingsProvider);
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
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: _CategoryTabs(
                        tabs: tabs,
                        selected: _tab,
                        onSelect: (i) => setState(() => _tab = i),
                      ),
                    ),
                    const SliverToBoxAdapter(
                        child: SizedBox(height: AppSpacing.xl)),
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
                    const SliverToBoxAdapter(
                        child: SizedBox(height: AppSpacing.xxl)),
                    // Derniers enseignements (cartes horizontales).
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: AppSpacing.screenPadding,
                        child: _SectionHeader(title: l.sectionLatestTeachings),
                      ),
                    ),
                    const SliverToBoxAdapter(
                        child: SizedBox(height: AppSpacing.md)),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 176,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: AppSpacing.screenPadding,
                          itemCount: teachings.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: AppSpacing.md),
                          itemBuilder: (_, i) => _AlbumCard(
                            teaching: teachings[i],
                            onTap: () => _openTeaching(teachings[i]),
                          ),
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(
                        child: SizedBox(height: AppSpacing.xl)),
                    // Recommandés (liste verticale).
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: AppSpacing.screenPadding,
                        child: _SectionHeader(title: l.mediaRecommended),
                      ),
                    ),
                    const SliverToBoxAdapter(
                        child: SizedBox(height: AppSpacing.sm)),
                    SliverList.builder(
                      itemCount: teachings.length,
                      itemBuilder: (_, i) => _PlaylistItem(
                        teaching: teachings[i],
                        onTap: () => _openTeaching(teachings[i]),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: MediaQuery.paddingOf(context).bottom +
                            AppSpacing.xl,
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
  final Teaching teaching;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
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
            TeachingCover(teaching: teaching),
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
                  Text(
                    teaching.author.toUpperCase(),
                    style: AppTypography.caption.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
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
  final Teaching teaching;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
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
              child: TeachingCover(teaching: teaching, radius: AppRadius.lg),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              teaching.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodyStrong.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 2),
            Text(
              teaching.author,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption
                  .copyWith(color: Colors.white.withValues(alpha: 0.6)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ligne verticale (recommandation).
class _PlaylistItem extends StatelessWidget {
  const _PlaylistItem({required this.teaching, this.onTap});
  final Teaching teaching;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
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
              child: TeachingCover(teaching: teaching, radius: AppRadius.md),
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
                  const SizedBox(height: 4),
                  Text(
                    teaching.author,
                    style: AppTypography.caption
                        .copyWith(color: Colors.white.withValues(alpha: 0.6)),
                  ),
                ],
              ),
            ),
            Text(
              teaching.duration,
              style: AppTypography.caption
                  .copyWith(color: Colors.white.withValues(alpha: 0.6)),
            ),
          ],
        ),
      ),
    );
  }
}
