/// **Le modèle de lecture des menus** — ce qu'un écran affiche d'une entrée de
/// menu, et rien de plus (#82).
///
/// Décision 3 d'ADR-0026 : *le magasin stocke ce que le serveur envoie ; la
/// présentation se calcule à la lecture*. Les lignes de `menu_entries` arrivent
/// donc entières — éteintes comprises, hors fenêtre comprises, destinations
/// inconnues comprises — et c'est ici que trois choses se décident :
///
/// 1. **la destination se résout**, ou l'entrée disparaît ;
/// 2. **la fenêtre de publication s'évalue**, à `DateTime.now()` ;
/// 3. **le libellé se replie**, par `pick` et lui seul.
///
/// ## Vocabulaire — à respecter à la lettre
///
/// **Entrée de menu**, jamais « onglet » : l'onglet est le *rendu* d'une entrée
/// sur une surface. Une même entrée paraît dans la médiathèque et à l'accueil,
/// sous deux gabarits.
///
/// **Destination** : l'intention servie par le portail, lue en **chaîne libre**
/// et jamais en énumération de donnée. L'énumération [MenuDestination] n'existe
/// qu'**une fois la chaîne traduite** — et une chaîne qu'elle ne sait pas
/// traduire ne se replie sur rien.
///
/// **Rubrique** : la taxonomie (nom, slug, couleur, icône). Elle ne décide plus
/// de l'agencement d'un écran.
library;

import 'package:flutter/foundation.dart';

import '../utils/i18n_text.dart';

/// **Les deux surfaces mobiles**, et leurs clés de protocole.
///
/// Les clés voyagent depuis le portail (`MENU_SURFACES`) et ne se renomment plus
/// (ADR-0017/0024). Les deux surfaces du site — `site_header`, `site_footer` —
/// n'existent pas ici : leurs colonnes ne descendent même pas.
enum MenuSurface {
  /// La barre d'onglets de la médiathèque.
  mediaLibrary('mobile_media'),

  /// Les sections de l'accueil, chacune sous son gabarit.
  home('mobile_home');

  const MenuSurface(this.key);

  /// La clé du portail, pour les messages et les tests.
  final String key;
}

/// **La famille de contenu qu'une destination de catalogue désigne** — donc
/// *quelle collection lire*.
///
/// Ce n'est pas une étiquette portée par une ligne de contenu : ADR-0026
/// décision 1 l'interdit, et le serveur ne sert toujours pas
/// `teachings.family`. C'est une part de l'**intention** de l'entrée, et c'est
/// ce qui apprend au client par quel canal remplir son onglet. Elle sert le tri
/// par canal, elle ne le remplace pas.
enum MenuContentFamily {
  teaching('teaching'),
  gathering('gathering');

  const MenuContentFamily(this.key);

  final String key;

  /// La chaîne servie, traduite. `null` quand ce binaire ne la connaît pas —
  /// l'entrée disparaît alors, elle ne se replie pas sur l'autre famille (un
  /// concert rendu dans l'écran d'un message serait pire qu'une entrée absente).
  static MenuContentFamily? of(String? raw) =>
      switch (raw?.trim().toLowerCase()) {
        'teaching' => MenuContentFamily.teaching,
        'gathering' => MenuContentFamily.gathering,
        _ => null,
      };
}

/// **Ce que l'entrée demande d'afficher**, une fois la chaîne libre traduite.
///
/// Deux formes seulement, parce que ce client ne sait faire que deux choses
/// d'une entrée : peindre une liste de contenus, ou ouvrir le navigateur du
/// système. Les trois autres types du catalogue serveur — `theme`,
/// `intervenant`, et les pages du site autres que la médiathèque — **n'ont pas
/// d'écran ici**, et c'est leur absence de forme qui fait disparaître l'entrée.
@immutable
sealed class MenuDestination {
  const MenuDestination();
}

/// **Une liste de contenus**, bornée par ce que l'entrée a demandé.
///
/// C'est aussi ce qu'est l'entrée indélébile de la médiathèque
/// (`page: mediatheque`, garde-fou 2 du cadrage) : le catalogue entier, famille
/// enseignement, sans rubrique ni recherche. Elle n'a pas de forme à elle — un
/// « tout » est un catalogue dont aucune borne n'est posée.
@immutable
class MenuCatalogue extends MenuDestination {
  const MenuCatalogue({
    required this.family,
    this.rubricId,
    this.rubricSlug,
    this.branchSlug,
    this.search,
  });

  /// Quelle collection lire.
  final MenuContentFamily family;

  /// L'identifiant local de la rubrique, **résolu depuis le slug** par le
  /// magasin. `null` = aucune rubrique demandée.
  ///
  /// ⚠️ Un slug **demandé et introuvable** ne donne pas `null` ici : il donne
  /// une destination qui ne ramène aucun contenu, donc une entrée que « pas de
  /// contenu, pas de section » retire. Les deux cas ne se confondent pas, et
  /// c'est [rubricSlug] qui les départage.
  final int? rubricId;

  /// Le slug demandé, tel que servi — `null` = le catalogue entier.
  final String? rubricSlug;

  /// Le slug de branche demandé, tel que servi.
  ///
  /// ⚠️ **Ce client ne sait pas le résoudre** : `BranchTransformer` ne sert pas
  /// de slug au flux delta, donc la copie locale de `branches` n'en porte aucun.
  /// Une entrée qui en exige un ne ramène rien, et disparaît — plutôt que de
  /// montrer le catalogue entier sous un nom de ville.
  final String? branchSlug;

  /// La recherche **figée par l'entrée**, à composer avec celle que la loupe
  /// saisit : l'entrée borne, le fidèle affine.
  final String? search;

  /// Avec la recherche du fidèle ajoutée à celle de l'entrée.
  MenuCatalogue withSearch(String? query) {
    final trimmed = query?.trim();
    if (trimmed == null || trimmed.isEmpty) return this;
    return MenuCatalogue(
      family: family,
      rubricId: rubricId,
      rubricSlug: rubricSlug,
      branchSlug: branchSlug,
      search: search == null || search!.isEmpty ? trimmed : '$search $trimmed',
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MenuCatalogue &&
      other.family == family &&
      other.rubricId == rubricId &&
      other.rubricSlug == rubricSlug &&
      other.branchSlug == branchSlug &&
      other.search == search;

  @override
  int get hashCode =>
      Object.hash(family, rubricId, rubricSlug, branchSlug, search);
}

/// **Une adresse hors du dépôt**, ouverte dans le navigateur du système — pour
/// les invités comme pour les membres.
///
/// Le seul type dont l'adresse est écrite à la main au portail, et le seul dont
/// le dépôt ne peut rien promettre : un fournisseur de dons, une chaîne vidéo.
/// Sans cette échappatoire, le besoin revenait par la fenêtre (décision 7).
@immutable
class MenuExternalLink extends MenuDestination {
  const MenuExternalLink(this.url);

  final String url;

  @override
  bool operator ==(Object other) =>
      other is MenuExternalLink && other.url == url;

  @override
  int get hashCode => url.hashCode;
}

/// **Une entrée de menu telle qu'un écran l'affiche.**
///
/// Tout y est déjà tranché : la destination est résolue, la fenêtre est
/// évaluée, le libellé est replié, les sous-entrées sont rangées sous leur
/// parent. Un écran qui en reçoit une n'a plus aucune règle à appliquer — donc
/// plus aucune occasion d'en appliquer une variante.
@immutable
class MenuEntryView {
  const MenuEntryView({
    required this.id,
    required this.label,
    required this.destination,
    this.labelKey,
    this.icon,
    this.featured = false,
    this.divided = false,
    this.layout,
    this.offersSearch = false,
    this.pageTitle = '',
    this.pageDescription = '',
    this.children = const [],
    this.itemCount = 0,
  });

  /// Applique les règles de présentation à une ligne de `menu_entries`.
  ///
  /// [label] est la **surcharge**, carte de traduction entière : `null` ou
  /// blanche veut dire « le libellé du dépôt », porté par [labelKey]. Les deux
  /// champs sont indissociables, et c'est la couche de présentation qui tranche
  /// — voir `l10n/menu_labels.dart`.
  MenuEntryView.resolve({
    required this.id,
    required this.destination,
    required String locale,
    Map<String, String>? label,
    this.labelKey,
    this.icon,
    this.featured = false,
    this.divided = false,
    this.layout,
    this.offersSearch = false,
    Map<String, String>? pageTitle,
    Map<String, String>? pageDescription,
    this.children = const [],
    this.itemCount = 0,
  })  : label = label == null ? '' : pick(label, locale).trim(),
        pageTitle = pageTitle == null ? '' : pick(pageTitle, locale).trim(),
        pageDescription =
            pageDescription == null ? '' : pick(pageDescription, locale).trim();

  /// SERIAL côté serveur. C'est la clé de rendu d'un onglet, et le seul moyen
  /// de rattacher une sous-entrée à son parent.
  final int id;

  /// Le libellé **surchargé**, déjà replié — chaîne vide quand le portail n'a
  /// rien réglé, c'est-à-dire « prends le libellé du dépôt ».
  final String label;

  /// La clé du dépôt, telle que servie. Elle n'est **pas** une clé `.arb` de ce
  /// dépôt : les entrées reprises portent les clés de la vitrine
  /// (`public.nav.*`). La traduction vit dans `l10n/menu_labels.dart`, qui est
  /// aussi l'endroit où une clé inconnue devient une absence de libellé.
  final String? labelKey;

  /// Ce que l'entrée demande d'afficher.
  final MenuDestination destination;

  /// Un nom d'icône du kit du portail, ou `null`. Le kit n'est pas celui de
  /// l'application : à l'affichage de faire ce qu'il peut d'un nom inconnu.
  final String? icon;

  /// La mise en avant et le filet, tels que réglés.
  final bool featured;
  final bool divided;

  /// Le gabarit de l'accueil (`hero` · `carousel` · `list`), **brut**. `null`
  /// hors de cette surface. Traduit en dessin par `HomeSectionLayout.of`, qui
  /// replie une forme inconnue au lieu de faire disparaître la section.
  final String? layout;

  /// L'entrée offre-t-elle la puce « recherche » ? C'est **le** lecteur que la
  /// case `filter_search` attendait : la loupe de la médiathèque.
  final bool offersSearch;

  /// Le lot éditorial de la page désignée, déjà replié. Chaîne vide = ce que
  /// l'écran compose déjà.
  final String pageTitle;
  final String pageDescription;

  /// Les sous-entrées, **un seul niveau**, dans leur ordre de surface. Elles se
  /// rendent en puces sous l'onglet.
  final List<MenuEntryView> children;

  /// Le nombre de contenus que la destination ramène du magasin.
  ///
  /// Toujours strictement positif pour une entrée rendue : c'est « pas de
  /// contenu, pas de section », et c'est ce qui répare la **suppression dure**
  /// côté serveur — la collection n'a pas de tombstone, une entrée retirée au
  /// portail cesse simplement de paraître au flux. Un lien externe porte `1` :
  /// son contenu est son adresse.
  final int itemCount;
}
