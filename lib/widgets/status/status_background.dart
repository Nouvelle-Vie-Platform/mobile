import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/status_palette.dart';

/// Fond d'un statut (onglet Annonces), empilé du fond vers l'avant :
///
/// 1. le **dégradé** dérivé de la couleur du statut — toujours présent : il
///    sert aussi de repli image et couvre le temps de chargement ;
/// 2. l'**image** de fond éventuelle, en `BoxFit.cover` ;
/// 3. le **voile** de lisibilité, plus dense en bas (là où vivent le texte et
///    la waveform) ;
/// 4. le [child].
///
/// Composant pur : il ne connaît ni le modèle `Announcement` ni le lecteur, il
/// ne reçoit que des primitives.
class StatusBackground extends StatelessWidget {
  const StatusBackground({
    super.key,
    required this.id,
    this.backgroundColor,
    this.imageUrl,
    this.scrim = true,
    required this.child,
  });

  /// Identifiant du statut : sert au choix **déterministe** de la couleur de
  /// repli (voir `statusBaseColor`).
  final String id;

  /// Couleur envoyée par le back, prioritaire sur la palette de marque.
  final int? backgroundColor;

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

  /// Couleur de texte à poser sur ce fond.
  ///
  /// En présence d'une image le texte est **toujours clair** : c'est le voile
  /// qui garantit alors la lisibilité, quelle que soit la couleur de base.
  static Color foregroundFor(
    String id, {
    int? backgroundColor,
    String? imageUrl,
  }) {
    if (imageUrl != null) return AppColors.textOnPrimary;
    return statusForegroundOn(
      statusBaseColor(id, backgroundColor: backgroundColor),
    );
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
    final base = statusBaseColor(id, backgroundColor: backgroundColor);
    final url = imageUrl;

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        DecoratedBox(decoration: BoxDecoration(gradient: statusGradient(base))),
        if (url != null) _buildImage(url),
        if (scrim)
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: scrimGradient(
                foregroundFor(
                  id,
                  backgroundColor: backgroundColor,
                  imageUrl: imageUrl,
                ),
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
