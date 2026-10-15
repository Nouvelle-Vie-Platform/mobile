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

import '../../models/teaching_download.dart';
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
  const PlaybackResolution._({
    this.localFilePath,
    this.hlsUrl,
    this.contractDuration,
  });

  /// Jouer le **fichier local** (complet, ou partiel hors ligne), avec la durée
  /// du contrat quand le magasin la connaît (#222).
  const PlaybackResolution.localFile(String path, {Duration? contractDuration})
      : this._(localFilePath: path, contractDuration: contractDuration);

  /// Jouer le **HLS** — le comportement d'avant #191, repli exact.
  const PlaybackResolution.hls(String url) : this._(hlsUrl: url);

  /// Le chemin du fichier `.aac` à jouer, ou `null` si la source est le HLS.
  final String? localFilePath;

  /// L'URL HLS à jouer, ou `null` si la source est un fichier local.
  final String? hlsUrl;

  /// **La durée que le contrat de synchronisation déclare** (#222), portée
  /// **uniquement** sur une résolution locale — `null` en HLS, où la mesure du
  /// lecteur est juste et reste seule en piste.
  ///
  /// Elle est ici parce qu'un `.aac` ne peut pas la dire : l'ADTS n'écrit sa
  /// durée nulle part et l'encodeur est ABR, donc le lecteur ne fait que
  /// l'estimer — jusqu'à 1,02 s d'écart mesuré (mobile#215), et −0,9 % à +4,8 %
  /// pour une estimation par le conteneur (streaming-service#55), soit ~6
  /// minutes sur deux heures d'enseignement. `download.durationSeconds`, elle,
  /// est mesurée sur la **source** au transcodage, et c'est la seule durée
  /// disponible hors ligne : `teachings` n'en porte aucune colonne.
  ///
  /// `null` même en local est un cas normal, pas une panne : un fonds ancien
  /// jamais re-transcodé n'a pas de contrat. L'affichage retombe alors sur le
  /// lecteur, exactement comme avant.
  final Duration? contractDuration;

  /// Vrai quand la source résolue est un fichier local.
  bool get isLocal => localFilePath != null;

  @override
  bool operator ==(Object other) =>
      other is PlaybackResolution &&
      other.localFilePath == localFilePath &&
      other.hlsUrl == hlsUrl &&
      other.contractDuration == contractDuration;

  @override
  int get hashCode => Object.hash(localFilePath, hlsUrl, contractDuration);

  @override
  String toString() => isLocal
      ? 'PlaybackResolution.localFile($localFilePath)'
      : 'PlaybackResolution.hls($hlsUrl)';
}

/// **Le résolveur offline-first.** Voir l'en-tête du fichier.
class DownloadResolver {
  DownloadResolver({
    required DownloadsDao dao,
    required NetworkStatus network,
    required this.metadataFor,
  })  : _dao = dao,
        _network = network;

  final DownloadsDao _dao;
  final NetworkStatus _network;

  /// **Le contrat de téléchargement d'un contenu** (`teachings.download`), lu
  /// hors ligne — la seule source d'une durée juste sur un `.aac` (#222).
  ///
  /// Une dépendance et non un drapeau facultatif : l'oublier referait afficher
  /// la durée du lecteur sans que rien ne le dise.
  final Future<TeachingDownload?> Function(String contentId) metadataFor;

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
        if (path != null) return _local(contentId, path);
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
          return _local(contentId, path);
        }
        return PlaybackResolution.hls(hlsUrl);
    }
  }

  /// Une résolution locale, **avec la durée du contrat** (#222).
  ///
  /// La même pour un complet et pour un **partiel** : c'est la durée de
  /// l'enseignement, pas celle des octets reçus. Un partiel joué hors ligne
  /// s'arrête donc à l'EOF en montrant `1:10:00 / 2:00:00` — ce qui est vrai, et
  /// dit au fidèle qu'il lui manque la fin. L'autre choix — la durée des octets
  /// reçus — serait une estimation (celle que cette tranche supprime), ferait
  /// passer un enseignement de deux heures pour un d'une heure dix, et ferait
  /// enregistrer « terminé » au bout du tronçon.
  Future<PlaybackResolution> _local(String contentId, String path) async {
    final contract = await metadataFor(contentId);
    return PlaybackResolution.localFile(
      path,
      contractDuration: contract?.duration,
    );
  }
}
