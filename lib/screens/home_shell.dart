import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router/app_router.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';
import 'announcements_screen.dart';
import 'groups_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';

/// Conteneur principal : onglets en [IndexedStack], barre à encoche et FAB
/// central docké (nouvelle requête).
///
/// L'onglet courant est un état local de la coquille (porté par le `State`),
/// ce qui le préserve d'une reconstruction à l'autre.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

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

  @override
  Widget build(BuildContext context) {
    final tabs = <Widget>[
      const HomeScreen(),
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

    return Scaffold(
      // Le contenu s'étend derrière la barre givrée (effet verre dépoli).
      extendBody: true,
      body: IndexedStack(index: _index, children: tabs),
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
  }
}
