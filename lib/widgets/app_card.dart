import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';

/// Conteneur « carte » de base (fond surface, arrondi, ombre légère).
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
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? palette.surface,
        borderRadius: AppRadius.card,
        border: border ?? Border.all(color: palette.divider),
        boxShadow: shadow ? AppShadows.elevation1 : null,
      ),
      child: child,
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
