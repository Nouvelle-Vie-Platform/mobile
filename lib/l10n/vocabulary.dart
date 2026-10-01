/// **Le point unique où la surcharge du portail recouvre le `.arb`** (#81).
///
/// ## La règle, écrite une seule fois
///
/// Surcharge du portail → sinon le `.arb` compilé → sinon rien d'autre à
/// montrer. Dans cet ordre, et à cet endroit seul : un widget qui déciderait
/// lui-même créerait une **seconde vérité**, et c'est elle qui se mettrait à
/// diverger le jour où la règle bouge.
///
/// ## Le `.arb` n'est pas un repli honteux
///
/// Avant son premier cycle de synchronisation, l'application montre ce qu'elle
/// a compilé — un écran vide ou une clé technique au premier lancement serait
/// pire que le mot du dépôt. Et le `.arb` **reste la vérité** pour toute clé
/// que le portail ne surcharge pas : la grande majorité d'entre elles.
///
/// Trois chemins mènent au mot du dépôt, et ce sont les trois cas normaux :
/// aucun cycle encore passé, aucune surcharge pour cette clé, surcharge
/// **vide**. Le dernier est le piège : le serveur écrit `null` plutôt que de
/// supprimer la ligne, et une carte sans aucune langue remplie veut dire
/// « garde le mot du dépôt », jamais « affiche rien ».
///
/// ## Aucune composition, aucun accord calculé
///
/// Un terme porte son singulier et son pluriel, écrits à la main au portail.
/// Une phrase composée est **sa propre clé**, surchargée entière. C'est une
/// décision de cadrage, pas un report : « Derniers enseignements » → «
/// Dernières publications » change le genre *et* l'accord de l'adjectif, et
/// aucune paire singulier/pluriel ne produit cela.
library;

import 'package:flutter/widgets.dart';

import '../models/vocabulary.dart';
import '../utils/i18n_text.dart';
import 'app_localizations.dart';

/// **Les mots de l'interface, surcharge comprise.** Construit par
/// `context.words` (voir `l10n_extension.dart`), jamais à la main dans un
/// widget.
///
/// Les getters nommés couvrent les clés `.arb` que le catalogue du portail
/// déclare surchargeables (`app/presentation/support/vocabulary_catalog.ts`,
/// entrées `surface: 'mobile'`). Une clé qui n'y est pas se lit par
/// `context.l10n` comme avant : la liste est **curée**, et une absence n'est
/// pas un manque.
@immutable
class AppWords {
  const AppWords(this._l10n, this.overrides, this._locale);

  final AppLocalizations _l10n;

  /// Ce que le portail a réglé. Vide tant qu'aucun cycle n'est passé.
  final VocabularyOverrides overrides;

  /// La langue **d'interface** que `MaterialApp` a résolue — pas la langue de
  /// repli du contenu. Les deux coïncident presque toujours ; les confondre
  /// ferait afficher un libellé d'interface dans une langue que la personne n'a
  /// pas choisie.
  final String _locale;

  /// **La résolution, et c'est la seule.** [delivered] est le mot du dépôt :
  /// il n'est pas optionnel, parce qu'il n'y a aucun cas où l'absence de
  /// surcharge autorise à ne rien montrer.
  ///
  /// Une surcharge **vide ou blanche** se comporte exactement comme une
  /// surcharge absente — c'est `pick` qui rend `''`, et `''` n'est pas un
  /// libellé.
  String label(String key, String delivered) {
    final override = overrides.labels[key];
    if (override == null) return delivered;
    final picked = pick(override, _locale);
    return picked.trim().isEmpty ? delivered : picked;
  }

  /// Le **singulier** d'un terme, là où le mot est seul.
  ///
  /// [delivered] vient de l'appelant et non d'une clé `.arb` : aucun `.arb` ne
  /// porte aujourd'hui un terme nu, et cette tranche ne touche à aucun `.arb`.
  /// C'est l'écran qui nomme le mot du dépôt, comme il nomme déjà sa clé.
  String termSingular(String key, String delivered) =>
      _term(overrides.terms[key]?.singular, delivered);

  /// Le **pluriel** d'un terme. Écrit à la main au portail — jamais dérivé du
  /// singulier.
  String termPlural(String key, String delivered) =>
      _term(overrides.terms[key]?.plural, delivered);

  String _term(Map<String, String>? override, String delivered) {
    if (override == null) return delivered;
    final picked = pick(override, _locale);
    return picked.trim().isEmpty ? delivered : picked;
  }

  // ── Les clés surchargeables du catalogue, `surface: 'mobile'` ────────────
  //
  // Relevées sur `app/presentation/support/vocabulary_catalog.ts` (LABEL_CATALOG).
  // Y ajouter une clé ici sans l'ajouter là-bas ne produit rien : le portail ne
  // l'offre pas au réglage, et aucune ligne ne descendra jamais sous ce nom.

  /// Accueil et médiathèque : le titre de la section des contenus récents.
  String get sectionLatestTeachings =>
      label('sectionLatestTeachings', _l10n.sectionLatestTeachings);

  /// Le texte qui explique ce que change le choix d'assemblée.
  String get branchScopeLead => label('branchScopeLead', _l10n.branchScopeLead);

  /// Le titre de la barre d'un contenu d'enseignement.
  String get teachingAppBarTitle =>
      label('teachingAppBarTitle', _l10n.teachingAppBarTitle);

  /// L'onglet des enseignements, dans les filtres de la médiathèque.
  String get filterTeachings => label('filterTeachings', _l10n.filterTeachings);

  /// L'invite du champ de recherche de la médiathèque.
  String get mediaSearchHint => label('mediaSearchHint', _l10n.mediaSearchHint);

  /// Le titre affiché quand un contenu a été retiré en cours d'écoute.
  String get teachingRetractedTitle =>
      label('teachingRetractedTitle', _l10n.teachingRetractedTitle);

  /// Le corps du même message.
  String get teachingRetractedMessage =>
      label('teachingRetractedMessage', _l10n.teachingRetractedMessage);

  /// L'état vide de la page Téléchargements.
  String get downloadsEmptyMessage =>
      label('downloadsEmptyMessage', _l10n.downloadsEmptyMessage);

  /// Le nom de repli d'une copie téléchargée dont la source a disparu.
  String get downloadsUnknownTitle =>
      label('downloadsUnknownTitle', _l10n.downloadsUnknownTitle);

  /// L'avis de purge, quand le titre n'est pas connu.
  String get downloadPurgeNoticeUnnamed =>
      label('downloadPurgeNoticeUnnamed', _l10n.downloadPurgeNoticeUnnamed);

  /// Le titre du réglage de qualité d'écoute.
  String get mediaSettingsStreaming =>
      label('mediaSettingsStreaming', _l10n.mediaSettingsStreaming);
}

/// **Porte le vocabulaire jusqu'aux widgets**, sous `MaterialApp`.
///
/// Un `InheritedWidget` et non un `ref.watch` disséminé : `context.words` doit
/// se lire exactement comme `context.l10n`, depuis n'importe quel
/// `StatelessWidget`, sans que chacun ait à devenir un `Consumer`. C'est aussi
/// ce qui rend la règle **inévitable** — un widget ne peut pas lire la
/// surcharge sans passer par la résolution.
///
/// **Absent, il ne casse rien** : [of] rend alors [VocabularyOverrides.empty],
/// et tout se lit sur le `.arb`. C'est l'état d'un test d'écran monté sans
/// scope, et c'est le même état que la toute première ouverture.
class VocabularyScope extends InheritedWidget {
  const VocabularyScope({
    required this.overrides,
    required super.child,
    super.key,
  });

  final VocabularyOverrides overrides;

  /// Ce que le portail a réglé, ou **rien** si personne ne l'a posé.
  static VocabularyOverrides of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<VocabularyScope>()
          ?.overrides ??
      VocabularyOverrides.empty;

  @override
  bool updateShouldNotify(VocabularyScope oldWidget) =>
      oldWidget.overrides != overrides;
}
