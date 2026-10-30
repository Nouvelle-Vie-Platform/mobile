/// Le magasin d'une Bible **dans un navigateur** : un `Cache` par origine, une
/// entrée par livre.
///
/// `Cache` et non la base locale : les livres sont des octets opaques que rien
/// n'interroge — on lit `books/43.json` en entier ou pas du tout — et les y
/// mettre aurait coûté une migration de schéma pour ranger des fichiers dans
/// des lignes. C'est aussi là que vivent déjà les enseignements hors ligne
/// (`data/downloads/offline_cache.dart`), sous un `Cache` voisin, et ce que le
/// navigateur évince, il l'évince **par origine, tout à la fois** : deux
/// supports n'auraient pas rendu la Bible plus sûre.
library;

import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'bible_store.dart';

/// Le nom du `Cache`. Distinct de `nv-offline-v1` : celui-là est écrit par le
/// service worker à la fin d'un Background Fetch, celui-ci par la page.
const String kBibleCacheName = 'nv-bible-v1';

/// Le préfixe des clés — dans une portée lisible depuis l'inspecteur.
const String kBibleKeyPrefix = '/bible/';

/// [root] est ignoré : il n'y a pas de dossier ici. Le paramètre survit pour
/// que `bible_archive.dart` garde **une seule** signature des deux côtés.
BibleStore bibleStore({Future<String> Function()? root}) =>
    const _CacheBibleStore();

final class _CacheBibleStore implements BibleStore {
  const _CacheBibleStore();

  Future<web.Cache> _open() => web.window.caches.open(kBibleCacheName).toDart;

  @override
  Future<String> install(String code, Map<String, List<int>> entries) async {
    final localPath = '$kBibleKeyPrefix${safeBibleCode(code)}';
    await remove(localPath);
    final cache = await _open();
    for (final MapEntry(key: name, value: bytes) in entries.entries) {
      // Le corps part en **texte** : ces entrées sont du JSON, et `read` les
      // relit par `response.text()`. Passer par des octets obligerait à
      // traverser `BufferSource` dans les deux sens pour le même résultat.
      final response = web.Response(
        utf8.decode(bytes, allowMalformed: true).toJS,
        web.ResponseInit(
          headers: {'content-type': 'application/json'}.jsify()! as JSObject,
        ),
      );
      await cache.put('$localPath/$name'.toJS, response).toDart;
    }
    return localPath;
  }

  @override
  Future<String?> read(String localPath, String name) async {
    try {
      final cache = await _open();
      final response = await cache.match('$localPath/$name'.toJS).toDart;
      if (response == null) return null;
      return (await response.text().toDart).toDart;
    } on Object {
      // Pas de `Cache` (contexte non sûr), ou copie évincée : dans les deux cas
      // il n'y a rien à lire, ce que `null` dit déjà.
      return null;
    }
  }

  @override
  Future<bool> has(String localPath) async =>
      await read(localPath, 'manifest.json') != null;

  @override
  Future<void> remove(String localPath) async {
    try {
      final cache = await _open();
      final requests = (await cache.keys().toDart).toDart;
      for (final request in requests) {
        if (Uri.parse(request.url).path.startsWith('$localPath/')) {
          await cache.delete(request).toDart;
        }
      }
    } on Object {
      // Rien à effacer, ou pas de `Cache` : la place est rendue dans les deux
      // cas.
    }
  }
}
