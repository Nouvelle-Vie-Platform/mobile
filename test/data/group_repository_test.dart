// **La lecture de la messagerie de groupe depuis le magasin.**
//
// Ce que ce fichier garde : l'appartenance (`group_members`, scoppée sur moi)
// sépare l'inbox de la découverte ; la découverte ne remonte que les publics
// non rejoints, avec l'état « demande en attente » ; et l'origine d'un message
// se lit sur le couple `(authorId, isSystem)`, jamais sur `authorId` seul.
//
// Les lignes sont posées **par le chemin de synchronisation**
// (`SyncDao.applyPage`), jamais écrites à la main : le magasin se remplit comme
// en production.

import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/repositories/group_repository.dart';
import 'package:maison_du_miracle/data/sync/sync_rows.dart';
import 'package:maison_du_miracle/models/models.dart';

import 'local/local_database_fixtures.dart';

void main() {
  late AppDatabase db;
  late StoreGroupRepository repo;

  const me = 'user-me';

  setUp(() {
    db = openTestDatabase();
    repo = StoreGroupRepository(db.groupDao, currentUserId: me);
  });

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

  Future<void> putJoinRequest(Map<String, Object?> json) =>
      db.syncDao.applyPage(
        db.syncDao.groupJoinRequestsCollection,
        upserts: [groupJoinRequestRowOf(json)],
        cursor: 'jr',
      );

  test(
      'inbox = groupes dont je suis membre ; découverte = publics non rejoints',
      () async {
    await putGroup({
      'id': 'g-mine',
      'name': 'Chorale',
      'ownerKind': 'user',
      'ownerId': 'owner-1',
      'joinPolicy': 'open',
    });
    await putGroup({
      'id': 'g-open',
      'name': 'Jeunesse',
      'ownerKind': 'official_account',
      'ownerOfficialAccountId': 3,
      'joinPolicy': 'request',
    });
    await putGroup({
      'id': 'g-private',
      'name': 'Comité',
      'ownerKind': 'user',
      'ownerId': 'owner-2',
      'joinPolicy': 'invite_only',
    });
    await putMembership({
      'id': 1,
      'groupId': 'g-mine',
      'userId': me,
      'role': 'member',
    });

    final inbox = await repo.conversations().first;
    expect(inbox.map((c) => c.id), ['g-mine']);

    final discover = await repo.groupsToJoin().first;
    // g-open (request) est listé ; g-private (invite_only) ne l'est jamais ;
    // g-mine est exclu (déjà membre).
    expect(discover.map((g) => g.id), ['g-open']);
    expect(discover.single.joinPolicy, GroupJoinPolicy.request);
    expect(discover.single.pendingRequest, isFalse);
  });

  test('une demande en attente bascule la carte en « En attente »', () async {
    await putGroup({
      'id': 'g-open',
      'name': 'Jeunesse',
      'ownerKind': 'user',
      'ownerId': 'o',
      'joinPolicy': 'request',
    });
    await putJoinRequest({
      'id': 10,
      'groupId': 'g-open',
      'userId': me,
      'status': 'pending',
    });

    final discover = await repo.groupsToJoin().first;
    expect(discover.single.pendingRequest, isTrue);
  });

  test('l\'origine d\'un message se lit sur (authorId, isSystem)', () async {
    await putMessage({
      'id': 'm-1',
      'groupId': 'g',
      'authorId': me,
      'isSystem': false,
      'body': 'de moi',
    });
    await putMessage({
      'id': 'm-2',
      'groupId': 'g',
      'authorId': 'someone',
      'isSystem': false,
      'body': 'reçu',
    });
    await putMessage({
      'id': 'm-3',
      'groupId': 'g',
      'authorId': null,
      'isSystem': true,
      'body': 'a rejoint le groupe',
    });
    await putMessage({
      'id': 'm-4',
      'groupId': 'g',
      'authorId': null,
      'isSystem': false,
      'body': 'auteur parti',
    });

    final messages = await repo.messages('g').first;
    final byText = {for (final m in messages) m.text: m};

    expect(byText['de moi']!.mine, isTrue);
    expect(byText['reçu']!.mine, isFalse);
    expect(byText['reçu']!.system, isFalse);
    // Message système : bannière (system), jamais une bulle.
    expect(byText['a rejoint le groupe']!.system, isTrue);
    // Auteur retiré : **pas** un message système, malgré authorId nul.
    expect(byText['auteur parti']!.system, isFalse);
    expect(byText['auteur parti']!.authorRemoved, isTrue);
    expect(byText['auteur parti']!.mine, isFalse);
  });

  // ── Messagerie directe (DM 1-à-1, PRD `messagerie-directe.md`) ──────────────

  Future<void> putProfile(Map<String, Object?> json) => db.syncDao.applyPage(
        db.syncDao.profilesCollection,
        upserts: [profileRowOf(json)],
        cursor: 'p',
      );

  // Amorce un DM entre `me` et `other` : groupe `is_direct`, les deux
  // appartenances (le roster voyage désormais), et le profil de l'autre.
  Future<void> seedDirect({required String other, String? otherName}) async {
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
        {'id': 2, 'groupId': 'dm-1', 'userId': other, 'role': 'member'});
    if (otherName != null) {
      await putProfile({'id': other, 'displayName': otherName});
    }
  }

  test('un DM se lit en kind=direct, titré par le profil de l\'autre', () async {
    await seedDirect(other: 'user-bob', otherName: 'Bob Mensah');

    final inbox = await repo.conversations().first;
    expect(inbox, hasLength(1));
    final dm = inbox.single;
    expect(dm.kind, ConversationKind.direct);
    expect(dm.name, 'Bob Mensah');
    expect(dm.peerUserId, 'user-bob');
  });

  test('un DM sans profil encore synchronisé : titre vide, mais pair connu',
      () async {
    await seedDirect(other: 'user-bob'); // pas de profil

    final dm = (await repo.conversations().first).single;
    expect(dm.kind, ConversationKind.direct);
    expect(dm.name, '');
    // Le pair reste connu (roster), donc le fil reste adressable/rouvrable.
    expect(dm.peerUserId, 'user-bob');
  });

  test('directConversationWith résout le fil direct par userId', () async {
    await seedDirect(other: 'user-bob', otherName: 'Bob');

    expect((await repo.directConversationWith('user-bob').first)?.id, 'dm-1');
    // Aucun fil avec un inconnu.
    expect(await repo.directConversationWith('user-x').first, isNull);
  });

  test('members() = le roster, nommé par profiles, scopé au groupe', () async {
    await putGroup({
      'id': 'g',
      'name': 'Chorale',
      'ownerKind': 'user',
      'ownerId': me,
      'joinPolicy': 'open',
    });
    await putMembership(
        {'id': 1, 'groupId': 'g', 'userId': me, 'role': 'leader'});
    await putMembership(
        {'id': 2, 'groupId': 'g', 'userId': 'user-bob', 'role': 'member'});
    await putProfile({'id': 'user-bob', 'displayName': 'Bob Mensah'});
    // Un membre d'un AUTRE groupe ne doit pas fuiter dans cette liste.
    await putMembership(
        {'id': 3, 'groupId': 'autre', 'userId': 'user-zoe', 'role': 'member'});

    final members = await repo.members('g').first;
    expect(members.map((m) => m.userId).toSet(), {me, 'user-bob'});
    final bob = members.firstWhere((m) => m.userId == 'user-bob');
    expect(bob.name, 'Bob Mensah');
    expect(bob.role, GroupRole.member);
  });

  test('un DM n\'apparaît jamais dans la découverte', () async {
    await seedDirect(other: 'user-bob', otherName: 'Bob');
    final discover = await repo.groupsToJoin().first;
    expect(discover.where((g) => g.id == 'dm-1'), isEmpty);
  });
}
