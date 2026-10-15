import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// **Le magasin durable des médias reçus** (T1, #223).
///
/// Pourquoi un dossier de plus, à côté de [MediaOutbox] : l'outbox garde ce qui
/// **part** et se balaie dès que l'écho n'est plus cité ; ce magasin garde ce
/// qui est **arrivé**, et rien ne l'efface dans le dos du fidèle (décision 1 du
/// cadrage — c'est l'écran « Stockage » de #226 qui purgera).
///
/// Il est **dans le support de l'application** (`getApplicationSupportDirectory`),
/// pas dans le cache : `getTemporaryDirectory()`, où le téléchargement des
/// documents écrivait jusqu'ici, est vidé par le système quand il veut —
/// « enregistré en local » n'y est jamais durable.
///
/// ## La clé est l'identité du message, et c'est tout
///
/// Un média de message est **immuable** : la clé au magasin ne change jamais
/// pour un `messageId` donné. Le chemin est donc **déductible** — un dossier par
/// message, une entrée par variante (le fichier, la vignette) — et il n'y a
/// aucune validation à inventer. C'est heureux : sur cette origine, `If-Range`
/// est ignoré (`streaming-service` ADR-0012), donc aucune garde conditionnelle
/// n'y serait fiable.
///
/// Un dossier **par message** parce que deux documents de deux messages peuvent
/// porter le même nom ; `thumb_` préfixe la vignette, qui vit dans le même
/// dossier que son fichier.
class MessageMediaStore {
  MessageMediaStore({Future<Directory> Function()? root})
      : _root = root ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _root;
  Directory? _dir;

  Future<Directory> _directory() async {
    final cached = _dir;
    if (cached != null) return cached;
    return _dir = Directory('${(await _root()).path}/message_media');
  }

  /// Le chemin du média de [messageId] — ou de sa vignette —, **qu'il existe ou
  /// non**. Ne touche pas au disque : c'est l'appelant qui teste et qui écrit.
  Future<String> pathFor({
    required String messageId,
    required String fileName,
    bool thumbnail = false,
  }) async {
    final dir = await _directory();
    final safeId = _safe(messageId);
    final safeName = _safe(fileName);
    return '${dir.path}/$safeId/${thumbnail ? 'thumb_' : ''}$safeName';
  }

  /// Crée le dossier de [path] s'il manque, et rend `path`. Appelé **juste
  /// avant** d'écrire, jamais avant de lire : un magasin vide n'a pas besoin
  /// d'exister.
  Future<String> prepare(String path) async {
    await Directory(File(path).parent.path).create(recursive: true);
    return path;
  }

  /// Un séparateur dans un nom de fichier ferait un sous-dossier, ou sortirait
  /// du magasin (`../`). Le nom vient du serveur : on ne le suppose pas sain.
  static String _safe(String raw) => raw.replaceAll(RegExp(r'[/\\:]'), '_');
}
