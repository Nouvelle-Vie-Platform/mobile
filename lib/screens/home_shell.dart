import 'package:flutter/material.dart';
import 'package:flutter_zoom_drawer/flutter_zoom_drawer.dart';
import 'package:go_router/go_router.dart';

import '../models/legal_document_view.dart';
import '../router/app_router.dart';
import '../theme/app_colors.dart';
import '../widgets/app_background.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/app_drawer_menu.dart';
import 'announcements_screen.dart';
import 'groups_screen.dart';
import 'home_screen.dart';

/// Écran provisoire pour l'onglet Bible.
class _BiblePlaceholderScreen extends StatelessWidget {
  const _BiblePlaceholderScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          'Page en construction',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

/// Conteneur principal : onglets en [IndexedStack], barre à encoche et FAB
/// central docké, le tout dans le menu latéral ([ZoomDrawer]).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  static const Key tabsKey = Key('home_shell_tabs');

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const int _announcementsTab = 1;

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
    setState(() => _index = 0);
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
      body: IndexedStack(key: HomeShell.tabsKey, index: _index, children: tabs),
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