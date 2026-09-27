import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Variantes de bouton issues de la section « Boutons » du design.
/// La variante `danger` existe pour les actions **irréversibles**, et pour
/// elles seules — aujourd'hui la seule est la suppression de compte. Elle a été
/// ajoutée plutôt que d'habiller un bouton au cas par cas dans l'écran : le
/// rouge d'un bouton qui efface pour toujours ne doit pas dépendre de qui l'a
/// écrit. `MenuTile` porte déjà la même notion (`destructive`).
enum AppButtonVariant { primary, secondary, accent, outline, ghost, danger }

/// Bouton réutilisable couvrant toutes les variantes et états du design
/// (Normal / Disabled). La couleur du texte et du fond s'adapte à la variante.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.trailingIcon,
    this.expand = true,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final IconData? trailingIcon;

  /// Occupe toute la largeur disponible (cas par défaut dans les écrans).
  final bool expand;
  final bool loading;

  bool get _enabled => onPressed != null && !loading;

  @override
  Widget build(BuildContext context) {
    final style = _resolveStyle(context);

    final child = loading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation(style.foreground),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: style.foreground),
                const SizedBox(width: AppSpacing.sm),
              ],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.button.copyWith(color: style.foreground),
                ),
              ),
              if (trailingIcon != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Icon(trailingIcon, size: 18, color: style.foreground),
              ],
            ],
          );

    final button = Material(
      color: style.background,
      borderRadius: AppRadius.button,
      child: InkWell(
        borderRadius: AppRadius.button,
        onTap: _enabled ? onPressed : null,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: AppRadius.button,
            border: style.border,
          ),
          child: Container(
            height: 52,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: child,
          ),
        ),
      ),
    );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }

  _ButtonStyle _resolveStyle(BuildContext context) {
    final palette = context.palette;
    if (!_enabled) {
      return _ButtonStyle(
        background: palette.surfaceAlt,
        foreground: palette.textSecondary,
      );
    }
    switch (variant) {
      case AppButtonVariant.primary:
        return const _ButtonStyle(
          background: AppColors.primary,
          foreground: AppColors.textOnPrimary,
        );
      case AppButtonVariant.secondary:
        return const _ButtonStyle(
          background: AppColors.secondary,
          foreground: AppColors.textOnPrimary,
        );
      case AppButtonVariant.danger:
        return const _ButtonStyle(
          background: AppColors.danger,
          foreground: AppColors.textOnPrimary,
        );
      case AppButtonVariant.accent:
        return const _ButtonStyle(
          background: AppColors.neutralLight,
          foreground: AppColors.primary,
        );
      case AppButtonVariant.outline:
        return _ButtonStyle(
          background: palette.surface,
          foreground: palette.textPrimary,
          border: Border.fromBorderSide(BorderSide(color: palette.border)),
        );
      case AppButtonVariant.ghost:
        return _ButtonStyle(
          background: Colors.transparent,
          foreground: palette.primary,
        );
    }
  }
}

class _ButtonStyle {
  const _ButtonStyle({
    required this.background,
    required this.foreground,
    this.border,
  });

  final Color background;
  final Color foreground;
  final BoxBorder? border;
}
