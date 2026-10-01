import 'package:flutter/material.dart';

import '../l10n/l10n_extension.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'brand_logo.dart';
import 'home_tab.dart';

/// Panneau du menu latéral de l'accueil (`flutter_zoom_drawer`).
///
/// **Quatre entrées, rien d'autre** : Accueil, CGU, Politique de
/// confidentialité, À propos. Pas de mode sombre, pas d'aide, pas de
/// déconnexion — l'onglet Profil les porte déjà, et les dupliquer laisserait le
/// fidèle chercher lequel des deux ouvrir. Pas d'entête utilisateur non plus :
/// `_ProfileHeader` fait exactement cela dans l'onglet Profil. **L'entête de ce
/// menu porte la marque, pas la personne.**
///
/// Le panneau ne navigue pas lui-même et ne connaît pas le tiroir : il ne fait
/// que rappeler. C'est la coquille ([HomeShell]) qui ferme le tiroir **avant**
/// de naviguer — sans quoi un `context.pop()` depuis l'écran CGU ramènerait sur
/// une coquille encore rétrécie et pivotée.
class AppDrawerMenu extends StatelessWidget {
  const AppDrawerMenu({
    super.key,
    required this.currentTab,
    required this.onHome,
    required this.onTerms,
    required this.onPrivacy,
    required this.onAbout,
  });

  /// Onglet courant de la coquille, **nommé**. Seule l'entrée « Accueil » peut
  /// être courante : les trois autres poussent une route par-dessus la coquille,
  /// elles ne changent pas d'onglet.
  ///
  /// C'était un **numéro** — le même que celui de la barre du bas, dupliqué ici
  /// sans que l'un référence l'autre. Réordonner la barre faisait alors de ce
  /// panneau le premier menteur : il désignait l'onglet 0, pas l'accueil, et
  /// personne ne s'en apercevait avant un retour de fidèle.
  final HomeTab currentTab;

  final VoidCallback onHome;
  final VoidCallback onTerms;
  final VoidCallback onPrivacy;
  final VoidCallback onAbout;

  /// Clés des quatre entrées, pour les cibler depuis les tests sans se heurter
  /// aux libellés de la barre d'onglets (« Accueil » y figure déjà).
  static const Key homeKey = Key('drawer_entry_home');
  static const Key termsKey = Key('drawer_entry_terms');
  static const Key privacyKey = Key('drawer_entry_privacy');
  static const Key aboutKey = Key('drawer_entry_about');

  /// L'onglet que l'entrée « Accueil » **désigne** — un nom, pas une position.
  static const HomeTab homeTab = HomeTab.home;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      // Le `menuScreen` du tiroir n'est pas un `Scaffold` : sans cette couche,
      // les `InkWell` des entrées n'auraient aucun `Material` au-dessus d'eux.
      decoration: const BoxDecoration(gradient: AppColors.gradientPrimary),
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _BrandHeader(),
                const SizedBox(height: AppSpacing.xl),
                _DrawerEntry(
                  key: homeKey,
                  icon: Icons.home_outlined,
                  label: l10n.navHome,
                  current: currentTab == homeTab,
                  onTap: onHome,
                ),
                _DrawerEntry(
                  key: termsKey,
                  icon: Icons.description_outlined,
                  label: l10n.drawerTerms,
                  onTap: onTerms,
                ),
                _DrawerEntry(
                  key: privacyKey,
                  icon: Icons.lock_outline,
                  label: l10n.drawerPrivacy,
                  onTap: onPrivacy,
                ),
                _DrawerEntry(
                  key: aboutKey,
                  icon: Icons.info_outline,
                  label: l10n.drawerAbout,
                  onTap: onAbout,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Entête de marque : l'emblème de l'église, en filigrane.
///
/// **Rien d'autre.** Le nom complet de l'église y figurait, il a été retiré : le
/// panneau n'a que quatre entrées, ce sont elles qu'on vient y lire, et un
/// bloc de marque qui les concurrence à l'ouverture leur vole la première
/// seconde. L'emblème reste, effacé — il situe le panneau sans se disputer
/// l'attention.
class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  /// Assez présent pour se reconnaître, assez effacé pour ne pas se lire.
  static const double _opacity = 0.68;

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      // **La variante inversée, et pas l'originale** : le panneau est peint au
      // bleu de marque, et le disque blanc plein de la pièce d'origine y ferait
      // une tache. Ici le disque est évidé — le dégradé du panneau passe au
      // travers, derrière la colombe.
      child: BrandLogo.inverse(size: 120, opacity: _opacity),
    );
  }
}

/// Une ligne du menu.
///
/// **L'entrée courante se signale par sa seule clarté** — blanc franc contre
/// blanc très atténué, et gras contre demi-gras. La barre d'accent jaune qui
/// tenait ce rôle a été retirée : dans un panneau de quatre lignes, un liseré de
/// 4 px est un signal faible qu'il fallait aller chercher, et il introduisait la
/// seule touche de jaune d'un écran qui n'en a nulle part ailleurs. L'écart de
/// clarté, lui, se voit sans être cherché.
///
/// L'alignement n'a pas bougé pour autant : la barre occupait 4 px suivis de
/// `AppSpacing.md`, soit exactement les `AppSpacing.lg` de marge que porte
/// désormais la ligne — et que porte déjà l'emblème au-dessus.
class _DrawerEntry extends StatelessWidget {
  const _DrawerEntry({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.current = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final color = current ? Colors.white : Colors.white.withValues(alpha: 0.55);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md,
          horizontal: AppSpacing.lg,
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                label,
                style: AppTypography.bodyLarge.copyWith(
                  fontSize: 15,
                  color: color,
                  fontWeight: current ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
