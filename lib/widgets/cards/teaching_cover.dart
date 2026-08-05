import 'package:flutter/material.dart';

import '../../models/mediatheque_view.dart';
import '../../theme/app_spacing.dart';

/// Orientation du visuel demandé — le back en sert **un par ratio**, recadré à
/// la main dans le portail : on choisit, on ne recadre pas.
enum CoverOrientation {
  /// Bandeau large : mise en avant, en-tête de détail.
  landscape,

  /// Vignette haute : carrousels et listes.
  portrait,
}

/// Visuel d'un enseignement : image d'habillage (réseau) avec **repli coloré**
/// (la couleur de l'enseignement) si l'image est absente, hors-ligne ou en test.
///
/// Le repli n'est pas un pis-aller : en connectivité limitée, c'est ce que
/// verront la plupart des membres.
///
/// Partagé par l'accueil et la médiathèque pour un rendu cohérent.
class TeachingCover extends StatelessWidget {
  const TeachingCover({
    super.key,
    required this.teaching,
    this.radius = AppRadius.lg,
    this.orientation = CoverOrientation.portrait,
  });

  /// **Le modèle de lecture, pas la ligne.** Ses deux URL sont déjà absolues
  /// et sa couleur déjà résolue : ce widget n'applique plus aucune règle, il
  /// choisit un cadrage et dessine.
  final TeachingView teaching;
  final double radius;

  /// Ratio voulu. Si le visuel correspondant manque, l'autre prend le relais
  /// plutôt que d'afficher la couleur seule — une image mal cadrée reste plus
  /// informative qu'un aplat.
  final CoverOrientation orientation;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: Color(teaching.color),
      child: const Center(
        child: Icon(Icons.headphones_rounded, color: Colors.white70, size: 30),
      ),
    );

    // La résolution des chemins relatifs a déjà eu lieu, une fois, dans le
    // modèle de lecture — ici on ne fait que choisir le cadrage.
    final image = orientation == CoverOrientation.landscape
        ? teaching.landscapeOrPortrait
        : teaching.portraitOrLandscape;
    final Widget content = image == null
        ? fallback
        : Image.network(
            image,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => fallback,
            loadingBuilder: (_, child, progress) =>
                progress == null ? child : fallback,
          );

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox.expand(child: content),
    );
  }
}
