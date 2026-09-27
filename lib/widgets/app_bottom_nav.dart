import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../l10n/l10n_extension.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';

/// Élément de la barre de navigation (icône au repos / active + libellé).
class NavItem {
  const NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// Barre de navigation inférieure avec **encoche** pour le bouton d'action
/// central (FAB), géré au niveau de [Scaffold] par la coquille.
///
/// Disposition « Accueil · Annonces · (encoche) · Échanges · Bible ».
///
/// **Quatre onglets, en invité comme en membre**, et la géométrie ne dépend
/// donc d'aucun état d'authentification : c'est la coquille qui refuse l'entrée
/// du hub à un invité, par `requireSession()` (voir `HomeShell`). Deux raisons
/// de ne pas retirer l'onglet ici — l'encoche du FAB est calée sur *deux*
/// onglets de chaque côté, qu'une barre à trois rendrait boiteuse ; et l'index
/// d'onglet est un **numéro** que se partagent cette barre, le tiroir latéral et
/// leurs tests. Une barre à géométrie variable ferait de ce numéro une valeur
/// dont le sens dépend de qui regarde.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onSelect,
    this.items,
  });

  /// Hauteur de la barre, **nommée parce qu'un autre widget en dépend** : la
  /// coquille pose la mention légale du premier lancement juste au-dessus, et
  /// `extendBody: true` fait passer le corps derrière cette barre. Un littéral
  /// recopié là-bas se serait désaccordé à la première retouche de hauteur, et le
  /// bandeau aurait recouvert les onglets.
  static const double barHeight = 64;

  final int currentIndex;
  final ValueChanged<int> onSelect;

  /// Onglets affichés. Si `null`, on utilise les onglets par défaut localisés.
  final List<NavItem>? items;

  /// Onglets par défaut « Accueil · Annonces · Échanges · Bible », **tous
  /// localisés** : les deux derniers étaient écrits en dur, et ne se
  /// traduisaient donc ni en anglais ni en éwé alors que les clés existaient.
  static List<NavItem> defaultItems(BuildContext context) => [
        NavItem(
          icon: Icons.home_outlined,
          activeIcon: Icons.home,
          label: context.l10n.navHome,
        ),
        NavItem(
          icon: Icons.campaign_outlined,
          activeIcon: Icons.campaign,
          label: context.l10n.navAnnouncements,
        ),
        NavItem(
          icon: Icons.forum_outlined,
          activeIcon: Icons.forum,
          // **`navGroups`, et pas un libellé de plus** : la même clé titre déjà
          // le hub des conversations (voir sa description dans `app_fr.arb`).
          label: context.l10n.navGroups,
        ),
        NavItem(
          icon: Icons.menu_book_outlined,
          activeIcon: Icons.menu_book,
          label: context.l10n.navBible,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final navItems = items ?? defaultItems(context);
    final left = navItems.take(2).toList();
    final right = navItems.skip(2).toList();
    final palette = context.palette;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: BottomAppBar(
          color: palette.surface.withValues(alpha: 0.72),
          surfaceTintColor: Colors.transparent,
          shape: const CircularNotchedRectangle(),
          notchMargin: 8,
          height: barHeight,
          padding: EdgeInsets.zero,
          child: Row(
            children: [
              for (var i = 0; i < left.length; i++)
                Expanded(child: _tab(palette, left[i], i)),
              // Espace réservé à l'encoche du FAB central.
              const SizedBox(width: 64),
              for (var i = 0; i < right.length; i++)
                Expanded(child: _tab(palette, right[i], i + left.length)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tab(AppPalette palette, NavItem item, int index) {
    final selected = index == currentIndex;
    final color = selected ? palette.primary : palette.textSecondary;
    return InkResponse(
      onTap: () => onSelect(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(selected ? item.activeIcon : item.icon, color: color, size: 24),
          const SizedBox(height: 3),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTypography.caption.copyWith(
                color: color,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
