import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_zoom_drawer/flutter_zoom_drawer.dart';
import 'package:go_router/go_router.dart';

import '../l10n/l10n_extension.dart';
import '../models/legal_document_view.dart';
import '../router/app_router.dart';
import '../state/session_gate.dart';
import '../theme/app_colors.dart';
import '../widgets/app_background.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/app_drawer_menu.dart';
import '../widgets/app_update_banner.dart';
import '../widgets/legal_notice_banner.dart';
import 'announcements_screen.dart';
import 'groups_screen.dart';
import 'home_screen.dart';

/// Écran provisoire pour l'onglet Bible.
class _BiblePlaceholderScreen extends StatelessWidget {
  const _BiblePlaceholderScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          // La phrase était écrite en dur ici, alors que `pageUnderConstruction`
          // existait dans les trois fichiers de traduction sans appelant.
          context.l10n.pageUnderConstruction,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

/// Conteneur principal : onglets en [IndexedStack], barre à encoche et FAB
/// central docké, le tout dans le menu latéral ([ZoomDrawer]).
///
/// ## Le hub « Échanges » est réservé aux membres, et se ferme **ici**
///
/// Les quatre onglets ne sont pas des routes : ils vivent dans un
/// [IndexedStack], et la garde du routeur (`memberOnlyRoutes`) ne peut donc rien
/// pour eux. Or la décision du client met la communauté derrière la connexion.
///
/// **L'onglet reste visible et son appui ouvre la connexion** — plutôt que de
/// disparaître pour un invité. Quatre raisons, dans l'ordre d'importance :
///
/// 1. **Un onglet retiré est une fermeture invisible**, exactement celle contre
///    laquelle `memberOnlyRoutes` prévient : « personne ne réclame un écran
///    qu'il n'a jamais vu ». L'onglet visible, lui, fait de la barre du bas
///    l'endroit où l'on **découvre qu'un compte existe** et ce qu'il ouvre.
/// 2. **L'index d'onglet est un numéro partagé.** [AppBottomNav] et
///    [AppDrawerMenu] parlent en numéros, et `drawer_menu_test.dart` vérifie
///    qu'« Accueil » ramène à l'onglet 0 **depuis l'onglet 3**. Une barre à
///    géométrie variable ferait de ce numéro une valeur dont le sens dépend de
///    qui regarde — et il faudrait alors réécrire ce vocabulaire partout.
/// 3. **L'encoche du FAB est calée sur deux onglets de chaque côté** (`take(2)` /
///    `skip(2)` dans [AppBottomNav]). À trois onglets, la barre devient
///    boiteuse : deux à gauche, un à droite d'un creux dimensionné pour deux.
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
  int _index = 0;

  /// Les quatre onglets, **nommés**. Le numéro reste le vocabulaire partagé avec
  /// la barre et le tiroir (voir l'en-tête) ; ces constantes évitent seulement
  /// qu'il se promène en littéral dans ce fichier.
  static const int _homeTab = 0;
  static const int _announcementsTab = 1;
  static const int _communityTab = 2;

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

  void _goHome() {
    _drawer.close?.call();
    setState(() => _index = _homeTab);
  }

  /// **L'appui sur un onglet**, et le seul endroit où un onglet peut exiger un
  /// compte.
  ///
  /// Pour un membre, `requireSession` est transparent : il exécute le geste dans
  /// la foulée et rend `true`. Pour un invité, il pousse le parcours de connexion
  /// par-dessus la coquille et rejoue le geste après le succès.
  void _selectTab(int index) {
    if (index != _communityTab) {
      setState(() => _index = index);
      return;
    }
    ref.requireSession(action: _showCommunity);
  }

  /// Le geste rejoué après la connexion.
  ///
  /// **C'est le seul geste branché dont la reprise dépende de l'état d'un
  /// widget**, et il faut l'écrire : l'onglet courant vit en `State` **local**
  /// (le remonter dans un provider global est interdit — « Riverpod = état
  /// partagé »), et la reprise passe par un `router.go(origin)`, c'est-à-dire par
  /// une reconstruction de la pile. La coquille y survit tant que la page
  /// `/home` garde sa clé — c'est le cas aujourd'hui, et c'est ce qui fait
  /// atterrir le nouveau membre **sur le hub qu'il avait demandé**.
  ///
  /// Le `mounted` n'est donc pas une précaution de style : si cette page était un
  /// jour reconstruite, la reprise doit **retomber sur l'accueil** et non lever.
  /// Un membre qui atterrit sur l'accueil au lieu du hub est une déception ; un
  /// `setState` sur un `State` mort est un écran rouge.
  void _showCommunity() {
    if (!mounted) return;
    setState(() => _index = _communityTab);
  }

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
      HomeScreen(onMenuTap: _openMenu),
      AnnouncementsScreen(
        isActive: _index == _announcementsTab,
        onVideoChanged: (isVideo) {
          if (_videoStatus == isVideo) return;
          setState(() => _videoStatus = isVideo);
        },
      ),
      const GroupsScreen(),
      const _BiblePlaceholderScreen(),
    ];

    final dimFab = _index == _announcementsTab && _videoStatus;

    final main = Scaffold(
      extendBody: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          IndexedStack(
            key: HomeShell.tabsKey,
            index: _index,
            children: tabs,
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
        currentIndex: _index,
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
          currentIndex: _index,
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
