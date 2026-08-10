import 'package:flutter/material.dart';

import '../../models/content_view.dart';
import '../../theme/app_spacing.dart';

/// Orientation du visuel demandé — le back en sert **un par ratio**, recadré à
/// la main dans le portail : on choisit, on ne recadre pas.
enum CoverOrientation {
  /// Bandeau large : mise en avant, en-tête de détail.
  landscape,

  /// Vignette haute : carrousels et listes.
  portrait,
}

/// Visuel d'un **contenu de médiathèque** — enseignement ou rassemblement :
/// image d'habillage (réseau) avec **repli coloré** si l'image est absente,
/// hors-ligne ou en test.
///
/// Il prend un [ContentView] et non l'un des deux types concrets, et c'est le
/// **seul partage qui ait un sens ici** : les deux familles servent deux URL
/// recadrées à la main et une couleur de repli, et ce widget ne fait rien
/// d'autre que choisir un cadrage et dessiner. Le distinguer par famille aurait
/// donné deux copies d'un `Image.network` avec repli — deux occasions d'oublier
/// l'`errorBuilder`, dont l'absence casse aussi bien le hors-ligne que
/// `flutter test`.
///
/// Le repli n'est pas un pis-aller : en connectivité limitée, c'est ce que
/// verront la plupart des membres.
class ContentCover extends StatelessWidget {
  const ContentCover({
    super.key,
    required this.content,
    this.radius = AppRadius.lg,
    this.orientation = CoverOrientation.portrait,
  });

  /// **Le modèle de lecture, pas la ligne.** Ses deux URL sont déjà absolues
  /// et sa couleur déjà résolue : ce widget n'applique plus aucune règle.
  final ContentView content;
  final double radius;

  /// Ratio voulu. Si le visuel correspondant manque, l'autre prend le relais
  /// plutôt que d'afficher la couleur seule — une image mal cadrée reste plus
  /// informative qu'un aplat.
  final CoverOrientation orientation;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: Color(content.color),
      child: const Center(
        child: Icon(Icons.headphones_rounded, color: Colors.white70, size: 30),
      ),
    );

    // La résolution des chemins relatifs a déjà eu lieu, une fois, dans le
    // modèle de lecture — ici on ne fait que choisir le cadrage.
    final image = orientation == CoverOrientation.landscape
        ? content.landscapeOrPortrait
        : content.portraitOrLandscape;
    final Widget child = image == null
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
      child: SizedBox.expand(child: child),
    );
  }
}
