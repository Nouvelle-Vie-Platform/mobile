import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_palette.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Thème global de l'application, décliné en mode clair et sombre.
abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light, AppPalette.light);
  static ThemeData get dark => _build(Brightness.dark, AppPalette.dark);

  static ThemeData _build(Brightness brightness, AppPalette palette) {
    final isDark = brightness == Brightness.dark;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: palette.primary,
      onPrimary: isDark ? const Color(0xFF0E1118) : AppColors.textOnPrimary,
      secondary: AppColors.secondary,
      onSecondary: AppColors.textOnPrimary,
      tertiary: AppColors.accent,
      onTertiary: AppColors.neutralDark,
      surface: palette.surface,
      onSurface: palette.textPrimary,
      onSurfaceVariant: palette.textSecondary,
      outline: palette.border,
      outlineVariant: palette.divider,
      error: AppColors.danger,
      onError: AppColors.textOnPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      // Transparent : le dégradé « glass » global (posé dans app.dart) reste
      // visible derrière les écrans et les surfaces translucides.
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: palette.surface,
      textTheme: AppTypography.textTheme(palette.textPrimary),
      dividerColor: palette.divider,
      splashFactory: InkRipple.splashFactory,
      extensions: [palette],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: palette.textPrimary,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: palette.textPrimary),
        titleTextStyle: AppTypography.h5.copyWith(color: palette.textPrimary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        hintStyle: AppTypography.body.copyWith(color: palette.textSecondary),
        border: _fieldBorder(palette.border),
        enabledBorder: _fieldBorder(palette.border),
        focusedBorder: _fieldBorder(AppColors.secondary, width: 1.6),
        errorBorder: _fieldBorder(AppColors.danger),
        focusedErrorBorder: _fieldBorder(AppColors.danger, width: 1.6),
        disabledBorder: _fieldBorder(palette.border),
        errorStyle: AppTypography.caption.copyWith(color: AppColors.danger),
      ),
      dividerTheme: DividerThemeData(
        color: palette.divider,
        thickness: 1,
        space: 1,
      ),
    );
  }

  static OutlineInputBorder _fieldBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: AppRadius.field,
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
