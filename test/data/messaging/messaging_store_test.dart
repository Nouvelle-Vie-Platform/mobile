/// **Le magasin de la messagerie fiable** (#140) : le corps nul, le rangement
/// des lignes hors du tirage, et la formule des non-lus.
///
/// Tout ici tourne sur une **vraie** base Drift en mémoire, par les vraies
/// fonctions de rangement — celles du registre, que le moteur, le canal
/// `users/{id}` et l'historique partagent.
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/core/network/api_client.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/local/sync_dao.dart';
import 'package:maison_du_miracle/data/messaging/messaging_store_writer.dart';
import 'package:maison_du_miracle/data/repositories/store_echanges_repository.dart';
import 'package:maison_du_miracle/data/sync/sync_api.dart';
import 'package:maison_du_miracle/data/sync/sync_engine.dart';
import 'package:maison_du_miracle/data/sync/sync_rows.dart';
import 'package:maison_du_miracle/data/sync/synced_collection.dart';

import '../local/local_database_fixtures.dart';
import '../../helpers/fake_sync_server.dart';
import '../../helpers/sync_fixtures.dart';

/// **Un vocal** : la forme courante d'un message-média, `body: null`. C'est ce
/// que le serveur sert au-delà du plancher de compatibilité, et **toujours** sur
/// le canal.
const Map<String, Object?> _voicePayload = {
  'id': '019a3000-0000-7000-8000-00000000msg9',
  'groupId': kGroupId,
  'authorId': kPeerId,
  'isSystem': false,
  'body': null,
  'mediaKey': 'groups/vocal.m4a',
  'mediaKind': 'voice',
  'mediaDuration': 12,
  'clientMessageId': null,
  'clientCreatedAt': null,
  'createdAt': '2026-09-03T10:45:00.000Z',
  'deletedAt': null,
};

Map<String, Object?> _read(String messageId, String at, {int id = 1}) => {
      'id': id,
      'groupId': kGroupId,
      'lastReadMessageId': messageId,
      'lastReadAt': at,
    };

void main() {
  late AppDatabase db;
  late MessagingStoreWriter writer;

  setUp(() {
    db = openTestDatabase();
    writer = MessagingStoreWriter(db);
  });

  tearDown(() => db.close());

  /// Mon groupe, son roster et ses quatre messages — un de chaque origine, plus
  /// le mien. Rangés par le **même** chemin que le canal.
  Future<void> seedGroup() async {
    await writer.store(SyncCollectionKey.groups, myGroupPayload);
    await writer.store(SyncCollectionKey.groupMembers, myMembershipPayload);
    await writer.store(SyncCollectionKey.groupMembers, peerMembershipPayload);
    for (final message in const [
      memberMessagePayload, // 10:30, du co-membre
      myMessagePayload, // 10:32, le mien
      systemMessagePayload, // 10:35, le serveur
      removedAuthorMessagePayload, // 10:40, auteur retiré
    ]) {
      await writer.store(SyncCollectionKey.groupMessages, message);
    }
  }

  Future<int> unread() => db.groupDao.unreadCountOf(kGroupId, kMeId);

  group('Le corps nul (piège 1)', () {
    test('groupMessageRowOf accepte un `body: null`, et le garde nul', () {
      final row = groupMessageRowOf(_voicePayload);
      expect(row.body.value, isNull);
    });

    test(
        'une page qui porte un message-média ne coupe PLUS le cycle : le fil '
        'est tiré, et la ligne entre au magasin', () async {
      final server = FakeSyncServer();
      final dio = Dio(BaseOptions(baseUrl: 'https://eenv.brainsial.com'))
        ..interceptors.add(unwrapEnvelopeInterceptor)
        ..httpClientAdapter = server;
      server
        ..serveManifest({
          'scope_version': 1,
          'collections': [
            manifestEntry(
              SyncCollectionKey.groupMessages,
              partition: 'branch',
              currentCursor: groupMessagesCursor,
              hasChanges: true,
              fromZero: true,
            ),
          ],
        })
        ..serveCollection(
          SyncCollectionKey.groupMessages,
          groupMessagesPage(
            items: const [memberMessagePayload, _voicePayload],
          ),
        );

      final report = await SyncEngine(
        api: SyncApi(dio: dio),
        dao: db.syncDao,
        collections: [
          syncedCollectionFor(SyncCollectionKey.groupMessages)!,
        ],
      ).synchronize();

      // Avant #140, `_text(…, 'body')` levait `MalformedSyncRow` : la page était
      // rejetée, curseur compris, à chaque tour — et rien ne le disait.
      expect(report.pulled, [SyncCollectionKey.groupMessages]);
      expect(
        await db.syncDao.cursorFor(SyncCollectionKey.groupMessages),
        groupMessagesCursor,
      );
      final voice = await (db.select(db.groupMessages)
            ..where((m) => m.id.equals(_voicePayload['id']! as String)))
          .getSingle();
      expect(voice.body, isNull);
    });

    test('le fil rend le message-média, corps nul compris', () async {
      await seedGroup();
      await writer.store(SyncCollectionKey.groupMessages, _voicePayload);

      final thread = await StoreEchangesRepository(db.groupDao, userId: kMeId)
          .thread(kGroupId)
          .first;
      final voice = thread.singleWhere((m) => m.id == _voicePayload['id']);
      expect(voice.body, isNull);
    });
  });

  group('Ranger une ligne hors du tirage', () {
    test('une ligne vivante remplace la locale, sans toucher au curseur',
        () async {
      await seedGroup();
      // Le détachement d'auteur (ADR-0032) arrive par le canal sur une ligne
      // déjà stockée : remplacer, jamais fusionner.
      await writer.store(
        SyncCollectionKey.groupMessages,
        {...attachedAuthorMessagePayload},
      );
      await writer.store(
        SyncCollectionKey.groupMessages,
        removedAuthorMessagePayload,
      );

      final row = await (db.select(db.groupMessages)
            ..where((m) =>
                m.id.equals(removedAuthorMessagePayload['id']! as String)))
          .getSingle();
      expect(row.authorId, isNull);
      expect(row.isSystem, isFalse);
      expect(
        await db.syncDao.cursorFor(SyncCollectionKey.groupMessages),
        isNull,
        reason: 'un curseur ne couvre que ce que le tirage a livré',
      );
    });

    test(
        'un tombstone (`message.deleted`) est GARDÉ, sans son texte '
        '(M2, #141)', () async {
      await seedGroup();
      await writer.store(
        SyncCollectionKey.groupMessages,
        deletedMessagePayload,
      );

      final row = await (db.select(db.groupMessages)
            ..where((m) => m.id.equals(deletedMessagePayload['id']! as String)))
          .getSingle();
      expect(row.deletedAt, isNotNull);
      expect(row.body, isNull);
    });

    test(
        'l\'écho en attente cède la place à la ligne serveur de même '
        '`clientMessageId`, et la table des échos est ramassée', () async {
      await seedGroup();
      const key = 'c-0001';
      await db.groupDao.rememberPending(
        clientMessageId: key,
        groupId: kGroupId,
        body: 'Gloire à Dieu',
        createdAt: DateTime.utc(2026, 9, 3, 11),
      );

      await writer.store(SyncCollectionKey.groupMessages, {
        ...memberMessagePayload,
        'id': '019a3000-0000-7000-8000-0000000msg10',
        'authorId': kMeId,
        'body': 'Gloire à Dieu',
        'clientMessageId': key,
        'createdAt': '2026-09-03T11:00:00.412Z',
      });

      final thread = await db.groupDao.threadOf(kGroupId, kMeId).get();
      expect(
        thread.where((e) => e.body == 'Gloire à Dieu'),
        hasLength(1),
        reason: 'jamais de doublon : l\'écho et la ligne serveur sont un seul '
            'message',
      );
      expect(thread.where((e) => e.isPending), isEmpty);
      expect(await db.select(db.pendingGroupMessages).get(), isEmpty);
    });

    test('un groupe inconnu se signale, et sa ligne est rangée quand même',
        () async {
      final known = await writer.store(
        SyncCollectionKey.groupMessages,
        memberMessagePayload,
      );
      expect(known, isFalse);
      expect(await db.select(db.groupMessages).get(), hasLength(1));

      await writer.store(SyncCollectionKey.groups, myGroupPayload);
      expect(
        await writer.store(
          SyncCollectionKey.groupMessages,
          systemMessagePayload,
        ),
        isTrue,
      );
    });

    test('`group.updated` apporte l\'effectif servi par le serveur', () async {
      await seedGroup();
      await writer.store(
        SyncCollectionKey.groups,
        {...myGroupPayload, 'memberCount': 7},
      );
      final group = await db.groupDao.groupById(kGroupId).getSingle();
      expect(group.group.memberCount, 7);
    });

    test(
        '`membership.changed` tombstoné sur MA ligne retire la conversation '
        'de la liste', () async {
      await seedGroup();
      expect(await db.groupDao.conversationsOf(kMeId).get(), hasLength(1));

      await writer.store(
        SyncCollectionKey.groupMembers,
        myMembershipRetractedPayload,
      );
      expect(await db.groupDao.conversationsOf(kMeId).get(), isEmpty);
    });

    test('la lecture ne recule jamais, quel que soit l\'ordre d\'arrivée',
        () async {
      await seedGroup();
      final later = _read(
        removedAuthorMessagePayload['id']! as String,
        '2026-09-03T10:41:00.000Z',
      );
      final earlier = _read(
        memberMessagePayload['id']! as String,
        '2026-09-03T10:31:00.000Z',
      );

      await writer.store(SyncCollectionKey.groupReads, later);
      await writer.store(SyncCollectionKey.groupReads, earlier);

      final read = await db.groupDao.readOf(kGroupId);
      expect(read!.lastReadMessageId, removedAuthorMessagePayload['id']);
    });
  });

  group('Les non-lus — la formule du contrat M1a', () {
    test(
        'sans lecture : tout ce qui n\'est ni de moi ni du serveur, AUTEUR '
        'RETIRÉ COMPRIS', () async {
      await seedGroup();
      // Le message du co-membre et celui de l'auteur retiré. Le mien et celui
      // du serveur ne comptent pas. Un `author_id <> moi` nu aurait perdu
      // l'auteur retiré (`NULL <> x` est `NULL` en SQL).
      expect(await unread(), 2);
    });

    test('une lecture posée sur un message en magasin : comparaison exacte',
        () async {
      await seedGroup();
      await writer.store(
        SyncCollectionKey.groupReads,
        _read(memberMessagePayload['id']! as String, '2026-09-03T12:00:00Z'),
      );
      // Après 10:30 : le mien (10:32, exclu), le système (10:35, exclu),
      // l'auteur retiré (10:40) — un seul.
      expect(await unread(), 1);
    });

    test('le message lu n\'est pas en magasin : repli sur `lastReadAt`',
        () async {
      await seedGroup();
      await writer.store(
        SyncCollectionKey.groupReads,
        _read('019a3000-0000-7000-8000-0000000purged', '2026-09-03T10:36:00Z'),
      );
      expect(await unread(), 1, reason: 'seul le message de 10:40 est après');
    });

    test(
        'une lecture locale pas encore confirmée éteint la pastille sans '
        'attendre le réseau', () async {
      await seedGroup();
      expect(await unread(), 2);

      final advanced = await db.groupDao.rememberRead(
        groupId: kGroupId,
        messageId: removedAuthorMessagePayload['id']! as String,
        messageCreatedAt: DateTime.utc(2026, 9, 3, 10, 40),
      );
      expect(advanced, isTrue);
      expect(await unread(), 0);
    });

    test('la lecture locale ne recule pas', () async {
      await seedGroup();
      await db.groupDao.rememberRead(
        groupId: kGroupId,
        messageId: removedAuthorMessagePayload['id']! as String,
        messageCreatedAt: DateTime.utc(2026, 9, 3, 10, 40),
      );
      final again = await db.groupDao.rememberRead(
        groupId: kGroupId,
        messageId: memberMessagePayload['id']! as String,
        messageCreatedAt: DateTime.utc(2026, 9, 3, 10, 30),
      );
      expect(again, isFalse);
      expect(await unread(), 0);
    });

    test(
        'la liste, le fil et le compte disent la même chose — une seule '
        'formule', () async {
      await seedGroup();
      await writer.store(
        SyncCollectionKey.groupReads,
        _read(memberMessagePayload['id']! as String, '2026-09-03T12:00:00Z'),
      );

      final conversation =
          (await db.groupDao.conversationsOf(kMeId).get()).single;
      final thread = await db.groupDao.threadOf(kGroupId, kMeId).get();

      expect(conversation.unreadCount, 1);
      expect(thread.where((e) => e.isUnread).map((e) => e.id), [
        removedAuthorMessagePayload['id'],
      ]);
      expect(await unread(), 1);
    });

    test('un message tombstoné cesse de compter', () async {
      await seedGroup();
      await writer.store(
        SyncCollectionKey.groupMessages,
        deletedMessagePayload,
      );
      expect(await unread(), 1);
    });
  });

  group('Le fil par pages', () {
    test('la fenêtre rend les N plus récents, dans l\'ordre chronologique',
        () async {
      await seedGroup();
      final window =
          await db.groupDao.threadOf(kGroupId, kMeId, limit: 2).get();
      expect(window.map((e) => e.id), [
        systemMessagePayload['id'],
        removedAuthorMessagePayload['id'],
      ]);
    });

    test('une page d\'historique se range comme le tirage', () async {
      await seedGroup();
      await writer.storeMessages([
        {
          ...memberMessagePayload,
          'id': '019a3000-0000-7000-8000-0000000old01',
          'createdAt': '2026-08-20T08:00:00.000Z',
        },
      ]);
      final all = await db.groupDao.threadOf(kGroupId, kMeId).get();
      expect(all.first.id, '019a3000-0000-7000-8000-0000000old01');
    });
  });
}
