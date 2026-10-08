/// **Un Spark publié apparaît sans redémarrer** : le `sync.nudge` du canal
/// `users/{id}` lance un cycle, et le cycle tire l'annonce.
///
/// iPhone et iPad n'ont pas de push sans APNs : au premier plan, ce signal du
/// canal est le seul qui dise qu'une collection a bougé. Ce test suit le vrai
/// chemin — trame décodée, `MessagingLink`, `SyncScheduler.trigger(realtime)`,
/// `SyncEngine` sur le double du serveur, magasin.
library;

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/core/network/api_client.dart';
import 'package:maison_du_miracle/data/local/sync_dao.dart';
import 'package:maison_du_miracle/data/messaging/messaging_channel.dart';
import 'package:maison_du_miracle/data/messaging/messaging_link.dart';
import 'package:maison_du_miracle/data/sync/sync_api.dart';
import 'package:maison_du_miracle/data/sync/sync_engine.dart';
import 'package:maison_du_miracle/data/sync/sync_scheduler.dart';
import 'package:maison_du_miracle/data/sync/synced_collection.dart';

import '../data/local/local_database_fixtures.dart';
import '../helpers/fake_sync_server.dart';
import '../helpers/sync_fixtures.dart';

const String _me = '019a1000-0000-7000-8000-00000000me01';

class _Channel implements MessagingChannel {
  final controller = StreamController<MessagingEvent>();

  @override
  Stream<MessagingEvent> watch(String userId) => controller.stream;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('un nudge `announcements` reçu au premier plan fait apparaître le Spark',
      () async {
    final db = openTestDatabase();
    addTearDown(db.close);
    final cursor = serverCursor(
      updatedAtIso: '2026-05-20T18:00:00.000Z',
      id: fullAnnouncementPayload['id']!,
    );
    Map<String, Object?> manifest({required bool changed}) => {
          'scope_version': 1,
          'collections': [
            manifestEntry(
              SyncCollectionKey.announcements,
              partition: kSyncCollections[SyncCollectionKey.announcements]!,
              currentCursor: changed ? cursor : null,
              hasChanges: changed,
            ),
          ],
        };
    // Ouverture : rien. Puis le Spark est publié.
    final server = FakeSyncServer()
      ..serveManifests([manifest(changed: false), manifest(changed: true)])
      ..serveCollection(
        SyncCollectionKey.announcements,
        deltaPage(items: const [fullAnnouncementPayload], nextCursor: cursor),
      );
    final dio = Dio(BaseOptions(baseUrl: 'https://eenv.brainsial.com'))
      ..interceptors.add(unwrapEnvelopeInterceptor)
      ..httpClientAdapter = server;
    final scheduler = SyncScheduler(
      SyncEngine(
        api: SyncApi(dio: dio),
        dao: db.syncDao,
        collections: syncedCollections()
            .where((c) => c.key == SyncCollectionKey.announcements)
            .toList(growable: false),
      ).synchronize,
    );

    await scheduler.trigger(SyncTrigger.appStart);
    expect(await db.select(db.announcements).get(), isEmpty);

    final channel = _Channel();
    final link = MessagingLink(
      userId: _me,
      channel: channel,
      apply: (_) async => true,
      resynchronize: () => scheduler.trigger(SyncTrigger.realtime),
    );
    addTearDown(link.close);
    link.open();

    final nudge = decodeMessagingData(
      jsonEncode({
        'channel': userChannelName(_me),
        'payload': {'type': 'sync.nudge', 'collection': 'announcements'},
      }),
      channel: userChannelName(_me),
    )!;
    channel.controller.add(nudge);

    final deadline = DateTime.now().add(const Duration(seconds: 3));
    while ((await db.select(db.announcements).get()).isEmpty) {
      if (DateTime.now().isAfter(deadline)) {
        fail('le Spark n\'est jamais arrivé');
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    final rows = await db.select(db.announcements).get();
    expect(rows.single.id, fullAnnouncementPayload['id']);
    expect(scheduler.lastTrigger, SyncTrigger.realtime);
  });
}
