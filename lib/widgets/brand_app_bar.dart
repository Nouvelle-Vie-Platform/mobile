import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Barre d'application de marque : dégradé bleu primaire et texte blanc,
/// dans les mêmes coloris que l'en-tête du profil.
///
/// Réutilisée par tous les écrans à en-tête (hors accueil, qui a son propre
/// en-tête ondulé).
class BrandAppBar extends StatelessWidget implements PreferredSizeWidget {
  const BrandAppBar({
    super.key,
    this.title,
    this.actions,
    this.centerTitle = true,
  });

  final String? title;
  final List<Widget>? actions;
  final bool centerTitle;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      // Fond solide garanti, sublimé par le dégradé en flexibleSpace.
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      iconTheme: const IconThemeData(color: Colors.white),
      centerTitle: centerTitle,
      flexibleSpace: const DecoratedBox(
        decoration: BoxDecoration(gradient: AppColors.gradientPrimary),
      ),
      title: title == null
          ? null
          : Text(title!, style: AppTypography.h5.copyWith(color: Colors.white)),
      actions: actions,
    );
  }
}
