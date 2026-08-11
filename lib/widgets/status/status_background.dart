import 'package:flutter/material.dart';

import '../../models/announcement_view.dart';
import '../../theme/app_colors.dart';
import '../../theme/status_palette.dart';

/// Fond d'un statut (onglet Annonces), empilé du fond vers l'avant :
///
/// 1. le **dégradé** du statut — toujours présent : il sert aussi de repli
///    image et couvre le temps de chargement ;
/// 2. l'**image** de fond éventuelle, en `BoxFit.cover` ;
/// 3. le **voile** de lisibilité, plus dense en bas (là où vivent le texte et
///    la waveform) ;
/// 4. le [child].
///
/// **C'est ici, et nulle part ailleurs, que se décide « fond servi ou repli ».**
/// Les deux statiques [gradientFor] et [foregroundFor] portent cette bascule
/// pour tout ce qui peint un statut — la visionneuse, les vignettes de la
/// feuille, la barre de segments. Dupliquer la règle donnerait deux fonds
/// différents pour la même annonce selon l'endroit où on la regarde.
class StatusBackground extends StatelessWidget {
  const StatusBackground({
    super.key,
    required this.id,
    this.backdrop,
    this.imageUrl,
    this.scrim = true,
    required this.child,
  });

  /// Identifiant du statut : sert au choix **déterministe** de la teinte de
  /// repli (voir `statusBaseColor`).
  final String id;

  /// Fond **servi** par le référentiel, ou `null`.
  ///
  /// Ses trois arrêts et son encre ont été dérivés par le serveur à l'écriture
  /// (ADR-0030) : le widget les peint, il ne les recalcule pas.
  final StatusBackdrop? backdrop;

  /// Image de fond éventuelle. Un échec (hors-ligne, 404, ou test — le réseau
  /// renvoie 400 sous `flutter test`) retombe silencieusement sur le dégradé.
  final String? imageUrl;

  /// Voile sombre de lisibilité derrière le contenu.
  final bool scrim;

  final Widget child;

  /// Clé du repli affiché quand l'image de fond échoue. Exposée pour les tests,
  /// qui doivent pouvoir prouver que le chemin `errorBuilder` s'exécute.
  @visibleForTesting
  static const Key imageErrorKey = Key('status-background-image-error');

  /// Durée du fondu à l'apparition de l'image. Bornée : un `pumpAndSettle`
  /// doit pouvoir se terminer.
  static const Duration fadeDuration = Duration(milliseconds: 240);

  /// **Le dégradé du statut : celui qu'on a servi, ou celui qu'on déduit.**
  ///
  /// Avec un [backdrop], les trois arrêts partent tels quels — le serveur les a
  /// dérivés à l'écriture et le client ne refait pas ce calcul. Sans lui, la
  /// teinte vient du hash de l'[id] et le dégradé s'en déduit : c'est le seul
  /// endroit de l'application où une variation de couleur se calcule encore.
  static LinearGradient gradientFor(String id, StatusBackdrop? backdrop) {
    if (backdrop == null) return statusGradient(statusBaseColor(id));
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[
        Color(backdrop.topColor),
        Color(backdrop.baseColor),
        Color(backdrop.bottomColor),
      ],
    );
  }

  /// Couleur de texte à poser sur ce fond.
  ///
  /// Trois cas, dans cet ordre :
  /// - en présence d'une **image**, le texte est toujours clair : c'est le voile
  ///   qui garantit alors la lisibilité, quelle que soit la couleur dessous ;
  /// - avec un [backdrop], l'encre vient du **serveur** (ADR-0030). La déduire
  ///   de la luminance serait refaire un calcul déjà fait, et le refaire
  ///   différemment un jour ;
  /// - sans fond servi, la luminance de la teinte de repli tranche.
  static Color foregroundFor(
    String id, {
    StatusBackdrop? backdrop,
    String? imageUrl,
  }) {
    if (imageUrl != null) return AppColors.textOnPrimary;
    if (backdrop != null) {
      return backdrop.ink == StatusInk.light
          ? AppColors.textOnPrimary
          : AppColors.textPrimary;
    }
    return statusForegroundOn(statusBaseColor(id));
  }

  /// Voile dégradé : discret en haut (l'en-tête auteur y vit), transparent au
  /// milieu, franchement dense en bas.
  ///
  /// Sa teinte suit le texte, pas l'inverse : un voile noir sous un texte
  /// **sombre** (fond clair) détruirait le contraste au lieu de le renforcer —
  /// on assombrit derrière un texte clair, on éclaircit derrière un texte
  /// sombre.
  static LinearGradient scrimGradient(Color foreground) {
    final tint =
        ThemeData.estimateBrightnessForColor(foreground) == Brightness.light
            ? Colors.black
            : Colors.white;
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[
        tint.withValues(alpha: 0.28),
        tint.withValues(alpha: 0.0),
        tint.withValues(alpha: 0.45),
        tint.withValues(alpha: 0.72),
      ],
      stops: const <double>[0.0, 0.32, 0.74, 1.0],
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(gradient: gradientFor(id, backdrop)),
        ),
        if (url != null) _buildImage(url),
        if (scrim)
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: scrimGradient(
                foregroundFor(id, backdrop: backdrop, imageUrl: imageUrl),
              ),
            ),
          ),
        child,
      ],
    );
  }

  Widget _buildImage(String url) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      // Règle impérative du CLAUDE.md : sans `errorBuilder`, l'écran casse
      // hors-ligne *et* en test. Le repli est le dégradé déjà peint dessous.
      errorBuilder: (_, __, ___) =>
          const SizedBox.shrink(key: StatusBackground.imageErrorKey),
      frameBuilder: (_, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0.0 : 1.0,
          duration: fadeDuration,
          curve: Curves.easeOut,
          child: child,
        );
      },
    );
  }
}
