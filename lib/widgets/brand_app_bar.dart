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
    this.color,
  });

  final String? title;
  final List<Widget>? actions;
  final bool centerTitle;

  /// Un fond uni à la place du dégradé — le bleu nuit du module Bible.
  final Color? color;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      // Fond solide garanti, sublimé par le dégradé en flexibleSpace.
      backgroundColor: color ?? AppColors.primary,
      foregroundColor: Colors.white,
      iconTheme: const IconThemeData(color: Colors.white),
      centerTitle: centerTitle,
      flexibleSpace: color != null
          ? null
          : const DecoratedBox(
              decoration: BoxDecoration(gradient: AppColors.gradientPrimary),
            ),
      title: title == null
          ? null
          : Text(title!, style: AppTypography.h5.copyWith(color: Colors.white)),
      actions: actions,
    );
  }
}
