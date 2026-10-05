/// **Au retour dans l'application, la liste voit ce que le réveil de fond a
/// écrit** (#138).
///
/// Le réveil push d'une application en arrière-plan (`push_background.dart`)
/// ouvre une **seconde** `AppDatabase` sur le même fichier, tire, écrit les
/// lignes **et avance le curseur**. Les flux `watch()` de l'isolate principal
/// n'en savent rien : drift ne prévient que les écouteurs de **sa** connexion.
/// Puis, au retour, le cycle du planificateur trouve un curseur déjà avancé, le
/// serveur répond « rien à tirer », rien n'est écrit — et aucun flux ne se
/// relit. La liste des Échanges restait périmée jusqu'au redémarrage.
///
/// Ce fichier rejoue exactement cela : deux connexions sur un même fichier
/// temporaire, le vrai `SyncEngine` restreint du réveil de fond sur la seconde,
/// et le **vrai chemin du retour** sur la première — `syncSchedulerProvider`
/// tel que l'application le câble, notifié par `didChangeAppLifecycleState`.
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/core/network/api_client.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/local/group_dao.dart';
import 'package:maison_du_miracle/data/local/sync_dao.dart';
import 'package:maison_du_miracle/data/sync/sync_api.dart';
import 'package:maison_du_miracle/data/sync/sync_engine.dart';
import 'package:maison_du_miracle/data/sync/sync_scheduler.dart';
import 'package:maison_du_miracle/data/sync/synced_collection.dart';
import 'package:maison_du_miracle/state/sync_providers.dart';

import '../helpers/fake_sync_server.dart';
import '../helpers/sync_fixtures.dart';

/// Les cinq collections d'« Échanges », dans l'ordre du registre.
const List<String> _echanges = [
  SyncCollectionKey.profiles,
  SyncCollectionKey.groups,
  SyncCollectionKey.groupMembers,
  SyncCollectionKey.groupJoinRequests,
  SyncCollectionKey.groupMessages,
];

/// Ce que tire un réveil de groupe (`PushWakeHandler`) : quatre collections.
const List<String> _groupWake = [
  SyncCollectionKey.profiles,
  SyncCollectionKey.groups,
  SyncCollectionKey.groupMembers,
  SyncCollectionKey.groupMessages,
];

/// Le message que seul le réveil de fond a vu passer.
const Map<String, Object?> _wakeMessagePayload = {
  'id': '019a3000-0000-7000-8000-00000000msg9',
  'groupId': kGroupId,
  'authorId': kPeerId,
  'isSystem': false,
  'body': 'Arrivé pendant que l\'application dormait.',
  'clientMessageId': null,
  'clientCreatedAt': null,
  'createdAt': '2026-09-06T12:00:00.000Z',
  'deletedAt': null,
};

void main() {
  late Directory dir;
  late FakeSyncServer server;
  late AppDatabase store;
  AppDatabase? background;
  late ProviderContainer container;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'jeton-de-test'});
    dir = await Directory.systemTemp.createTemp('nv-138-');
    final file = File('${dir.path}/store.sqlite');

    server = FakeSyncServer();
    ApiClient.instance.dio.httpClientAdapter = server;

    store = AppDatabase(NativeDatabase(file));
    container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(store)],
    );
  });

  tearDown(() async {
    container.dispose();
    await store.close();
    await background?.close();
    background = null;
    await dir.delete(recursive: true);
  });

  Map<String, Object?> manifest({
    required Set<String> changed,
    bool fromZero = false,
  }) =>
      {
        'scope_version': 1,
        'collections': [
          for (final key in _echanges)
            manifestEntry(
              key,
              partition: kSyncCollections[key]!,
              currentCursor: switch (key) {
                SyncCollectionKey.profiles => profilesCursor,
                SyncCollectionKey.groups => groupsCursor,
                SyncCollectionKey.groupMembers => groupMembersCursor,
                SyncCollectionKey.groupJoinRequests => groupJoinRequestsCursor,
                _ => changed.contains(key)
                    ? groupMessagesCursorAfterChange
                    : groupMessagesCursor,
              },
              hasChanges: changed.contains(key),
              fromZero: fromZero,
            ),
        ],
      };

  /// Attend qu'une émission satisfasse [test], ou échoue au bout du délai.
  Future<void> eventually<T>(
    List<T> emissions,
    bool Function(T) test, {
    required String reason,
  }) async {
    final deadline = DateTime.now().add(const Duration(seconds: 3));
    while (!emissions.any(test)) {
      if (DateTime.now().isAfter(deadline)) fail(reason);
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  test(
      'au retour au premier plan, la liste et le fil relisent ce que le réveil '
      'de fond a écrit par une autre connexion', () async {
    // ── 1. L'état de départ, tiré par l'application elle-même ───────────────
    // Les trois manifestes d'un coup : le double ne consomme une réponse que
    // s'il en reste une autre derrière — la dernière se répète.
    server
      ..serveManifests([
        manifest(changed: _echanges.toSet(), fromZero: true),
        // Le réveil de fond : seul le fil a bougé.
        manifest(changed: {SyncCollectionKey.groupMessages}),
        // Le retour : le curseur est déjà avancé, plus rien à tirer.
        manifest(changed: const {}),
      ])
      ..serveCollection('profiles', profilesPage())
      ..serveCollection('groups', groupsPage())
      ..serveCollection('group_members', groupMembersPage())
      ..serveCollection('group_join_requests', groupJoinRequestsPage())
      ..servePages('group_messages', [
        groupMessagesPage(),
        deltaPage(
          items: const [_wakeMessagePayload],
          nextCursor: groupMessagesCursorAfterChange,
        ),
      ]);
    await SyncEngine(
      api: SyncApi(dio: ApiClient.instance.dio),
      dao: store.syncDao,
      collections: syncedCollections()
          .where((c) => _echanges.contains(c.key))
          .toList(growable: false),
    ).synchronize();

    // ── 2. Les écrans ouverts : la liste des Échanges et le fil ─────────────
    final conversations = <List<ConversationRecord>>[];
    final thread = <List<ThreadEntryRecord>>[];
    final subscriptions = [
      store.groupDao.conversationsOf(kMeId).watch().listen(conversations.add),
      store.groupDao.threadOf(kGroupId, kMeId).watch().listen(thread.add),
    ];
    addTearDown(() async {
      for (final s in subscriptions) {
        await s.cancel();
      }
    });
    await eventually(conversations, (_) => true, reason: 'liste jamais lue');
    await eventually(thread, (_) => true, reason: 'fil jamais lu');

    bool listShowsWake(List<ConversationRecord> rows) => rows.any(
          (r) =>
              r.groupId == kGroupId &&
              r.lastBody == _wakeMessagePayload['body'],
        );
    bool threadShowsWake(List<ThreadEntryRecord> rows) =>
        rows.any((r) => r.id == _wakeMessagePayload['id']);

    expect(conversations.any(listShowsWake), isFalse);
    expect(thread.any(threadShowsWake), isFalse);

    // ── 3. Le réveil de fond : une seconde connexion, le moteur restreint ───
    final fond = background =
        AppDatabase(NativeDatabase(File('${dir.path}/store.sqlite')));
    final wake = await SyncEngine(
      api: SyncApi(
          dio: Dio(BaseOptions(baseUrl: 'https://eenv.brainsial.com'))
            ..interceptors.add(unwrapEnvelopeInterceptor)
            ..httpClientAdapter = server),
      dao: fond.syncDao,
      collections: syncedCollections()
          .where((c) => _groupWake.contains(c.key))
          .toList(growable: false),
      persistsScopeVersion: false,
    ).synchronize();
    expect(wake.pulled, [SyncCollectionKey.groupMessages]);

    // La ligne est en base, le curseur est avancé — vu par la connexion
    // principale…
    expect(
      await store.syncDao.cursorFor(SyncCollectionKey.groupMessages),
      groupMessagesCursorAfterChange,
    );
    // … mais ses flux n'en savent rien : c'est le défaut, pas un artefact.
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(conversations.any(listShowsWake), isFalse);

    // ── 4. Le retour au premier plan, par le chemin réel ─────────────────────
    // Le curseur est déjà avancé : le serveur n'a plus rien à donner.
    final scheduler = container.read(syncSchedulerProvider);
    addTearDown(scheduler.dispose);

    scheduler.didChangeAppLifecycleState(AppLifecycleState.resumed);
    final report = await scheduler.trigger(SyncTrigger.foreground);
    expect(report, isNotNull, reason: '${scheduler.lastFailure}');
    expect(report!.pulled, isEmpty, reason: 'rien à tirer : tout est en base');

    await eventually(
      conversations,
      listShowsWake,
      reason: 'la liste des Échanges est restée périmée au retour',
    );
    await eventually(
      thread,
      threadShowsWake,
      reason: 'le fil est resté périmé au retour',
    );
  });
}
