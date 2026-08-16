// Tests du **cycle de vie serveur ↔ copie locale** (`DownloadLifecycle`, #194).
//
// La réconciliation est une **méthode explicite** : on l'appelle, on n'observe
// aucun flux réactif. Elle se vérifie donc entièrement sur la VM Dart, sans se
// heurter à l'horloge factice de `flutter test`.
//
// Deux événements serveur, gestes opposés (ADR-0039) :
//   - révision (version changée) → `outdated`, fichier **conservé** ;
//   - retrait (enseignement absent du magasin) → purge (ligne + tâche + fichier)
//     + notification nommée.

import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/downloads/disk_space.dart';
import 'package:maison_du_miracle/data/downloads/download_lifecycle.dart';
import 'package:maison_du_miracle/data/downloads/download_manager.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/local/tables/download_tables.dart';
import 'package:maison_du_miracle/data/network/network_transport.dart';
import 'package:maison_du_miracle/models/teaching_download.dart';

import '../../helpers/fake_download_backend.dart';
import '../local/local_database_fixtures.dart';

TeachingDownload _download(String version) => TeachingDownload(
      version: version,
      durationSeconds: 3600,
      renditions: const {
        'mid': DownloadRendition(url: 'https://x/mid.aac', bytes: 200),
      },
    );

void main() {
  late AppDatabase db;
  late FakeDownloadBackend backend;
  late DownloadManager manager;
  late DownloadLifecycle lifecycle;

  setUp(() {
    db = openTestDatabase();
    backend = FakeDownloadBackend();
    manager = DownloadManager(
      dao: db.downloadsDao,
      backend: backend,
      diskSpace: const FixedDiskSpace(1000000),
      network: FixedNetworkTransport(),
      metadataFor: (id) => db.mediathequeDao.downloadFor(id),
      mobileDataAllowed: () async => false,
      newTaskId: () => 'task-1',
      now: () => DateTime.utc(2026, 8, 15),
    );
    manager.start();
    lifecycle = DownloadLifecycle(
      dao: db.downloadsDao,
      notifications: db.downloadNotificationsDao,
      manager: manager,
      syncStateFor: (id) => db.mediathequeDao.syncStateFor(id),
      now: () => DateTime.utc(2026, 8, 15),
    );
  });

  tearDown(() async {
    await manager.dispose();
    await backend.dispose();
    await db.close();
  });

  /// Un enseignement dans le magasin, avec son contrat de téléchargement.
  Future<void> seedTeaching(String id, {String version = 'v1'}) async {
    await db.into(db.teachings).insert(
          TeachingsCompanion.insert(
            id: id,
            title: 'La foi qui déplace les montagnes',
            download: Value(_download(version)),
          ),
        );
  }

  /// Une ligne `downloads` complète, avec un fichier réel sur le disque.
  Future<File> seedDownload(
    String id, {
    String versionId = 'v1',
    String? title = 'La foi qui déplace les montagnes',
    DownloadState state = DownloadState.complete,
  }) async {
    final file = File(
      '${Directory.systemTemp.createTempSync('dl').path}/$id.mid.aac',
    );
    await file.writeAsBytes(List<int>.filled(200, 0));
    await db.downloadsDao.upsert(
      DownloadsCompanion.insert(
        contentType: 'teaching',
        contentId: id,
        quality: 'mid',
        state: Value(state),
        bytesReceived: const Value(200),
        bytesTotal: const Value(200),
        versionId: Value(versionId),
        taskId: const Value('task-1'),
        localPath: Value(file.path),
        createdAt: DateTime.utc(2026, 8, 15),
      ),
    );
    await db.downloadsDao.setTitle(id, title);
    backend.active.add('task-1');
    return file;
  }

  group('révision (ADR-0039)', () {
    test('version changée ⇒ outdated, fichier conservé, aucune notification',
        () async {
      await seedTeaching('t-1', version: 'v2'); // le serveur a révisé
      final file = await seedDownload('t-1', versionId: 'v1');

      await lifecycle.reconcile();

      final row = await db.downloadsDao.forContent('t-1');
      expect(row!.state, DownloadState.outdated);
      expect(await file.exists(), isTrue, reason: 'jamais purger sur révision');
      expect(backend.canceled, isEmpty);
      expect(await db.downloadNotificationsDao.all(), isEmpty);
    });

    test('un partiel n\'est pas marqué périmé (seul un complété l\'est)',
        () async {
      await seedTeaching('t-1', version: 'v2');
      await seedDownload('t-1', versionId: 'v1', state: DownloadState.paused);

      await lifecycle.reconcile();

      expect((await db.downloadsDao.forContent('t-1'))!.state,
          DownloadState.paused);
    });
  });

  group('retrait (ADR-0025)', () {
    test('enseignement absent ⇒ purge (ligne + tâche + fichier) + notification',
        () async {
      // Aucun `seedTeaching` : l'enseignement a quitté le magasin.
      final file = await seedDownload('t-1', title: 'Le pardon');

      await lifecycle.reconcile();

      // La ligne, la tâche et le fichier sont partis.
      expect(await db.downloadsDao.forContent('t-1'), isNull);
      expect(backend.canceled, contains('task-1'));
      expect(await file.exists(), isFalse);

      // La notification nomme l'enseignement grâce au titre dénormalisé.
      final notices = await db.downloadNotificationsDao.all();
      expect(notices, hasLength(1));
      expect(notices.single.contentId, 't-1');
      expect(notices.single.title, 'Le pardon');
    });

    test('un second passage ne re-notifie pas (la ligne a disparu)', () async {
      await seedDownload('t-1', title: 'Le pardon');
      await lifecycle.reconcile();
      await lifecycle.reconcile();

      expect(await db.downloadNotificationsDao.all(), hasLength(1));
    });
  });

  group('inchangé', () {
    test('même version ⇒ rien : ni outdated, ni purge, ni notification',
        () async {
      await seedTeaching('t-1', version: 'v1');
      final file = await seedDownload('t-1', versionId: 'v1');

      await lifecycle.reconcile();

      final row = await db.downloadsDao.forContent('t-1');
      expect(row!.state, DownloadState.complete);
      expect(await file.exists(), isTrue);
      expect(await db.downloadNotificationsDao.all(), isEmpty);
    });
  });
}
