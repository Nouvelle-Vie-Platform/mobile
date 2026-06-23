import 'package:flutter/material.dart';

import '../routes.dart';
import '../widgets/app_bottom_nav.dart';
import 'groups_screen.dart';
import 'home_screen.dart';
import 'media_library_screen.dart';
import 'profile_screen.dart';

/// Conteneur principal avec barre de navigation inférieure.
///
/// Reste sans `StatefulWidget` : l'onglet courant est porté par un
/// [ValueNotifier] et l'arbre réagit via [ValueListenableBuilder].
class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  static const List<Widget> _tabs = [
    HomeScreen(),
    MediaLibraryScreen(),
    GroupsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final current = ValueNotifier<int>(0);

    return ValueListenableBuilder<int>(
      valueListenable: current,
      builder: (context, index, _) {
        return Scaffold(
          body: IndexedStack(index: index, children: _tabs),
          bottomNavigationBar: AppBottomNav(
            currentIndex: index,
            onSelect: (i) => current.value = i,
            onFabTap: () => Navigator.pushNamed(context, AppRoutes.newRequest),
          ),
        );
      },
    );
  }
}
