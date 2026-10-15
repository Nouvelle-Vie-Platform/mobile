import '../../../models/media_preferences.dart';
import '../../downloads/disk_space.dart';
import '../../local/group_dao.dart' show MediaToDescend;
import '../../network/network_transport.dart';
import 'group_media_urls.dart';

/// **La descente des médias reçus** (T3, #225) — la file de fond qui rend le
/// fil consultable hors ligne sans un geste, **en wifi seulement** par défaut.
///
/// ## Pourquoi une file à part, et non `DownloadManager`
///
/// Le moteur de `lib/data/downloads/` sait déjà faire file de fond, attente du
/// wifi et pré-check d'espace. On ne s'y branche pourtant pas, et la raison
/// n'est pas le vocabulaire (`Downloads`, la qualité, le bouton à cinq états) :
/// c'est que **son contrat d'URL est l'inverse du nôtre**.
///
/// Il confie l'URL au moteur natif, qui la garde, la rejoue au redémarrage et
/// reprend par `Range` — ce qui n'est possible que parce qu'une URL
/// d'enseignement est **stable et connue hors ligne** (ADR-0038). Un média de
/// message n'a pas d'URL : il a une **clé**, qu'on échange contre une URL
/// présignée valable une heure (`GroupMediaUrls.resolve`). Une tâche persistée
/// se réveillerait sur une URL morte, et le moteur n'a aucun moyen de la
/// renouveler — il faudrait lui apprendre à redemander, c'est-à-dire lui
/// apprendre notre résolution. Ajoutons que la reprise par `Range` ne vaut rien
/// ici : `If-Range` est ignoré par cette origine (`streaming-service`
/// ADR-0012), et nos fichiers sont de taille de message, pas d'heure d'écoute.
///
/// Ce qui est réellement partagé a donc été **réutilisé, pas recopié** :
/// [NetworkTransport] pour le wifi, [DiskSpace] pour l'espace, et
/// [GroupMediaUrls.download] — qui porte déjà la résolution, le test du disque
/// avant le réseau, l'écriture en `.part` puis le renommage atomique, et la
/// note au magasin (T1, #223). Il ne reste ici que l'ordonnancement.
///
/// ## Il n'y a ni table de file ni palier Drift
///
/// La file est **dérivée** du magasin (`GroupDao.watchMediaToDescend`) et le
/// réglage vit dans `app_settings`, qui est clé/valeur. Rien à réconcilier,
/// rien à migrer.
///
/// ## Deux déclencheurs, une seule règle réseau
///
/// - **l'arrivée** : [pump] est appelé après chaque cycle de synchronisation
///   réussi (`app.dart`). C'est exactement « à la réception » — le canal temps
///   réel déclenche un cycle quand un message entre, et le retour du réseau en
///   déclenche un autre en se reconnectant. Pas de minuterie, pas d'abonnement
///   de plus : le dépôt n'en veut pas (`SyncScheduler`, « jamais de polling »).
/// - **l'affichage** : [keep] note un média qu'une bulle vient de peindre, même
///   antérieur à ce chantier. Il passe par la **même** file, donc par la même
///   règle réseau : peindre une image coûte déjà ses octets, mais l'écrire sur
///   le disque en coûterait une **seconde** fois — pas sur le forfait de
///   quelqu'un qui n'a rien demandé.
class MessageMediaQueue {
  MessageMediaQueue({
    required Future<List<MediaToDescend>> Function() arrived,
    required GroupMediaUrls urls,
    required NetworkTransport network,
    required Future<ChatMediaDescent> Function() descent,
    DiskSpace diskSpace = const BestEffortDiskSpace(),
  })  : _arrived = arrived,
        _urls = urls,
        _network = network,
        _descent = descent,
        _diskSpace = diskSpace;

  /// **Ce qui est arrivé et n'est pas encore sur l'appareil**, lu à la demande.
  ///
  /// Un rappel et non le DAO : cette file n'a alors **aucun magasin**, elle
  /// n'ordonne que des décisions. Elle se vérifie donc sans base — et un test
  /// d'écran peut la monter sans ouvrir un flux Drift, que l'horloge factice de
  /// `testWidgets` ne fait jamais avancer. C'est le provider qui compose la
  /// lecture et sa frontière (`SettingsDao.chatMediaDescentSince`).
  final Future<List<MediaToDescend>> Function() _arrived;
  final GroupMediaUrls _urls;
  final NetworkTransport _network;
  final Future<ChatMediaDescent> Function() _descent;
  final DiskSpace _diskSpace;

  /// Les médias **affichés** qu'on garde, en attente de leur tour. En mémoire
  /// seulement : les perdre au redémarrage ne perd rien — rouvrir le fil les
  /// redemande, et c'est le geste même qui les a mis là.
  final List<MediaToDescend> _displayed = [];

  /// **Un passage à la fois.** Même raison que `DownloadManager._handling` :
  /// deux passages concurrents descendraient deux fois le même média, et le
  /// `.part` de l'un écraserait celui de l'autre. Le chaînage sérialise, et
  /// `catchError` évite qu'un passage en erreur condamne tous les suivants.
  Future<void> _inFlight = Future<void>.value();

  /// Au-delà de trois échecs d'affilée, on arrête le passage : ce n'est plus un
  /// média fautif, c'est le réseau. Le prochain cycle réessaiera. Sans cette
  /// borne, une coupure ferait défiler toute la file en pure perte ; sans le
  /// « d'affilée », un seul média définitivement cassé (404) bloquerait pour
  /// toujours tout ce qui est derrière lui.
  static const int _maxConsecutiveFailures = 3;

  /// **Descend ce qui doit l'être**, puis rend la main. Idempotent, et sans
  /// effet quand le réglage ou le réseau l'interdit.
  Future<void> pump() {
    return _inFlight = _inFlight.then((_) => _run()).catchError((Object _) {});
  }

  /// **Garde un média que la bulle vient d'afficher** — l'historique qui se
  /// remplit au fil de la navigation.
  ///
  /// [mediaKey] est la clé du magasin ; son dernier segment nomme le fichier,
  /// comme dans `GroupDao.watchMediaToDescend`. Ne rend rien et n'attend rien :
  /// il est appelé depuis le chemin d'affichage d'une bulle, qui ne doit pas
  /// dépendre du disque.
  void keep({
    required String groupId,
    required String messageId,
    required String mediaKey,
    String? thumbnailKey,
    int? sizeBytes,
  }) {
    if (_displayed.any((m) => m.messageId == messageId)) return;
    _displayed.add(
      MediaToDescend(
        messageId: messageId,
        groupId: groupId,
        fileName: mediaKey.split('/').last,
        thumbFileName: thumbnailKey?.split('/').last,
        sizeBytes: sizeBytes,
      ),
    );
    pump();
  }

  Future<void> _run() async {
    final choice = await _descent();
    if (choice == ChatMediaDescent.never) {
      // Rien ne descend tout seul : on n'accumule pas une file que personne ne
      // videra jamais.
      _displayed.clear();
      return;
    }
    // Le réseau est consulté **une fois par passage**, au moment de décider —
    // jamais observé. Sur données mobiles sans accord, on repart sans rien
    // descendre et sans rien perdre : le prochain cycle (le retour du wifi
    // reconnecte le canal, donc en déclenche un) reprendra la même file, qui
    // est dérivée du magasin.
    if (!choice.allowsCellular && await _network.isOnCellular()) return;

    // Les médias affichés d'abord : quelqu'un les regarde.
    final arrived = await _arrived();
    final seen = <String>{};
    final queue = [
      for (final media in [..._displayed, ...arrived])
        if (seen.add(media.messageId)) media,
    ];

    // **Le pré-check d'espace, avant le premier octet** : la taille vient du
    // serveur (`group_messages.media_size`), donc on la connaît sans rien
    // télécharger. L'espace libre, lui, est **inconnu** sur ce socle —
    // `BestEffortDiskSpace` rend `null` faute d'API Dart multiplateforme —, et
    // l'inconnu laisse passer (fail-open, voir [DiskSpace]). Le filet réel
    // reste donc celui du système au moment d'écrire ; cette garde-ci devient
    // vraie le jour où `freeBytes()` rend un nombre, sans toucher à ce fichier.
    var remaining = await _diskSpace.freeBytes();
    var failures = 0;

    for (final media in queue) {
      final size = media.sizeBytes;
      if (remaining != null && size != null && size > remaining) continue;

      final path = await _urls.download(
        groupId: media.groupId,
        messageId: media.messageId,
        fileName: media.fileName,
      );
      if (path == null) {
        if (++failures >= _maxConsecutiveFailures) return;
        continue;
      }
      failures = 0;
      if (remaining != null && size != null) remaining -= size;
      _displayed.removeWhere((m) => m.messageId == media.messageId);

      final thumb = media.thumbFileName;
      if (thumb == null) continue;
      // La vignette **après** le fichier : c'est le fichier qui rend le fil
      // consultable hors ligne, et son échec rend l'une comme l'autre inutile.
      await _urls.download(
        groupId: media.groupId,
        messageId: media.messageId,
        fileName: thumb,
        thumbnail: true,
      );
    }
  }
}
