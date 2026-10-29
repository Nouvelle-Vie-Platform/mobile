/// **Ce que la plateforme permet au téléchargement hors ligne** (#273) — les
/// trois questions que l'écran doit poser avant de promettre quoi que ce soit.
///
/// Elles ne sont pas des réglages : ce sont des **faits de plateforme**, et
/// chacune a été mesurée le 29/10/2026 sur un Android 6 / Chrome 106 ou lue
/// dans la spécification de Background Fetch. L'écran les lit pour **ne pas
/// mentir** — la règle du dépôt étant l'absence, jamais le grisage.
///
/// Même motif que [DiskSpace] ou `InstallPrompt` : une porte, deux
/// implémentations, et toute la décision d'écran se vérifie sur la VM Dart
/// contre un double.
library;

/// Voir l'en-tête du fichier.
abstract interface class DownloadCapabilities {
  /// **Le moteur de transfert existe-t-il ici ?**
  ///
  /// Faux sur Safari, qui n'a pas Background Fetch — quel que soit le code, et
  /// ce n'est pas rattrapable : `fetch` + `Range` ne survit pas à la fermeture
  /// de l'onglet, et c'est précisément ce qu'on garde (voir le plan, §4). Là où
  /// c'est faux, le téléchargement **ne s'affiche pas du tout**.
  bool get available;

  /// **Le moteur sait-il mettre en pause ?**
  ///
  /// Faux dans un navigateur : Background Fetch n'a ni pause ni reprise à
  /// l'octet. C'est la contrepartie assumée du transfert qui survit à la
  /// fermeture de l'onglet, pas une lacune à contourner — l'écran propose donc
  /// **annuler**, et jamais un bouton Pause qui ne ferait rien.
  bool get canPause;

  /// **Le stockage gardera-t-il ce qu'on y descend ?** — et sinon, demande-le.
  ///
  /// Sur un appareil, un fichier est un fichier : toujours vrai. Dans un
  /// navigateur, `navigator.storage.persist()` répond *non* avant
  /// l'installation et *oui* après (mesuré le 29/10/2026), et sans persistance
  /// Chrome évince **tout le stockage de l'origine d'un coup** — les
  /// enseignements téléchargés **et** le magasin Drift ensemble. Un faux ici
  /// veut dire « ne descends pas 80 Mo que le navigateur peut jeter », et
  /// l'écran invite à installer.
  Future<bool> ensureDurable();
}

/// **Le défaut, et celui de tous les tests** : un appareil sait tout faire.
///
/// C'est l'état exact du mobile natif — `background_downloader` met en pause,
/// et un fichier dans les documents de l'application ne s'évapore pas.
class NativeDownloadCapabilities implements DownloadCapabilities {
  const NativeDownloadCapabilities();

  @override
  bool get available => true;

  @override
  bool get canPause => true;

  @override
  Future<bool> ensureDurable() async => true;
}
