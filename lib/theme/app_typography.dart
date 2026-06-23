import 'package:flutter/material.dart';

/// Échelle typographique du système de design, basée sur la police embarquée
/// **Atkinson Hyperlegible** (« Highly legible sans-serif » de la charte).
///
/// La famille fournit deux graisses réelles (Regular 400, Bold 700) ; les
/// graisses intermédiaires (medium/semibold) sont résolues vers la plus proche
/// par Flutter. Les styles sont **structurels** (sans couleur) : le texte
/// hérite de `onSurface` via le thème, ce qui le rend adaptatif clair/sombre.
///
/// H1 32/40 Bold · H2 24/32 SemiBold · H3 20/28 SemiBold
/// H4 18/24 Medium · H5 16/24 Medium · Corps 14 · Légende 12.
abstract final class AppTypography {
  /// Nom de famille déclaré dans `pubspec.yaml`.
  static const String fontFamily = 'Atkinson Hyperlegible';

  static TextStyle _base(double size, FontWeight weight, double lineHeight) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: size,
      fontWeight: weight,
      height: lineHeight / size,
    );
  }

  static TextStyle get h1 => _base(32, FontWeight.w700, 40);
  static TextStyle get h2 => _base(24, FontWeight.w600, 32);
  static TextStyle get h3 => _base(20, FontWeight.w600, 28);
  static TextStyle get h4 => _base(18, FontWeight.w500, 24);
  static TextStyle get h5 => _base(16, FontWeight.w500, 24);

  static TextStyle get bodyLarge => _base(16, FontWeight.w400, 24);
  static TextStyle get body => _base(14, FontWeight.w400, 20);
  static TextStyle get bodyStrong => _base(14, FontWeight.w600, 20);
  static TextStyle get caption => _base(12, FontWeight.w500, 16);
  static TextStyle get button => _base(15, FontWeight.w600, 20);

  /// Construit le [TextTheme] Material coloré pour la luminosité donnée.
  static TextTheme textTheme(Color onSurface) {
    final t = TextTheme(
      displayLarge: h1,
      headlineMedium: h2,
      headlineSmall: h3,
      titleLarge: h4,
      titleMedium: h5,
      bodyLarge: bodyLarge,
      bodyMedium: body,
      labelLarge: button,
      bodySmall: caption,
    );
    return t.apply(
      fontFamily: fontFamily,
      bodyColor: onSurface,
      displayColor: onSurface,
    );
  }
}
