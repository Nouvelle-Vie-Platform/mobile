/// **La réponse aux grands écrans** — points de rupture, largeur de lecture, et
/// borne de l'échelle de texte.
///
/// L'application se dessine en pixels **logiques** : une marge de 16 dp vaut
/// 16 dp sur un téléphone comme sur une tablette. C'est ce qui fait qu'un même
/// écran a la même échelle partout — et c'est aussi ce qui fait que, sur un
/// écran large, une colonne de texte s'étire jusqu'à devenir illisible. Ces
/// quelques constantes et un widget servent à ça, et à rien d'autre.
library;

import 'package:flutter/widgets.dart';

/// Points de rupture, en **largeur logique** (dp) — les « window size classes »
/// de Material 3.
abstract final class AppBreakpoints {
  /// < 600 dp : téléphone en portrait. Le gabarit pour lequel l'application est
  /// dessinée, et celui de tous les appareils visés.
  static const double compact = 600;

  /// 600–840 dp : tablette en portrait, ou téléphone en paysage.
  static const double medium = 840;

  /// ≥ 840 dp : grande tablette ou ordinateur.
  static const double expanded = 840;

  /// Largeur maximale de **lecture** du contenu sur grand écran.
  ///
  /// Au-delà, le contenu est **centré** avec des marges plutôt qu'étiré : des
  /// lignes larges de 1200 dp sont pénibles à suivre.
  ///
  /// ⚠️ **840 et non 600, et ce n'est pas un hasard.** Sur un téléphone (≤ 430
  /// dp) la contrainte est inerte, et elle ne mord qu'au-delà du seuil « grand
  /// écran ». C'est aussi ce qui laisse les **tests d'écran strictement
  /// inchangés** : leur largeur logique reste sous ce seuil (le plus souvent
  /// 800 × 600), donc [ContentMaxWidth] n'ajoute aucune marge.
  static const double contentMaxWidth = 840;
}

/// Plafond de l'**échelle de texte système**.
///
/// Le texte suit le réglage d'accessibilité de la personne, et c'est voulu. Mais
/// au-delà de ~1.3, des mises en page écrites pour 1.0 débordent (lignes
/// coupées, boutons qui se chevauchent). On borne donc **le haut**, sans
/// descendre sous 1.0 : l'application reste lisible sur tous les appareils, au
/// prix d'un réglage extrême ignoré.
const double kMaxTextScale = 1.3;

/// **Le conteneur de lecture** : borne la largeur du contenu et le centre.
///
/// Inerte tant que la largeur disponible reste sous
/// [AppBreakpoints.contentMaxWidth] — donc sur **tous les téléphones** : le
/// widget rend alors son enfant tel quel, contraintes identiques, sans une
/// image de diff. Au-delà, il ajoute des marges latérales égales pour garder le
/// contenu centré et lisible.
///
/// Il **conserve la hauteur** — contrairement à un `Center` posé dans une pile,
/// qui relâcherait les contraintes verticales : il ne touche qu'aux marges
/// **horizontales**, le long d'un [LayoutBuilder].
class ContentMaxWidth extends StatelessWidget {
  const ContentMaxWidth({
    super.key,
    required this.child,
    this.maxWidth = AppBreakpoints.contentMaxWidth,
  });

  final Widget child;

  /// Largeur maximale tolérée. Paramétrable pour les tests et les surfaces
  /// spéciales ; la valeur par défaut est la largeur de lecture retenue.
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= maxWidth) return child;
        final side = (constraints.maxWidth - maxWidth) / 2;
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: side),
          child: child,
        );
      },
    );
  }
}
