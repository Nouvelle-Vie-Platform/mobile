import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/l10n_extension.dart';
import '../l10n/menu_labels.dart';
import '../models/content_view.dart';
import '../models/menu_entry_view.dart';
import '../router/app_router.dart';
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

/// **La médiathèque, et ses onglets qui filtrent pour de vrai** (#82).
///
/// Ce que cet écran était : quatre onglets dont `_tab` ne servait qu'à déplacer
/// un soulignement — « Musique » affichait exactement la même chose que
/// « Tout » —, une loupe en `onPressed: () {}`, et **trois sections affichant le
/// même tableau, entier, trois fois, dans le même ordre**. « Recommandés pour
/// vous » n'était pas une recommandation.
///
/// Ce qu'il est : **une barre d'onglets réglée au portail et une seule liste
/// honnête**. Les trois sections décoratives ont disparu — garder « Recommandés
/// pour vous » aurait été entretenir le mensonge, et le remplacer par un
/// algorithme est hors de ce chantier (il n'y a pas de recommandation, il y a un
/// retrait).
///
/// ## Ce que l'écran décide, et ce qu'il ne décide pas
///
/// Il ne décide **rien** du menu : l'ordre, les libellés, les destinations, les
/// sous-entrées et la fenêtre de publication arrivent tranchés par
/// `StoreMenuRepository`. Il décide **quel onglet est actif, et ce qu'il
/// montre** — et c'est tout ce qu'un écran a à répondre.
///
/// ## L'onglet implicite, quand il n'y a pas de menu
///
/// Un menu **vide** est un état plein de sens : avant le premier cycle, sur un
/// serveur en retard d'une version (la collection prend un `404`, le moteur la
/// saute), ou si le portail a tout décoché. L'écran montre alors **le catalogue
/// entier**, sans barre d'onglets : c'est exactement ce que l'ancienne barre
/// prétendait faire avec son onglet « Tout », et c'est la seule réponse qui ne
/// cache aucun contenu. Une barre vide, elle, se lirait comme une panne.
///
/// ## Trois choses qu'une entrée porte et que cet écran ne rend pas
///
/// - **`icon`** : le nom vient du kit du portail (`lucide`), que ce binaire
///   n'embarque pas. Le traduire demanderait une table de correspondance tenue à
///   la main, qu'un seul ajout au portail désaccorderait en silence ;
/// - **`filterRubric` / `filterBranch` / `filterFamily`** : les puces d'un onglet
///   sont ses **sous-entrées**, qui portent leur libellé et leur destination
///   réglés au portail. Fabriquer des puces depuis ces trois cases donnerait un
///   ordre et des libellés que le portail ne voit pas ;
/// - **le slug de branche** : voir `menuTeachingsProvider` — ce client ne sait pas
///   le résoudre, et une entrée qui en exige un ne paraît pas du tout.
///
/// `filterSearch`, lui, a enfin son lecteur : **la loupe**.
class MediaLibraryScreen extends ConsumerStatefulWidget {
  const MediaLibraryScreen({super.key, this.initialRubric});

  /// Le **slug** d'une rubrique d'enseignement, quand on arrive par le « Voir
  /// tout » d'une section d'accueil.
  ///
  /// Un slug et non un identifiant : c'est ce qui survit au renommage, c'est ce
  /// que porte le modèle de menu, et c'est ce qu'un lien partagé ou une
  /// notification saurait transporter.
  final String? initialRubric;

  /// La loupe de l'en-tête. Ciblée par clé : un test qui la vise doit résister à
  /// un changement de pictogramme.
  static const Key searchButtonKey = Key('media_search_button');

  /// Le champ de recherche, une fois la loupe pressée.
  static const Key searchFieldKey = Key('media_search_field');

  @override
  ConsumerState<MediaLibraryScreen> createState() => _MediaLibraryScreenState();
}

class _MediaLibraryScreenState extends ConsumerState<MediaLibraryScreen> {
  /// L'entrée retenue. `null` = « je n'ai rien choisi », ce qui n'est pas la même
  /// chose que « la première » : sans choix, c'est la rubrique demandée par la
  /// route qui l'emporte, et la première entrée seulement à défaut.
  int? _selectedId;

  /// La sous-entrée retenue sous l'onglet actif, s'il y en a une.
  int? _selectedChildId;

  /// Ce que la loupe a saisi. Vide = pas de recherche, jamais « cherche la
  /// chaîne vide ».
  String _query = '';
  bool _searching = false;

  void _openContent(ContentView content, MenuContentFamily family) {
    // **Une route par famille**, jamais `/content/:famille/:id` : le chemin
    // dirait sinon au client qu'il lui revient de trancher entre deux
    // collections. Et l'identifiant, jamais l'objet.
    context.pushNamed(
      switch (family) {
        MenuContentFamily.teaching => AppRoute.teachingDetail,
        MenuContentFamily.gathering => AppRoute.gatheringDetail,
      },
      pathParameters: {'id': content.id},
    );
  }

  /// Le geste sur un onglet. Une destination externe **ouvre le navigateur** et
  /// ne devient pas l'onglet actif : il n'y a pas de liste dont elle serait le
  /// filtre, et la souligner laisserait un écran qui ne change pas.
  Future<void> _tapEntry(MenuEntryView entry) async {
    final destination = entry.destination;
    if (destination is MenuExternalLink) {
      await ref.read(externalLinkLauncherProvider).open(destination.url);
      return;
    }
    setState(() {
      _selectedId = entry.id;
      _selectedChildId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final menu = ref.watch(mediaMenuProvider);
    // Une entrée sans libellé affichable ne paraît pas : un onglet nommé
    // « public.nav.dons » ressemble à une fuite de code, pas à un réglage.
    final entries = [
      for (final entry in menu.value ?? const <MenuEntryView>[])
        if (menuEntryLabel(context, entry) != null) entry,
    ];

    final active = _activeEntry(entries);
    final destination = _activeDestination(entries, active);
    final children = active?.children ?? const <MenuEntryView>[];
    final offersSearch = active?.offersSearch ?? false;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: _discoverGradient),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _Header(
                // Le lot éditorial de l'entrée prend la place du titre quand le
                // portail en a réglé un : c'est ce que « titre de la page »
                // signifie, et c'est son seul lecteur sur cette surface.
                title: _titleOf(active),
                searching: _searching,
                hint: context.words.mediaSearchHint,
                // La loupe n'existe que si l'entrée offre la puce « recherche ».
                // C'est la case `filter_search`, servie depuis la tranche
                // précédente et qui n'avait aucun consommateur.
                onSearch: offersSearch ? _toggleSearch : null,
                onQueryChanged: (value) => setState(() => _query = value),
              ),
              // La barre d'onglets n'existe que s'il y a un menu : une barre
              // vide se lirait comme une panne, et le catalogue entier est de
              // toute façon ce que l'écran montre alors.
              if (entries.isNotEmpty)
                _MenuTabs(
                  entries: entries,
                  activeId: active?.id,
                  onTap: _tapEntry,
                ),
              if (children.isNotEmpty)
                _MenuChips(
                  children: children,
                  activeId: _selectedChildId,
                  onTap: (child) => setState(() => _selectedChildId = child.id),
                ),
              if (_descriptionOf(active) case final description?)
                Padding(
                  padding: AppSpacing.screenPadding +
                      const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    description,
                    style: AppTypography.caption
                        .copyWith(color: Colors.white.withValues(alpha: 0.75)),
                  ),
                ),
              Expanded(
                // **Tirer-pour-rafraîchir** — le troisième déclencheur
                // d'ADR-0017, et le seul que l'utilisateur commande. Il enrobe
                // les trois états : c'est sur un magasin **vide** qu'on tire.
                child: RefreshIndicator(
                  onRefresh: ref.watch(pullToRefreshProvider),
                  child: menu.hasError
                      ? _pullable(
                          _error(() => ref.invalidate(mediaMenuProvider)))
                      : _Catalogue(
                          destination: destination,
                          query: _query,
                          onOpen: _openContent,
                          frame: _pullable,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleSearch() => setState(() {
        _searching = !_searching;
        // Refermer la loupe **efface la recherche** : laisser un filtre actif
        // derrière un champ qu'on ne voit plus est le genre de liste tronquée
        // qu'on prend pour un catalogue vide.
        if (!_searching) _query = '';
      });

  /// L'entrée dont l'onglet est souligné, ou `null` — menu vide, ou rubrique
  /// demandée par la route qu'aucune entrée ne désigne.
  MenuEntryView? _activeEntry(List<MenuEntryView> entries) {
    if (entries.isEmpty) return null;
    for (final entry in entries) {
      if (entry.id == _selectedId) return entry;
    }
    if (_selectedId != null) return null;

    // Aucun choix fait. Si la route demande une rubrique, c'est l'entrée qui la
    // désigne qui s'allume — et **aucune** si personne ne la désigne : souligner
    // un onglet dirait que la liste vient de lui, et elle n'en vient pas.
    final requested = _requestedDestination();
    if (requested != null) {
      for (final entry in entries) {
        if (entry.destination == requested) return entry;
      }
      return null;
    }
    // Le premier onglet qui montre une liste. Un lien externe n'en est pas un :
    // il n'a pas de liste à être l'onglet de.
    for (final entry in entries) {
      if (entry.destination is MenuCatalogue) return entry;
    }
    return null;
  }

  /// Ce que la liste montre, et c'est la seule question que l'écran tranche.
  MenuCatalogue _activeDestination(
    List<MenuEntryView> entries,
    MenuEntryView? active,
  ) {
    if (active != null) {
      for (final child in active.children) {
        if (child.id != _selectedChildId) continue;
        final destination = child.destination;
        if (destination is MenuCatalogue) return destination;
      }
      final own = active.destination;
      if (own is MenuCatalogue) return own;
    }
    // La rubrique demandée par la route, quand aucune entrée ne la désigne : le
    // « Voir tout » d'une section d'accueil doit filtrer **même** si personne n'a
    // créé l'entrée correspondante — c'est le bug que cette tranche répare.
    final requested = _requestedDestination();
    if (requested != null) return requested;
    // L'onglet implicite : le catalogue entier.
    return const MenuCatalogue(family: MenuContentFamily.teaching);
  }

  /// La destination que la route demande, ou `null`.
  ///
  /// Un slug **inconnu du magasin** donne une destination qui ne ramène rien, et
  /// non le catalogue entier : c'est la doctrine du site public devant un
  /// `?rubrique=` inconnu, et la seule qui ne mente pas.
  MenuCatalogue? _requestedDestination() {
    final slug = widget.initialRubric?.trim();
    if (slug == null || slug.isEmpty) return null;
    return MenuCatalogue(
      family: MenuContentFamily.teaching,
      rubricSlug: slug,
      rubricId: ref.watch(teachingRubricIdProvider(slug)).value,
    );
  }

  String _titleOf(MenuEntryView? active) {
    final pageTitle = active?.pageTitle ?? '';
    return pageTitle.isNotEmpty ? pageTitle : context.l10n.mediaTitle;
  }

  String? _descriptionOf(MenuEntryView? active) {
    final description = active?.pageDescription ?? '';
    return description.isEmpty ? null : description;
  }

  Widget _error(VoidCallback onRetry) => AppErrorState(
        message: context.l10n.stateErrorMessage,
        onRetry: onRetry,
      );

  /// Centre un état de liste **sans le rendre immobile**.
  ///
  /// `RefreshIndicator` ne réagit qu'à un défilement : sans cette enveloppe, le
  /// geste n'existerait pas exactement là où il sert — sur un catalogue vide ou
  /// après une lecture ratée.
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

/// **Le corps : une seule liste, filtrée par la destination de l'onglet actif.**
///
/// Elle dispatche sur la famille et **jamais sur un champ de ligne** : deux
/// providers, deux collections, deux routes. `destinationFamily` dit quelle
/// collection lire, elle ne range pas une ligne (ADR-0026 décision 1).
class _Catalogue extends ConsumerWidget {
  const _Catalogue({
    required this.destination,
    required this.query,
    required this.onOpen,
    required this.frame,
  });

  final MenuCatalogue destination;
  final String query;
  final void Function(ContentView content, MenuContentFamily family) onOpen;
  final Widget Function(Widget child) frame;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // La recherche de l'entrée et celle du fidèle se **composent** : l'entrée
    // borne, le fidèle affine.
    final effective = destination.withSearch(query);
    final items = switch (destination.family) {
      MenuContentFamily.teaching => ref.watch(menuTeachingsProvider(effective)),
      MenuContentFamily.gathering =>
        ref.watch(menuGatheringsProvider(effective)),
    };

    return items.when(
      loading: () => const Padding(
        padding: EdgeInsets.only(top: AppSpacing.xl),
        child: AppListSkeleton(itemCount: 4, padding: AppSpacing.screenPadding),
      ),
      // Une lecture du magasin qui échoue est une **panne**, jamais un catalogue
      // vide : teintée, et avec quelque chose à faire.
      error: (_, __) => frame(
        AppErrorState(
          message: context.l10n.stateErrorMessage,
          onRetry: () => ref.invalidate(
            destination.family == MenuContentFamily.teaching
                ? menuTeachingsProvider(effective)
                : menuGatheringsProvider(effective),
          ),
        ),
      ),
      data: (contents) {
        // Le magasin a répondu, et il n'a rien : la réponse normale d'un premier
        // lancement, ou d'une recherche qui ne trouve pas. Neutre, sans bouton —
        // il n'y a rien à réessayer.
        if (contents.isEmpty) {
          return frame(
            AppEmptyState(
              icon: Icons.library_music_outlined,
              title: context.l10n.stateEmptyTitle,
              message: context.l10n.stateEmptyMessage,
            ),
          );
        }
        return ListView.builder(
          // La liste est plus longue que l'écran, mais le geste ne doit pas
          // dépendre de sa longueur : on tire aussi sur trois contenus.
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(
            top: AppSpacing.md,
            bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.xl,
          ),
          itemCount: contents.length,
          itemBuilder: (_, i) => _ContentRow(
            content: contents[i],
            onTap: () => onOpen(contents[i], destination.family),
          ),
        );
      },
    );
  }
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

  /// `null` quand l'entrée active n'offre pas la puce « recherche » : **on ne
  /// grise pas une loupe**, on ne la propose pas. Une icône inerte reste une
  /// promesse que personne ne tient — c'est exactement ce qu'était
  /// `onPressed: () {}`.
  final VoidCallback? onSearch;
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
          if (onSearch != null)
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

/// **La barre d'onglets : les entrées du portail, dans leur ordre.**
///
/// `divided` pose un filet avant l'entrée — ignoré sur la première, où il n'y a
/// rien à séparer. `featured` met le libellé à l'accent même non sélectionné :
/// c'est ce qu'une « mise en avant » peut valoir sur une barre d'onglets, qui n'a
/// pas de bouton à accentuer.
class _MenuTabs extends StatelessWidget {
  const _MenuTabs({
    required this.entries,
    required this.activeId,
    required this.onTap,
  });

  final List<MenuEntryView> entries;
  final int? activeId;
  final void Function(MenuEntryView entry) onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: entries.length,
        itemBuilder: (_, i) {
          final entry = entries[i];
          final selected = entry.id == activeId;
          final label = menuEntryLabel(context, entry)!;
          return Row(
            children: [
              if (entry.divided && i > 0)
                Container(
                  width: 1,
                  height: 16,
                  margin: const EdgeInsets.only(right: AppSpacing.sm),
                  color: Colors.white.withValues(alpha: 0.3),
                ),
              GestureDetector(
                onTap: () => onTap(entry),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Column(
                    children: [
                      Text(
                        label,
                        style: AppTypography.bodyLarge.copyWith(
                          color: selected
                              ? Colors.white
                              : entry.featured
                                  ? _peach
                                  : Colors.white.withValues(alpha: 0.55),
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w400,
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
              ),
            ],
          );
        },
      ),
    );
  }
}

/// **Les sous-entrées de l'onglet actif, en puces.**
///
/// Un seul niveau, comme le portail l'impose : au-delà il faudrait inventer un
/// déroulant à étages sur un téléphone. Aucune puce n'est sélectionnée par
/// défaut — l'onglet montre d'abord **sa** destination, et une puce la resserre.
class _MenuChips extends StatelessWidget {
  const _MenuChips({
    required this.children,
    required this.activeId,
    required this.onTap,
  });

  final List<MenuEntryView> children;
  final int? activeId;
  final void Function(MenuEntryView child) onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: children.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (_, i) {
          final child = children[i];
          final label = menuEntryLabel(context, child);
          if (label == null) return const SizedBox.shrink();
          final selected = child.id == activeId;
          return Align(
            child: GestureDetector(
              onTap: () => onTap(child),
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
                  label,
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

/// Une ligne du catalogue — le seul dessin de contenu de cet écran.
///
/// Trois en vivaient auparavant (carte de carrousel, vignette d'étagère, ligne
/// de liste) pour afficher **trois fois la même liste**. Il n'en reste qu'un,
/// parce qu'il n'y a qu'une liste.
class _ContentRow extends StatelessWidget {
  const _ContentRow({required this.content, this.onTap});

  final ContentView content;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
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
              width: 56,
              height: 56,
              child: ContentCover(
                content: content,
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
                    content.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        AppTypography.bodyStrong.copyWith(color: Colors.white),
                  ),
                  // Intervenant manquant : **la ligne ne se rend pas**. Un
                  // « Auteur inconnu » ressemblerait à une donnée et serait pris
                  // pour une erreur de saisie.
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
            if (content.typeLabel.isNotEmpty)
              Text(
                content.typeLabel,
                style: AppTypography.caption
                    .copyWith(color: Colors.white.withValues(alpha: 0.6)),
              ),
          ],
        ),
      ),
    );
  }
}
