import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// **Le dossier des médias en partance** (M4, #143).
///
/// Un média envoyé hors ligne doit **survivre** à un redémarrage : l'écho
/// reste au fil, et le renvoi automatique (#140) le reprendra au retour du
/// réseau. Le fichier choisi par le sélecteur vit, lui, dans un cache que le
/// système vide quand il veut. On le **copie** donc ici — ou on y écrit la
/// version dégradée —, et l'écho (`pending_group_messages.media_path`) le cite.
///
/// Ce qu'aucun écho ne cite plus (message confirmé, envoi abandonné) part au
/// prochain [sweep].
class MediaOutbox {
  MediaOutbox({Future<Directory> Function()? root})
      : _root = root ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _root;
  Directory? _dir;

  Future<Directory> _directory() async {
    final cached = _dir;
    if (cached != null) return cached;
    final dir = Directory('${(await _root()).path}/message_outbox');
    if (!await dir.exists()) await dir.create(recursive: true);
    return _dir = dir;
  }

  /// Un chemin neuf dans le dossier, pour [name] (`<id>.jpg`, `<id>.m4a`…).
  Future<String> pathFor(String name) async =>
      '${(await _directory()).path}/$name';

  /// **Recopie** [sourcePath] dans le dossier sous [name]. Rend le chemin de
  /// la copie. Une source déjà dans le dossier est rendue telle quelle.
  Future<String> adopt(String sourcePath, String name) async {
    final dir = await _directory();
    if (sourcePath.startsWith(dir.path)) return sourcePath;
    final target = '${dir.path}/$name';
    await File(sourcePath).copy(target);
    return target;
  }

  /// **Efface ce qu'aucun écho ne cite** ([keep]). Jamais d'exception : un
  /// fichier qui résiste sera repris au passage suivant.
  Future<void> sweep(Set<String> keep) async {
    try {
      final dir = await _directory();
      await for (final entity in dir.list()) {
        if (entity is File && !keep.contains(entity.path)) {
          try {
            await entity.delete();
          } on FileSystemException {
            // Repris au prochain passage.
          }
        }
      }
    } on Object {
      // Pas de dossier, pas de plugin (tests) : rien à nettoyer.
    }
  }
}
