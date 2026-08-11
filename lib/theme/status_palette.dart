import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../utils/stable_hash.dart';
import 'app_colors.dart';

/// **Le repli d'habillage d'un statut, et rien d'autre.**
///
/// Ce fichier a changé de rôle avec la refonte des annonces (issue #35).
/// L'habillage d'un statut est désormais **servi** : le référentiel
/// `status_backgrounds` porte trois arrêts de dégradé et une encre, tous dérivés
/// par le serveur à l'écriture (ADR-0030), et le rendu ne fait que peindre. La
/// palette fermée de cinq teintes qui vivait ici a donc disparu : une palette
/// dans le binaire est une décision figée à la livraison, alors qu'un fond
/// s'ajoute désormais depuis le portail, sans mise à jour de l'application.
///
/// Ce qui reste sert au **seul** cas où le magasin n'a rien à peindre : aucun
/// fond choisi, ou fond pas encore synchronisé. Les trois règles du cahier des
/// charges (§8 « Fonds ») valent alors, et elles seules :
///
/// * **Déterminisme** — la teinte est choisie par *hash stable* de l'`id` du
///   statut. Jamais `Random()` : la même annonce doit garder la même couleur
///   d'un `build` à l'autre, d'une session à l'autre et d'une plateforme à
///   l'autre.
/// * **Dégradés, pas d'aplats** — toute l'application est construite sur des
///   dégradés et du verre dépoli ; un aplat détonnerait.
/// * **Contraste garanti** — sur un or pâle, un texte blanc devient illisible et
///   personne ne s'en apercevra avant les utilisateurs. La luminance décide donc
///   d'un texte clair ou sombre. **Cette déduction ne s'applique qu'au repli** :
///   quand le serveur sert un fond, c'est lui qui a tranché l'encre.

/// Teintes du **repli**, toutes issues d'[AppColors].
///
/// Privée, et c'est le point : ce n'est plus « la palette des statuts », c'est
/// ce qu'on peint faute de mieux. Rien hors de ce fichier n'a de raison d'y
/// puiser — un écran qui la lirait recommencerait à choisir des couleurs dans le
/// binaire.
final List<Color> _fallbackTints = List<Color>.unmodifiable(<Color>[
  AppColors.primary, // 0xFF223B8C — bleu de marque
  AppColors.gradientPrimary.colors.last, // 0xFF1B2E6E — bleu profond
  AppColors.secondary, // 0xFF00A693 — teal secondaire
  AppColors.accent, // 0xFFF8D05E — or accent (⇒ texte sombre)
  AppColors.gradientAppDark.colors.first, // 0xFF0C1422 — nuit profonde
]);

/// Teinte de repli d'un statut, choisie déterministement d'après [id].
///
/// N'est appelée **que** lorsque aucun fond n'est servi : le rendu d'un statut
/// habillé lit `StatusBackdrop`, il ne passe jamais par ici.
Color statusBaseColor(String id) =>
    _fallbackTints[stableHash(id) % _fallbackTints.length];

/// Dégradé de fond dérivé de [base] : légèrement éclairci en haut à gauche,
/// assombri en bas à droite, la teinte d'origine au milieu.
///
/// **Réservé au repli.** Un fond servi porte déjà ses trois arrêts : les
/// recalculer à partir de sa teinte de base rendrait deux dégradés différents
/// pour la même annonce selon la version installée.
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
/// **Réservé au repli** : quand un fond est servi, l'encre vient du serveur
/// (`StatusBackdrop.ink`) et n'est pas déduite ici.
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

double _clamp01(double value) => value.clamp(0.0, 1.0);
