import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Champ de saisie avec label, issu de la section « Champs de saisie ».
///
/// Gère les états visuels du design : par défaut, rempli, erreur, désactivé.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.initialValue,
    this.errorText,
    this.helperText,
    this.obscureText = false,
    this.enabled = true,
    this.keyboardType,
    this.prefixIcon,
    this.suffixIcon,
    this.maxLines = 1,
    this.onSuffixTap,
  });

  final String label;
  final String? hint;
  final TextEditingController? controller;
  final String? initialValue;
  final String? errorText;
  final String? helperText;
  final bool obscureText;
  final bool enabled;
  final TextInputType? keyboardType;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final int maxLines;
  final VoidCallback? onSuffixTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.bodyStrong),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          controller: controller,
          initialValue: controller == null ? initialValue : null,
          obscureText: obscureText,
          enabled: enabled,
          keyboardType: keyboardType,
          maxLines: obscureText ? 1 : maxLines,
          style: AppTypography.bodyLarge,
          decoration: InputDecoration(
            hintText: hint,
            errorText: errorText,
            helperText: helperText,
            helperStyle:
                AppTypography.caption.copyWith(color: palette.textSecondary),
            fillColor: enabled ? palette.surface : palette.surfaceAlt,
            prefixIcon: prefixIcon == null
                ? null
                : Icon(prefixIcon, size: 20, color: palette.textSecondary),
            suffixIcon: suffixIcon == null
                ? null
                : IconButton(
                    icon: Icon(suffixIcon,
                        size: 20, color: palette.textSecondary),
                    onPressed: onSuffixTap,
                  ),
          ),
        ),
      ],
    );
  }
}

/// Barre de recherche réutilisée dans la médiathèque et les notes.
class AppSearchField extends StatelessWidget {
  const AppSearchField({
    super.key,
    required this.hint,
    this.controller,
    this.onChanged,
  });

  final String hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: AppTypography.bodyLarge,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(Icons.search,
            size: 20, color: context.palette.textSecondary),
        contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      ),
    );
  }
}
