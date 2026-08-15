import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';

import '../../models/media_preferences.dart';
import '../../models/teaching_download.dart';
import '../local/app_database.dart';
import '../local/downloads_dao.dart';
import '../local/tables/download_tables.dart';
import '../network/network_transport.dart';
import 'disk_space.dart';
import 'download_backend.dart';

/// Motifs d'échec, en **clés stables** — l'écran choisira la phrase (#192/#193).
/// Une erreur ne sort jamais en brut ; ce sont des jetons, pas des messages.
const String kDownloadFailureInsufficientSpace = 'insufficient_space';
const String kDownloadFailureEnqueueRejected = 'enqueue_rejected';
const String kDownloadFailureResumeRejected = 'resume_rejected';
const String kDownloadFailureSourceGone = 'source_gone';
const String kDownloadFailureNetwork = 'network';

/// **Le moteur de téléchargement hors ligne** (#190) — il mappe la table
/// `downloads` ⇄ les tâches `background_downloader`, et il est le **seul** à le
/// faire.
///
/// Il tient trois rôles, et un seul principe les gouverne (ADR-0026) : **le
/// magasin peint l'écran, le réseau jamais.**
///
/// 1. **Commander** — [download], [pause], [resume], [cancel] : il décide (quelle
///    rendition, quelle contrainte, y a-t-il la place) puis parle au moteur natif
///    par [DownloadBackend].
/// 2. **Écouter et écrire** — il s'abonne aux rappels bruts du moteur ([start])
///    et **écrit l'état et la progression dans Drift**. Les écrans observent
///    Drift, jamais ce moteur ni le réseau.
/// 3. **Réconcilier** — [reconcile] au démarrage et au retour au premier plan :
///    une tâche que le moteur natif a oubliée (application tuée) est
///    ré-enqueuée, reprise **par `Range`** grâce aux octets déjà sur le disque.
///
/// **Tout le plugin est derrière [DownloadBackend]** : ce fichier ne l'importe
/// pas et se teste donc entièrement sur la VM Dart. Les décisions (wifi, disque,
/// mapping d'état) vivent ici ; #191–#194 s'appuient sur ces primitives sans
/// jamais toucher au plugin.
class DownloadManager {
  DownloadManager({
    required DownloadsDao dao,
    required DownloadBackend backend,
    required DiskSpace diskSpace,
    required NetworkTransport network,
    required Future<TeachingDownload?> Function(String contentId) metadataFor,
    Future<bool> Function()? mobileDataAllowed,
    String Function()? newTaskId,
    DateTime Function()? now,
  })  : _dao = dao,
        _backend = backend,
        _diskSpace = diskSpace,
        _network = network,
        _metadataFor = metadataFor,
        // Défaut **wifi-only** (F8) : sans réglage « données mobiles » (le
        // toggle est #192/#193), la contrainte penche du côté sûr — on ne
        // consomme pas le forfait d'un fidèle sans qu'il l'ait choisi.
        _mobileDataAllowed = mobileDataAllowed ?? (() async => false),
        _newTaskId = newTaskId ?? (() => const Uuid().v7()),
        _now = now ?? (() => DateTime.now().toUtc());

  final DownloadsDao _dao;
  final DownloadBackend _backend;
  final DiskSpace _diskSpace;
  final NetworkTransport _network;
  final Future<TeachingDownload?> Function(String contentId) _metadataFor;
  final Future<bool> Function() _mobileDataAllowed;
  final String Function() _newTaskId;
  final DateTime Function() _now;

  StreamSubscription<DownloadBackendEvent>? _subscription;

  /// Abonne le moteur aux rappels du transport. Idempotent : un second appel ne
  /// double pas l'abonnement (le provider n'est pas `autoDispose`, mais un
  /// `start()` de trop ne doit pas peindre deux fois).
  void start() {
    _subscription ??= _backend.events.listen(_onEvent);
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  /// **Lance (ou relance) le téléchargement d'un contenu.**
  ///
  /// [quality] est le réglage « Téléchargement » (défaut `mid`, F6) ; [auto] et
  /// une qualité absente se replient sur un palier concret disponible — un
  /// fichier `.aac` a toujours une qualité, jamais « automatique ».
  ///
  /// Un contenu **déjà complet** n'est pas retéléchargé. Un échec ou un état en
  /// cours est **écrasé** — relancer est le geste normal de « réessayer ».
  Future<void> download({
    required String contentId,
    required String contentType,
    required MediaQuality quality,
    required TeachingDownload metadata,
  }) async {
    final existing = await _dao.forContent(contentId);
    if (existing != null && existing.state == DownloadState.complete) return;

    final resolved = _resolveRendition(quality, metadata);
    if (resolved == null) return; // rien de téléchargeable, rien à écrire.
    final (chosenQuality, rendition) = resolved;

    // Pré-check espace (F9). Inconnu ⇒ on laisse passer (fail-open, cf.
    // [DiskSpace]) ; le disque plein en cours se rattrape en échec + partiel.
    final free = await _diskSpace.freeBytes();
    if (free != null && rendition.bytes > free) {
      await _dao.upsert(
        DownloadsCompanion.insert(
          contentType: contentType,
          contentId: contentId,
          quality: chosenQuality.key,
          state: const Value(DownloadState.failed),
          bytesTotal: Value(rendition.bytes),
          versionId: Value(metadata.version),
          createdAt: _now(),
          failureReason: const Value(kDownloadFailureInsufficientSpace),
        ),
      );
      return;
    }

    final requiresWifi = !await _mobileDataAllowed();
    final held = requiresWifi && await _network.isOnCellular();
    final taskId = _newTaskId();

    await _dao.upsert(
      DownloadsCompanion.insert(
        contentType: contentType,
        contentId: contentId,
        quality: chosenQuality.key,
        state: Value(held ? DownloadState.waitingWifi : DownloadState.queued),
        bytesTotal: Value(rendition.bytes),
        versionId: Value(metadata.version),
        taskId: Value(taskId),
        createdAt: _now(),
      ),
    );

    final ok = await _backend.enqueue(
      DownloadTaskSpec(
        taskId: taskId,
        url: rendition.url,
        filename: _filenameFor(contentId, chosenQuality),
        requiresWifi: requiresWifi,
      ),
    );
    if (!ok) {
      await _dao.setState(
        contentId: contentId,
        state: DownloadState.failed,
        failureReason: kDownloadFailureEnqueueRejected,
      );
    }
  }

  /// Met en pause. Le partiel reste sur le disque, reprenable par `Range`.
  Future<void> pause(String contentId) async {
    final row = await _dao.forContent(contentId);
    final taskId = row?.taskId;
    if (taskId == null) return;
    await _backend.pause(taskId);
    await _dao.setState(contentId: contentId, state: DownloadState.paused);
  }

  /// Reprend un téléchargement en pause ou en attente.
  ///
  /// Respecte la contrainte wifi : wifi-only sur cellulaire ⇒ l'item reste « en
  /// attente de wifi » plutôt que de partir sur le forfait.
  Future<void> resume(String contentId) async {
    final row = await _dao.forContent(contentId);
    final taskId = row?.taskId;
    if (taskId == null) return;

    final requiresWifi = !await _mobileDataAllowed();
    if (requiresWifi && await _network.isOnCellular()) {
      await _dao.setState(
        contentId: contentId,
        state: DownloadState.waitingWifi,
      );
      return;
    }

    final ok = await _backend.resume(taskId);
    if (ok) {
      await _dao.setState(
        contentId: contentId,
        state: DownloadState.running,
        clearFailureReason: true,
      );
    } else {
      await _dao.setState(
        contentId: contentId,
        state: DownloadState.failed,
        failureReason: kDownloadFailureResumeRejected,
      );
    }
  }

  /// **Annule** un téléchargement : arrête la tâche, efface la ligne **et** le
  /// fichier partiel. C'est la primitive mécanique ; la confirmation avant de
  /// jeter un contenu prêt est une décision d'écran (#193).
  Future<void> cancel(String contentId) async {
    final row = await _dao.forContent(contentId);
    if (row == null) return;
    final taskId = row.taskId;
    if (taskId != null) await _backend.cancel(taskId);
    await _deleteFileIfAny(row.localPath);
    await _dao.removeForContent(contentId);
  }

  /// **Réconcilie** la table avec le moteur natif — au démarrage et au retour
  /// au premier plan.
  ///
  /// Une ligne inachevée dont la tâche n'est plus connue du moteur (application
  /// tuée, tâche oubliée) est ré-enqueuée : `background_downloader` reprend par
  /// `Range` sur le partiel déjà écrit. Les URLs viennent de `teachings.download`
  /// (via [metadataFor]) — le moteur les connaît **hors ligne**, sans réseau.
  Future<void> reconcile() async {
    final rows = await _dao.all();
    final active = await _backend.activeTaskIds();
    for (final row in rows) {
      if (row.state == DownloadState.complete) continue;
      if (row.state == DownloadState.failed) continue;
      final taskId = row.taskId;
      if (taskId != null && active.contains(taskId)) continue;
      await _reEnqueue(row);
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Rappels du moteur natif → écriture dans Drift
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> _onEvent(DownloadBackendEvent event) async {
    final row = await _dao.forTask(event.taskId);
    if (row == null) return; // tâche annulée : la ligne est déjà partie.

    switch (event) {
      case DownloadProgressEvent(:final bytesReceived, :final bytesTotal):
        await _dao.updateProgress(
          contentId: row.contentId,
          bytesReceived: bytesReceived,
          bytesTotal:
              (bytesTotal != null && bytesTotal > 0) ? bytesTotal : null,
        );
      case DownloadStatusEvent(:final status, :final filePath, :final reason):
        await _applyStatus(row, status, filePath: filePath, reason: reason);
    }
  }

  Future<void> _applyStatus(
    DownloadRow row,
    DownloadBackendStatus status, {
    String? filePath,
    String? reason,
  }) async {
    switch (status) {
      case DownloadBackendStatus.enqueued:
      case DownloadBackendStatus.running:
        await _dao.setState(
          contentId: row.contentId,
          state: DownloadState.running,
          clearFailureReason: true,
        );
      case DownloadBackendStatus.paused:
        await _dao.setState(
          contentId: row.contentId,
          state: DownloadState.paused,
        );
      case DownloadBackendStatus.waitingToRetry:
        await _dao.setState(
          contentId: row.contentId,
          state: DownloadState.waitingWifi,
        );
      case DownloadBackendStatus.complete:
        await _dao.setState(
          contentId: row.contentId,
          state: DownloadState.complete,
          localPath: filePath,
          // Le total connu depuis l'enqueue fait foi : à la complétion, reçu =
          // total, même si le dernier rappel de progression a manqué.
          bytesReceived: row.bytesTotal,
          clearFailureReason: true,
        );
      case DownloadBackendStatus.failed:
        // Le partiel est **conservé** (F9) : `setState` ne touche pas au
        // `localPath` ni aux octets reçus.
        await _dao.setState(
          contentId: row.contentId,
          state: DownloadState.failed,
          failureReason: reason ?? kDownloadFailureNetwork,
        );
      case DownloadBackendStatus.canceled:
      case DownloadBackendStatus.notFound:
        // Rien : une annulation a déjà retiré la ligne, et une tâche inconnue
        // sera reprise par [reconcile], pas peinte en échec dans le dos.
        break;
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Rouages
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> _reEnqueue(DownloadRow row) async {
    final metadata = await _metadataFor(row.contentId);
    final quality = MediaQuality.parse(row.quality);
    final rendition = metadata?.renditionFor(quality);
    if (metadata == null || rendition == null) {
      await _dao.setState(
        contentId: row.contentId,
        state: DownloadState.failed,
        failureReason: kDownloadFailureSourceGone,
      );
      return;
    }

    final requiresWifi = !await _mobileDataAllowed();
    final held = requiresWifi && await _network.isOnCellular();
    final taskId = row.taskId ?? _newTaskId();

    await _dao.setState(
      contentId: row.contentId,
      state: held ? DownloadState.waitingWifi : DownloadState.queued,
      taskId: taskId,
      clearFailureReason: true,
    );

    final ok = await _backend.enqueue(
      DownloadTaskSpec(
        taskId: taskId,
        url: rendition.url,
        filename: _filenameFor(row.contentId, quality),
        requiresWifi: requiresWifi,
      ),
    );
    if (!ok) {
      await _dao.setState(
        contentId: row.contentId,
        state: DownloadState.failed,
        failureReason: kDownloadFailureEnqueueRejected,
      );
    }
  }

  /// La rendition à télécharger, et la qualité concrète retenue — ou `null` si
  /// l'enseignement n'a aucun fichier.
  ///
  /// Ordre de repli : la qualité demandée d'abord, puis les autres. `auto` (et
  /// une qualité absente) part de `mid` — le défaut du réglage « Téléchargement »
  /// (F6). En dernier ressort, **n'importe quelle** rendition présente : mieux
  /// vaut un palier inattendu qu'un bouton mort.
  (MediaQuality, DownloadRendition)? _resolveRendition(
    MediaQuality quality,
    TeachingDownload metadata,
  ) {
    for (final candidate in _preferenceOrder(quality)) {
      final rendition = metadata.renditionFor(candidate);
      if (rendition != null) return (candidate, rendition);
    }
    // Une clé hors échelle (variante future) : on prend la première offerte,
    // rangée sous la qualité qui la nomme si on la connaît, sinon `mid`.
    for (final entry in metadata.renditions.entries) {
      return (MediaQuality.parse(entry.key), entry.value);
    }
    return null;
  }

  List<MediaQuality> _preferenceOrder(MediaQuality quality) {
    switch (quality) {
      case MediaQuality.low:
        return const [MediaQuality.low, MediaQuality.mid, MediaQuality.high];
      case MediaQuality.high:
        return const [MediaQuality.high, MediaQuality.mid, MediaQuality.low];
      case MediaQuality.mid:
      case MediaQuality.auto:
        return const [MediaQuality.mid, MediaQuality.high, MediaQuality.low];
    }
  }

  String _filenameFor(String contentId, MediaQuality quality) =>
      '$contentId.${quality.key}.aac';

  Future<void> _deleteFileIfAny(String? path) async {
    if (path == null) return;
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
