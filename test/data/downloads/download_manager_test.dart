// Tests du **moteur de téléchargement** (`DownloadManager`, #190).
//
// Tout le plugin est derrière `DownloadBackend`, faké ici : les décisions du
// manager — quelle rendition, pré-check disque, contrainte wifi, mapping d'état,
// réconciliation — se vérifient sur la VM Dart, sans appareil.

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/downloads/disk_space.dart';
import 'package:maison_du_miracle/data/downloads/download_backend.dart';
import 'package:maison_du_miracle/data/downloads/download_manager.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/local/tables/download_tables.dart';
import 'package:maison_du_miracle/data/network/network_transport.dart';
import 'package:maison_du_miracle/models/media_preferences.dart';
import 'package:maison_du_miracle/models/teaching_download.dart';

import '../../helpers/fake_download_backend.dart';
import '../local/local_database_fixtures.dart';

TeachingDownload _download({
  String version = 'v1',
  Map<String, DownloadRendition>? renditions,
}) =>
    TeachingDownload(
      version: version,
      durationSeconds: 3600,
      renditions: renditions ??
          const {
            'low': DownloadRendition(url: 'https://x/low.aac', bytes: 100),
            'mid': DownloadRendition(url: 'https://x/mid.aac', bytes: 200),
            'high': DownloadRendition(url: 'https://x/high.aac', bytes: 300),
          },
    );

void main() {
  late AppDatabase db;
  late FakeDownloadBackend backend;
  late FixedNetworkTransport network;

  // Générateur d'identifiants de tâche **déterministe**.
  late int taskCounter;
  String nextTaskId() => 'task-${++taskCounter}';

  DownloadManager build({
    int? freeBytes = 1000000,
    bool cellular = false,
    bool mobileDataAllowed = false,
    Map<String, TeachingDownload>? metadata,
  }) {
    network = FixedNetworkTransport(cellular: cellular);
    final store = metadata ?? {'t-1': _download()};
    final manager = DownloadManager(
      dao: db.downloadsDao,
      backend: backend,
      diskSpace: FixedDiskSpace(freeBytes),
      network: network,
      metadataFor: (id) async => store[id],
      mobileDataAllowed: () async => mobileDataAllowed,
      newTaskId: nextTaskId,
      now: () => DateTime.utc(2026, 8, 15),
    );
    manager.start();
    return manager;
  }

  setUp(() {
    db = openTestDatabase();
    backend = FakeDownloadBackend();
    taskCounter = 0;
  });

  tearDown(() async {
    await backend.dispose();
    await db.close();
  });

  group('enqueue', () {
    test('écrit une ligne en file et enqueue la rendition mid par défaut',
        () async {
      final manager = build();
      await manager.download(
        contentId: 't-1',
        contentType: 'teaching',
        quality: MediaQuality.auto,
        metadata: _download(version: 'v1'),
      );

      final row = await db.downloadsDao.forContent('t-1');
      expect(row!.state, DownloadState.queued);
      expect(row.quality, 'mid', reason: 'auto se replie sur mid (défaut F6)');
      expect(row.bytesTotal, 200);
      expect(row.versionId, 'v1');
      expect(row.taskId, 'task-1');

      expect(backend.enqueued, hasLength(1));
      expect(backend.enqueued.single.url, 'https://x/mid.aac');
      expect(backend.enqueued.single.filename, 't-1.mid.aac');
      // Wifi par défaut (F8) : la tâche exige le wifi.
      expect(backend.enqueued.single.requiresWifi, isTrue);
    });

    test('la qualité demandée absente se replie sur une autre', () async {
      final manager = build();
      await manager.download(
        contentId: 't-1',
        contentType: 'teaching',
        quality: MediaQuality.high,
        metadata: _download(
          renditions: const {
            'low': DownloadRendition(url: 'https://x/low.aac', bytes: 100),
          },
        ),
      );

      final row = await db.downloadsDao.forContent('t-1');
      expect(row!.quality, 'low');
      expect(backend.enqueued.single.url, 'https://x/low.aac');
    });

    test('pré-check espace : total > libre ⇒ échec, aucun enqueue', () async {
      final manager = build(freeBytes: 150);
      await manager.download(
        contentId: 't-1',
        contentType: 'teaching',
        quality: MediaQuality.mid, // 200 octets > 150 libres
        metadata: _download(),
      );

      final row = await db.downloadsDao.forContent('t-1');
      expect(row!.state, DownloadState.failed);
      expect(row.failureReason, kDownloadFailureInsufficientSpace);
      expect(row.bytesTotal, 200);
      expect(backend.enqueued, isEmpty);
    });

    test('espace inconnu ⇒ on laisse passer (fail-open)', () async {
      final manager = build(freeBytes: null);
      await manager.download(
        contentId: 't-1',
        contentType: 'teaching',
        quality: MediaQuality.mid,
        metadata: _download(),
      );

      expect((await db.downloadsDao.forContent('t-1'))!.state,
          DownloadState.queued);
      expect(backend.enqueued, hasLength(1));
    });

    test(
        'wifi-only sur cellulaire ⇒ « en attente de wifi », enqueue quand même',
        () async {
      final manager = build(cellular: true, mobileDataAllowed: false);
      await manager.download(
        contentId: 't-1',
        contentType: 'teaching',
        quality: MediaQuality.mid,
        metadata: _download(),
      );

      final row = await db.downloadsDao.forContent('t-1');
      expect(row!.state, DownloadState.waitingWifi);
      // La contrainte part au moteur natif, qui tient l'attente.
      expect(backend.enqueued.single.requiresWifi, isTrue);
    });

    test('données mobiles autorisées ⇒ pas de contrainte, file même en 4G',
        () async {
      final manager = build(cellular: true, mobileDataAllowed: true);
      await manager.download(
        contentId: 't-1',
        contentType: 'teaching',
        quality: MediaQuality.mid,
        metadata: _download(),
      );

      final row = await db.downloadsDao.forContent('t-1');
      expect(row!.state, DownloadState.queued);
      expect(backend.enqueued.single.requiresWifi, isFalse);
    });

    test('un refus du moteur ⇒ échec enqueue_rejected', () async {
      backend.enqueueResult = false;
      final manager = build();
      await manager.download(
        contentId: 't-1',
        contentType: 'teaching',
        quality: MediaQuality.mid,
        metadata: _download(),
      );

      final row = await db.downloadsDao.forContent('t-1');
      expect(row!.state, DownloadState.failed);
      expect(row.failureReason, kDownloadFailureEnqueueRejected);
    });

    test('un contenu déjà complet n\'est pas retéléchargé', () async {
      final manager = build();
      await db.downloadsDao.upsert(
        DownloadsCompanion.insert(
          contentType: 'teaching',
          contentId: 't-1',
          quality: 'mid',
          state: const Value(DownloadState.complete),
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      );

      await manager.download(
        contentId: 't-1',
        contentType: 'teaching',
        quality: MediaQuality.mid,
        metadata: _download(),
      );

      expect(backend.enqueued, isEmpty);
    });
  });

  group('rappels du moteur → écriture Drift', () {
    Future<DownloadManager> enqueued() async {
      final manager = build();
      await manager.download(
        contentId: 't-1',
        contentType: 'teaching',
        quality: MediaQuality.mid,
        metadata: _download(),
      );
      return manager;
    }

    test('progression : les octets reçus sont écrits', () async {
      await enqueued();
      await backend.emit(
        const DownloadProgressEvent('task-1',
            bytesReceived: 120, bytesTotal: 200),
      );

      expect((await db.downloadsDao.forContent('t-1'))!.bytesReceived, 120);
    });

    test('complétion : état complet, chemin résolu, reçu = total', () async {
      await enqueued();
      await backend.emit(
        const DownloadStatusEvent('task-1',
            status: DownloadBackendStatus.complete,
            filePath: '/data/t-1.mid.aac'),
      );

      final row = await db.downloadsDao.forContent('t-1');
      expect(row!.state, DownloadState.complete);
      expect(row.localPath, '/data/t-1.mid.aac');
      expect(row.bytesReceived, 200);
    });

    test('échec réseau : état failed, partiel conservé', () async {
      await enqueued();
      await backend.emit(
        const DownloadProgressEvent('task-1', bytesReceived: 90),
      );
      await backend.emit(
        const DownloadStatusEvent('task-1',
            status: DownloadBackendStatus.failed,
            failure: DownloadBackendFailure.other),
      );

      final row = await db.downloadsDao.forContent('t-1');
      expect(row!.state, DownloadState.failed);
      expect(row.failureReason, kDownloadFailureNetwork,
          reason: 'une clé stable, jamais la phrase anglaise du moteur natif');
      expect(row.bytesReceived, 90, reason: 'le partiel reste (F9)');
    });

    test('disque plein en cours : espace insuffisant, partiel conservé (F9)',
        () async {
      await enqueued();
      await backend.emit(
        const DownloadProgressEvent('task-1', bytesReceived: 90),
      );
      await backend.emit(
        const DownloadStatusEvent('task-1',
            status: DownloadBackendStatus.failed,
            failure: DownloadBackendFailure.insufficientSpace),
      );

      final row = await db.downloadsDao.forContent('t-1');
      expect(row!.state, DownloadState.failed);
      expect(row.failureReason, kDownloadFailureInsufficientSpace);
      expect(row.bytesReceived, 90, reason: 'le partiel reste (F9)');
    });

    // L'écart mesuré en production le 2026-10-15 (PRD §6, spike 3) : l'origine
    // **ignore** `If-Range` et répond `206` sur un validateur périmé. La garde
    // est la comparaison d'`ETag`, que le moteur natif fait et rapporte en
    // refus de reprise. Ce que le manager en fait est **tout** ce qui restait
    // à écrire — et sans lui la ligne mourait en `failed` : `reconcile()`
    // saute les échecs, personne ne la reprendrait jamais.
    test('reprise refusée (ETag changé) : on repart de zéro', () async {
      await enqueued();
      await backend.emit(
        const DownloadProgressEvent('task-1', bytesReceived: 90),
      );
      await db.downloadsDao.setState(
        contentId: 't-1',
        state: DownloadState.running,
        localPath: '/data/t-1.mid.aac',
      );
      backend.enqueued.clear();

      await backend.emit(
        const DownloadStatusEvent('task-1',
            status: DownloadBackendStatus.failed,
            failure: DownloadBackendFailure.resume),
      );

      final row = await db.downloadsDao.forContent('t-1');
      expect(row!.state, DownloadState.queued,
          reason: 'repartie, pas figée en échec');
      expect(row.bytesReceived, 0, reason: 'les octets d\'un autre corps');
      expect(row.localPath, isNull, reason: 'le partiel ne désigne plus rien');
      expect(backend.enqueued, hasLength(1));
      expect(backend.enqueued.single.taskId, isNot('task-1'),
          reason: 'un identifiant neuf : ce n\'est pas une reprise');
    });

    test('waitingToRetry ⇒ en attente de wifi', () async {
      await enqueued();
      await backend.emit(
        const DownloadStatusEvent('task-1',
            status: DownloadBackendStatus.waitingToRetry),
      );
      expect((await db.downloadsDao.forContent('t-1'))!.state,
          DownloadState.waitingWifi);
    });

    test('un rappel d\'une tâche inconnue est ignoré', () async {
      await enqueued();
      await backend.emit(
        const DownloadProgressEvent('fantome', bytesReceived: 999),
      );
      expect((await db.downloadsDao.forContent('t-1'))!.bytesReceived, 0);
    });
  });

  group('pause / reprise / annulation', () {
    Future<DownloadManager> running() async {
      final manager = build();
      await manager.download(
        contentId: 't-1',
        contentType: 'teaching',
        quality: MediaQuality.mid,
        metadata: _download(),
      );
      return manager;
    }

    test('pause : arrête la tâche et écrit l\'état', () async {
      final manager = await running();
      await manager.pause('t-1');
      expect(backend.paused, ['task-1']);
      expect((await db.downloadsDao.forContent('t-1'))!.state,
          DownloadState.paused);
    });

    test('reprise : relance la tâche et passe running', () async {
      final manager = await running();
      await manager.pause('t-1');
      await manager.resume('t-1');
      expect(backend.resumed, ['task-1']);
      expect((await db.downloadsDao.forContent('t-1'))!.state,
          DownloadState.running);
    });

    test('reprise wifi-only sur cellulaire ⇒ reste en attente, pas de relance',
        () async {
      final manager = await running();
      await manager.pause('t-1');
      network.emit(true); // bascule sur cellulaire
      await manager.resume('t-1');

      expect(backend.resumed, isEmpty);
      expect((await db.downloadsDao.forContent('t-1'))!.state,
          DownloadState.waitingWifi);
    });

    test('annulation : annule la tâche et efface la ligne', () async {
      final manager = await running();
      await manager.cancel('t-1');
      expect(backend.canceled, ['task-1']);
      expect(await db.downloadsDao.forContent('t-1'), isNull);
    });
  });

  group('réconciliation', () {
    test('une tâche inachevée oubliée du moteur est ré-enqueuée', () async {
      final manager = build();
      await manager.download(
        contentId: 't-1',
        contentType: 'teaching',
        quality: MediaQuality.mid,
        metadata: _download(),
      );
      // Le moteur natif a « oublié » la tâche (application tuée).
      backend.active.clear();
      backend.enqueued.clear();

      await manager.reconcile();

      expect(backend.enqueued, hasLength(1),
          reason: 'ré-enqueue par Range depuis le partiel');
      expect(backend.enqueued.single.url, 'https://x/mid.aac');
      expect((await db.downloadsDao.forContent('t-1'))!.state,
          DownloadState.queued);
    });

    test('une tâche encore connue du moteur n\'est pas ré-enqueuée', () async {
      final manager = build();
      await manager.download(
        contentId: 't-1',
        contentType: 'teaching',
        quality: MediaQuality.mid,
        metadata: _download(),
      );
      backend.enqueued.clear();
      // task-1 est toujours dans backend.active.

      await manager.reconcile();
      expect(backend.enqueued, isEmpty);
    });

    test('une ligne complète est laissée tranquille', () async {
      final manager = build();
      await db.downloadsDao.upsert(
        DownloadsCompanion.insert(
          contentType: 'teaching',
          contentId: 't-1',
          quality: 'mid',
          state: const Value(DownloadState.complete),
          taskId: const Value('task-old'),
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      );

      await manager.reconcile();
      expect(backend.enqueued, isEmpty);
      expect((await db.downloadsDao.forContent('t-1'))!.state,
          DownloadState.complete);
    });

    test('source disparue ⇒ échec source_gone', () async {
      final manager = build(metadata: {}); // plus aucune métadonnée
      await db.downloadsDao.upsert(
        DownloadsCompanion.insert(
          contentType: 'teaching',
          contentId: 't-1',
          quality: 'mid',
          state: const Value(DownloadState.running),
          taskId: const Value('task-old'),
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      );

      await manager.reconcile();
      final row = await db.downloadsDao.forContent('t-1');
      expect(row!.state, DownloadState.failed);
      expect(row.failureReason, kDownloadFailureSourceGone);
    });

    // La garde que l'application tient **hors ligne**, sans rien demander au
    // réseau : l'URL porte le `transcodeId`, donc une version neuve est un
    // autre fichier. Recoller son corps sur l'ancien partiel donnerait un
    // `.aac` qui n'est ni l'un ni l'autre — et aucun `If-Range` ne l'arrêterait,
    // cette origine l'ignorant (mesuré le 2026-10-15, PRD §6 spike 3).
    test('version du contrat changée ⇒ départ de zéro, pas une reprise',
        () async {
      final manager = build(
        metadata: {
          't-1': _download(
            version: 'v2',
            renditions: const {
              'mid': DownloadRendition(url: 'https://x/v2/mid.aac', bytes: 555),
            },
          ),
        },
      );
      await db.downloadsDao.upsert(
        DownloadsCompanion.insert(
          contentType: 'teaching',
          contentId: 't-1',
          quality: 'mid',
          state: const Value(DownloadState.running),
          bytesReceived: const Value(90),
          bytesTotal: const Value(200),
          localPath: const Value('/data/t-1.mid.aac'),
          taskId: const Value('task-old'),
          versionId: const Value('v1'),
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      );

      await manager.reconcile();

      final row = await db.downloadsDao.forContent('t-1');
      expect(row!.bytesReceived, 0);
      expect(row.bytesTotal, 555, reason: 'la taille du nouveau corps');
      expect(row.versionId, 'v2');
      expect(row.localPath, isNull);
      expect(backend.enqueued.single.url, 'https://x/v2/mid.aac');
      expect(backend.enqueued.single.taskId, isNot('task-old'),
          reason: 'identifiant neuf : le moteur natif ne doit pas reprendre');
    });

    test('version inchangée ⇒ on reprend sur le partiel', () async {
      final manager = build();
      await db.downloadsDao.upsert(
        DownloadsCompanion.insert(
          contentType: 'teaching',
          contentId: 't-1',
          quality: 'mid',
          state: const Value(DownloadState.running),
          bytesReceived: const Value(90),
          bytesTotal: const Value(200),
          localPath: const Value('/data/t-1.mid.aac'),
          taskId: const Value('task-old'),
          versionId: const Value('v1'),
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      );

      await manager.reconcile();

      final row = await db.downloadsDao.forContent('t-1');
      expect(row!.bytesReceived, 90, reason: 'le partiel vaut encore');
      expect(row.localPath, '/data/t-1.mid.aac');
      expect(backend.enqueued.single.taskId, 'task-old');
    });
  });
}
