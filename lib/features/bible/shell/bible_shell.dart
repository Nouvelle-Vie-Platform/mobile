/// **Le module Bible** (M1, #199, décision 2) : cinq onglets — Accueil,
/// Bible, Favori, Notes, Plus — sous une barre du bas **propre au module**, et
/// une flèche de retour vers l'accueil de l'église.
///
/// Route `/bible?tab=home|bible|favorites|notes|more`, **ouverte à tous** et
/// **poussée** par-dessus la coquille de l'application (dont la barre est donc
/// masquée). Sans `?tab=`, le module rouvre son dernier onglet, gardé dans
/// `app_settings` (`SettingsDao.bibleTab`, la clé de la page à deux onglets
/// qu'il remplace : « bible » et « notes » s'y lisent encore).
///
/// **Le mode sélection** (`/bible/select`, décision 7) : l'onglet Bible seul,
/// sans barre du bas ; on choisit un livre, un chapitre, puis des versets, et
/// le bouton flottant « Insérer Jean 3:16-18 » **dépile la route avec le
/// `BibleLink`** — c'est ce que la feuille « Ajouter un lien » attend.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_extension.dart';
import '../../../router/app_router.dart';
import '../../../screens/notes/notes_tab.dart';
import '../../../state/theme_provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/app_empty_state.dart';
import '../data/canon.dart';
import '../home/home_view.dart';
import '../reader/bible_reader_screen.dart';
import '../search/bible_search_screen.dart';
import 'bible_browser.dart';
import 'bible_slots.dart';

/// Les cinq onglets, dans l'ordre de la barre — leur nom est la valeur de
/// `?tab=` et celle qu'on mémorise.
enum BibleModuleTab { home, bible, favorites, notes, more }

class BibleShell extends ConsumerStatefulWidget {
  const BibleShell({super.key, this.initialTab, this.selectMode = false});

  /// L'onglet demandé par la route, ou `null` pour « le dernier ouvert ».
  final BibleModuleTab? initialTab;

  /// Le mode sélection des liens de notes.
  final bool selectMode;

  static const Key navKey = Key('bible_nav');
  static const Key backKey = Key('bible_back');
  static const Key searchKey = Key('bible_search');
  static const Key insertKey = Key('bible_insert');
  static Key tabKey(BibleModuleTab tab) => Key('bible_tab_${tab.name}');

  @override
  ConsumerState<BibleShell> createState() => _BibleShellState();
}

class _BibleShellState extends ConsumerState<BibleShell> {
  late BibleModuleTab _tab = widget.selectMode
      ? BibleModuleTab.bible
      : widget.initialTab ?? BibleModuleTab.bible;

  /// Un onglet n'est monté qu'une fois visité, puis gardé : l'onglet Bible
  /// retrouve son livre et son chapitre au retour.
  late final Set<BibleModuleTab> _visited = {_tab};
  bool _touched = false;
  BibleLink? _selection;

  @override
  void initState() {
    super.initState();
    if (widget.initialTab == null && !widget.selectMode) _restoreTab();
  }

  Future<void> _restoreTab() async {
    final saved = await ref.read(settingsDaoProvider).bibleTab();
    final tab = BibleModuleTab.values.asNameMap()[saved];
    // Un geste fait entre-temps l'emporte sur la mémoire.
    if (tab == null || !mounted || _touched || tab == _tab) return;
    setState(() {
      _tab = tab;
      _visited.add(tab);
    });
  }

  void _select(BibleModuleTab tab) {
    _touched = true;
    setState(() {
      _tab = tab;
      _visited.add(tab);
    });
    ref.read(settingsDaoProvider).setBibleTab(tab.name);
  }

  /// La flèche : sortir du module. Par la pile quand il y en a une, sinon
  /// (lien profond, cible web) vers l'accueil de l'église.
  void _leave() {
    final router = ref.read(routerProvider);
    if (router.canPop()) {
      router.pop();
    } else {
      router.goNamed(AppRoute.home);
    }
  }

  String _labelOf(BibleModuleTab tab) {
    final l = context.l10n;
    return switch (tab) {
      BibleModuleTab.home => l.bibleTabHome,
      BibleModuleTab.bible => l.bibleTabBible,
      BibleModuleTab.favorites => l.bibleTabFavorites,
      BibleModuleTab.notes => l.bibleTabNotes,
      BibleModuleTab.more => l.bibleTabMore,
    };
  }

  IconData _iconOf(BibleModuleTab tab) => switch (tab) {
        BibleModuleTab.home => Icons.home_outlined,
        BibleModuleTab.bible => Icons.menu_book_outlined,
        BibleModuleTab.favorites => Icons.star_outline,
        BibleModuleTab.notes => Icons.sticky_note_2_outlined,
        BibleModuleTab.more => Icons.more_horiz,
      };

  IconData _selectedIconOf(BibleModuleTab tab) => switch (tab) {
        BibleModuleTab.home => Icons.home,
        BibleModuleTab.bible => Icons.menu_book,
        BibleModuleTab.favorites => Icons.star,
        BibleModuleTab.notes => Icons.sticky_note_2,
        BibleModuleTab.more => Icons.more_horiz,
      };

  Widget _screenFor(BibleModuleTab tab) => switch (tab) {
        BibleModuleTab.home => const _HomeTab(),
        BibleModuleTab.bible => BibleBrowser(
            onOpen: (link) =>
                BibleReaderScreen.push(ref.read(routerProvider), link),
          ),
        BibleModuleTab.favorites => const _FavoritesTab(),
        BibleModuleTab.notes => const NotesTab(),
        BibleModuleTab.more => const _MoreTab(),
      };

  @override
  Widget build(BuildContext context) {
    ref.listen(bibleTabRequestProvider, (_, next) {
      final tab = BibleModuleTab.values.asNameMap()[next];
      if (tab != null) _select(tab);
    });
    final l = context.l10n;
    // L'accueil (maquette « Splash & Accueil ») porte sa propre flèche sur
    // l'image, sous la barre d'état : pas de barre bleue.
    final bare = !widget.selectMode && _tab == BibleModuleTab.home;
    final title = widget.selectMode
        ? l.bibleSelectTitle
        : _tab == BibleModuleTab.notes
            ? l.notesAppBarTitle
            : l.navBible;
    final selection = _selection;
    return Scaffold(
      backgroundColor: bare ? BibleHomeColors.creamBottom : null,
      appBar: bare
          ? null
          : AppBar(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              iconTheme: const IconThemeData(color: Colors.white),
              centerTitle: true,
              flexibleSpace: const DecoratedBox(
                decoration: BoxDecoration(gradient: AppColors.gradientPrimary),
              ),
              leading: IconButton(
                key: BibleShell.backKey,
                icon: Icon(widget.selectMode ? Icons.close : Icons.arrow_back),
                tooltip: widget.selectMode
                    ? MaterialLocalizations.of(context).closeButtonTooltip
                    : l.bibleBackToHome,
                onPressed: _leave,
              ),
              title: Text(
                title,
                style: AppTypography.h5.copyWith(color: Colors.white),
              ),
              actions: [
                // La loupe (M3) sur l'onglet Bible (l'accueil a sa barre).
                if (!widget.selectMode && _tab == BibleModuleTab.bible)
                  IconButton(
                    key: BibleShell.searchKey,
                    icon: const Icon(Icons.search),
                    tooltip: l.bibleSearchTitle,
                    onPressed: () =>
                        BibleSearchScreen.open(ref.read(routerProvider)),
                  ),
              ],
            ),
      body: widget.selectMode
          ? BibleBrowser(
              mode: BibleBrowserMode.select,
              onSelection: (link) => setState(() => _selection = link),
            )
          : IndexedStack(
              index: _tab.index,
              children: [
                for (final tab in BibleModuleTab.values)
                  _visited.contains(tab)
                      ? _screenFor(tab)
                      : const SizedBox.shrink(),
              ],
            ),
      floatingActionButton: widget.selectMode && selection != null
          ? FloatingActionButton.extended(
              key: BibleShell.insertKey,
              icon: const Icon(Icons.add_link),
              label: Text(l.bibleInsertReference(selection.labelFr)),
              onPressed: () => ref.read(routerProvider).pop(selection),
            )
          : null,
      bottomNavigationBar: widget.selectMode
          ? null
          // La barre de la maquette : fond crème, filet en haut, pas de
          // pastille ; l'onglet actif en bleu nuit, icône pleine.
          : DecoratedBox(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFDBDAD8))),
              ),
              child: NavigationBarTheme(
                data: NavigationBarThemeData(
                  labelTextStyle: WidgetStateProperty.resolveWith(
                    (states) => AppTypography.caption.copyWith(
                      fontSize: 13,
                      color: states.contains(WidgetState.selected)
                          ? BibleHomeColors.button
                          : const Color(0xFF8A8A8E),
                    ),
                  ),
                ),
                child: NavigationBar(
                  key: BibleShell.navKey,
                  selectedIndex: _tab.index,
                  height: 50,
                  backgroundColor: BibleHomeColors.creamBottom,
                  surfaceTintColor: Colors.transparent,
                  indicatorColor: Colors.transparent,
                  labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                  onDestinationSelected: (i) =>
                      _select(BibleModuleTab.values[i]),
                  destinations: [
                    for (final tab in BibleModuleTab.values)
                      NavigationDestination(
                        key: BibleShell.tabKey(tab),
                        icon: Icon(
                          _iconOf(tab),
                          color: const Color(0xFF8A8A8E),
                        ),
                        selectedIcon: Icon(
                          _selectedIconOf(tab),
                          color: BibleHomeColors.button,
                        ),
                        label: _labelOf(tab),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// L'écran d'attente d'un onglet que les tranches suivantes rempliront.
class BibleSoonView extends StatelessWidget {
  const BibleSoonView({super.key, required this.message, required this.icon});

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: AppSpacing.screenPadding.copyWith(top: AppSpacing.xxl),
      children: [
        AppEmptyState(
          title: context.l10n.bibleSoonTitle,
          message: message,
          icon: icon,
        ),
      ],
    );
  }
}

/// **Accueil** : les sections enregistrées (M7), dans l'ordre.
class _HomeTab extends ConsumerWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sections = ref.watch(bibleSlotsProvider).homeSections;
    if (sections.isEmpty) {
      return BibleSoonView(
        message: context.l10n.bibleHomeSoon,
        icon: Icons.wb_sunny_outlined,
      );
    }
    return BibleHomeBackground(
      child: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
          children: [for (final s in sections) s.builder(context)],
        ),
      ),
    );
  }
}

/// **Favori** : une puce par filtre enregistré (M2), la liste du filtre
/// choisi dessous.
class _FavoritesTab extends ConsumerStatefulWidget {
  const _FavoritesTab();

  @override
  ConsumerState<_FavoritesTab> createState() => _FavoritesTabState();
}

class _FavoritesTabState extends ConsumerState<_FavoritesTab> {
  String? _filterId;

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(bibleSlotsProvider).favoriteFilters;
    if (filters.isEmpty) {
      return BibleSoonView(
        message: context.l10n.bibleFavoritesSoon,
        icon: Icons.star_outline,
      );
    }
    final current = filters.firstWhere(
      (f) => f.id == _filterId,
      orElse: () => filters.first,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: AppSpacing.screenPadding.copyWith(
            top: AppSpacing.md,
            bottom: AppSpacing.sm,
          ),
          child: Row(
            children: [
              for (final f in filters)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: ChoiceChip(
                    label: Text(f.label(context)),
                    selected: f.id == current.id,
                    onSelected: (_) => setState(() => _filterId = f.id),
                  ),
                ),
            ],
          ),
        ),
        Expanded(child: current.builder(context)),
      ],
    );
  }
}

/// **Plus** : une ligne par entrée enregistrée.
class _MoreTab extends ConsumerWidget {
  const _MoreTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(bibleSlotsProvider).moreEntries;
    if (entries.isEmpty) {
      return BibleSoonView(
        message: context.l10n.bibleMoreSoon,
        icon: Icons.more_horiz,
      );
    }
    return ListView(
      children: [
        for (final e in entries)
          ListTile(
            key: Key('bible_more_${e.id}'),
            leading: Icon(e.icon),
            title: Text(e.label(context)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => e.onTap(context, ref),
          ),
      ],
    );
  }
}
