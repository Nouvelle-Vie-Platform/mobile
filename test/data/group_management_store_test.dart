/// **Le magasin, côté discussions et groupes gérés depuis l'application**
/// (#145, tranche M6).
///
/// Trois choses, sur une **vraie** base Drift en mémoire et par les vraies
/// fonctions de rangement (celles du canal et du tirage) :
///
/// 1. **mes contacts de groupe** sont bornés comme le serveur les borne : un
///    groupe qui n'est pas un tête-à-tête, moi exclu ;
/// 2. la fiche d'un groupe **suit mon rôle** quand seul le roster change ;
/// 3. **le premier message d'un tête-à-tête** paraît sous la clé de la personne,
///    puis cède à la ligne serveur — même `clientMessageId` — rangée dans le
///    vrai fil.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/local/sync_dao.dart';
import 'package:maison_du_miracle/data/messaging/messaging_store_writer.dart';
import 'package:maison_du_miracle/data/repositories/group_message_composer.dart';
import 'package:maison_du_miracle/data/repositories/group_message_sender.dart';
import 'package:maison_du_miracle/data/repositories/store_echanges_repository.dart';
import 'package:maison_du_miracle/models/echanges_view.dart';

import '../helpers/sync_fixtures.dart';
import 'local/local_database_fixtures.dart';

/// Une personne que je ne connais **que** par un tête-à-tête.
const String _dmOnlyId = '019a1000-0000-7000-8000-0000000dmo01';
const String _dmOnlyGroupId = '019a2000-0000-7000-8000-000000grp099';

class _RecordingSender implements GroupMessageSender {
  final List<String> threadKeys = [];

  @override
  Future<bool> send({
    required String groupId,
    required String body,
    required String clientMessageId,
    required DateTime clientCreatedAt,
    String? replyToMessageId,
  }) async {
    threadKeys.add(groupId);
    return true;
  }
}

void main() {
  late AppDatabase db;
  late MessagingStoreWriter writer;

  setUp(() {
    db = openTestDatabase();
    writer = MessagingStoreWriter(db);
  });

  tearDown(() => db.close());

  StoreEchangesRepository repository() =>
      StoreEchangesRepository(db.groupDao, userId: kMeId);

  /// Mon groupe (Estelle y est animatrice), un tête-à-tête avec elle, et un
  /// tête-à-tête avec quelqu'un que je ne connais que par lui.
  Future<void> seed() async {
    for (final profile in [
      myProfilePayload,
      peerProfilePayload,
      {
        'id': _dmOnlyId,
        'displayName': 'Yawo Ablodé',
        'avatarUrl': null,
        'updatedAt': '2026-09-01T08:20:00.000Z',
      },
    ]) {
      await writer.store(SyncCollectionKey.profiles, profile);
    }
    await writer.store(SyncCollectionKey.groups, myGroupPayload);
    await writer.store(SyncCollectionKey.groups, directGroupPayload);
    await writer.store(SyncCollectionKey.groups, {
      ...directGroupPayload,
      'id': _dmOnlyGroupId,
    });
    for (final membership in [
      myMembershipPayload,
      peerMembershipPayload,
      myDirectMembershipPayload,
      peerDirectMembershipPayload,
      {
        ...myDirectMembershipPayload,
        'id': 20,
        'groupId': _dmOnlyGroupId,
      },
      {
        ...peerDirectMembershipPayload,
        'id': 21,
        'groupId': _dmOnlyGroupId,
        'userId': _dmOnlyId,
      },
    ]) {
      await writer.store(SyncCollectionKey.groupMembers, membership);
    }
  }

  group('Mes contacts de groupe', () {
    test('les co-membres d\'un vrai groupe, moi exclu, une fois chacun',
        () async {
      await seed();

      final contacts = await repository().contacts().first;

      // Estelle partage un groupe **et** un tête-à-tête : une seule ligne.
      expect(contacts.map((c) => c.userId), [kPeerId]);
      expect(contacts.single.displayName, 'Estelle Adjo');
    });

    test('une personne connue par un seul tête-à-tête n\'est pas proposée',
        () async {
      await seed();

      final contacts = await repository().contacts().first;

      // Le serveur refuserait de **démarrer** avec elle (pas de groupe
      // commun) : le sélecteur ne la propose donc pas.
      expect(contacts.map((c) => c.userId), isNot(contains(_dmOnlyId)));
    });

    test('quitter le groupe retire le contact', () async {
      await seed();
      await writer.store(
        SyncCollectionKey.groupMembers,
        myMembershipRetractedPayload,
      );

      expect(await repository().contacts().first, isEmpty);
    });
  });

  group('La fiche suit mon rôle', () {
    test('nommé modérateur : la fiche le dit sans que le groupe bouge',
        () async {
      await seed();
      expect((await repository().group(kGroupId).first)!.myRole, 'member');

      final promoted = expectLater(
        repository().group(kGroupId),
        emitsThrough(
          predicate<GroupDetailView?>((g) => g?.myRole == 'moderator'),
        ),
      );
      // Seule ma ligne du roster change — `groups` ne bouge pas.
      await writer.store(SyncCollectionKey.groupMembers, {
        ...myMembershipPayload,
        'role': 'moderator',
        'updatedAt': '2026-09-06T10:00:00.000Z',
      });
      await promoted;
    });

    test('la politique et l\'état du groupe sont lus', () async {
      await writer.store(SyncCollectionKey.groups, openGroupPayload);

      final detail = await repository().group(kOpenGroupId).first;

      expect(detail!.joinPolicy, 'open');
      expect(detail.myRole, isNull, reason: 'je n\'en suis pas membre');
    });
  });

  group('Le premier message d\'un tête-à-tête', () {
    test('l\'écho paraît sous la clé de la personne, et part à sa route',
        () async {
      final sender = _RecordingSender();
      final composer = GroupMessageComposer(
        dao: db.groupDao,
        sender: sender,
        resynchronize: () async {},
        mintId: () => 'c-first',
        now: () => DateTime.utc(2026, 10, 6, 9),
      );
      final key = directThreadKey(_dmOnlyId);

      await composer.send(groupId: key, body: 'Bonjour Yawo');

      expect(sender.threadKeys, [key]);
      final echo = await repository().thread(key).first;
      expect(echo.single.body, 'Bonjour Yawo');
      expect(echo.single.mine, isTrue);
    });

    test('la ligne serveur, rangée dans le vrai fil, remplace l\'écho',
        () async {
      await seed();
      final composer = GroupMessageComposer(
        dao: db.groupDao,
        sender: _RecordingSender(),
        resynchronize: () async {},
        mintId: () => 'c-first',
        now: () => DateTime.utc(2026, 10, 6, 9),
      );
      final key = directThreadKey(kPeerId);
      await composer.send(groupId: key, body: 'Salut Estelle');

      // Le serveur a créé (ou retrouvé) le fil direct, et le canal range le
      // message — même `clientMessageId`.
      await writer.store(SyncCollectionKey.groupMessages, {
        'id': '019a3000-0000-7000-8000-0000000first',
        'groupId': kDirectGroupId,
        'authorId': kMeId,
        'isSystem': false,
        'body': 'Salut Estelle',
        'mediaKey': null,
        'mediaKind': null,
        'mediaDuration': null,
        'clientMessageId': 'c-first',
        'clientCreatedAt': '2026-10-06T09:00:00.000Z',
        'createdAt': '2026-10-06T09:00:00.412Z',
        'deletedAt': null,
      });

      expect(await repository().thread(key).first, isEmpty);
      final real = await repository().thread(kDirectGroupId).first;
      expect(real.single.body, 'Salut Estelle');
      expect(real.single.delivery, MessageDelivery.sent);
    });
  });
}
