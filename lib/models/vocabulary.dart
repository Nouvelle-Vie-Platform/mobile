/// **Le vocabulaire réglé au portail**, tel que le magasin le rend (#81).
///
/// Deux cartes, et rien d'autre : les **surcharges de libellé** indexées par
/// clé de dictionnaire, et les **termes** indexés par leur slug. Les valeurs
/// sont des cartes de traduction **entières** — le choix de la langue se fait à
/// la lecture, par `pick`, et à un seul endroit (`l10n/vocabulary.dart`).
///
/// Ce n'est pas un repli de contenu : `LocalizedText` / `parseI18nMap` portent
/// le titre d'une rubrique ou le nom d'un compte officiel. Ici il s'agit de
/// l'**interface**, et la surcharge recouvre le `.arb` compilé dans le binaire.
library;

import 'package:flutter/foundation.dart';

/// Un **terme** : un mot métier et ses deux formes, écrites à la main au
/// portail. Aucun accord n'est calculé, ni ici ni ailleurs.
///
/// Les deux cartes sont nullables **séparément** : le portail peut avoir réglé
/// le singulier sans le pluriel, et `null` veut dire « garde le mot du dépôt »
/// pour cette forme-là seulement.
@immutable
class VocabularyTerm {
  const VocabularyTerm({this.singular, this.plural});

  /// Carte de traduction du singulier, ou `null` = le mot du dépôt.
  final Map<String, String>? singular;

  /// Carte de traduction du pluriel, ou `null` = le mot du dépôt.
  final Map<String, String>? plural;

  @override
  bool operator ==(Object other) =>
      other is VocabularyTerm &&
      mapEquals(other.singular, singular) &&
      mapEquals(other.plural, plural);

  @override
  int get hashCode => Object.hash(
        Object.hashAllUnordered(singular?.keys ?? const <String>[]),
        Object.hashAllUnordered(plural?.keys ?? const <String>[]),
      );
}

/// **Ce que le portail surcharge**, et rien de plus.
///
/// Une collection vide — [empty] — est l'état **légitime** d'une application
/// qui n'a pas encore synchronisé, et celui d'un parc dont le serveur est en
/// retard d'une version (un `404` saute la collection). Dans les deux cas
/// l'écran montre ce que le binaire a compilé, ce qui est exactement ce qu'on
/// veut.
@immutable
class VocabularyOverrides {
  const VocabularyOverrides({
    this.labels = const {},
    this.terms = const {},
  });

  /// Aucune surcharge : le `.arb` fait foi partout.
  static const VocabularyOverrides empty = VocabularyOverrides();

  /// Clé de dictionnaire → carte de traduction de la surcharge.
  ///
  /// Une clé **absente** de cette carte et une clé dont la surcharge est vide
  /// disent la même chose : garde le mot du dépôt. C'est la résolution qui le
  /// tranche, jamais l'appelant.
  final Map<String, Map<String, String>> labels;

  /// Slug de terme (`teaching`, `gathering`…) → ses deux formes.
  final Map<String, VocabularyTerm> terms;

  bool get isEmpty => labels.isEmpty && terms.isEmpty;

  /// Égalité **profonde** : les valeurs de [labels] sont elles-mêmes des
  /// cartes, et `Map` n'a pas d'égalité de valeur en Dart. Une comparaison
  /// superficielle rendrait « différent » deux vocabulaires identiques — donc
  /// une reconstruction d'arbre à chaque cycle de synchronisation, pour rien.
  @override
  bool operator ==(Object other) =>
      other is VocabularyOverrides &&
      mapEquals(other.terms, terms) &&
      other.labels.length == labels.length &&
      labels.keys.every((key) => mapEquals(other.labels[key], labels[key]));

  @override
  int get hashCode => Object.hash(
        Object.hashAllUnordered(labels.keys),
        Object.hashAllUnordered(terms.keys),
      );
}
