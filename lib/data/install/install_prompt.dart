/// **L'offre d'installation** — ce que le navigateur permet de proposer, et
/// rien de plus.
///
/// L'installation n'est pas une coquetterie sur cette plateforme : elle porte
/// le **téléchargement hors ligne** et la **durabilité du stockage**. Mesuré le
/// 29/10/2026 sur un Android 6 / Chrome 106 :
/// `navigator.storage.persist()` répond *non* avant l'installation et *oui*
/// après. Un fidèle qui n'installe pas garde un magasin que Chrome peut vider
/// d'un coup, enseignements téléchargés compris.
///
/// Trois offres, parce que les navigateurs n'offrent pas la même chose :
library;

/// Ce qu'on peut proposer ici et maintenant.
enum InstallOffer {
  /// Rien à proposer : déjà installée, ou navigateur qui ne sait pas installer.
  none,

  /// Le navigateur a **accepté** de différer sa propre invite : un bouton à
  /// nous peut ouvrir la vraie boîte d'installation (`beforeinstallprompt`).
  prompt,

  /// Aucun événement, mais le geste existe : iOS, où l'on ajoute à l'écran
  /// d'accueil par le menu *Partager*. On ne peut que **l'expliquer**.
  manualIos,
}

/// La porte unique derrière laquelle vit l'interop du navigateur.
///
/// Même motif que `ContentPlayer` devant `just_audio` : un seul fichier du
/// dépôt importe `dart:js_interop`, tout le reste ne connaît que ce contrat et
/// se teste donc sur la VM Dart.
abstract interface class InstallPrompt {
  /// L'offre courante, lisible tout de suite.
  InstallOffer get offer;

  /// Les changements d'offre. Chrome émet `beforeinstallprompt` **quand il
  /// veut** — souvent après le premier rendu, parfois jamais —, et l'offre
  /// retombe à [InstallOffer.none] dès l'installation faite.
  Stream<InstallOffer> get changes;

  /// Ouvre la boîte d'installation du navigateur.
  ///
  /// ⚠️ **À n'appeler que depuis un geste** : Chrome refuse une invite qui ne
  /// descend pas d'un appui. Sans objet quand l'offre n'est pas
  /// [InstallOffer.prompt].
  Future<void> show();
}

/// **Le défaut de production**, et celui de tous les tests : il n'offre rien.
///
/// C'est l'état exact du mobile natif — on n'installe pas une application déjà
/// installée — et celui d'un navigateur qui ne sait pas le faire.
class InertInstallPrompt implements InstallPrompt {
  const InertInstallPrompt();

  @override
  InstallOffer get offer => InstallOffer.none;

  @override
  Stream<InstallOffer> get changes => const Stream<InstallOffer>.empty();

  @override
  Future<void> show() async {}
}
