import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../l10n/l10n_extension.dart';
import '../theme/app_palette.dart';
import 'home_tab.dart';
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
/// Disposition « Accueil · Annonces · (encoche) · Échanges · Profil », et
/// **l'ordre ne vit pas ici** : il est celui de `HomeTab.values`. Cette barre ne
/// fait que le rendre, et le `switch` exhaustif de [itemFor] garantit qu'un
/// onglet neuf ne peut pas arriver sans son libellé — c'est l'autre moitié de ce
/// que l'`enum` a supprimé : deux listes parallèles dont la discordance ne
/// produisait aucune erreur de compilation, mais ouvrait Échanges quand on
/// tapait « Bible ».
///
/// **Quatre onglets, en invité comme en membre**, et la géométrie ne dépend donc
/// d'aucun état d'authentification. Les onglets réservés sont sélectionnables
/// comme les autres : sans session, c'est leur **contenu** qui devient le
/// formulaire de connexion (voir `HomeTab.requiresSession` et
/// `HomeShell._screenFor`). Deux raisons de n'en retirer aucun — un onglet
/// retiré est une fermeture invisible, et l'**encoche** du FAB est posée entre
/// deux moitiés égales, qu'un nombre impair d'onglets rendrait boiteuse.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.current,
    required this.onSelect,
  });

  /// Hauteur de la barre, **nommée parce qu'un autre widget en dépend** : la
  /// coquille pose la mention légale du premier lancement juste au-dessus, et
  /// `extendBody: true` fait passer le corps derrière cette barre. Un littéral
  /// recopié là-bas se serait désaccordé à la première retouche de hauteur, et le
  /// bandeau aurait recouvert les onglets.
  static const double barHeight = 64;

  /// L'onglet affiché par la coquille — **un nom, pas un numéro**.
  final HomeTab current;

  /// L'onglet demandé. La barre ne décide de rien : elle ne sait pas qu'un
  /// onglet peut exiger un compte, et n'a pas à le savoir.
  final ValueChanged<HomeTab> onSelect;

  /// L'icône et le libellé d'un onglet, **tous localisés** : « Échanges » et
  /// « Bible » étaient écrits en dur, et ne se traduisaient donc ni en anglais ni
  /// en éwé alors que les clés existaient.
  ///
  /// `switch` sur l'`enum` et non table indexée : le compilateur exige alors
  /// qu'il soit **exhaustif**.
  static NavItem itemFor(BuildContext context, HomeTab tab) => switch (tab) {
        HomeTab.home => NavItem(
            icon: Icons.home_outlined,
            activeIcon: Icons.home,
            label: context.l10n.navHome,
          ),
        HomeTab.announcements => NavItem(
            icon: Icons.campaign_outlined,
            activeIcon: Icons.campaign,
            // **`context.words`, pas `context.l10n`** (#132) : le nom de cet
            // onglet est réglé au portail (clé `navAnnouncements` du catalogue
            // du vocabulaire), et le `.arb` n'en est que le repli.
            label: context.words.navAnnouncements,
          ),
        HomeTab.community => NavItem(
            icon: Icons.forum_outlined,
            activeIcon: Icons.forum,
            // **`navGroups`, et pas un libellé de plus** : la même clé titre déjà
            // le hub des conversations (voir sa description dans `app_fr.arb`).
            label: context.l10n.navGroups,
          ),
        // **« Profil » pour tout le monde**, invité compris : la connexion se
        // demande dans l'onglet, jamais par un libellé qui change selon l'état.
        // La barre n'en porte aucun autre, et en introduire un ici créerait une
        // exception à justifier à chaque relecture.
        HomeTab.profile => NavItem(
            icon: Icons.person_outline,
            activeIcon: Icons.person,
            label: context.l10n.navProfile,
          ),
      };

  @override
  Widget build(BuildContext context) {
    // **L'encoche tombe entre deux moitiés égales**, et c'est la seule chose
    // que cette barre sait de la géométrie. Le partage est positionnel, donc
    // permuter deux onglets ne la déplace pas ; seul un nombre **impair**
    // d'onglets la rendrait boiteuse — d'où l'assertion, qui parle au moment où
    // la faute se commet plutôt qu'à la relecture d'une capture d'écran.
    assert(
      HomeTab.values.length.isEven,
      'l\'encoche du FAB est calée sur deux moitiés égales : '
      'la barre doit porter un nombre pair d\'onglets',
    );
    final half = HomeTab.values.length ~/ 2;
    final left = HomeTab.values.take(half).toList();
    final right = HomeTab.values.skip(half).toList();
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
              for (final tab in left)
                Expanded(child: _tab(context, palette, tab)),
              // Espace réservé à l'encoche du FAB central.
              const SizedBox(width: 64),
              for (final tab in right)
                Expanded(child: _tab(context, palette, tab)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tab(BuildContext context, AppPalette palette, HomeTab tab) {
    final item = itemFor(context, tab);
    final selected = tab == current;
    final color = selected ? palette.primary : palette.textSecondary;
    return InkResponse(
      onTap: () => onSelect(tab),
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
