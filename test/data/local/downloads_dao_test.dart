// Tests du **magasin des téléchargements** (`DownloadsDao`, #190).
//
// La table `downloads` est **locale seule** (même patron que
// `local_playback_positions`) : ce DAO écrit ET supprime librement, à la
// différence de `PlaybackDao`. Tout se joue sur une base en mémoire, sans
// appareil.

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/local/tables/download_tables.dart';

import 'local_database_fixtures.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = openTestDatabase());
  tearDown(() => db.close());

  DownloadsCompanion row(
    String contentId, {
    String quality = 'mid',
    DownloadState state = DownloadState.queued,
    int bytesReceived = 0,
    int bytesTotal = 0,
    String? taskId,
    String? localPath,
    String? versionId,
    DateTime? createdAt,
  }) =>
      DownloadsCompanion.insert(
        contentType: 'teaching',
        contentId: contentId,
        quality: quality,
        state: Value(state),
        bytesReceived: Value(bytesReceived),
        bytesTotal: Value(bytesTotal),
        taskId: Value(taskId),
        localPath: Value(localPath),
        versionId: Value(versionId),
        createdAt: createdAt ?? DateTime.utc(2026, 8, 15),
      );

  test('upsert puis lecture par contenu', () async {
    await db.downloadsDao.upsert(
      row('t-1', taskId: 'task-1', bytesTotal: 100, versionId: 'v1'),
    );

    final stored = await db.downloadsDao.forContent('t-1');
    expect(stored, isNotNull);
    expect(stored!.contentType, 'teaching');
    expect(stored.quality, 'mid');
    expect(stored.state, DownloadState.queued);
    expect(stored.bytesTotal, 100);
    expect(stored.taskId, 'task-1');
    expect(stored.versionId, 'v1');
  });

  test('upsert remplace la ligne du même contenu — une par contenu', () async {
    await db.downloadsDao.upsert(row('t-1', bytesTotal: 100));
    await db.downloadsDao.upsert(row('t-1', bytesTotal: 200, quality: 'high'));

    final all = await db.downloadsDao.all();
    expect(all, hasLength(1));
    expect(all.single.bytesTotal, 200);
    expect(all.single.quality, 'high');
  });

  test('forTask retrouve la ligne par identifiant de tâche natif', () async {
    await db.downloadsDao.upsert(row('t-1', taskId: 'task-abc'));

    final found = await db.downloadsDao.forTask('task-abc');
    expect(found?.contentId, 't-1');
    expect(await db.downloadsDao.forTask('inconnu'), isNull);
  });

  test('updateProgress écrit les octets reçus, et le total si fourni',
      () async {
    await db.downloadsDao.upsert(row('t-1', bytesTotal: 1000));

    await db.downloadsDao.updateProgress(contentId: 't-1', bytesReceived: 250);
    var stored = await db.downloadsDao.forContent('t-1');
    expect(stored!.bytesReceived, 250);
    expect(stored.bytesTotal, 1000,
        reason: 'le total ne bouge pas sans valeur');

    await db.downloadsDao
        .updateProgress(contentId: 't-1', bytesReceived: 500, bytesTotal: 1200);
    stored = await db.downloadsDao.forContent('t-1');
    expect(stored!.bytesReceived, 500);
    expect(stored.bytesTotal, 1200);
  });

  test('setState en échec conserve le partiel — localPath et octets intacts',
      () async {
    await db.downloadsDao.upsert(
      row(
        't-1',
        state: DownloadState.running,
        bytesReceived: 400,
        bytesTotal: 1000,
        localPath: '/data/t-1.mid.aac',
      ),
    );

    await db.downloadsDao.setState(
      contentId: 't-1',
      state: DownloadState.failed,
      failureReason: 'network',
    );

    final stored = await db.downloadsDao.forContent('t-1');
    expect(stored!.state, DownloadState.failed);
    expect(stored.failureReason, 'network');
    // Le partiel est **conservé** (F9) : ni le chemin ni les octets ne bougent.
    expect(stored.localPath, '/data/t-1.mid.aac');
    expect(stored.bytesReceived, 400);
  });

  test('setState complète : chemin résolu, motif d\'échec effacé', () async {
    await db.downloadsDao.upsert(
      row('t-1', state: DownloadState.failed, bytesTotal: 1000),
    );
    await db.downloadsDao
        .setState(contentId: 't-1', state: DownloadState.failed);

    await db.downloadsDao.setState(
      contentId: 't-1',
      state: DownloadState.complete,
      localPath: '/data/t-1.mid.aac',
      bytesReceived: 1000,
      clearFailureReason: true,
    );

    final stored = await db.downloadsDao.forContent('t-1');
    expect(stored!.state, DownloadState.complete);
    expect(stored.localPath, '/data/t-1.mid.aac');
    expect(stored.bytesReceived, 1000);
    expect(stored.failureReason, isNull);
  });

  test('watchForContent émet la ligne, puis ses changements', () async {
    final emissions = <DownloadRow?>[];
    final sub = db.downloadsDao.watchForContent('t-1').listen(emissions.add);
    // Laisse l'émission initiale (aucune ligne) partir avant d'écrire, sinon le
    // flux coalesce le null de départ avec la première écriture.
    await pumpEventQueue();

    await db.downloadsDao.upsert(row('t-1', state: DownloadState.queued));
    await pumpEventQueue();
    await db.downloadsDao
        .setState(contentId: 't-1', state: DownloadState.running);
    await pumpEventQueue();

    expect(emissions.first, isNull, reason: 'rien encore en magasin');
    expect(
        emissions.map((e) => e?.state),
        containsAllInOrder(
            [null, DownloadState.queued, DownloadState.running]));
    await sub.cancel();
  });

  test('watchAll trie du plus récent au plus ancien', () async {
    await db.downloadsDao
        .upsert(row('vieux', createdAt: DateTime.utc(2026, 1, 1)));
    await db.downloadsDao
        .upsert(row('recent', createdAt: DateTime.utc(2026, 8, 1)));

    final list = await db.downloadsDao.watchAll().first;
    expect(list.map((r) => r.contentId), ['recent', 'vieux']);
  });

  test('watchStorageUsage somme les octets reçus, partiels compris', () async {
    expect(await db.downloadsDao.watchStorageUsage().first, 0);

    await db.downloadsDao.upsert(
      row('t-1', state: DownloadState.complete, bytesReceived: 1000),
    );
    await db.downloadsDao.upsert(
      row('t-2', state: DownloadState.running, bytesReceived: 250),
    );

    expect(await db.downloadsDao.watchStorageUsage().first, 1250);
  });

  test('removeForContent efface la ligne — geste normal, table locale',
      () async {
    await db.downloadsDao.upsert(row('t-1'));
    await db.downloadsDao.removeForContent('t-1');
    expect(await db.downloadsDao.forContent('t-1'), isNull);
  });
}
