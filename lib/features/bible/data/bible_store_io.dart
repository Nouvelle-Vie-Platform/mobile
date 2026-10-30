/// Le magasin d'une Bible **sur un appareil** : un dossier, un fichier par
/// livre. C'est l'implémentation d'origine de C4, déplacée ici intacte.
library;

import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'bible_store.dart';

/// Le magasin de la plateforme. [root] n'existe que pour les tests, qui ne
/// peuvent pas appeler `getApplicationSupportDirectory` sans greffon.
BibleStore bibleStore({Future<String> Function()? root}) =>
    _DirectoryBibleStore(root);

final class _DirectoryBibleStore implements BibleStore {
  const _DirectoryBibleStore(this._root);

  final Future<String> Function()? _root;

  Future<String> _dir(String code) async {
    final base = await (_root ??
        () async => (await getApplicationSupportDirectory()).path)();
    return '$base/bible/${safeBibleCode(code)}';
  }

  @override
  Future<String> install(String code, Map<String, List<int>> entries) async {
    final path = await _dir(code);
    final dir = Directory(path);
    if (dir.existsSync()) await dir.delete(recursive: true);
    await Directory('$path/books').create(recursive: true);
    for (final MapEntry(key: name, value: bytes) in entries.entries) {
      await File('$path/$name').writeAsBytes(bytes);
    }
    return path;
  }

  @override
  Future<String?> read(String localPath, String name) async {
    final file = File('$localPath/$name');
    if (!file.existsSync()) return null;
    return file.readAsString();
  }

  /// Le **manifeste** et rien d'autre : `unpackBibleArchive` refuse une archive
  /// qui n'en a pas, donc sa présence vaut installation complète.
  @override
  Future<bool> has(String localPath) async =>
      File('$localPath/manifest.json').existsSync();

  @override
  Future<void> remove(String localPath) async {
    final dir = Directory(localPath);
    if (dir.existsSync()) await dir.delete(recursive: true);
  }
}
