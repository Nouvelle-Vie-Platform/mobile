import 'package:flutter/widgets.dart';

/// **La mise en page qu'une rubrique demande pour sa section d'accueil.**
///
/// C'est le serveur qui la choisit, champ par champ du référentiel
/// `teaching_types` : un administrateur crée une rubrique, la place
/// (`position`), choisit sa forme (`layout`) — et l'application suit, sans
/// livraison. Rien de tout cela n'est décidé ici.
///
/// La valeur voyage en **chaîne libre**, jamais en enum côté donnée : le
/// référentiel est administrable et le portail peut servir demain une forme que
/// cette version n'a jamais vue. L'enum n'existe donc qu'**à l'affichage**, le
/// temps de choisir un dessin, et [HomeSectionLayout.of] replie tout le reste.
enum HomeSectionLayout {
  /// **Mise en avant** : étagère de grandes cartes paysage
  /// ([kHeroCoverSize], 320 × 188), titre et intervenant posés sur le visuel.
  hero,

  /// **Étagère compacte** : vignette portrait ([kCarouselCoverSize],
  /// 104 × 172) et texte à côté.
  carousel,

  /// **Liste verticale** de lignes basses, plafonnée à
  /// [kHomeSectionListLimit].
  list;

  /// Forme servie quand le serveur n'en nomme aucune, ou en nomme une que ce
  /// binaire ne connaît pas.
  ///
  /// [carousel] et non [list] : le repli doit rendre **tous** les
  /// enseignements de la rubrique (ce qui écarte [hero], qui met en avant) et
  /// tenir une hauteur bornée quel qu'en soit le nombre (ce qui écarte
  /// [list], qu'une rubrique de quarante contenus ferait déborder de l'accueil
  /// jusqu'à en chasser les sections suivantes).
  static const HomeSectionLayout fallback = HomeSectionLayout.carousel;

  /// Traduit la chaîne servie par le référentiel en forme dessinable.
  ///
  /// Une valeur inconnue **n'est pas une erreur** : c'est un référentiel plus
  /// récent que l'application. Elle se replie en silence, la rubrique reste à
  /// l'accueil, et la mise à jour de l'app apportera son dessin.
  static HomeSectionLayout of(String? raw) =>
      switch (raw?.trim().toLowerCase()) {
        'hero' => HomeSectionLayout.hero,
        'carousel' => HomeSectionLayout.carousel,
        'list' => HomeSectionLayout.list,
        _ => fallback,
      };
}

/// Cadre du visuel d'une carte de mise en avant — **paysage**.
///
/// Ce ratio et celui de [kCarouselCoverSize] sont **opposés exprès** : le même
/// enseignement est rendu aux deux, tous deux en `BoxFit.cover`. C'est pour
/// cela que le serveur sert **deux** URL d'image par enseignement, recadrées à
/// la main dans le portail — un seul visuel recadré par la machine perdrait
/// systématiquement le sujet dans l'un des deux cadres.
const Size kHeroCoverSize = Size(320, 188);

/// Cadre du visuel d'une vignette d'étagère — **portrait**. Voir
/// [kHeroCoverSize] pour la raison des deux ratios.
const Size kCarouselCoverSize = Size(104, 172);

/// Cadre du visuel d'une ligne de liste : le **même ratio portrait** que
/// [kCarouselCoverSize], en plus petit. La liste n'introduit pas un troisième
/// recadrage — il n'y a que deux images.
const Size kListCoverSize = Size(48, 80);

/// Nombre de lignes qu'une section `list` montre au plus.
///
/// L'accueil est une vitrine, pas la médiathèque : une liste verticale non
/// bornée pousserait les sections suivantes hors de portée du pouce. Les
/// étagères horizontales n'ont pas besoin de ce plafond, leur hauteur ne dépend
/// pas du nombre d'éléments.
const int kHomeSectionListLimit = 5;
