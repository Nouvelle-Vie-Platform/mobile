import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Bouton de connexion sociale (Google / Apple) avec contour.
class SocialButton extends StatelessWidget {
  const SocialButton({
    super.key,
    required this.label,
    required this.icon,
    this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: palette.surface,
      borderRadius: AppRadius.button,
      child: InkWell(
        borderRadius: AppRadius.button,
        onTap: onPressed,
        child: Ink(
          height: 50,
          decoration: BoxDecoration(
            borderRadius: AppRadius.button,
            border: Border.all(color: palette.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: palette.textPrimary),
              const SizedBox(width: AppSpacing.sm),
              Text(label, style: AppTypography.bodyStrong),
            ],
          ),
        ),
      ),
    );
  }
}
