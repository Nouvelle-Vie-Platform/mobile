import 'package:flutter/material.dart';

/// Palette de couleurs de la charte « Maison du Miracle ».
///
/// Source : système de design fourni (palette, alertes, chips).
abstract final class AppColors {
  // --- Palette principale ---------------------------------------------------
  static const Color primary = Color(0xFF223B8C); // Bleu primaire
  static const Color secondary = Color(0xFF00A693); // Vert/teal secondaire
  static const Color accent = Color(0xFFF8D05E); // Jaune accent

  // --- Neutres --------------------------------------------------------------
  static const Color neutralLight = Color(0xFFFFFFFF); // Neutre clair
  static const Color neutralMedium = Color(0xFFF0F0F0); // Neutre moyen
  static const Color neutralDark = Color(0xFF1A1A1A); // Neutre foncé

  // --- Texte ----------------------------------------------------------------
  static const Color textPrimary = neutralDark;
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // --- Surfaces & bordures --------------------------------------------------
  static const Color background = Color(0xFFF7F8FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE5E7EB);
  static const Color divider = Color(0xFFEDEFF2);

  // --- États / alertes ------------------------------------------------------
  static const Color success = Color(0xFF1FA971);
  static const Color successBg = Color(0xFFE9F7F0);
  static const Color info = primary;
  static const Color infoBg = Color(0xFFE9EEF8);
  static const Color warning = Color(0xFFE6A100);
  static const Color warningBg = Color(0xFFFDF6E3);
  static const Color danger = Color(0xFFE53935);
  static const Color dangerBg = Color(0xFFFDECEC);

  // --- Chips / badges -------------------------------------------------------
  static const Color chipUrgent = danger;
  static const Color chipUrgentBg = Color(0xFFFDECEC);
  static const Color chipEvent = Color(0xFFE6A100);
  static const Color chipEventBg = Color(0xFFFDF6E3);
  static const Color chipNew = success;
  static const Color chipNewBg = Color(0xFFE9F7F0);

  // --- Dégradés -------------------------------------------------------------
  static const LinearGradient gradientPrimary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2A4AA8), Color(0xFF1B2E6E)],
  );

  static const LinearGradient gradientSecondary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF12BCA6), Color(0xFF008C7C)],
  );
}
