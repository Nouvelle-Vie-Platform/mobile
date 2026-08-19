// **Le handler de réveil push, prouvé sur la VM** — D1/D6 de
// `docs/prd/notifications-push.md`.
//
// Aucun plugin natif ici, et c'est le fond du lot : `onSync` est un simple
// callback, le magasin est une base Drift **en mémoire** remplie par le chemin de
// synchronisation (`SyncDao.applyPage`, comme en production — jamais un insert à
// la main), et la notification est captée par un [LocalNotifier] factice. On
// prouve les trois promesses du handler :
//
//  1. la **sync est déclenchée** (avant toute lecture) ;
//  2. le **contenu** de la notification est correct — titre = nom du groupe, ou
//     du **pair** pour un DM (via `profiles`) ; corps = **texte** du message ;
//  3. **rien n'est notifié** si le message reste introuvable après la sync
//     (course), plutôt qu'un contenu inventé.
//
// Le réveil serveur est content-free : tout le contenu vient du magasin, que la
// sync remplit. Le double `_RecordingNotifier` capte ce que le handler a composé.

import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/push/local_notifier.dart';
import 'package:maison_du_miracle/data/push/push_wake_handler.dart';
import 'package:maison_du_miracle/data/push/push_wake_payload.dart';
import 'package:maison_du_miracle/data/sync/sync_rows.dart';

import '../local/local_database_fixtures.dart';

/// Un notifieur qui **retient** ce qu'on lui a demandé de peindre.
class _RecordingNotifier implements LocalNotifier {
  final List<PushNotificationContent> shown = [];

  @override
  Future<void> show(PushNotificationContent content) async {
    shown.add(content);
  }
}

void main() {
  late AppDatabase db;

  const me = 'user-me';

  setUp(() => db = openTestDatabase());
  tearDown(() => db.close());

  Future<void> putGroup(Map<String, Object?> json) => db.syncDao.applyPage(
        db.syncDao.groupsCollection,
        upserts: [groupRowOf(json)],
        cursor: 'g',
      );

  Future<void> putMembership(Map<String, Object?> json) => db.syncDao.applyPage(
        db.syncDao.groupMembersCollection,
        upserts: [groupMemberRowOf(json)],
        cursor: 'm',
      );

  Future<void> putMessage(Map<String, Object?> json) => db.syncDao.applyPage(
        db.syncDao.groupMessagesCollection,
        upserts: [groupMessageRowOf(json)],
        cursor: 'msg',
      );

  Future<void> putProfile(Map<String, Object?> json) => db.syncDao.applyPage(
        db.syncDao.profilesCollection,
        upserts: [profileRowOf(json)],
        cursor: 'p',
      );

  PushWakeHandler handlerWith({
    required _RecordingNotifier notifier,
    required Future<void> Function() onSync,
    String? currentUserId = me,
  }) =>
      PushWakeHandler(
        onSync: onSync,
        groupDao: db.groupDao,
        notifier: notifier,
        currentUserId: currentUserId,
      );

  test(
      'groupe : sync déclenchée, puis notif (titre = nom du groupe, corps = texte)',
      () async {
    // Le groupe existe déjà en magasin ; le **message** n'arrive que par la sync.
    await putGroup({
      'id': 'g-1',
      'name': 'Chorale',
      'ownerKind': 'user',
      'ownerId': 'owner-1',
      'joinPolicy': 'open',
    });

    var syncCalls = 0;
    final notifier = _RecordingNotifier();
    final handler = handlerWith(
      notifier: notifier,
      onSync: () async {
        // La sync ramène le message déclencheur (flux delta).
        syncCalls++;
        await putMessage({
          'id': 'msg-1',
          'groupId': 'g-1',
          'authorId': 'user-bob',
          'isSystem': false,
          'body': 'La répétition est à 18h',
        });
      },
    );

    await handler.handle(
      const PushWakePayload(groupId: 'g-1', messageId: 'msg-1'),
    );

    // 1. sync déclenchée exactement une fois.
    expect(syncCalls, 1);
    // 2. contenu composé depuis le magasin.
    expect(notifier.shown, hasLength(1));
    final content = notifier.shown.single;
    expect(content.title, 'Chorale');
    expect(content.body, 'La répétition est à 18h');
    expect(content.conversationId, 'g-1');
  });

  test('DM : le titre est le nom du pair (via profiles), pas un nom de groupe',
      () async {
    final notifier = _RecordingNotifier();
    final handler = handlerWith(
      notifier: notifier,
      onSync: () async {
        // La sync ramène le fil direct, le roster {moi, lui}, le profil du pair,
        // et le message.
        await putGroup({
          'id': 'dm-1',
          'name': '',
          'ownerKind': 'user',
          'ownerId': me,
          'joinPolicy': 'invite_only',
          'isDirect': true,
        });
        await putMembership(
            {'id': 1, 'groupId': 'dm-1', 'userId': me, 'role': 'member'});
        await putMembership(
            {'id': 2, 'groupId': 'dm-1', 'userId': 'user-bob', 'role': 'member'});
        await putProfile({'id': 'user-bob', 'displayName': 'Bob Mensah'});
        await putMessage({
          'id': 'msg-2',
          'groupId': 'dm-1',
          'authorId': 'user-bob',
          'isSystem': false,
          'body': 'On se voit dimanche ?',
        });
      },
    );

    await handler.handle(
      const PushWakePayload(groupId: 'dm-1', messageId: 'msg-2'),
    );

    expect(notifier.shown, hasLength(1));
    final content = notifier.shown.single;
    expect(content.title, 'Bob Mensah');
    expect(content.body, 'On se voit dimanche ?');
    expect(content.conversationId, 'dm-1');
  });

  test('message introuvable après sync : sync déclenchée, mais rien de notifié',
      () async {
    await putGroup({
      'id': 'g-1',
      'name': 'Chorale',
      'ownerKind': 'user',
      'ownerId': 'owner-1',
      'joinPolicy': 'open',
    });

    var syncCalls = 0;
    final notifier = _RecordingNotifier();
    final handler = handlerWith(
      notifier: notifier,
      onSync: () async {
        // La sync tourne mais ne ramène pas ce message (course : encore en vol,
        // ou tombstoné entre-temps).
        syncCalls++;
      },
    );

    await handler.handle(
      const PushWakePayload(groupId: 'g-1', messageId: 'msg-absent'),
    );

    expect(syncCalls, 1, reason: 'la sync est déclenchée même sans message');
    expect(notifier.shown, isEmpty,
        reason: 'silencieux plutôt que d\'inventer un contenu');
  });

  test('la sync précède la lecture : un magasin vide avant sync notifie quand même',
      () async {
    // Rien en magasin au départ : si le handler lisait AVANT de synchroniser, il
    // ne trouverait rien. La preuve que la sync passe d'abord.
    final notifier = _RecordingNotifier();
    final handler = handlerWith(
      notifier: notifier,
      onSync: () async {
        await putGroup({
          'id': 'g-9',
          'name': 'Intercession',
          'ownerKind': 'user',
          'ownerId': 'o',
          'joinPolicy': 'open',
        });
        await putMessage({
          'id': 'msg-9',
          'groupId': 'g-9',
          'authorId': 'user-x',
          'isSystem': false,
          'body': 'Amen',
        });
      },
    );

    await handler.handle(
      const PushWakePayload(groupId: 'g-9', messageId: 'msg-9'),
    );

    expect(notifier.shown.single.title, 'Intercession');
    expect(notifier.shown.single.body, 'Amen');
  });

  group('PushWakePayload.tryParse — tolérant, ne lève jamais', () {
    test('charge bien formée', () {
      final payload = PushWakePayload.tryParse({
        'type': 'group_message',
        'groupId': 'g-1',
        'messageId': 'm-1',
      });
      expect(payload, isNotNull);
      expect(payload!.groupId, 'g-1');
      expect(payload.messageId, 'm-1');
    });

    test('type inconnu, clés manquantes, valeurs vides ou informes → null', () {
      expect(PushWakePayload.tryParse(null), isNull);
      expect(PushWakePayload.tryParse(const {}), isNull);
      expect(
        PushWakePayload.tryParse(
            {'type': 'sync', 'groupId': 'g', 'messageId': 'm'}),
        isNull,
      );
      expect(
        PushWakePayload.tryParse({'type': 'group_message', 'groupId': 'g'}),
        isNull,
      );
      expect(
        PushWakePayload.tryParse(
            {'type': 'group_message', 'groupId': '', 'messageId': 'm'}),
        isNull,
      );
      expect(
        PushWakePayload.tryParse({
          'type': 'group_message',
          'groupId': {'nested': true},
          'messageId': 'm',
        }),
        isNull,
      );
    });
  });
}
