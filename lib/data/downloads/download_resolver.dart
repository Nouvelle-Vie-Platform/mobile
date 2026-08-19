/// **Le point de résolution unique de la lecture offline-first** (#191).
///
/// À la lecture, une seule question : joue-t-on le fichier **local** ou le
/// **HLS** ? Le PRD §3.3 la tranche (F10/F11), et ce résolveur est le **seul**
/// endroit qui la tranche — tout écran qui ouvre un contenu passe par lui, plus
/// personne ne lit `playlistUrl` en brut pour décider.
///
/// Il ne parle **ni au réseau ni au lecteur** : il lit le magasin (`downloads`,
/// qui fait foi — ADR-0026) et un état réseau minimal ([NetworkStatus]), et rend
/// une [PlaybackResolution] que l'appelant confie au [ContentPlayer]. Sa logique
/// se vérifie donc entièrement sur la VM Dart.
library;

import 'package:flutter/foundation.dart';

import '../local/downloads_dao.dart';
import '../local/tables/download_tables.dart';
import '../network/network_transport.dart';

/// **La source à jouer**, telle que le résolveur la tranche : un fichier local
/// ou une URL HLS, jamais les deux.
///
/// [hlsUrl] reste porté même sur une résolution locale ? Non : les deux sont
/// exclusifs. L'appelant garde par ailleurs l'URL HLS de son côté (c'est le
/// repli du lecteur), ce que porte cette valeur est **la décision**, pas le
/// contexte.
@immutable
class PlaybackResolution {
  const PlaybackResolution._({this.localFilePath, this.hlsUrl});

  /// Jouer le **fichier local** (complet, ou partiel hors ligne).
  const PlaybackResolution.localFile(String path) : this._(localFilePath: path);

  /// Jouer le **HLS** — le comportement d'avant #191, repli exact.
  const PlaybackResolution.hls(String url) : this._(hlsUrl: url);

  /// Le chemin du fichier `.aac` à jouer, ou `null` si la source est le HLS.
  final String? localFilePath;

  /// L'URL HLS à jouer, ou `null` si la source est un fichier local.
  final String? hlsUrl;

  /// Vrai quand la source résolue est un fichier local.
  bool get isLocal => localFilePath != null;

  @override
  bool operator ==(Object other) =>
      other is PlaybackResolution &&
      other.localFilePath == localFilePath &&
      other.hlsUrl == hlsUrl;

  @override
  int get hashCode => Object.hash(localFilePath, hlsUrl);

  @override
  String toString() => isLocal
      ? 'PlaybackResolution.localFile($localFilePath)'
      : 'PlaybackResolution.hls($hlsUrl)';
}

/// **Le résolveur offline-first.** Voir l'en-tête du fichier.
class DownloadResolver {
  DownloadResolver({required DownloadsDao dao, required NetworkStatus network})
      : _dao = dao,
        _network = network;

  final DownloadsDao _dao;
  final NetworkStatus _network;

  /// **La matrice de décision** (PRD §3.3) :
  ///
  /// | téléchargement | en ligne | hors ligne |
  /// | --- | --- | --- |
  /// | absent | HLS | HLS |
  /// | **complet** (ou « à mettre à jour ») | **local** | **local** |
  /// | **partiel** (octets reçus) | HLS | **local** |
  ///
  /// - **Complet → local partout** (F10) : un fichier prêt s'écoute en ligne
  ///   comme hors ligne, de façon transparente. `outdated` (révisé côté serveur,
  ///   ADR-0039) garde son fichier écoutable, donc se joue comme un complet.
  /// - **Partiel → local seulement hors ligne** (F11) : en ligne on préfère le
  ///   HLS **complet** plutôt que servir un tronqué alors qu'on pourrait
  ///   streamer en entier. Le fichier partiel étant de l'AAC-ADTS, sa lecture
  ///   locale s'arrête proprement à l'EOF des octets reçus (stop propre) — c'est
  ///   le lecteur qui l'assure, pas ce résolveur.
  /// - **Sinon → HLS**, le repli exact d'avant #191.
  ///
  /// L'état réseau n'est interrogé que lorsqu'un partiel est réellement en jeu
  /// (un chemin **et** des octets reçus) : le cas dominant — complet, ou pas de
  /// téléchargement — ne touche jamais au réseau.
  Future<PlaybackResolution> resolve({
    required String contentId,
    required String hlsUrl,
  }) async {
    final row = await _dao.forContent(contentId);
    if (row == null) return PlaybackResolution.hls(hlsUrl);

    final path = row.localPath;
    switch (row.state) {
      case DownloadState.complete:
      case DownloadState.outdated:
        // Le magasin fait foi : un complet a un fichier. Un chemin nul ne
        // devrait pas arriver, mais ne doit pas casser la lecture — repli HLS.
        if (path != null) return PlaybackResolution.localFile(path);
        return PlaybackResolution.hls(hlsUrl);

      case DownloadState.queued:
      case DownloadState.running:
      case DownloadState.paused:
      case DownloadState.waitingWifi:
      case DownloadState.failed:
        // Partiel : jouable localement **uniquement hors ligne** (F11).
        if (path != null &&
            row.bytesReceived > 0 &&
            await _network.isOffline()) {
          return PlaybackResolution.localFile(path);
        }
        return PlaybackResolution.hls(hlsUrl);
    }
  }
}
