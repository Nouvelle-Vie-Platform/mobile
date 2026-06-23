import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Palette adaptative (clair / sombre) exposée via [ThemeExtension].
///
/// Les couleurs de **marque** (primaire navy, secondaire, accent, états)
/// restent fixes dans [AppColors] ; seules les couleurs dépendantes du mode
/// (surfaces, textes, bordures, teintes d'arrière-plan) vivent ici.
///
/// Accès : `context.palette.surface`, `context.palette.textPrimary`, …
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.textPrimary,
    required this.textSecondary,
    required this.primary,
    required this.border,
    required this.divider,
    required this.infoBg,
    required this.successBg,
    required this.warningBg,
    required this.dangerBg,
    required this.chipUrgentBg,
    required this.chipEventBg,
    required this.chipNewBg,
  });

  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color textPrimary;
  final Color textSecondary;

  /// Bleu d'accent pour textes/icônes sur surface (éclairci en mode sombre).
  final Color primary;
  final Color border;
  final Color divider;
  final Color infoBg;
  final Color successBg;
  final Color warningBg;
  final Color dangerBg;
  final Color chipUrgentBg;
  final Color chipEventBg;
  final Color chipNewBg;

  static const AppPalette light = AppPalette(
    background: Color(0xFFF7F8FA),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF0F0F0),
    textPrimary: Color(0xFF1A1A1A),
    textSecondary: Color(0xFF6B7280),
    primary: AppColors.primary,
    border: Color(0xFFE5E7EB),
    divider: Color(0xFFEDEFF2),
    infoBg: Color(0xFFE9EEF8),
    successBg: Color(0xFFE9F7F0),
    warningBg: Color(0xFFFDF6E3),
    dangerBg: Color(0xFFFDECEC),
    chipUrgentBg: Color(0xFFFDECEC),
    chipEventBg: Color(0xFFFDF6E3),
    chipNewBg: Color(0xFFE9F7F0),
  );

  static const AppPalette dark = AppPalette(
    background: Color(0xFF0E1118),
    surface: Color(0xFF171C28),
    surfaceAlt: Color(0xFF232B3B),
    textPrimary: Color(0xFFECEFF5),
    textSecondary: Color(0xFF9BA6BC),
    primary: Color(0xFF8AA4F2),
    border: Color(0xFF2A3344),
    divider: Color(0xFF222A38),
    infoBg: Color(0xFF1E2740),
    successBg: Color(0xFF14302A),
    warningBg: Color(0xFF332C19),
    dangerBg: Color(0xFF3A2222),
    chipUrgentBg: Color(0xFF3A2222),
    chipEventBg: Color(0xFF332C19),
    chipNewBg: Color(0xFF14302A),
  );

  @override
  AppPalette copyWith({
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? textPrimary,
    Color? textSecondary,
    Color? primary,
    Color? border,
    Color? divider,
    Color? infoBg,
    Color? successBg,
    Color? warningBg,
    Color? dangerBg,
    Color? chipUrgentBg,
    Color? chipEventBg,
    Color? chipNewBg,
  }) {
    return AppPalette(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      primary: primary ?? this.primary,
      border: border ?? this.border,
      divider: divider ?? this.divider,
      infoBg: infoBg ?? this.infoBg,
      successBg: successBg ?? this.successBg,
      warningBg: warningBg ?? this.warningBg,
      dangerBg: dangerBg ?? this.dangerBg,
      chipUrgentBg: chipUrgentBg ?? this.chipUrgentBg,
      chipEventBg: chipEventBg ?? this.chipEventBg,
      chipNewBg: chipNewBg ?? this.chipNewBg,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      border: Color.lerp(border, other.border, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      infoBg: Color.lerp(infoBg, other.infoBg, t)!,
      successBg: Color.lerp(successBg, other.successBg, t)!,
      warningBg: Color.lerp(warningBg, other.warningBg, t)!,
      dangerBg: Color.lerp(dangerBg, other.dangerBg, t)!,
      chipUrgentBg: Color.lerp(chipUrgentBg, other.chipUrgentBg, t)!,
      chipEventBg: Color.lerp(chipEventBg, other.chipEventBg, t)!,
      chipNewBg: Color.lerp(chipNewBg, other.chipNewBg, t)!,
    );
  }
}

/// Raccourci d'accès à la palette adaptative depuis un [BuildContext].
extension AppPaletteX on BuildContext {
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.light;
}
