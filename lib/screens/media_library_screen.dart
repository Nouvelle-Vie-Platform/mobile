import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/l10n_extension.dart';
import '../l10n/menu_labels.dart';
import '../models/content_view.dart';
import '../models/media_page_view.dart';
import '../models/menu_entry_view.dart';
import '../router/app_router.dart';
import '../state/gathering_providers.dart';
import '../state/mediatheque_providers.dart';
import '../state/menu_providers.dart';
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
const LinearGradient _discoverGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFF2A4AA8), Color(0xFF7E6A8E)],
  stops: [0.1, 0.9],
);

/// La page implicite quand **aucune page n'est reçue** (avant le premier
/// cycle, ou serveur en retard d'une version) : le catalogue entier, en liste,
/// sans barre d'onglets — ce que l'écran montrait déjà sans menu. Une barre vide
/// se lirait comme une panne.
const MediaPageView _wholeCatalogue = MediaPageView(
  id: 0,
  sections: [
    MediaSectionView(
      id: 0,
      layout: MediaSectionLayout.list,
      sort: MediaSectionSort.latest,
      family: MenuContentFamily.teaching,
      maxItems: 1 << 20,
    ),
  ],
);

/// **La médiathèque en pages** (#167, plan serveur
/// `docs/mediatheque-pages-plan.md`).
///
/// Un onglet est une **page**, une page est faite de **sections** empilées —
/// carrousel phare, cartes horizontales, liste, grille —, chacune avec sa
/// source, son tri et son plafond, réglés au portail (*Présentation ›
/// Médiathèque*). Les puces de la page et la loupe se composent avec la source
/// de **chaque** section ; la règle vit dans `composeSection`, hors de ce
/// widget. Une section vide ne paraît pas ; une page dont toutes les sections
/// sont vides montre l'état vide.
///
/// La surface `media_*` de `menu_entries` n'est plus lue ici (le serveur y
/// farde les pages pour les anciens clients).
class MediaLibraryScreen extends ConsumerStatefulWidget {
  const MediaLibraryScreen({super.key, this.initialRubric});

  /// Le **slug** d'une rubrique d'enseignement, quand on arrive par le « Voir
  /// tout » d'une section d'accueil. La page qui la vise s'ouvre ; à défaut, la
  /// rubrique affine la première page comme une puce. Un slug inconnu ne
  /// ramène rien — jamais tout le catalogue.
  final String? initialRubric;

  /// La loupe de l'en-tête. Ciblée par clé : un test qui la vise doit résister à
  /// un changement de pictogramme.
  static const Key searchButtonKey = Key('media_search_button');

  /// Le champ de recherche, une fois la loupe pressée.
  static const Key searchFieldKey = Key('media_search_field');

  /// Le contenu d'une section rendue, pour les tests.
  static Key sectionKey(int id) => ValueKey('media_section_$id');

  @override
  ConsumerState<MediaLibraryScreen> createState() => _MediaLibraryScreenState();
}

class _MediaLibraryScreenState extends ConsumerState<MediaLibraryScreen> {
  /// La page retenue. `null` = rien choisi : la page que la route demande,
  /// sinon la première.
  int? _selectedPageId;

  /// La puce retenue sous la page active.
  int? _selectedChipId;

  /// Ce que la loupe a saisi. Vide = pas de recherche.
  String _query = '';
  bool _searching = false;

  void _open(ContentView content, MenuContentFamily family) {
    // **Une route par famille**, et l'identifiant, jamais l'objet.
    context.pushNamed(
      switch (family) {
        MenuContentFamily.teaching => AppRoute.teachingDetail,
        MenuContentFamily.gathering => AppRoute.gatheringDetail,
      },
      pathParameters: {'id': content.id},
    );
  }

  @override
  Widget build(BuildContext context) {
    final layoutValue = ref.watch(mediaLibraryLayoutProvider);
    final teachings = ref.watch(allTeachingsProvider);
    final gatherings = ref.watch(allGatheringsProvider);
    final layout = layoutValue.value ?? MediaLibraryLayout.empty;

    // Une page sans libellé affichable ne paraît pas : un onglet nommé
    // « public.nav.dons » ressemble à une fuite de code, pas à un réglage.
    final pages = [
      for (final page in layout.pages)
        if (mediaPageLabel(context, page) != null) page,
    ];
    final slug = widget.initialRubric?.trim();
    final requested = slug == null || slug.isEmpty ? null : slug;
    MediaPageView? designated;
    for (final page in pages) {
      if (requested != null && page.filter.rubric == requested) {
        designated = page;
        break;
      }
    }
    MediaPageView? selected;
    for (final page in pages) {
      if (page.id == _selectedPageId) selected = page;
    }
    final active = selected ??
        designated ??
        (pages.isEmpty ? _wholeCatalogue : pages.first);

    final chips = [
      for (final chip in active.chips)
        if (chip.label.isNotEmpty) chip,
    ];
    MediaFilter? chipFilter;
    for (final chip in chips) {
      if (chip.id == _selectedChipId) chipFilter = chip.filter;
    }
    // La rubrique demandée par la route qu'aucune page ne vise : elle affine la
    // page ouverte comme une puce, tant que personne n'a choisi d'onglet.
    if (chipFilter == null &&
        selected == null &&
        designated == null &&
        requested != null) {
      chipFilter = MediaFilter(rubric: requested);
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: _discoverGradient),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _Header(
                title: context.l10n.mediaTitle,
                searching: _searching,
                hint: context.words.mediaSearchHint,
                onSearch: _toggleSearch,
                onQueryChanged: (value) => setState(() => _query = value),
              ),
              if (pages.isNotEmpty)
                _PageTabs(
                  pages: pages,
                  activeId: active.id,
                  onTap: (page) => setState(() {
                    _selectedPageId = page.id;
                    _selectedChipId = null;
                  }),
                ),
              if (chips.isNotEmpty)
                _PageChips(
                  chips: chips,
                  activeId: _selectedChipId,
                  // Un second appui sur la puce choisie la relâche.
                  onTap: (chip) => setState(() => _selectedChipId =
                      _selectedChipId == chip.id ? null : chip.id),
                ),
              Expanded(
                // **Tirer-pour-rafraîchir** — il enrobe les trois états : c'est
                // sur un magasin **vide** qu'on tire.
                child: RefreshIndicator(
                  onRefresh: ref.watch(pullToRefreshProvider),
                  child: _body(
                    layoutValue: layoutValue,
                    teachings: teachings,
                    gatherings: gatherings,
                    layout: layout,
                    page: active,
                    chip: chipFilter,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body({
    required AsyncValue<MediaLibraryLayout> layoutValue,
    required AsyncValue<List<ContentView>> teachings,
    required AsyncValue<List<ContentView>> gatherings,
    required MediaLibraryLayout layout,
    required MediaPageView page,
    required MediaFilter? chip,
  }) {
    // Une lecture du magasin qui échoue est une **panne**, jamais un catalogue
    // vide : teintée, et avec quelque chose à faire.
    if (layoutValue.hasError || teachings.hasError || gatherings.hasError) {
      return _pullable(
        AppErrorState(
          message: context.l10n.stateErrorMessage,
          onRetry: () {
            ref.invalidate(mediaLibraryLayoutProvider);
            ref.invalidate(allTeachingsProvider);
            ref.invalidate(allGatheringsProvider);
          },
        ),
      );
    }
    // Les pages en cours de lecture n'attendent pas : l'écran montre d'ici là
    // le catalogue entier, comme l'ancien écran avant son menu. Seuls les
    // contenus que la page lit font attendre.
    bool reads(MenuContentFamily family) =>
        page.sections.any((s) => s.family == family);
    if ((reads(MenuContentFamily.teaching) && !teachings.hasValue) ||
        (reads(MenuContentFamily.gathering) && !gatherings.hasValue)) {
      return const Padding(
        padding: EdgeInsets.only(top: AppSpacing.xl),
        child: AppListSkeleton(itemCount: 4, padding: AppSpacing.screenPadding),
      );
    }

    final shown = <(MediaSectionView, List<ContentView>)>[];
    for (final section in page.sections) {
      final family = section.family;
      if (family == null) continue;
      final items = composeSection<ContentView>(
        section: section,
        page: page,
        latestFirst: switch (family) {
          MenuContentFamily.teaching => teachings.requireValue,
          MenuContentFamily.gathering => gatherings.requireValue,
        },
        rubricIds: layout.rubricIdsOf(family),
        branchIds: layout.branchIds,
        chip: chip,
        query: _query,
      );
      if (items.isNotEmpty) shown.add((section, items));
    }

    // Le magasin a répondu, et rien ne paraît : la réponse normale d'un premier
    // lancement, ou d'une recherche qui ne trouve pas. Neutre, sans bouton.
    if (shown.isEmpty) {
      return _pullable(
        AppEmptyState(
          icon: Icons.library_music_outlined,
          title: context.l10n.stateEmptyTitle,
          message: context.l10n.stateEmptyMessage,
        ),
      );
    }

    return CustomScrollView(
      // On tire aussi sur trois contenus.
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
        for (final (section, items) in shown) ..._section(section, items),
        SliverToBoxAdapter(
          child: SizedBox(
            height: MediaQuery.paddingOf(context).bottom + AppSpacing.xl,
          ),
        ),
      ],
    );
  }

  /// Les slivers d'une section : son en-tête s'il y a un titre, puis son
  /// gabarit.
  List<Widget> _section(MediaSectionView section, List<ContentView> items) {
    final family = section.family!;
    final key = MediaLibraryScreen.sectionKey(section.id);
    void open(ContentView content) => _open(content, family);
    final title = mediaSectionTitle(context, section);
    return [
      if (title != null) ...[
        SliverToBoxAdapter(
          child: Padding(
            padding: AppSpacing.screenPadding,
            child: _SectionHeader(title: title),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
      ],
      switch (section.layout) {
        MediaSectionLayout.hero => SliverToBoxAdapter(
            key: key,
            child: SizedBox(
              height: 210,
              child: _HeroCarousel(items: items, onOpen: open),
            ),
          ),
        MediaSectionLayout.carousel => SliverToBoxAdapter(
            key: key,
            child: SizedBox(
              height: 176,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: AppSpacing.screenPadding,
                itemCount: items.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: AppSpacing.md),
                itemBuilder: (_, i) => _AlbumCard(
                  teaching: items[i],
                  onTap: () => open(items[i]),
                ),
              ),
            ),
          ),
        MediaSectionLayout.list => SliverList.builder(
            key: key,
            itemCount: items.length,
            itemBuilder: (_, i) => _PlaylistItem(
              teaching: items[i],
              onTap: () => open(items[i]),
            ),
          ),
        MediaSectionLayout.grid => SliverPadding(
            key: key,
            padding: AppSpacing.screenPadding,
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: AppSpacing.md,
                crossAxisSpacing: AppSpacing.md,
                childAspectRatio: 0.75,
              ),
              itemCount: items.length,
              itemBuilder: (_, i) => _GridTile(
                content: items[i],
                onTap: () => open(items[i]),
              ),
            ),
          ),
      },
      const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
    ];
  }

  void _toggleSearch() => setState(() {
        _searching = !_searching;
        // Refermer la loupe **efface la recherche** : un filtre actif derrière
        // un champ qu'on ne voit plus se prend pour un catalogue vide.
        if (!_searching) _query = '';
      });

  /// Centre un état de liste **sans le rendre immobile** : `RefreshIndicator`
  /// ne réagit qu'à un défilement.
  Widget _pullable(Widget child) => LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(padding: AppSpacing.screenPadding, child: child),
            ),
          ),
        ),
      );
}

/// En-tête : retour, titre (ou champ de recherche), loupe.
class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.searching,
    required this.hint,
    required this.onSearch,
    required this.onQueryChanged,
  });

  final String title;
  final bool searching;
  final String hint;
  final VoidCallback onSearch;
  final ValueChanged<String> onQueryChanged;

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
            child: searching
                ? TextField(
                    key: MediaLibraryScreen.searchFieldKey,
                    autofocus: true,
                    onChanged: onQueryChanged,
                    style:
                        AppTypography.bodyLarge.copyWith(color: Colors.white),
                    cursorColor: _peach,
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: hint,
                      hintStyle: AppTypography.bodyLarge.copyWith(
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                  )
                : Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.h2.copyWith(color: Colors.white),
                  ),
          ),
          IconButton(
            key: MediaLibraryScreen.searchButtonKey,
            icon: Icon(
              searching ? Icons.close : Icons.search,
              color: Colors.white,
              size: 26,
            ),
            onPressed: onSearch,
          ),
        ],
      ),
    );
  }
}

/// **La barre d'onglets : les pages, dans leur ordre.**
class _PageTabs extends StatelessWidget {
  const _PageTabs({
    required this.pages,
    required this.activeId,
    required this.onTap,
  });

  final List<MediaPageView> pages;
  final int activeId;
  final void Function(MediaPageView page) onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: pages.length,
        itemBuilder: (_, i) {
          final page = pages[i];
          final selected = page.id == activeId;
          return GestureDetector(
            onTap: () => onTap(page),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Column(
                children: [
                  Text(
                    mediaPageLabel(context, page)!,
                    style: AppTypography.bodyLarge.copyWith(
                      color: selected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.55),
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (selected)
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

/// **Les puces de la page active.** Aucune n'est choisie par défaut : la page
/// montre d'abord ses sections, et une puce les resserre **toutes**.
class _PageChips extends StatelessWidget {
  const _PageChips({
    required this.chips,
    required this.activeId,
    required this.onTap,
  });

  final List<MediaChipView> chips;
  final int? activeId;
  final void Function(MediaChipView chip) onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (_, i) {
          final chip = chips[i];
          final selected = chip.id == activeId;
          return Align(
            child: GestureDetector(
              onTap: () => onTap(chip),
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? _peach.withValues(alpha: 0.9)
                      : Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  chip.label,
                  style: AppTypography.caption.copyWith(
                    color: selected ? Colors.black87 : Colors.white,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// En-tête de section : barre pêche + titre. Le chevron d'avant `a178b8b` est
/// retiré : « Voir tout » est écarté par le plan, et une flèche qui ne mène
/// nulle part est une promesse que personne ne tient.
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
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.h4.copyWith(color: Colors.white),
          ),
        ),
      ],
    );
  }
}

/// Le carrousel phare : un `PageView` à `viewportFraction: 0.86`, dont le
/// contrôleur vit avec le widget (créé dans `build`, il se recréait à chaque
/// reconstruction et ramenait le carrousel au début).
class _HeroCarousel extends StatefulWidget {
  const _HeroCarousel({required this.items, required this.onOpen});

  final List<ContentView> items;
  final void Function(ContentView content) onOpen;

  @override
  State<_HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<_HeroCarousel> {
  final _controller = PageController(viewportFraction: 0.86);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _controller,
      itemCount: widget.items.length,
      itemBuilder: (_, i) => _HeroCard(
        teaching: widget.items[i],
        onTap: () => widget.onOpen(widget.items[i]),
      ),
    );
  }
}

/// Grande carte du carrousel phare (reprise de `a178b8b^`).
class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.teaching, this.onTap});
  final ContentView teaching;
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
                  // pris pour une erreur de saisie.
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

/// Carte carrée des cartes horizontales (reprise de `a178b8b^`).
class _AlbumCard extends StatelessWidget {
  const _AlbumCard({required this.teaching, this.onTap});
  final ContentView teaching;
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
              child: ContentCover(
                content: teaching,
                radius: AppRadius.lg,
                orientation: CoverOrientation.square,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              teaching.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodyStrong.copyWith(color: Colors.white),
            ),
            // Rien à la place de l'intervenant manquant.
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

/// Ligne verticale façon playlist (reprise de `a178b8b^`).
class _PlaylistItem extends StatelessWidget {
  const _PlaylistItem({required this.teaching, this.onTap});
  final ContentView teaching;
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
              child: ContentCover(
                content: teaching,
                radius: AppRadius.md,
                orientation: CoverOrientation.square,
              ),
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
            // sert pas. Il est **déjà replié** par le modèle de lecture.
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

/// Vignette de la grille sur deux colonnes (gabarit `grid`, neuf) : la
/// pochette carrée de [_AlbumCard], à la largeur de sa colonne.
class _GridTile extends StatelessWidget {
  const _GridTile({required this.content, this.onTap});
  final ContentView content;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final author = content.authorName;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: ContentCover(
              content: content,
              radius: AppRadius.lg,
              orientation: CoverOrientation.square,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            content.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodyStrong.copyWith(color: Colors.white),
          ),
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
    );
  }
}
