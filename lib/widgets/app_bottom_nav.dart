import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';

/// Élément de la barre de navigation.
class NavItem {
  const NavItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

/// Barre de navigation inférieure avec bouton d'action central (+).
///
/// Conforme à la maquette « Accueil · Médias · (+) · Groupes · Profil ».
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onSelect,
    this.onFabTap,
    this.items = defaultItems,
  });

  final int currentIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback? onFabTap;
  final List<NavItem> items;

  static const List<NavItem> defaultItems = [
    NavItem(icon: Icons.home_outlined, label: 'Accueil'),
    NavItem(icon: Icons.play_circle_outline, label: 'Médias'),
    NavItem(icon: Icons.groups_outlined, label: 'Groupes'),
    NavItem(icon: Icons.person_outline, label: 'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    // Insère le FAB au centre de la liste d'onglets.
    final left = items.take(2).toList();
    final right = items.skip(2).toList();
    final palette = context.palette;

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(top: BorderSide(color: palette.divider)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0F000000), blurRadius: 16, offset: Offset(0, -4)),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                for (var i = 0; i < left.length; i++)
                  Expanded(child: _tab(palette, left[i], i)),
                Expanded(child: _fab()),
                for (var i = 0; i < right.length; i++)
                  Expanded(child: _tab(palette, right[i], i + left.length)),
              ],
            ),
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(item.icon, color: color, size: 24),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTypography.caption.copyWith(
                color: color,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fab() {
    return Center(
      child: GestureDetector(
        onTap: onFabTap,
        child: Container(
          width: 52,
          height: 52,
          decoration: const BoxDecoration(
            gradient: AppColors.gradientSecondary,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Color(0x4000A693),
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(Icons.add, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}
