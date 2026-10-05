import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_zoom_drawer/flutter_zoom_drawer.dart';
import 'package:go_router/go_router.dart';

import '../models/legal_document_view.dart';
import '../router/app_router.dart';
import '../state/auth_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_responsive.dart';
import '../widgets/app_background.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/app_drawer_menu.dart';
import '../widgets/app_update_banner.dart';
import '../widgets/home_tab.dart';
import '../widgets/legal_notice_banner.dart';
import '../widgets/mini_player_host.dart';
import 'announcements_screen.dart';
import 'auth/sign_in_tab.dart';
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
/// ## Les onglets réservés se ferment **ici**, et par leur contenu
///
/// Les quatre onglets ne sont pas des routes : ils vivent dans un
/// [IndexedStack], et la garde du routeur (`memberOnlyRoutes`) ne peut donc rien
/// pour eux. C'est vrai du hub « Échanges », que la décision du client met
/// derrière la connexion ; c'est vrai aussi du **Profil**, qui n'a aucun sens
/// sans compte et qui perd la garde de route en redevenant un onglet. La
/// réponse est la même pour les deux, et elle est portée par
/// `HomeTab.requiresSession`.
///
/// ⚠️ **L'onglet est sélectionnable, et c'est son écran qui change.** L'appui
/// poussait jusqu'ici le parcours d'authentification **plein écran** par-dessus
/// la coquille, par `requireSession()`. C'était un cul-de-sac sur iPhone : le
/// premier écran du parcours n'avait aucune flèche de retour, et iOS n'a pas de
/// bouton système pour dépiler. Le bouton manquant n'était que le symptôme — la
/// faute était d'avoir fait une **navigation** de ce qui est un **état
/// d'onglet**. Sans session, l'onglet réservé affiche donc le formulaire de
/// connexion **à la place** de son écran ([SignInTab]) : la barre du bas reste
/// là, on sort en touchant un autre onglet, et rien n'est à dépiler.
///
/// **L'onglet reste visible** — plutôt que de disparaître pour un invité. Trois
/// raisons, dans l'ordre d'importance :
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
///
/// **`requireSession()` n'a pas disparu**, et il ne faut pas le démonter : il
/// garde les gestes qui ne sont **pas** des onglets — publier une annonce,
/// écrire une note, ouvrir une conversation depuis une notification —, où
/// l'intention mise de côté puis rejouée reste indispensable. Un onglet, lui, n'a
/// pas de geste à rejouer : la session s'ouvre, la coquille se repeint, et
/// l'écran de l'onglet prend la place du formulaire.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key, this.initialTab});

  /// **L'onglet à montrer en arrivant** (#140), lu dans `/home?tab=<nom>`.
  ///
  /// Il existe pour un seul chemin : un fil ouvert depuis une **notification**
  /// est ouvert par `goNamed`, sans pile dessous ; son retour mène ici, sur la
  /// liste des Échanges, et non sur l'accueil — ni dans le vide. L'onglet
  /// courant reste un état **local** (« Riverpod = état partagé ») ; ce
  /// paramètre n'en est que la valeur de départ.
  final HomeTab? initialTab;

  static const Key tabsKey = Key('home_shell_tabs');

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  late HomeTab _tab = widget.initialTab ?? HomeTab.home;

  @override
  void didUpdateWidget(HomeShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Une navigation vers `/home?tab=…` alors que la coquille est déjà montée.
    final requested = widget.initialTab;
    if (requested != null && requested != oldWidget.initialTab) {
      _tab = requested;
    }
  }

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

  /// **L'appui sur un onglet** — et il n'y a plus rien à y décider.
  ///
  /// Tous les onglets sont sélectionnables, invité compris. La question « cet
  /// onglet exige-t-il un compte ? » n'a pas disparu, elle a changé de place :
  /// elle ne décide plus si l'onglet *s'ouvre* mais **ce qu'il montre** (voir
  /// [_screenFor]). Elle appartient toujours à l'onglet
  /// (`HomeTab.requiresSession`), où un `switch` exhaustif oblige tout onglet
  /// neuf à y répondre.
  ///
  /// **C'est le seul endroit dont la reprise dépende de l'état d'un widget**, et
  /// il faut l'écrire : l'onglet courant vit en `State` **local** (le remonter
  /// dans un provider global est interdit — « Riverpod = état partagé »), et la
  /// reprise d'une intention passe par un `router.go(origin)`, c'est-à-dire par
  /// une reconstruction de la pile. La coquille y survit tant que la page
  /// `/home` garde sa clé — c'est le cas aujourd'hui, et c'est aussi ce qui fait
  /// retrouver son onglet à qui revient de l'écran du code.
  ///
  /// Le `mounted` n'est donc pas une précaution de style : si cette page était un
  /// jour reconstruite, un geste rejoué doit **retomber sur l'accueil** et non
  /// lever. Un membre qui atterrit sur l'accueil au lieu du hub est une
  /// déception ; un `setState` sur un `State` mort est un écran rouge.
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
  ///
  /// **Sans session, un onglet réservé montre le formulaire de connexion** et non
  /// son écran. Deux conséquences qu'il faut connaître :
  ///
  /// - l'écran réservé n'est pas simplement masqué, il n'est **pas construit** —
  ///   un `IndexedStack` construit pourtant tous ses enfants, et un invité
  ///   montait donc jusqu'ici le hub et le Profil hors de l'écran ;
  /// - [isGuest] et non `!isAuthenticated` : celui-ci est **aussi** vrai pendant
  ///   la résolution du démarrage (`AuthStatus.unknown`), et un membre verrait
  ///   passer le formulaire. La garde du routeur retient de toute façon le
  ///   démarrage sur le splash, mais la règle vaut partout (voir `isGuest`).
  Widget _screenFor(HomeTab tab, {required bool isGuest}) {
    if (isGuest && tab.requiresSession) return SignInTab(tab: tab);
    return switch (tab) {
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
  }

  @override
  Widget build(BuildContext context) {
    final dimFab = _tab == HomeTab.announcements && _videoStatus;
    // **La seule chose que la coquille lit de l'authentification**, et par
    // `select` : la session s'ouvre, l'onglet réservé se repeint avec son écran,
    // et personne n'a à y retoucher. C'est ce qui remplace le geste rejoué.
    final isGuest = ref.watch(authProvider.select((state) => state.isGuest));

    // **Sans la place du mini-lecteur** : la `BottomAppBar` porte une
    // `SafeArea`, et grandirait de la hauteur de la carte (#117).
    final main = WithoutMiniPlayerInset(
        child: Scaffold(
      extendBody: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          ContentMaxWidth(
            // **Le contenu, pas la barre.** Sur un grand écran, la largeur de
            // lecture est bornée et centrée ; la barre du bas et le FAB, eux,
            // restent à l'échelle de l'écran. Inerte sur téléphone — voir
            // `ContentMaxWidth`.
            //
            // **La place du mini-lecteur, rendue aux onglets** (#117) : retirée
            // autour du `Scaffold` pour que la barre ne grandisse pas, elle est
            // rajoutée ici, et l'accueil, Échanges, Profil et Annonces, qui
            // finissent déjà par la marge basse de l'écran, s'écartent d'eux-mêmes.
            child: WithMiniPlayerInset(
              child: IndexedStack(
                key: HomeShell.tabsKey,
                // **L'index, enfin réduit à ce qu'il est** : la position de
                // l'onglet dans l'ordre déclaré. Il ne circule plus, il se
                // calcule.
                index: _tab.index,
                children: [
                  for (final tab in HomeTab.values)
                    _screenFor(tab, isGuest: isGuest),
                ],
              ),
            ),
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
          //
          // **Le mini-lecteur prend la place la plus basse**, juste au-dessus
          // de la barre : il revient à chaque écoute, les bandeaux une fois, et
          // c'est lui que le pouce cherche. Il ne vit plus ici mais au-dessus du
          // `Navigator` (#117, `MiniPlayerHost`), qui ajoute sa hauteur à
          // `MediaQuery.padding.bottom` : lu sur le contexte de la coquille, ce
          // padding monte donc les bandeaux au-dessus de lui quand il est là, et
          // les rend à leur place quand il s'en va.
          Positioned(
            left: 0,
            right: 0,
            bottom:
                MediaQuery.paddingOf(context).bottom + AppBottomNav.barHeight,
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppUpdateBanner(),
                LegalNoticeBanner(),
              ],
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
        onSelect: _showTab,
        // **Le badge global des non-lus** (#140) — la somme des pastilles des
        // conversations, lue sur le même flux que la liste. Rien pour un invité :
        // il n'a pas de conversation.
        badges: {
          if (!isGuest)
            HomeTab.community:
                ref.watch(unreadTotalProvider(ref.watch(echangesActorProvider))),
        },
      ),
    ));

    // **Le mini-lecteur s'efface** (#117) pendant que le menu latéral est
    // ouvert — la coquille rétrécie glisse de côté, et une carte restée en bas
    // de l'écran flotterait par-dessus le menu, détachée de tout. La
    // visionneuse d'Annonces le masque elle-même (`AnnouncementsScreen`), sur
    // tout statut et pas seulement une vidéo : `dimFab` ne règle que le bouton
    // central.
    return MiniPlayerShield(
      hidden: _menuOpen,
      child: PopScope(
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
      ),
    );
  }
}
