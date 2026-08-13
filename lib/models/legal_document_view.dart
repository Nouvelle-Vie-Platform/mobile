/// **Le modèle de lecture d'un document légal** — ce qu'un écran affiche d'une
/// CGU, d'une politique de confidentialité ou d'une présentation, et rien de
/// plus.
///
/// Comme partout ailleurs (ADR-0026, décision 3), le magasin stocke ce que le
/// serveur envoie — les sections **brutes**, chacune portant ses deux cartes de
/// traduction `{fr, en, ee}` — et la présentation se calcule à la lecture.
///
/// **Ce qui est particulier ici, et qui l'est seulement ici, est le repli de
/// langue** : il se fait sur le **document entier**, jamais champ par champ.
/// Voir [resolveLegalLocale] et ADR-0035.
library;

import 'package:flutter/foundation.dart';

import '../utils/i18n_text.dart' show kContentFallbackLocale, languageSubtag;

/// Les **trois genres de document légal**, tels que le serveur les sert
/// (`legal_document_kind.ts`). Fermé : ajouter un genre est une décision de
/// conception des deux côtés, pas une donnée d'administration.
abstract final class LegalDocumentKind {
  /// Conditions générales d'utilisation.
  static const String terms = 'cgu';

  /// Politique de confidentialité.
  static const String privacy = 'privacy';

  /// Présentation de l'église. **N'entre jamais dans la barrière
  /// d'acceptation** : accepter une présentation n'a pas de sens.
  static const String about = 'about';

  /// Les genres que la route de **consultation** `/legal/:kind` sert.
  /// « À propos » a la sienne (`/about`), parce que son écran ne se réduit pas
  /// au document servi.
  static const List<String> consultable = [terms, privacy];
}

/// Une **section brute**, telle que le serveur l'envoie et telle que le magasin
/// la stocke : une clé stable, et deux cartes de traduction **entières**.
///
/// L'ordre du tableau est l'ordre de **lecture** : un texte légal se lit en
/// séquence et ses articles se référencent. Le rang n'est pas une préférence
/// d'affichage, il fait partie du document.
///
/// Ce type ne s'affiche pas : il entre dans [resolveLegalLocale] et en ressort
/// replié, sous la forme d'une [LegalSectionView].
@immutable
class LegalSection {
  const LegalSection({
    required this.key,
    required this.heading,
    required this.body,
  });

  /// Identifiant stable de la section (`objet`, `contact`…). **C'est elle qui
  /// fait foi, pas le titre** : elle survit à la réécriture du `heading` et
  /// identifie une section à travers les éditions.
  final String key;

  /// Titre de la section — carte de traduction entière. Texte **nu**, sans
  /// Markdown : c'est lui qui tient lieu de titre, et c'est précisément pour
  /// cela que les `#` sont interdits dans un corps.
  final Map<String, String> heading;

  /// Corps de la section — carte de traduction entière, en **Markdown
  /// restreint** (`utils/inline_markdown.dart`).
  final Map<String, String> body;

  @override
  bool operator ==(Object other) =>
      other is LegalSection &&
      other.key == key &&
      mapEquals(other.heading, heading) &&
      mapEquals(other.body, body);

  @override
  int get hashCode => Object.hash(key, heading.length, body.length);
}

/// Une section **déjà repliée dans une seule langue** — ce qu'un widget reçoit.
///
/// Il n'y a plus aucune règle à appliquer dessus, donc plus aucune occasion
/// d'en appliquer une variante.
@immutable
class LegalSectionView {
  const LegalSectionView({
    required this.key,
    required this.heading,
    required this.body,
  });

  final String key;

  /// Titre nu, dans la langue du document.
  final String heading;

  /// Corps en Markdown restreint, dans la langue du document.
  final String body;
}

/// **La locale d'un document légal, choisie une fois pour le document entier.**
///
/// La locale n'est retenue que si TOUTES les sections la portent — `heading`
/// ET `body`. Une seule absence bascule le document ENTIER sur le français.
///
/// Ne pas remplacer par `pick` section par section : voir ADR-0035. Un document
/// en éwé dont trois articles sortent en français est impossible à accepter —
/// on demande à quelqu'un de cocher « j'ai lu et j'accepte » un texte dont il
/// ne peut pas lire une partie, et le serveur en garde une trace horodatée.
/// Il s'affiche parfaitement et ne fait rougir aucun test existant.
///
/// C'est la **seule dérogation du dépôt** à la règle d'ADR-0023 (« `pick` est
/// l'unique autorité du repli de langue »), et elle ne vaut que pour
/// `legal_documents`. Le nom de cette fonction est celui du **motif**, jamais
/// celui de la mécanique : ni `pickAll`, ni `pickSections`.
///
/// Le résultat est **binaire** : la locale demandée, ou le français. Aucun état
/// intermédiaire.
///
/// Une valeur **vide ou blanche** compte comme absente, comme dans `pick` : une
/// traduction amorcée mais non remplie n'est pas une traduction, et laisser
/// passer un article vide serait exactement le trou que cet ADR ferme.
String resolveLegalLocale(List<LegalSection> sections, String wanted) {
  final language = languageSubtag(wanted);
  if (language.isEmpty || language == kContentFallbackLocale) {
    return kContentFallbackLocale;
  }

  // C'est le `every` du pseudo-code d'ADR-0035, écrit en sortie anticipée :
  // **toutes** les sections doivent porter les deux champs, jamais « la
  // majorité ». La première absence décide, et elle décide pour tout.
  for (final section in sections) {
    if (_valueFor(section.heading, language) == null) {
      return kContentFallbackLocale;
    }
    if (_valueFor(section.body, language) == null) {
      return kContentFallbackLocale;
    }
  }
  return language;
}

/// Un **document légal** tel qu'un écran l'affiche : ses sections repliées dans
/// une seule langue, et de quoi écrire son pied de page.
@immutable
class LegalDocumentView {
  const LegalDocumentView({
    required this.kind,
    required this.version,
    required this.locale,
    required this.sections,
    this.lastMandatoryVersion,
    this.publishedAt,
    this.updatedAt,
  });

  /// Applique la règle de repli en bloc ([resolveLegalLocale]) à des sections
  /// brutes. **Seule** façon de construire un document destiné à l'affichage.
  factory LegalDocumentView.resolve({
    required String kind,
    required int version,
    required List<LegalSection> sections,
    required String locale,
    int? lastMandatoryVersion,
    DateTime? publishedAt,
    DateTime? updatedAt,
  }) {
    // Une décision, une fois, pour tout le document.
    final resolved = resolveLegalLocale(sections, locale);
    return LegalDocumentView(
      kind: kind,
      version: version,
      locale: resolved,
      lastMandatoryVersion: lastMandatoryVersion,
      publishedAt: publishedAt,
      updatedAt: updatedAt,
      sections: List<LegalSectionView>.unmodifiable(
        sections.map(
          (section) => LegalSectionView(
            key: section.key,
            // La langue est déjà décidée : plus rien ne se replie ici. Un
            // champ absent rend une chaîne vide — c'est le cas du document
            // dont le français lui-même manque, et l'absence se dessine comme
            // une absence.
            heading: _valueFor(section.heading, resolved) ?? '',
            body: _valueFor(section.body, resolved) ?? '',
          ),
        ),
      ),
    );
  }

  /// `cgu`, `privacy` ou `about` — voir [LegalDocumentKind].
  final String kind;

  /// Numéro d'édition courante, écrit par le serveur. S'affiche au pied.
  final int version;

  /// Plancher d'acceptation exigé (`null` = aucun). Il ne s'affiche pas : il
  /// sert à la barrière de consentement (#56), qui compare un entier à un
  /// entier.
  final int? lastMandatoryVersion;

  /// **La langue effectivement retenue**, après repli en bloc. Vaut `fr` dès
  /// qu'une seule section manquait dans la langue demandée.
  final String locale;

  final List<LegalSectionView> sections;

  final DateTime? publishedAt;
  final DateTime? updatedAt;

  /// Date à afficher au pied : la mise à jour si le serveur en connaît une,
  /// sinon la publication. `null` si le serveur n'a servi ni l'une ni l'autre —
  /// l'absence se rend comme une absence, jamais comme une date inventée.
  DateTime? get footerDate => updatedAt ?? publishedAt;
}

/// Valeur **exploitable** de la carte pour cette langue, `null` sinon.
///
/// **Ce n'est pas un repli** : la fonction ne connaît qu'une langue et n'en
/// essaie aucune autre. Le seul repli du document a déjà eu lieu, une fois,
/// dans [resolveLegalLocale].
///
/// La comparaison se fait sur la sous-étiquette : le back ne régionalise pas
/// ses contenus, mais rien ne garantit qu'une carte n'arrive jamais avec
/// `fr_FR`.
String? _valueFor(Map<String, String> map, String language) {
  for (final entry in map.entries) {
    if (languageSubtag(entry.key) != language) continue;
    if (entry.value.trim().isEmpty) continue;
    return entry.value;
  }
  return null;
}
