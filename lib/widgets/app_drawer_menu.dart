import 'package:flutter/material.dart';

import '../l10n/l10n_extension.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'brand_logo.dart';

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
    required this.currentIndex,
    required this.onHome,
    required this.onTerms,
    required this.onPrivacy,
    required this.onAbout,
  });

  /// Onglet courant de la coquille. Seule l'entrée « Accueil » peut être
  /// courante : les trois autres poussent une route par-dessus la coquille,
  /// elles ne changent pas d'onglet.
  final int currentIndex;

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

  /// Index de l'onglet Accueil dans la coquille.
  static const int homeTab = 0;

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
                  current: currentIndex == homeTab,
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

/// Entête de marque : l'emblème de l'église et son nom.
class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // `BrandLogo` porte déjà le mot-symbole « Maison du Miracle » : le
          // nom complet de l'église le complète, il ne le répète pas.
          const BrandLogo(size: 96),
          const SizedBox(height: AppSpacing.md),
          Text(
            context.l10n.drawerBrandName,
            style: AppTypography.bodyStrong.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

/// Une ligne du menu. L'entrée courante porte la barre d'accent à gauche.
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
    final color = current ? Colors.white : Colors.white.withValues(alpha: 0.82);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          children: [
            // Barre d'accent de l'entrée courante. Elle occupe la place même
            // quand elle ne se voit pas : sans cela les libellés se
            // décaleraient d'une entrée à l'autre.
            Container(
              width: 4,
              height: 24,
              decoration: BoxDecoration(
                color: current ? AppColors.accent : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
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
