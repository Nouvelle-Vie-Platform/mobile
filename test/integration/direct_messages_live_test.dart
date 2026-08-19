/// **La messagerie directe (DM 1-à-1), contre un vrai serveur** (PRD
/// `messagerie-directe.md`). Le pendant « live » des tests de magasin : ici rien
/// n'est simulé — un vrai `POST /groups/direct/:targetUserId/messages`, un vrai
/// tirage `/sync`, et le **moteur de synchronisation du client** exercé tel quel
/// contre les réponses du serveur.
///
/// Ce que le scénario prouve, de bout en bout :
/// 1. l'envoi direct **crée paresseusement** le fil (aucune étape « créer ») ;
/// 2. le fil, ses deux appartenances, son message **et le profil de l'autre**
///    reviennent par la synchronisation dans le magasin de chaque participant ;
/// 3. le magasin rend un DM en `ConversationKind.direct`, **titré par le nom**
///    de l'autre (collection `profiles`), son `peerUserId` porté ;
/// 4. un **tiers** ne voit jamais le fil (privé, hors découverte) ;
/// 5. l'**idempotence** offline tient (un renvoi ne duplique pas le message).
///
/// Sauté par défaut (étiquette `live-server`, cf. `dart_test.yaml`). Monter le
/// serveur : `OTP_PHONE_DRIVER=log OTP_DEV_ECHO_CODE=true npm run dev`.
@Tags(['live-server'])
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/core/network/api_client.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/repositories/group_repository.dart';
import 'package:maison_du_miracle/data/sync/sync_api.dart';
import 'package:maison_du_miracle/data/sync/sync_engine.dart';
import 'package:maison_du_miracle/data/sync/synced_collection.dart';
import 'package:maison_du_miracle/models/models.dart';

import '../data/local/local_database_fixtures.dart';
import 'live_server.dart';

void main() {
  late LiveServer server;

  // Identités **fraîches à chaque run** (le dev-serveur garde ses comptes) : une
  // paire neuve, donc un DM neuf, donc des assertions de comptage sûres.
  final stamp = DateTime.now().microsecondsSinceEpoch;
  final aliceEmail = 'dm-alice-$stamp@example.com';
  final bobEmail = 'dm-bob-$stamp@example.com';
  final carolEmail = 'dm-carol-$stamp@example.com';

  late String aliceToken, bobToken, carolToken;
  late String aliceId, bobId, carolId;

  setUpAll(() async {
    server = LiveServer();

    aliceToken = await server.signIn(aliceEmail);
    bobToken = await server.signIn(bobEmail);
    carolToken = await server.signIn(carolEmail);

    await server.setName(aliceToken, firstName: 'Alice', lastName: 'Koffi');
    await server.setName(bobToken, firstName: 'Bob', lastName: 'Mensah');

    aliceId = await server.me(aliceToken);
    bobId = await server.me(bobToken);
    carolId = await server.me(carolToken);

    // Le geste central : Alice écrit à Bob. Le fil n'existait pas ; ce POST le crée.
    final sent = await server.sendDirect(
      aliceToken,
      bobId,
      'Salut Bob',
      clientMessageId: 'c-1',
    );
    expect(sent['body'], 'Salut Bob');
    expect(sent['authorId'], aliceId);
  });

  tearDownAll(() => server.close());

  /// Monte un magasin neuf, y **synchronise réellement** depuis le serveur au nom
  /// de [token], et rend le repository de lecture pour [userId].
  Future<(AppDatabase, StoreGroupRepository)> syncAs(
    String token,
    String userId,
  ) async {
    final db = openTestDatabase();
    final dio = Dio(
      BaseOptions(
        baseUrl: server.url,
        headers: {'Authorization': 'Bearer $token'},
      ),
    )..interceptors.add(unwrapEnvelopeInterceptor);
    // Deux cycles : le premier tire, le second prouve qu'aucun resync n'est dû.
    await SyncEngine(
      api: SyncApi(dio: dio),
      dao: db.syncDao,
      collections: syncedCollections(),
    ).synchronize();
    dio.close(force: true);
    return (db, StoreGroupRepository(db.groupDao, currentUserId: userId));
  }

  test('Bob voit le DM en direct, titré « Alice Koffi », adressé par userId',
      () async {
    final (db, repo) = await syncAs(bobToken, bobId);
    addTearDown(db.close);

    final inbox = await repo.conversations().first;
    final dm = inbox.singleWhere((c) => c.kind == ConversationKind.direct);
    expect(dm.name, 'Alice Koffi');
    expect(dm.peerUserId, aliceId);
    expect(dm.lastMessagePreview, 'Salut Bob');

    // Résolution par userId (ce que fait l'écran de DM naissant).
    final resolved = await repo.directConversationWith(aliceId).first;
    expect(resolved, isNotNull);
    expect(resolved!.id, dm.id);

    // La liste des membres du fil : les deux, nommés par `profiles`.
    final members = await repo.members(dm.id).first;
    expect(members.map((m) => m.userId).toSet(), {aliceId, bobId});
    expect(
      members.firstWhere((m) => m.userId == aliceId).name,
      'Alice Koffi',
    );
  });

  test('Alice voit le même fil, titré « Bob Mensah »', () async {
    final (db, repo) = await syncAs(aliceToken, aliceId);
    addTearDown(db.close);

    final dm = (await repo.conversations().first)
        .singleWhere((c) => c.kind == ConversationKind.direct);
    expect(dm.name, 'Bob Mensah');
    expect(dm.peerUserId, bobId);
  });

  test('un tiers (Carol) ne voit jamais le fil direct', () async {
    final (db, repo) = await syncAs(carolToken, carolId);
    addTearDown(db.close);

    final inbox = await repo.conversations().first;
    expect(inbox.where((c) => c.kind == ConversationKind.direct), isEmpty);
    // Ni comme fil à résoudre.
    expect(await repo.directConversationWith(aliceId).first, isNull);
  });

  test('idempotence : un renvoi (même clientMessageId) ne duplique pas', () async {
    // Renvoi à l'identique — get-or-create + idempotence de message.
    await server.sendDirect(aliceToken, bobId, 'Salut Bob', clientMessageId: 'c-1');

    final (db, repo) = await syncAs(bobToken, bobId);
    addTearDown(db.close);

    final dm = (await repo.conversations().first)
        .singleWhere((c) => c.kind == ConversationKind.direct);
    final messages = await repo.messages(dm.id).first;
    expect(messages.where((m) => m.text == 'Salut Bob'), hasLength(1));
  });
}
