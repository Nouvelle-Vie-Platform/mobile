/// **Le fond des lecteurs, sur le disque du téléphone.**
///
/// Le serveur sert l'adresse du fond ; ce magasin-ci le **descend une fois**,
/// puis le sert depuis le disque à toutes les ouvertures suivantes. C'est une
/// exigence explicite : un fond plein écran re-téléchargé à chaque lecture
/// coûterait, sur un forfait prépayé, plus que l'enseignement qu'il habille.
///
/// ## Pourquoi pas `Image.network`
///
/// Le cache de `NetworkImage` est **en mémoire** : il disparaît avec le
/// processus, donc le fond repartirait sur le réseau à chaque lancement. Et un
/// cache HTTP générique (`flutter_cache_manager`) revalide au bout de sept
/// jours — ce qui est un comportement raisonnable pour une image quelconque, et
/// faux pour celle-ci : l'adresse d'un fond **change quand le fond change**
/// (`<uuid>-<largeur>w.webp`), si bien que l'URL est déjà sa propre version.
/// Tant qu'elle ne bouge pas, il n'y a rien à revalider.
///
/// ## Ce fichier ne lève jamais
///
/// [ensureLocal] rend `null` sur **toute** défaillance — réseau absent, disque
/// plein, canal de plugin inexistant sous `flutter test`. Un décor n'est pas
/// une donnée : le lecteur retombe sur son aplat de couleur et la lecture
/// continue. Faire remonter l'échec ferait rougir tous les tests d'écran et,
/// en production, échangerait un fond manquant contre un écran d'erreur.
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

/// Le sous-dossier du cache. Nommé, parce qu'il est purgé entièrement.
const String _kDirectory = 'season_backgrounds';

/// Le magasin de fonds, derrière une abstraction — les tests en injectent un
/// double, comme pour les sélecteurs d'image et le lecteur de version.
abstract class SeasonBackgroundStore {
  /// Le fichier local du fond d'[url], descendu si besoin. `null` si l'adresse
  /// est vide, ou si quoi que ce soit a échoué.
  Future<File?> ensureLocal(String? url);

  /// Le fond **déjà descendu**, sans jamais toucher au réseau ni à la base.
  ///
  /// C'est ce que lit le démarrage : l'écran de marque dure le temps de
  /// résoudre une session, et un fond qui arriverait après lui n'aurait servi à
  /// personne. Le dossier ne contient qu'un fichier — la purge s'en charge —, et
  /// c'est précisément ce qui permet de le retrouver **sans connaître son
  /// adresse**, donc sans ouvrir le magasin.
  ///
  /// `null` est l'état normal du premier lancement.
  Future<File?> cachedFile();
}

/// Celui des tests et du mode sans backend : ne descend rien, ne rend rien.
class InertSeasonBackgroundStore implements SeasonBackgroundStore {
  const InertSeasonBackgroundStore();

  @override
  Future<File?> ensureLocal(String? url) async => null;

  @override
  Future<File?> cachedFile() async => null;
}

/// L'implémentation réelle : un fichier par adresse, dans le dossier de
/// support de l'application.
class FileSeasonBackgroundStore implements SeasonBackgroundStore {
  /// [fetch] descend `url` **vers** `destination`. Injecté plutôt que codé en
  /// dur : ce magasin sait où poser un fichier et quand ne pas le redemander ;
  /// par quel tuyau les octets arrivent ne le regarde pas, et un test n'a pas à
  /// monter un serveur pour éprouver le « une seule fois ».
  FileSeasonBackgroundStore({
    required Future<void> Function(String url, String destination) fetch,
    Future<Directory> Function()? root,
  })  : _fetch = fetch,
        _root = root ?? getApplicationSupportDirectory;

  /// Celui de production : un `Dio` **nu**, sans intercepteur.
  ///
  /// Un fond est un fichier public de `/uploads/`, pas un appel d'API. Passer
  /// par le `Dio` d'`ApiClient` y enverrait le jeton du porteur et ferait
  /// traverser la réponse à l'intercepteur de 401 — autrement dit, donnerait à
  /// un téléchargement d'image le pouvoir de déconnecter quelqu'un.
  factory FileSeasonBackgroundStore.network({
    Dio? dio,
    Future<Directory> Function()? root,
  }) {
    final client = dio ?? Dio();
    return FileSeasonBackgroundStore(
      fetch: (url, destination) => client.download(url, destination),
      root: root,
    );
  }

  final Future<void> Function(String url, String destination) _fetch;

  /// **Le dossier de _support_, jamais celui des documents.** Les documents
  /// sont sauvegardés par iCloud et iTunes : y ranger un cache ferait payer à
  /// la sauvegarde d'un fidèle des octets qu'un seul appel réseau reconstruit.
  /// C'est aussi ce qui distingue ce dossier de `teaching_downloads`, qui est
  /// du contenu voulu par la personne et doit, lui, survivre à une
  /// restauration.
  final Future<Directory> Function() _root;

  @override
  Future<File?> ensureLocal(String? url) async {
    final source = url?.trim();
    if (source == null || source.isEmpty) return null;

    try {
      final directory = Directory('${(await _root()).path}/$_kDirectory');
      await directory.create(recursive: true);

      final target = File('${directory.path}/${_fileName(source)}');
      // **Le chemin le plus fréquent, et il ne touche pas au réseau.**
      if (await target.exists()) return target;

      // Un fichier temporaire, puis un renommage : le renommage est atomique
      // sur les deux plateformes, si bien qu'un fichier présent est un fichier
      // **complet**. Sans lui, une coupure réseau laisserait un WebP tronqué
      // que toutes les ouvertures suivantes trouveraient « déjà là ».
      final partial = File('${target.path}.partial');
      await _fetch(source, partial.path);
      await partial.rename(target.path);

      // La saison a changé : le fond précédent n'a plus de raison d'occuper le
      // disque. Purge **après** la réussite, jamais avant — un échec ne doit
      // pas coûter le fond qu'on avait déjà.
      await _purgeExcept(directory, target);

      return target;
    } catch (_) {
      // Voir l'en-tête : un décor n'est pas une donnée.
      return null;
    }
  }

  @override
  Future<File?> cachedFile() async {
    try {
      final directory = Directory('${(await _root()).path}/$_kDirectory');
      if (!await directory.exists()) return null;

      await for (final entry in directory.list()) {
        // Les `.partial` sont des descentes interrompues : les rendre
        // afficherait une image tronquée, et surtout la figerait à l'écran de
        // démarrage de tous les lancements suivants.
        if (entry is File && !entry.path.endsWith('.partial')) return entry;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Le nom de fichier local d'une adresse.
  ///
  /// Le nom servi (`<uuid>-1920w.webp`) est déjà unique, mais rien ne le
  /// garantit dans le contrat — d'où l'empreinte de l'adresse **entière** en
  /// préfixe. Elle est calculée ici (FNV-1a, huit caractères) plutôt que prise
  /// à `String.hashCode`, qui n'est stable ni entre deux lancements ni entre
  /// deux versions du SDK : un cache dont la clé change au redémarrage est un
  /// cache qui ne sert jamais.
  static String _fileName(String url) {
    var hash = 0x811c9dc5;
    for (final unit in url.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    final stamp = hash.toRadixString(16).padLeft(8, '0');
    final extension = _extensionOf(url);
    return '$stamp$extension';
  }

  /// L'extension de l'adresse, `.img` si elle n'en porte aucune — le décodeur
  /// de Flutter lit les octets, pas le nom ; l'extension n'est là que pour qui
  /// inspecte le dossier.
  static String _extensionOf(String url) {
    final path = Uri.tryParse(url)?.path ?? url;
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot < path.lastIndexOf('/')) return '.img';
    final extension = path.substring(dot);
    return extension.length > 6 ? '.img' : extension;
  }

  Future<void> _purgeExcept(Directory directory, File keep) async {
    await for (final entry in directory.list()) {
      if (entry is File && entry.path != keep.path) {
        try {
          await entry.delete();
        } catch (_) {
          // Un fichier qu'on ne peut pas effacer n'est pas une panne : il sera
          // retenté à la prochaine bascule de saison.
        }
      }
    }
  }
}
