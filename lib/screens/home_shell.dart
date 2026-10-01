import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_zoom_drawer/flutter_zoom_drawer.dart';
import 'package:go_router/go_router.dart';

import '../models/legal_document_view.dart';
import '../router/app_router.dart';
import '../state/session_gate.dart';
import '../theme/app_colors.dart';
import '../widgets/app_background.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/app_drawer_menu.dart';
import '../widgets/app_update_banner.dart';
import '../widgets/home_tab.dart';
import '../widgets/legal_notice_banner.dart';
import 'announcements_screen.dart';
import 'groups_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';

/// Conteneur principal : onglets en [IndexedStack], barre à encoche et FAB
/// central docké, le tout dans le menu latéral ([ZoomDrawer]).
///
/// ## Les onglets portent un nom, et l'index est un détail de rendu
///
/// L'ordre d'affichage vit **dans [HomeTab]**, et nulle part ailleurs : la pile
/// ci-dessous et la barre du bas le lisent toutes deux dans `HomeTab.values`, et
/// chacune résout son contenu par un `switch` **exhaustif**. Deux listes
/// parallèles — les écrans ici, les libellés là-bas — pouvaient se désaccorder
/// sans la moindre erreur de compilation : on tapait « Bible » et Échanges
/// s'ouvrait. Le type l'interdit désormais.
///
/// ## Les onglets réservés se ferment **ici**
///
/// Les quatre onglets ne sont pas des routes : ils vivent dans un
/// [IndexedStack], et la garde du routeur (`memberOnlyRoutes`) ne peut donc rien
/// pour eux. C'est vrai du hub « Échanges », que la décision du client met
/// derrière la connexion ; c'est vrai aussi du **Profil**, qui n'a aucun sens
/// sans compte et qui perd la garde de route en redevenant un onglet. La
/// réponse est la même pour les deux, et elle est portée par
/// `HomeTab.requiresSession` : `requireSession()` au moment du **geste**.
///
/// **L'onglet reste visible et son appui ouvre la connexion** — plutôt que de
/// disparaître pour un invité. Quatre raisons, dans l'ordre d'importance :
///
/// 1. **Un onglet retiré est une fermeture invisible**, exactement celle contre
///    laquelle `memberOnlyRoutes` prévient : « personne ne réclame un écran
///    qu'il n'a jamais vu ». L'onglet visible, lui, fait de la barre du bas
///    l'endroit où l'on **découvre qu'un compte existe** et ce qu'il ouvre.
/// 2. **Le libellé ne change pas selon l'état** : « Profil » pour tout le monde.
///    La barre n'en porte aucun autre qui varie, et en introduire un ici
///    créerait une exception à justifier à chaque relecture.
/// 3. **L'encoche du FAB est calée sur deux moitiés égales** (voir
///    [AppBottomNav]). À trois onglets, la barre devient boiteuse : deux à
///    gauche, un à droite d'un creux dimensionné pour deux.
/// 4. C'est ce pour quoi `requireSession()` a été écrit : exiger un compte au
///    moment du **geste**, et reprendre le geste après la connexion.
///
/// Le coût assumé : un invité peut appuyer sur un onglet qui ne l'emmène pas où
/// il croyait. C'est exactement ce que le parcours de connexion lui explique, et
/// renoncer n'est qu'un retour en arrière.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  static const Key tabsKey = Key('home_shell_tabs');

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  HomeTab _tab = HomeTab.home;

  bool _videoStatus = false;

  final ZoomDrawerController _drawer = ZoomDrawerController();

  bool _menuOpen = false;

  ValueNotifier<DrawerState>? _drawerState;

  @override
  void initState() {
    super.initState();
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

  /// Le rappel du tiroir : il **nomme** l'onglet qu'il ouvre.
  void _goHome() {
    _drawer.close?.call();
    _showTab(AppDrawerMenu.homeTab);
  }

  /// **L'appui sur un onglet**, et le seul endroit où un onglet peut exiger un
  /// compte.
  ///
  /// La question « cet onglet exige-t-il un compte ? » n'est pas tranchée ici :
  /// elle appartient à l'onglet (`HomeTab.requiresSession`), où un `switch`
  /// exhaustif oblige tout onglet neuf à y répondre. Posée ici en comparaisons,
  /// elle se serait oubliée en silence — c'est le cul-de-sac le plus facile à
  /// manquer du dépôt, et le seul dont l'oubli n'allume aucun test.
  ///
  /// Pour un membre, `requireSession` est transparent : il exécute le geste dans
  /// la foulée et rend `true`. Pour un invité, il pousse le parcours de connexion
  /// par-dessus la coquille et rejoue le geste après le succès.
  void _selectTab(HomeTab tab) {
    if (!tab.requiresSession) {
      _showTab(tab);
      return;
    }
    ref.requireSession(action: () => _showTab(tab));
  }

  /// Affiche un onglet — y compris **rejoué après une connexion**.
  ///
  /// **C'est le seul geste branché dont la reprise dépende de l'état d'un
  /// widget**, et il faut l'écrire : l'onglet courant vit en `State` **local**
  /// (le remonter dans un provider global est interdit — « Riverpod = état
  /// partagé »), et la reprise passe par un `router.go(origin)`, c'est-à-dire par
  /// une reconstruction de la pile. La coquille y survit tant que la page
  /// `/home` garde sa clé — c'est le cas aujourd'hui, et c'est ce qui fait
  /// atterrir le nouveau membre **sur l'onglet qu'il avait demandé**.
  ///
  /// Le `mounted` n'est donc pas une précaution de style : si cette page était un
  /// jour reconstruite, la reprise doit **retomber sur l'accueil** et non lever.
  /// Un membre qui atterrit sur l'accueil au lieu du hub est une déception ; un
  /// `setState` sur un `State` mort est un écran rouge.
  void _showTab(HomeTab tab) {
    if (!mounted) return;
    setState(() => _tab = tab);
  }

  void _openDocument(String routeName, {String? kind}) {
    _drawer.close?.call();
    context.pushNamed(
      routeName,
      pathParameters: kind == null ? const {} : {'kind': kind},
    );
  }

  /// **L'écran d'un onglet.** Pendant exact de `AppBottomNav.itemFor`, et
  /// `switch` exhaustif pour la même raison : un onglet ajouté à [HomeTab] ne
  /// compile pas tant qu'il n'a ni écran ni libellé. C'est ce qui remplace les
  /// deux listes parallèles d'autrefois, qui pouvaient se désaccorder en
  /// silence.
  Widget _screenFor(HomeTab tab) => switch (tab) {
        HomeTab.home => HomeScreen(onMenuTap: _openMenu),
        HomeTab.announcements => AnnouncementsScreen(
            isActive: _tab == HomeTab.announcements,
            onVideoChanged: (isVideo) {
              if (_videoStatus == isVideo) return;
              setState(() => _videoStatus = isVideo);
            },
          ),
        HomeTab.community => const GroupsScreen(),
        // Sans `showBack` : c'est un onglet, on en sort par la barre du bas. La
        // route `/profile` sert le même écran avec sa flèche de retour.
        HomeTab.profile => const ProfileScreen(),
      };

  @override
  Widget build(BuildContext context) {
    final dimFab = _tab == HomeTab.announcements && _videoStatus;

    final main = Scaffold(
      extendBody: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          IndexedStack(
            key: HomeShell.tabsKey,
            // **L'index, enfin réduit à ce qu'il est** : la position de l'onglet
            // dans l'ordre déclaré. Il ne circule plus, il se calcule.
            index: _tab.index,
            children: [for (final tab in HomeTab.values) _screenFor(tab)],
          ),
          // **La mention légale du premier lancement**, posée par-dessus les
          // onglets et non dans l'un d'eux : elle parle de l'application, pas de
          // l'accueil, et un invité qui ouvrirait d'abord les annonces doit la
          // voir aussi. Elle ne bloque rien — elle ne capte les gestes que sur sa
          // propre surface, et se retire d'elle-même quand il n'y a rien à dire
          // (voir `LegalNoticeBanner`).
          //
          // Elle est posée **au-dessus de la barre** : la coquille garde
          // `extendBody: true`, donc le bas du corps passe derrière la barre
          // givrée, et un bandeau à `bottom: 0` recouvrirait les onglets.
          //
          // **Le bandeau de mise à jour** partage cette place, et pour les
          // mêmes raisons : il parle de l'application, pas de l'accueil, et il
          // ne bloque rien. Les deux sont empilés dans une `Column` plutôt que
          // superposés — ils peuvent être là en même temps (une installation
          // neuve sur une version dépassée), et deux bandeaux au même endroit
          // en masqueraient un. Chacun se retire de lui-même quand il n'a rien
          // à dire, la colonne est alors vide et ne mesure rien.
          Positioned(
            left: 0,
            right: 0,
            bottom:
                MediaQuery.paddingOf(context).bottom + AppBottomNav.barHeight,
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [AppUpdateBanner(), LegalNoticeBanner()],
            ),
          ),
        ],
      ),
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
        current: _tab,
        onSelect: _selectTab,
      ),
    );

    return PopScope(
      canPop: !_menuOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _drawer.close?.call();
      },
      child: ZoomDrawer(
        controller: _drawer,
        menuScreen: AppDrawerMenu(
          currentTab: _tab,
          onHome: _goHome,
          onTerms: () => _openDocument(
            AppRoute.legalDocument,
            kind: LegalDocumentKind.terms,
          ),
          onPrivacy: () => _openDocument(
            AppRoute.legalDocument,
            kind: LegalDocumentKind.privacy,
          ),
          onAbout: () => _openDocument(AppRoute.about),
        ),
        mainScreen: AppBackground(child: main),
        disableDragGesture: true,
        mainScreenTapClose: true,
        angle: 0,
        menuBackgroundColor: AppColors.primary,
        showShadow: true,
      ),
    );
  }
}
