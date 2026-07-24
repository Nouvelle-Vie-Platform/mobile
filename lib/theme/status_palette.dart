import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Habillage des statuts (onglet Annonces) : couleur de base, dégradé de fond
/// et **garantie de contraste** du texte posé dessus.
///
/// Trois règles, tirées du cahier des charges (§8 « Fonds ») :
///
/// * **Déterminisme** — à défaut de couleur envoyée par le back, la teinte est
///   choisie par *hash stable* de l'`id` du statut. Jamais `Random()` : la même
///   annonce doit garder la même couleur d'un `build` à l'autre, d'une session
///   à l'autre et d'une plateforme à l'autre.
/// * **Dégradés, pas d'aplats** — toute l'application est construite sur des
///   dégradés et du verre dépoli ; un aplat détonnerait.
/// * **Contraste garanti** — si le back envoie un jaune pâle, un texte blanc
///   devient illisible et personne ne s'en apercevra avant les utilisateurs.
///   La luminance de la couleur décide donc d'un texte clair ou sombre.

/// Palette **fermée** des fonds de statut, toutes teintes issues d'[AppColors].
///
/// Cinq entrées harmonisées : les bleus de marque, le teal secondaire, l'or
/// accent et une nuit profonde. Non `const` car deux teintes sont lues dans les
/// dégradés d'[AppColors] plutôt que redéclarées en dur.
final List<Color> statusPalette = List<Color>.unmodifiable(<Color>[
  AppColors.primary, // 0xFF223B8C — bleu de marque
  AppColors.gradientPrimary.colors.last, // 0xFF1B2E6E — bleu profond
  AppColors.secondary, // 0xFF00A693 — teal secondaire
  AppColors.accent, // 0xFFF8D05E — or accent (⇒ texte sombre)
  AppColors.gradientAppDark.colors.first, // 0xFF0C1422 — nuit profonde
]);

/// Couleur de base d'un statut : celle du back si fournie, sinon une teinte de
/// [statusPalette] choisie déterministement d'après [id].
Color statusBaseColor(String id, {int? backgroundColor}) {
  if (backgroundColor != null) return Color(backgroundColor);
  return statusPalette[_stableHash(id) % statusPalette.length];
}

/// Dégradé de fond dérivé de [base] : légèrement éclairci en haut à gauche,
/// assombri en bas à droite, la teinte d'origine au milieu.
LinearGradient statusGradient(Color base) {
  final hsl = HSLColor.fromColor(base);
  final top = hsl
      .withLightness(_clamp01(hsl.lightness + 0.10))
      .withSaturation(_clamp01(hsl.saturation * 0.92))
      .toColor();
  final bottom = hsl
      .withLightness(_clamp01(hsl.lightness - 0.14))
      .withSaturation(_clamp01(hsl.saturation * 1.05))
      .toColor();

  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[top, base, bottom],
  );
}

/// Couleur de texte garantissant la lisibilité sur [base].
///
/// On compare le **rapport de contraste** (WCAG) obtenu avec l'encre claire et
/// avec l'encre sombre, tous deux calculés à partir des luminances relatives,
/// et on retient le meilleur. Le basculement se fait donc autour d'une
/// luminance de ~0,18 — et non de 0,5, seuil naïf qui laisserait du blanc sur
/// des ors et des ambres pourtant bien trop clairs pour ça.
Color statusForegroundOn(Color base) {
  final luminance = base.computeLuminance();
  final withLight = _contrastRatio(
    luminance,
    AppColors.textOnPrimary.computeLuminance(),
  );
  final withDark = _contrastRatio(
    luminance,
    AppColors.textPrimary.computeLuminance(),
  );
  return withLight >= withDark
      ? AppColors.textOnPrimary
      : AppColors.textPrimary;
}

/// Rapport de contraste WCAG entre deux luminances relatives.
double _contrastRatio(double a, double b) {
  final lighter = math.max(a, b);
  final darker = math.min(a, b);
  return (lighter + 0.05) / (darker + 0.05);
}

/// Hash FNV-1a 32 bits : stable dans le temps, entre sessions et entre
/// plateformes — contrairement à `String.hashCode`, dont la valeur n'est
/// garantie qu'à l'intérieur d'une même exécution.
int _stableHash(String value) {
  var hash = 0x811c9dc5;
  for (final unit in value.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash;
}

double _clamp01(double value) => value.clamp(0.0, 1.0);
