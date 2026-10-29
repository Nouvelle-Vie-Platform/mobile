/// **Le `Cache` des enseignements hors ligne** (#273) — la porte unique, du
/// côté Dart, vers ce que le service worker y range.
///
/// Deux pièces la franchissent, et aucune autre : le moteur de transfert
/// (`background_fetch_download_backend.dart`), qui n'écrit rien lui-même mais
/// relève ce qui est arrivé, et le lecteur web (`hls_content_player.dart`), qui
/// en fabrique une URL de blob. L'écriture, elle, n'a pas lieu ici : seul
/// `web/sw-offline.js` la fait, à `backgroundfetchsuccess`, parce que c'est le
/// seul code qui tourne encore quand l'onglet est fermé.
///
/// **Le nom du Cache et la forme des clés sont le contrat entre les deux
/// moitiés.** Il n'y en a pas d'autre : le service worker ne parle pas à Dart
/// (voir l'en-tête du backend), et la seule chose qu'ils partagent est ce
/// `Cache`, qui est par origine.
///
/// ## La clé porte le `taskId` **et** le nom de fichier, et les deux servent
///
/// `/offline/<taskId>/<nom de fichier>.aac` :
///
/// - le **`taskId`** permet de retrouver la ligne Drift d'un transfert qui a
///   abouti pendant que l'onglet était fermé — personne n'était là pour
///   l'apprendre, et c'est un relevé du `Cache` qui le rattrape ;
/// - le **nom de fichier** (`<contentId>.<qualité>.aac`) est stable pour un même
///   contenu à une même qualité : il permet de jeter la copie précédente avant
///   d'en descendre une neuve, exactement comme le moteur natif réécrit par
///   dessus le même fichier.
///
/// La clé **est** le `localPath` de la ligne Drift : c'est elle que la
/// complétion rend, que le résolveur relit, et que la suppression efface. Rien
/// n'a à la décoder hors de ce fichier.
library;

import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Le nom du `Cache`. **À garder identique dans `web/sw-offline.js`.**
const String kOfflineCacheName = 'nv-offline-v1';

/// Le préfixe des clés — dans la portée du service worker, pour que ce soit
/// lisible dans l'inspecteur.
const String kOfflineKeyPrefix = '/offline/';

/// La clé de `Cache` d'un transfert, à partir de son identifiant Background
/// Fetch (`<taskId>/<nom de fichier>`). **Même calcul dans le worker.**
String offlineKeyFor(String fetchId) => '$kOfflineKeyPrefix$fetchId';

/// Le `taskId` porté par une clé, ou `null` si elle n'en porte pas — une clé
/// d'une version précédente, ou autre chose rangé là par erreur.
String? offlineTaskIdOf(String key) {
  if (!key.startsWith(kOfflineKeyPrefix)) return null;
  final rest = key.substring(kOfflineKeyPrefix.length);
  final slash = rest.indexOf('/');
  if (slash <= 0) return null;
  return rest.substring(0, slash);
}

Future<web.Cache> _open() => web.window.caches.open(kOfflineCacheName).toDart;

/// Les clés présentes, en chemins (`/offline/…`) — la forme exacte de ce qui
/// est rangé dans `downloads.localPath`.
Future<List<String>> offlineKeys() async {
  try {
    final cache = await _open();
    final requests = (await cache.keys().toDart).toDart;
    return [
      for (final request in requests) Uri.parse(request.url).path,
    ];
  } on Object {
    // Pas de `Cache` sur cette origine (contexte non sûr), ou stockage refusé :
    // il n'y a alors aucune copie locale, ce qui est exactement ce que dit une
    // liste vide.
    return const [];
  }
}

/// Y a-t-il quelque chose sous cette clé ? Sert à attendre que le worker ait
/// fini de ranger avant d'annoncer un téléchargement complet.
Future<bool> offlineHas(String key) async {
  try {
    final cache = await _open();
    return await cache.match(key.toJS).toDart != null;
  } on Object {
    return false;
  }
}

/// Efface une copie. Sans effet s'il n'y a rien.
Future<void> offlineDelete(String key) async {
  try {
    final cache = await _open();
    await cache.delete(key.toJS).toDart;
  } on Object {
    // Rien à effacer, ou pas de `Cache` : dans les deux cas la place est rendue.
  }
}

/// Efface toute copie **du même fichier**, quel que soit le transfert qui l'a
/// descendue : un re-téléchargement frappe un nouvel identifiant de tâche, donc
/// une nouvelle clé, et la précédente occuperait la place pour toujours.
Future<void> offlineForget(String filename) async {
  final suffix = '/$filename';
  for (final key in await offlineKeys()) {
    if (key.endsWith(suffix)) await offlineDelete(key);
  }
}

/// **L'URL de blob d'une copie locale**, ou `null` si elle n'est plus là
/// (éviction du navigateur, copie jamais arrivée).
///
/// ponytail: le corps entier passe en mémoire — un enseignement de deux heures
/// à 128 kbps fait ~115 Mo. C'est le prix de la lecture par `<audio src>` ; pour
/// s'en passer il faudrait que le service worker réponde aux requêtes de
/// l'élément (`fetch` dans sa portée), donc une URL servie par lui, donc le
/// double chemin que cette tranche a écarté. À reprendre le jour où un appareil
/// le refuse.
Future<String?> offlineBlobUrl(String key) async {
  try {
    final cache = await _open();
    final response = await cache.match(key.toJS).toDart;
    if (response == null) return null;
    final blob = await response.blob().toDart;
    return web.URL.createObjectURL(blob);
  } on Object {
    return null;
  }
}
