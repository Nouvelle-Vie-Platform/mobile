import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Fond dégradé « glass » de l'application.
///
/// Enveloppe chaque route (les `Scaffold` étant transparents) afin que le
/// dégradé soit peint **par écran**. Chaque page est ainsi opaque : pendant
/// les transitions, la page entrante recouvre proprement la page sortante
/// (sinon, avec un fond unique sous le Navigator, on verrait au travers).
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient:
            isDark ? AppColors.gradientAppDark : AppColors.gradientAppLight,
      ),
      child: child,
    );
  }
}
