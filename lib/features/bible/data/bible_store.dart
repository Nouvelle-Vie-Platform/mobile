/// **Où vit une Bible installée** — la porte unique entre le dézippage et le
/// support qui garde les octets.
///
/// C4 rangeait les livres dans un **dossier**, et c'était le bon choix sur un
/// téléphone : un fichier par livre, lus un à un, `Jean` coûte ~60 Ko au lieu
/// des 4 Mo de la version entière. Mais un navigateur n'a pas de dossier, et le
/// bouton « Télécharger » y échouait **après** avoir descendu l'archive — le
/// fidèle voyait « Réessayez plus tard » sans que rien ne puisse jamais
/// réussir.
///
/// La couture est donc ici, et nulle part ailleurs : `bible_archive.dart` ne
/// connaît plus `File` ni `Directory`, seulement ces trois gestes. Le découpage
/// par livre survit intact des deux côtés — c'est lui qui fait la vitesse, pas
/// le système de fichiers.
///
/// Même porte que le hors-ligne des enseignements (`data/downloads/`), et même
/// raison : une seconde implémentation *ajoutée*, jamais une branche `kIsWeb`
/// semée dans le code métier.
library;

export 'bible_store_io.dart'
    if (dart.library.js_interop) 'bible_store_web.dart';

/// Le magasin d'une Bible installée.
///
/// [localPath] n'est pas forcément un chemin de fichier : c'est l'identifiant
/// que `bible_installed_versions.localPath` garde, et que [read] et [remove]
/// relisent. Sur un téléphone c'est un dossier, dans un navigateur une clé de
/// `Cache`. Rien d'autre n'a à le décoder.
abstract interface class BibleStore {
  /// Range les entrées d'une archive (`manifest.json`, `books/NN.json`) et rend
  /// le `localPath` de la version. **Efface d'abord** ce qui s'y trouvait : une
  /// réinstallation ne doit pas laisser cohabiter les livres de deux éditions.
  Future<String> install(String code, Map<String, List<int>> entries);

  /// Le contenu d'une entrée, ou `null` si elle n'est pas là — un livre que
  /// cette version n'a pas (l'éwé 2014 n'a ni Esther ni Daniel), ou une copie
  /// que le navigateur a évincée.
  Future<String?> read(String localPath, String name);

  /// Rend la place. Sans effet s'il n'y a rien.
  Future<void> remove(String localPath);
}

/// Un code de version ne nomme une entrée qu'une fois réduit à ce qui ne peut
/// pas sortir du magasin — il vient du serveur, on ne le suppose pas sain
/// (même garde que `MessageMediaStore._safe`).
String safeBibleCode(String code) =>
    code.replaceAll(RegExp('[^A-Za-z0-9_-]'), '_');
