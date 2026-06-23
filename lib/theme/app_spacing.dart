import 'package:flutter/widgets.dart';

/// Échelle d'espacement et de rayons issue de la section « Espacements »
/// du système de design.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  /// Marge horizontale standard des écrans.
  static const EdgeInsets screenPadding = EdgeInsets.symmetric(horizontal: lg);
}

/// Rayons d'arrondi standards.
abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double pill = 999;

  static const BorderRadius card = BorderRadius.all(Radius.circular(md));
  static const BorderRadius button = BorderRadius.all(Radius.circular(md));
  static const BorderRadius field = BorderRadius.all(Radius.circular(md));
}

/// Ombres réutilisables (section « Ombres » du design).
abstract final class AppShadows {
  static const List<BoxShadow> elevation1 = [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> elevation2 = [
    BoxShadow(
      color: Color(0x1F000000),
      blurRadius: 24,
      offset: Offset(0, 10),
    ),
  ];
}
