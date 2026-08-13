import 'package:flutter/material.dart';
import 'package:flutter_zoom_drawer/flutter_zoom_drawer.dart';
import 'package:go_router/go_router.dart';

import '../router/app_router.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/app_drawer_menu.dart';
import 'announcements_screen.dart';
import 'groups_screen.dart';
import 'home_screen.dart';
import 'legal_placeholder_screen.dart';
import 'profile_screen.dart';

/// Conteneur principal : onglets en [IndexedStack], barre à encoche et FAB
/// central docké (nouvelle requête), le tout dans le **menu latéral** de
/// l'accueil ([ZoomDrawer]).
///
/// L'onglet courant est un état local de la coquille (porté par le `State`),
/// ce qui le préserve d'une reconstruction à l'autre.
///
/// **Le tiroir se construit ici et non dans la route `/home`**, et pour une
/// raison précise : c'est ce qui garde `_index` en `State` local. Le menu le
/// change par un simple rappel, sans qu'aucun provider ne porte l'onglet
/// courant — `CLAUDE.md` réserve Riverpod à l'état **partagé**, et l'onglet est
/// de l'état de coquille.
///
/// **Le `mainScreen` est le [Scaffold] entier.** Les quatre onglets, la barre à
/// encoche et le FAB rétrécissent et pivotent ensemble : c'est le rendu attendu
/// du composant. N'envelopper que [HomeScreen] laisserait la barre du bas et le
/// FAB **fixes** pendant que le contenu pivote au-dessus — le composant aurait
/// l'air cassé, pas animé.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  /// Clé de la pile d'onglets, pour lire l'onglet courant depuis les tests
  /// (l'`IndexedStack` de la coquille n'est pas le seul de l'arbre).
  static const Key tabsKey = Key('home_shell_tabs');

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  /// Index de l'onglet « Annonces ».
  ///
  /// La visionneuse de statuts a besoin de savoir si elle est visible :
  /// l'[IndexedStack] la garde montée en permanence, donc sans cette
  /// information la lecture démarrerait en tâche de fond. On passe le drapeau
  /// explicitement plutôt que de remonter l'état d'onglet dans un provider —
  /// il reste de l'état local de la coquille.
  static const int _announcementsTab = 1;

  /// Le statut affiché est une vidéo : le FAB s'efface pour ne pas trouer
  /// l'image. Remonté par rappel depuis l'onglet — la coquille est seule
  /// concernée, inutile d'en faire un état global.
  bool _videoStatus = false;

  final ZoomDrawerController _drawer = ZoomDrawerController();

  /// Le tiroir est-il ouvert (ou en train de s'ouvrir) ? Sert au [PopScope] :
  /// sur Android, le bouton retour doit **fermer le menu**, pas dépiler
  /// `/home`.
  bool _menuOpen = false;

  /// L'état du tiroir, publié par le [ZoomDrawer] lui-même.
  ValueNotifier<DrawerState>? _drawerState;

  @override
  void initState() {
    super.initState();
    // `ZoomDrawerController` n'est câblé qu'à l'`initState` du [ZoomDrawer],
    // donc **après** la première construction de la coquille : on s'abonne au
    // premier frame, pas ici.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final notifier = _drawer.stateNotifier;
      if (notifier == null) return;
      _drawerState = notifier..addListener(_onDrawerStateChanged);
      _onDrawerStateChanged();
    });
  }

  @override
  void dispose() {
    // `removeListener` est sans effet sur un notifier déjà disposé — le
    // [ZoomDrawer] dispose le sien, l'ordre n'a donc pas à être garanti.
    _drawerState?.removeListener(_onDrawerStateChanged);
    super.dispose();
  }

  void _onDrawerStateChanged() {
    final state = _drawerState?.value;
    final open = state == DrawerState.open || state == DrawerState.opening;
    if (_menuOpen == open) return;
    setState(() => _menuOpen = open);
  }

  void _openMenu() => _drawer.open?.call();

  /// Revient à l'accueil depuis n'importe quel onglet, menu refermé.
  void _goHome() {
    _drawer.close?.call();
    setState(() => _index = 0);
  }

  /// Ouvre une destination documentaire. **Le tiroir se ferme d'abord** : sans
  /// cela, le `context.pop()` de l'écran poussé ramènerait sur une coquille
  /// encore rétrécie et pivotée.
  void _openDocument(String routeName, {String? kind}) {
    _drawer.close?.call();
    context.pushNamed(
      routeName,
      pathParameters: kind == null ? const {} : {'kind': kind},
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = <Widget>[
      // L'icône du menu n'existe **que** sur l'accueil : le geste de glissement
      // étant coupé, il n'y a aucun moyen de l'ouvrir depuis les trois autres
      // onglets, donc aucune incohérence visible.
      HomeScreen(onMenuTap: _openMenu),
      AnnouncementsScreen(
        isActive: _index == _announcementsTab,
        onVideoChanged: (isVideo) {
          if (_videoStatus == isVideo) return;
          setState(() => _videoStatus = isVideo);
        },
      ),
      const GroupsScreen(),
      const ProfileScreen(),
    ];

    final dimFab = _index == _announcementsTab && _videoStatus;

    final main = Scaffold(
      // Le contenu s'étend derrière la barre givrée (effet verre dépoli).
      extendBody: true,
      body: IndexedStack(key: HomeShell.tabsKey, index: _index, children: tabs),
      // Bouton central : accès à la médiathèque. Il s'estompe au-dessus d'un
      // statut vidéo, sans jamais disparaître : il reste utilisable.
      floatingActionButton: AnimatedOpacity(
        opacity: dimFab ? 0.4 : 1,
        duration: const Duration(milliseconds: 200),
        child: FloatingActionButton(
          onPressed: () => context.pushNamed(AppRoute.media),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 2,
          shape: const CircleBorder(),
          child: const Icon(Icons.play_arrow_rounded, size: 32),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: AppBottomNav(
        currentIndex: _index,
        onSelect: (i) => setState(() => _index = i),
      ),
    );

    return PopScope(
      // Le bouton retour Android ferme le panneau ouvert au lieu de quitter
      // `/home`. On l'écrit ici plutôt que d'activer `androidCloseOnBackTap` :
      // celui du paquet évalue sa garde **pendant** le `build` et referme donc
      // le tiroir à la moindre reconstruction (un changement d'onglet, par
      // exemple), en plus de ne se poser ni sur le web ni hors Android.
      canPop: !_menuOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _drawer.close?.call();
      },
      child: ZoomDrawer(
        controller: _drawer,
        menuScreen: AppDrawerMenu(
          currentIndex: _index,
          onHome: _goHome,
          onTerms: () => _openDocument(
            AppRoute.legalDocument,
            kind: LegalPlaceholderScreen.terms,
          ),
          onPrivacy: () => _openDocument(
            AppRoute.legalDocument,
            kind: LegalPlaceholderScreen.privacy,
          ),
          onAbout: () => _openDocument(AppRoute.about),
        ),
        mainScreen: main,
        // **Sans négociation.** Le geste par défaut capte le glissement
        // horizontal sur tout l'écran principal, où vivent trois carrousels et
        // surtout le `PageView` de la visionneuse de statuts — dont l'en-tête
        // prévient déjà que l'imbrication des gestes y est « critique ». Un
        // capteur horizontal au-dessus rendrait non déterministe, à l'œil, le
        // geste le plus courant de l'onglet Annonces. Le menu s'ouvre par
        // l'icône, et par elle seule.
        disableDragGesture: true,
        // Toucher la coquille rétrécie referme le menu : le tiroir absorbe
        // déjà les touchers de l'écran principal quand il est ouvert, sans
        // cela le seul recours serait le bouton retour.
        mainScreenTapClose: true,
        // Le fond qui apparaît derrière la coquille pivotée : sans lui, les
        // coins dégagés par la rotation laisseraient voir du blanc.
        menuBackgroundColor: AppColors.primary,
        showShadow: true,
      ),
    );
  }
}
