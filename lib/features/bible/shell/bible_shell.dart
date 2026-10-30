/// **Le module Bible** (M1, #199, décision 2 ; barre refaite par #265) :
/// quatre onglets — Accueil, Bible, Notes, Mon espace — sous une barre du bas
/// **propre au module**, et une flèche de retour vers l'accueil de l'église.
///
/// Route `/bible?tab=home|bible|notes|more`, **ouverte à tous** et **poussée**
/// par-dessus la coquille de l'application (dont la barre est donc masquée).
/// Sans `?tab=`, le module rouvre son dernier onglet, gardé dans
/// `app_settings` (`SettingsDao.bibleTab`, la clé de la page à deux onglets
/// qu'il remplace : « bible » et « notes » s'y lisent encore). Mon espace
/// garde la valeur `more` de l'ancien onglet Plus : liens et mémoire tiennent
/// sans migration. `favorites` (l'ancien onglet) : voir
/// [BibleShell.openFavorites].
///
/// **Sans Bible téléchargée** (#265), Accueil, Bible et Mon espace montrent
/// l'invitation à en télécharger une ; Notes et le mode sélection restent
/// ouverts — ils ne lisent que la versification, pas le texte.
///
/// **Le mode sélection** (`/bible/select`, décision 7) : l'onglet Bible seul,
/// sans barre du bas ; on choisit un livre, un chapitre, puis des versets, et
/// le bouton flottant « Insérer Jean 3:16-18 » **dépile la route avec le
/// `BibleLink`** — c'est ce que la feuille « Ajouter un lien » attend.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_extension.dart';
import '../../../router/app_router.dart';
import '../../../screens/notes/notes_tab.dart';
import '../../../state/theme_provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_palette.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/app_empty_state.dart';
import '../data/bible_providers.dart';
import '../data/canon.dart';
import '../home/home_view.dart';
import '../personalize/bible_catalog.dart';
import '../personalize/bible_versions_screen.dart';
import '../personalize/my_space_screen.dart';
import '../reader/bible_reader_screen.dart';
import '../search/bible_search_screen.dart';
import 'bible_browser.dart';
import 'bible_favorites_screen.dart';
import 'bible_slots.dart';

/// Les quatre onglets, dans l'ordre de la barre — leur nom est la valeur de
/// `?tab=` et celle qu'on mémorise.
enum BibleModuleTab { home, bible, notes, more }

class BibleShell extends ConsumerStatefulWidget {
  const BibleShell({
    super.key,
    this.initialTab,
    this.selectMode = false,
    this.openFavorites = false,
  });

  /// L'onglet demandé par la route, ou `null` pour « le dernier ouvert ».
  final BibleModuleTab? initialTab;

  /// Le mode sélection des liens de notes.
  final bool selectMode;

  /// `/bible?tab=favorites`, un lien d'avant #265 : l'écran Favoris poussé
  /// dès l'ouverture. Un dernier onglet **mémorisé** `favorites`, lui, ne
  /// rouvre que l'onglet Bible — pas d'écran surprise au lancement.
  final bool openFavorites;

  static const Key navKey = Key('bible_nav');
  static const Key backKey = Key('bible_back');
  static const Key searchKey = Key('bible_search');
  static const Key insertKey = Key('bible_insert');
  static const Key favoritesKey = Key('bible_more_favorites');
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
    if (widget.openFavorites) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) BibleFavoritesScreen.open(ref);
      });
    }
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
    // Les chiffres de l'en-tête de Mon espace sont lus une fois : l'onglet
    // reste monté, on les relit à chaque retour (un chapitre lu entre-temps).
    if (tab == BibleModuleTab.more) ref.invalidate(bibleMySpaceStatsProvider);
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

  Widget _screenFor(BibleModuleTab tab) => switch (tab) {
        BibleModuleTab.home => const _HomeTab(),
        BibleModuleTab.bible => BibleBrowser(
            onOpen: (link) =>
                BibleReaderScreen.push(ref.read(routerProvider), link),
          ),
        BibleModuleTab.notes => const NotesTab(),
        BibleModuleTab.more => const _MySpaceTab(),
      };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final unlocked = ref.watch(bibleHasRealVersionProvider);
    // Sans vraie Bible, tout onglet sauf Notes cède la place à l'invitation.
    final locked =
        !widget.selectMode && !unlocked && _tab != BibleModuleTab.notes;
    // L'accueil (maquette « Splash & Accueil ») porte sa propre flèche sur
    // l'image, sous la barre d'état : pas de barre bleue.
    final bare = !widget.selectMode && !locked && _tab == BibleModuleTab.home;
    final title = widget.selectMode
        ? l.bibleSelectTitle
        : switch (_tab) {
            BibleModuleTab.notes => l.notesAppBarTitle,
            BibleModuleTab.more => l.bibleTabMore,
            _ => l.navBible,
          };
    final selection = _selection;
    return Scaffold(
      backgroundColor: bare ? BibleHomeColors.of(context).pageBottom : null,
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
                if (!widget.selectMode &&
                    !locked &&
                    _tab == BibleModuleTab.bible)
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
              // L'invitation est un enfant de plus, et non un remplaçant par
              // onglet : une seule, qui garde la progression d'un
              // téléchargement d'un onglet à l'autre et à travers Notes.
              index: locked ? BibleModuleTab.values.length : _tab.index,
              children: [
                for (final tab in BibleModuleTab.values)
                  _visited.contains(tab) &&
                          (unlocked || tab == BibleModuleTab.notes)
                      ? _screenFor(tab)
                      : const SizedBox.shrink(),
                if (unlocked)
                  const SizedBox.shrink()
                else
                  const BibleVersionsScreen(invitation: true),
              ],
            ),
      floatingActionButton: widget.selectMode && selection != null
          ? FloatingActionButton.extended(
              key: BibleShell.insertKey,
              icon: const Icon(Icons.add_link),
              label: Text(l.bibleInsertReference(
                  selection.labelIn(ref.watch(bibleBookLanguageProvider)))),
              onPressed: () => ref.read(routerProvider).pop(selection),
            )
          : null,
      bottomNavigationBar: widget.selectMode
          ? null
          : _BibleNavBar(key: BibleShell.navKey, tab: _tab, onSelect: _select),
    );
  }
}

/// **La barre du module** (#265) : quatre icônes, chacune avec son libellé
/// dessous (#267 ; elles en ont été privées un temps). L'onglet actif sort en **pastille
/// ronde** au-dessus de la barre, qui s'y bombe ; pastille et renflement
/// glissent ensemble d'un onglet à l'autre. Peinte à la main : la
/// `NavigationBar` de Material ne déborde pas de sa boîte, et quatre icônes ne
/// valent pas une dépendance.
class _BibleNavBar extends StatelessWidget {
  const _BibleNavBar({super.key, required this.tab, required this.onSelect});

  final BibleModuleTab tab;
  final ValueChanged<BibleModuleTab> onSelect;

  /// Les libellés sont revenus sous les icônes (#267) : la barre grandit, et
  /// la pastille monte d'autant pour que celui de l'onglet actif passe
  /// dessous.
  static const _barHeight = 64.0;

  /// La marge au-dessus de la barre, où monte le dôme.
  static const _lift = 30.0;
  static const _bubble = 52.0;

  /// La pastille dépasse de la barre d'un quart de son diamètre (la maquette
  /// disait 8 %, sans libellés) ; le dôme l'entoure d'une marge d'un quart de
  /// diamètre.
  static const _bubbleTop = _lift - 14;
  static const _domeRadius = _bubble / 2 + 12;

  static String _labelOf(BuildContext context, BibleModuleTab tab) {
    final l = context.l10n;
    return switch (tab) {
      BibleModuleTab.home => l.bibleTabHome,
      BibleModuleTab.bible => l.bibleTabBible,
      BibleModuleTab.notes => l.bibleTabNotes,
      BibleModuleTab.more => l.bibleTabMore,
    };
  }

  static IconData _iconOf(BibleModuleTab tab) => switch (tab) {
        BibleModuleTab.home => Icons.home_outlined,
        BibleModuleTab.bible => Icons.menu_book_outlined,
        BibleModuleTab.notes => Icons.sticky_note_2_outlined,
        BibleModuleTab.more => Icons.person_outline,
      };

  @override
  Widget build(BuildContext context) {
    final c = BibleHomeColors.of(context);
    // La pastille prend le bleu des boutons (celui de l'appli le jour), et la
    // barre, la nuit, la teinte des cartes.
    final dark = Theme.of(context).brightness == Brightness.dark;
    final barColor = dark ? c.card : Colors.white;
    final bubbleColor = c.button;
    final activeLabel = dark ? c.ink : c.button;
    const tabs = BibleModuleTab.values;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: tab.index.toDouble()),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
      builder: (context, at, _) => CustomPaint(
        painter: _BarPainter(
          at: at,
          count: tabs.length,
          color: barColor,
          top: _lift,
          centerY: _bubbleTop + _bubble / 2,
          domeRadius: _domeRadius,
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: _lift + _barHeight,
            child: LayoutBuilder(
              builder: (context, box) {
                final w = box.maxWidth / tabs.length;
                return Stack(
                  children: [
                    for (final t in tabs)
                      Positioned(
                        left: t.index * w,
                        width: w,
                        top: _lift,
                        bottom: 0,
                        child: Semantics(
                          selected: t == tab,
                          button: true,
                          child: InkResponse(
                            key: BibleShell.tabKey(t),
                            onTap: () => onSelect(t),
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  // L'icône au trait s'efface sous la pastille
                                  // qui arrive.
                                  Opacity(
                                    opacity:
                                        (at - t.index).abs().clamp(0.0, 1.0),
                                    child: Icon(_iconOf(t), color: c.navIdle),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _labelOf(context, t),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.caption.copyWith(
                                      fontSize: 11,
                                      color: t == tab ? activeLabel : c.navIdle,
                                      fontWeight: t == tab
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      left: (at + 0.5) * w - _bubble / 2,
                      top: _bubbleTop,
                      width: _bubble,
                      height: _bubble,
                      // Le toucher passe à l'onglet dessous.
                      child: IgnorePointer(
                        child: DecoratedBox(
                          // Icône blanche, sans anneau : l'or de la maquette
                          // a été retiré le 28/10/2026.
                          decoration: BoxDecoration(
                            color: bubbleColor,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(_iconOf(tab), color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Le fond de la barre : coins hauts arrondis, et un **dôme** — un cercle
/// concentrique à la pastille — raccordé au bord par deux congés creux (`at` :
/// la position de l'onglet, fractionnaire pendant le glissement).
class _BarPainter extends CustomPainter {
  const _BarPainter({
    required this.at,
    required this.count,
    required this.color,
    required this.top,
    required this.centerY,
    required this.domeRadius,
  });

  final double at;
  final int count;
  final Color color;

  /// Le haut de la barre, sous la marge où monte le dôme.
  final double top;

  /// Le centre de la pastille, donc du dôme.
  final double centerY;
  final double domeRadius;

  @override
  void paint(Canvas canvas, Size size) {
    const radius = 20.0;
    const fillet = 14.0;
    final cx = (at + 0.5) * size.width / count;
    final w = size.width;
    final r = domeRadius;
    // Le congé : un cercle de rayon `fillet` posé sur le bord (centre à
    // `top - fillet`) et tangent extérieurement au dôme (distance `r + fillet`).
    final dy = centerY - (top - fillet);
    final dx = math.sqrt((r + fillet) * (r + fillet) - dy * dy);
    // Le point où congé et dôme se touchent, sur la droite de leurs centres.
    final k = r / (r + fillet);
    final tx = dx * k;
    final ty = centerY - dy * k;
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, top + radius)
      ..quadraticBezierTo(0, top, radius, top)
      ..lineTo(cx - dx, top)
      ..arcToPoint(Offset(cx - tx, ty),
          radius: const Radius.circular(fillet), clockwise: false)
      ..arcToPoint(Offset(cx + tx, ty), radius: Radius.circular(r))
      ..arcToPoint(Offset(cx + dx, top),
          radius: const Radius.circular(fillet), clockwise: false)
      ..lineTo(w - radius, top)
      ..quadraticBezierTo(w, top, w, top + radius)
      ..lineTo(w, size.height)
      ..close();
    canvas
      ..drawShadow(path, Colors.black, 6, false)
      ..drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.at != at ||
      old.color != color ||
      old.count != count ||
      old.centerY != centerY ||
      old.domeRadius != domeRadius;
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

  /// Sous l'en-tête fixe, au moins de quoi voir « Lecture du jour » et le haut
  /// de sa carte. Un iPhone 17 Pro en laisse ~250, un iPhone SE ~130.
  static const _minScrollArea = 120.0;

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
        // **« Lecture du jour » et la suite défilent, seules** (#265) : le
        // premier écran — l'image, la recherche, les raccourcis — couvre toute
        // la largeur et reste en place ; les sections
        // suivantes défilent dans la colonne du contenu. Un écran trop court
        // (petit téléphone, paysage) n'aurait plus rien à faire défiler : là,
        // tout défile, comme avant.
        child: LayoutBuilder(
          builder: (context, box) {
            final head = [
              for (final s in sections)
                if (s.id == 'home_view') s.builder(context),
            ];
            final rest = [
              for (final s in sections)
                if (s.id != 'home_view')
                  BibleHomeColumn(child: s.builder(context)),
            ];
            const padding = EdgeInsets.only(bottom: AppSpacing.xxl);
            final fixed = box.maxHeight - BibleHomeView.heightOf(context) >=
                _minScrollArea;
            if (!fixed) {
              return ListView(
                padding: padding,
                children: [...head, ...rest],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...head,
                Expanded(
                  child: ListView(padding: padding, children: rest),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// **Mon espace** (#265, l'ancien onglet Plus) : la série et les chapitres
/// lus en tête, puis Favoris et une ligne par entrée enregistrée. Rechercher,
/// les plans, les défis et les quiz n'y sont plus : l'accueil les porte déjà.
class _MySpaceTab extends ConsumerWidget {
  const _MySpaceTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final entries = ref.watch(bibleSlotsProvider).moreEntries;
    final stats =
        ref.watch(bibleMySpaceStatsProvider).value ?? const BibleMySpaceStats();
    // Le canon figé, comme l'écran des badges (C3, #240).
    final total = bibleChapters.length;
    return ListView(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      children: [
        Padding(
          padding: AppSpacing.screenPadding,
          child: AppCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.local_fire_department,
                      color: context.palette.primary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        l.bibleM4Streak(stats.streakDays),
                        style: AppTypography.h5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(l.bibleM4ChaptersRead(stats.chaptersRead, total)),
                const SizedBox(height: AppSpacing.xs),
                LinearProgressIndicator(
                  value: (stats.chaptersRead / total).clamp(0.0, 1.0),
                  backgroundColor: context.palette.divider,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        ListTile(
          key: BibleShell.favoritesKey,
          leading: const Icon(Icons.star_outline),
          title: Text(l.bibleTabFavorites),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => BibleFavoritesScreen.open(ref),
        ),
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
