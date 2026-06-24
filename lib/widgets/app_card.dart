import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';

/// Conteneur « carte » de base, au rendu **verre dépoli** (glassmorphisme) :
/// fond translucide, fin liseré clair et léger flou d'arrière-plan.
/// Sert de socle aux cartes métier (événement, enseignement, etc.).
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.onTap,
    this.color,
    this.border,
    this.shadow = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final BoxBorder? border;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final fill =
        color ?? palette.surface.withValues(alpha: isDark ? 0.55 : 0.62);
    final glassBorder = border ??
        Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.60),
        );

    final content = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: AppRadius.card,
        boxShadow: shadow ? AppShadows.elevation1 : null,
      ),
      child: ClipRRect(
        borderRadius: AppRadius.card,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: AppRadius.card,
              border: glassBorder,
            ),
            child: child,
          ),
        ),
      ),
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadius.card,
        onTap: onTap,
        child: content,
      ),
    );
  }
}
