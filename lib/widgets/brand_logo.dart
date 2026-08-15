import 'package:flutter/material.dart';

/// Emblème de l'église : la colombe au rameau, l'anneau au nom complet, le
/// bandeau « Maison du Miracle ».
///
/// **Deux dessins, pas deux teintes.** L'emblème est une pièce bicolore qu'on ne
/// peut pas recolorer par code : la colombe est *évidée* dans le disque, la
/// teindre l'effacerait. Les deux variantes sont donc deux fichiers, la seconde
/// dérivée de la première par `tool/brand_logo_inverse.py` :
///
/// - [BrandLogo] — l'original. Structure indigo, disque **blanc plein**, textes
///   blancs. C'est la pièce telle qu'elle est imprimée.
/// - [BrandLogo.inverse] — la variante posée sur le **bleu de marque**.
///   Structure et tracé de la colombe en blanc, disque **évidé** (le fond de
///   l'écran s'y voit), textes dans le bleu primaire.
///
/// Aucune ne se pose sur n'importe quoi : l'inversée exige un fond soutenu (son
/// disque est transparent et ses textes bleus deviendraient illisibles sur du
/// clair), l'originale pose un disque blanc franc qui fait tache sur un fond
/// sombre dès qu'on la grandit.
class BrandLogo extends StatelessWidget {
  /// L'emblème d'origine — pour les fonds clairs.
  const BrandLogo({super.key, this.size = 160, this.opacity = 1})
      : _asset = _original;

  /// La variante inversée — pour le bleu de marque.
  const BrandLogo.inverse({super.key, this.size = 160, this.opacity = 1})
      : _asset = _inverse;

  /// Côté du carré dans lequel l'emblème s'inscrit. Il est très légèrement plus
  /// large que haut, `BoxFit.contain` le centre donc avec un filet de marge en
  /// haut et en bas.
  final double size;

  /// Opacité du dessin, pour l'effacer sans le retirer. Passe par `Image.opacity`
  /// et non par un `Opacity` autour : celui-ci ouvrirait un calque hors écran à
  /// chaque peinture, là où l'image sait teinter à la volée.
  final double opacity;

  final String _asset;

  static const String _original = 'assets/images/brand_logo.webp';
  static const String _inverse = 'assets/images/brand_logo_inverse.webp';

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      _asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      opacity: AlwaysStoppedAnimation(opacity),
      // Les fichiers font 1251 px de côté. Décodés à leur taille native pour
      // être peints à 96, ils occuperaient ~6 Mo de mémoire ; on les décode à la
      // taille d'affichage réelle.
      cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
      // Réduction d'un facteur ~13 sur un dessin au trait fin : sans cela
      // l'anneau et les plumes crénellent.
      filterQuality: FilterQuality.medium,
      // Décoratif, partout : l'anneau est illisible sous 120 px, et là où le nom
      // de l'église est écrit (« À propos »), le doubler le ferait annoncer deux
      // fois. Dans le menu latéral, où plus aucun texte ne l'accompagne, ce sont
      // les quatre entrées qui portent le sens — pas l'emblème.
      excludeFromSemantics: true,
    );
  }
}
