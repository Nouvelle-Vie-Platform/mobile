/// **Les cinq collections d'« Échanges », de bout en bout** (#96).
///
/// Ce que ce fichier vérifie n'est pas l'affichage — c'est le voyage : que les
/// groupes, le roster, les profils et le fil arrivent, que `profiles` arrive
/// **avant** `group_messages`, que le **détachement d'un auteur** (ADR-0032)
/// efface vraiment l'uuid d'une ligne déjà stockée, que les tombstones retirent ce
/// qu'ils doivent retirer, et qu'un serveur qui ne connaît pas encore l'une des
/// cinq ne coûte **rien** aux autres.
///
/// Les DAO s'écrivent ici par le **moteur**, jamais par un insert nu : c'est la
/// seule façon de prouver que la forme servie par le serveur traverse réellement
/// `sync_rows.dart` et le magasin.
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/core/network/api_client.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/local/sync_dao.dart';
import 'package:maison_du_miracle/data/repositories/store_echanges_repository.dart';
import 'package:maison_du_miracle/data/sync/branch_filter.dart';
import 'package:maison_du_miracle/data/sync/sync_api.dart';
import 'package:maison_du_miracle/data/sync/sync_engine.dart';
import 'package:maison_du_miracle/data/sync/synced_collection.dart';
import 'package:maison_du_miracle/models/echanges_view.dart';

import '../data/local/local_database_fixtures.dart';
import '../helpers/fake_sync_server.dart';
import '../helpers/sync_fixtures.dart';

/// Les cinq clés, dans l'ordre où ce client les tire.
const List<String> _echanges = [
  SyncCollectionKey.profiles,
  SyncCollectionKey.groups,
  SyncCollectionKey.groupMembers,
  SyncCollectionKey.groupJoinRequests,
  SyncCollectionKey.groupMessages,
];

void main() {
  late FakeSyncServer server;
  late Dio dio;
  late AppDatabase db;
  late SyncDao dao;

  setUp(() {
    server = FakeSyncServer();
    dio = Dio(BaseOptions(baseUrl: 'https://eenv.brainsial.com'))
      ..interceptors.add(unwrapEnvelopeInterceptor)
      ..httpClientAdapter = server;
    db = openTestDatabase();
    dao = db.syncDao;
  });

  tearDown(() => db.close());

  /// Le manifeste des seules collections qui nous intéressent, avec la partition
  /// **relevée sur le descripteur** et non devinée : `profiles`, `group_members`
  /// et `group_join_requests` sont `private` (périmètre **relationnel**), `groups`
  /// et `group_messages` sont `branch` (périmètre piloté par l'appartenance).
  Map<String, Object?> echangesManifest() => {
        'scope_version': 1,
        'collections': [
          for (final key in _echanges)
            manifestEntry(
              key,
              partition: kSyncCollections[key]!,
              currentCursor: _cursorOf(key),
              hasChanges: true,
              fromZero: true,
            ),
        ],
      };

  void serveAll() {
    server
      ..serveManifest(echangesManifest())
      ..serveCollection('profiles', profilesPage())
      ..serveCollection('groups', groupsPage())
      ..serveCollection('group_members', groupMembersPage())
      ..serveCollection('group_join_requests', groupJoinRequestsPage())
      ..serveCollection('group_messages', groupMessagesPage());
  }

  SyncEngine engine({List<String>? only, Future<int?> Function()? branchId}) =>
      SyncEngine(
        api: SyncApi(dio: dio),
        dao: dao,
        collections: syncedCollections()
            .where((c) => (only ?? _echanges).contains(c.key))
            .toList(growable: false),
        branchId: branchId,
      );

  StoreEchangesRepository repository() =>
      StoreEchangesRepository(db.groupDao, userId: kMeId);

  group('Le registre', () {
    test('les cinq collections sont là, et `profiles` précède le fil', () {
      final keys = syncedCollections().map((c) => c.key).toList();

      for (final key in _echanges) {
        expect(keys, contains(key), reason: '« $key » doit être répliquée');
      }

      // **La seule contrainte d'ordre que le cadrage écrit en toutes lettres** :
      // `profiles` nomme ce que les messages désignent. Un fil arrivé avant les
      // noms s'afficherait sous des avatars anonymes, puis changerait de visage au
      // cycle suivant.
      expect(
        keys.indexOf(SyncCollectionKey.profiles),
        lessThan(keys.indexOf(SyncCollectionKey.groupMessages)),
      );
      // Et le roster après le groupe qu'il peuple — la règle du pivot
      // `teaching_guests` : une appartenance ne désigne rien par elle-même.
      expect(
        keys.indexOf(SyncCollectionKey.groups),
        lessThan(keys.indexOf(SyncCollectionKey.groupMembers)),
      );
    });

    test('aucune des cinq n\'est filtrée par la préférence de branche', () {
      // ⚠️ `groups` et `group_messages` sont `partition: 'branch'` **côté
      // serveur**, et elles n'entrent pourtant pas dans la liste du client. Leur
      // périmètre réel est l'**appartenance** : filtrer ici par la préférence de
      // branche retirerait du téléphone un groupe dont je suis membre et qui est
      // rattaché à une autre assemblée — c'est-à-dire ma propre conversation.
      for (final key in _echanges) {
        expect(kBranchScopedCollections, isNot(contains(key)));
        expect(isBranchScoped(key), isFalse, reason: key);
      }
    });

    test('aucun `branch_id` ne part, même avec une préférence posée', () async {
      serveAll();

      await engine(branchId: () async => 3).synchronize();

      for (final key in _echanges) {
        expect(
          server.requestsFor(key).last.queryParameters['branch_id'],
          isNull,
          reason: '« $key » ne doit pas être filtrée par branche',
        );
      }
    });
  });

  group('Le tirage', () {
    test('les cinq collections entrent au magasin, avec leurs curseurs',
        () async {
      serveAll();

      final report = await engine().synchronize();

      expect(report.pulled, _echanges);
      expect(await db.select(db.profiles).get(), hasLength(3));
      expect(await db.select(db.groups).get(), hasLength(3));
      expect(await db.select(db.groupMembers).get(), hasLength(4));
      expect(await db.select(db.groupJoinRequests).get(), hasLength(1));
      expect(await db.select(db.groupMessages).get(), hasLength(4));

      for (final key in _echanges) {
        expect(await dao.cursorFor(key), _cursorOf(key), reason: key);
      }
    });

    test('un groupe garde ce que le serveur sert, et rien de plus', () async {
      serveAll();
      await engine().synchronize();

      final row = (await (db.select(db.groups)
                ..where((g) => g.id.equals(kGroupId)))
              .get())
          .single;

      expect(row.name, 'Chorale Harmonie');
      expect(row.joinPolicy, 'invite_only');
      expect(row.postPolicy, 'all');
      expect(row.isWriteLocked, isFalse);
      expect(row.isActive, isTrue);
      expect(row.isDirect, isFalse);
      // **`ownerId` est `owner_user_id`**, renommé par le transformer : il n'y a
      // pas de clé `ownerUserId` sur le fil.
      expect(row.ownerId, kPeerId);
      expect(row.ownerKind, 'user');
      // L'effectif vient du **serveur** (membres actifs), pas du roster local.
      expect(row.memberCount, 3);
      expect(row.syncStamp, greaterThan(0));
    });

    test('un profil sans nom entre quand même, nom nul compris', () async {
      serveAll();
      await engine().synchronize();

      final row = (await (db.select(db.profiles)
                ..where((p) => p.id.equals(kGoneId)))
              .get())
          .single;

      // Un compte qui n'a jamais rempli son profil n'a pas de nom à montrer, et
      // c'est un cas **courant** — pas une ligne mutilée qui coûterait la page.
      expect(row.displayName, isNull);
      // `avatarUrl` est toujours nul aujourd'hui : `users` n'a pas de colonne
      // d'avatar.
      expect(row.avatarUrl, isNull);
    });
  });

  group('L\'origine d\'un message — le couple, jamais le nul seul', () {
    /// Les quatre lignes du tableau du contrat, lues **par le repository**, donc
    /// par le seul chemin que les écrans empruntent.
    Future<Map<String, GroupMessageView>> thread() async {
      serveAll();
      await engine().synchronize();
      final messages = await repository().thread(kGroupId).first;
      return {for (final m in messages) m.id: m};
    }

    test('(uuid, false) d\'un autre : un membre, et une bulle', () async {
      final m = (await thread())[memberMessagePayload['id']]!;

      expect(m.origin, MessageOrigin.member);
      expect(m.origin.isBubble, isTrue);
      expect(m.mine, isFalse);
      // Le nom vient de `profiles`, joint tolérablement.
      expect(m.authorName, 'Estelle Adjo');
    });

    test('(uuid, false) = le mien : une bulle envoyée', () async {
      final m = (await thread())[myMessagePayload['id']]!;

      expect(m.origin, MessageOrigin.member);
      // **`mine` se dérive**, il ne se sert pas : c'est la comparaison de
      // `authorId` à l'identifiant de session.
      expect(m.mine, isTrue);
      expect(m.delivery, MessageDelivery.sent);
    });

    test('(null, true) : le serveur parle, donc un bandeau', () async {
      final m = (await thread())[systemMessagePayload['id']]!;

      expect(m.origin, MessageOrigin.system);
      expect(m.origin.isBubble, isFalse);
      expect(m.mine, isFalse);
      expect(m.authorName, isNull);
    });

    test('(null, false) : UN AUTEUR RETIRÉ — et c\'est une BULLE', () async {
      // ⚠️ **Le test qui échoue si quelqu'un réécrit `authorId == null`.** Le nul
      // a deux sens depuis la suppression de compte (ADR-0032) : tester le nul
      // seul afficherait la phrase d'un fidèle parti comme une annonce du
      // serveur — centrée, en gris, mêlée aux « X a rejoint le groupe ».
      final m = (await thread())[removedAuthorMessagePayload['id']]!;

      expect(m.origin, MessageOrigin.removedAuthor);
      expect(
        m.origin.isBubble,
        isTrue,
        reason: 'un auteur retiré est une bulle, jamais un bandeau',
      );
      expect(m.origin, isNot(MessageOrigin.system));
      // Il n'est **jamais** `mine` : la comparaison à `null` doit échouer, pas se
      // replier.
      expect(m.mine, isFalse);
      // Et pas de nom : « Membre retiré » est un libellé d'interface, choisi par
      // l'écran sur l'origine, et il ne doit pas traverser le modèle.
      expect(m.authorName, isNull);
    });

    test('les quatre origines du fil sont bien trois origines distinctes',
        () async {
      final messages = (await thread()).values.toList();

      // Le fil porte **un exemplaire de chaque ligne du tableau**, et c'est ce
      // qui fait que le cas de l'auteur retiré est montré par un écran et pas
      // seulement par un test unitaire.
      expect(
        messages.map((m) => m.origin).toSet(),
        {
          MessageOrigin.member,
          MessageOrigin.system,
          MessageOrigin.removedAuthor,
        },
      );
    });
  });

  group('Le détachement arrive sur une ligne DÉJÀ STOCKÉE', () {
    test('l\'uuid de l\'auteur est perdu, et l\'origine bascule', () async {
      // ⚠️ **Le cas qui ne s'obtient qu'en deux temps**, et le plus facile à
      // rater : `EraseAccount` écrit `author_id = NULL` **et** bouscule
      // `updated_at` à la main, exprès pour que la ligne reparte dans le flux. Le
      // mobile ne reçoit donc pas un message neuf — il reçoit **la mise à jour
      // d'un message qu'il a déjà**.
      //
      // Les deux pages sont scriptées **avant** le premier cycle : la file du
      // double rend sa dernière réponse en boucle, et une page ajoutée après coup
      // se rangerait derrière celle qui vient d'être servie.
      server
        ..serveManifest(echangesManifest())
        ..serveCollection('profiles', profilesPage())
        ..serveCollection('groups', groupsPage())
        ..serveCollection('group_members', groupMembersPage())
        ..serveCollection('group_join_requests', groupJoinRequestsPage())
        ..servePages('group_messages', [
          groupMessagesPageAttached(),
          groupMessagesDetachPage(),
        ]);

      await engine().synchronize();

      final id = removedAuthorMessagePayload['id']! as String;
      Future<GroupMessageRow> stored() async =>
          (await (db.select(db.groupMessages)..where((m) => m.id.equals(id)))
                  .get())
              .single;

      // Premier état : la ligne porte son auteur.
      expect((await stored()).authorId, kGoneId);
      expect(
          (await repository().thread(kGroupId).first)
              .firstWhere((m) => m.id == id)
              .origin,
          MessageOrigin.member);

      // Le flux ramène **la même ligne**, détachée.
      await engine().synchronize();

      // ⚠️ **L'écriture doit REMPLACER, pas fusionner.** Un upsert qui ignorerait
      // les champs nuls (`Value.absentIfNull`, un `COALESCE`, un « ne pas écraser
      // par du vide ») laisserait l'ancien uuid en place, et l'effacement serait
      // faux sur **tous les téléphones déjà synchronisés** : la seule promesse qui
      // compte — « vos messages ne vous sont plus attribués » — ne serait tenue
      // que côté serveur.
      expect(
        (await stored()).authorId,
        isNull,
        reason: 'le magasin doit avoir PERDU l\'uuid, pas l\'avoir conservé',
      );
      // Et `isSystem` n'a pas bougé : c'est ce qui en fait un auteur retiré et
      // non un message du serveur.
      expect((await stored()).isSystem, isFalse);
      // Une seule ligne : la mise à jour a remplacé, elle n'a pas doublé.
      expect(await db.select(db.groupMessages).get(), hasLength(4));
    });

    test('un écran ouvert suit, parce que le domaine se lit en Stream',
        () async {
      // Le corollaire du précédent, et il compte autant : une bulle affichée doit
      // perdre son auteur **sous les yeux du lecteur**, pas au prochain démarrage.
      // Un `Future` livrerait une photographie prise au moment du clic.
      server
        ..serveManifest(echangesManifest())
        ..serveCollection('profiles', profilesPage())
        ..serveCollection('groups', groupsPage())
        ..serveCollection('group_members', groupMembersPage())
        ..serveCollection('group_join_requests', groupJoinRequestsPage())
        ..servePages('group_messages', [
          groupMessagesPageAttached(),
          groupMessagesDetachPage(),
        ]);
      await engine().synchronize();

      final id = removedAuthorMessagePayload['id']! as String;
      final detached = repository().thread(kGroupId).firstWhere(
            (messages) => messages.any(
                (m) => m.id == id && m.origin == MessageOrigin.removedAuthor),
          );

      await engine().synchronize();

      // Le flux a émis de lui-même : rien n'a rouvert l'écran.
      expect(await detached, isNotEmpty);
    });
  });

  group('Les tombstones', () {
    test('un message supprimé par modération quitte le magasin', () async {
      server
        ..serveManifest(echangesManifest())
        ..serveCollection('profiles', profilesPage())
        ..serveCollection('groups', groupsPage())
        ..serveCollection('group_members', groupMembersPage())
        ..serveCollection('group_join_requests', groupJoinRequestsPage())
        ..servePages('group_messages', [
          groupMessagesPage(),
          groupMessagesDeletionPage(),
        ]);
      await engine().synchronize();
      expect(await db.select(db.groupMessages).get(), hasLength(4));

      await engine().synchronize();

      // `readsAsRetraction` tranche **avant** toute désérialisation : la ligne
      // quitte le magasin par son identifiant, quelle que soit son origine.
      expect(await db.select(db.groupMessages).get(), hasLength(3));
      final ids = (await db.select(db.groupMessages).get()).map((m) => m.id);
      expect(ids, isNot(contains(memberMessagePayload['id'])));
    });

    test('mon départ retire la conversation, sans effacer le groupe', () async {
      // ⚠️ **La raison pour laquelle la liste se lit sur `group_members`.** Ni
      // `groups` ni `profiles` n'a de tombstone : quitter un groupe n'efface
      // aucune ligne de `groups`. Ce qui voyage, c'est la rétractation de **mon
      // appartenance** — et c'est elle qui doit faire disparaître la tuile.
      server
        ..serveManifest(echangesManifest())
        ..serveCollection('profiles', profilesPage())
        ..serveCollection('groups', groupsPage())
        ..servePages('group_members', [
          groupMembersPage(),
          groupMembersRetractionPage(),
        ])
        ..serveCollection('group_join_requests', groupJoinRequestsPage())
        ..serveCollection('group_messages', groupMessagesPage());
      await engine().synchronize();

      final before = await repository().conversations().first;
      expect(before.map((c) => c.groupId), contains(kGroupId));

      await engine().synchronize();

      final after = await repository().conversations().first;
      expect(
        after.map((c) => c.groupId),
        isNot(contains(kGroupId)),
        reason: 'la conversation quittée ne doit plus être listée',
      );
      // Le groupe, lui, est **toujours en magasin** : il n'a pas de tombstone, et
      // c'est la lecture qui cesse de le lister.
      expect(
        (await db.select(db.groups).get()).map((g) => g.id),
        contains(kGroupId),
      );
    });
  });

  group('Un serveur en retard d\'une version', () {
    test('le 404 de `profiles` saute la collection et ne coupe rien', () async {
      // `FakeSyncServer` répond **404** à une collection jamais scriptée, comme le
      // registre serveur le fait d'une clé non enregistrée.
      //
      // ⚠️ **On fait échouer `profiles`, et on prouve que `groups` — rangée juste
      // après elle — est tirée quand même.** Choisir une collection éloignée
      // affaiblirait le test en sautant tout ce qui est entre les deux : le `404`
      // est la *seule* erreur non fatale du moteur, et toute autre couperait le
      // cycle, donc **toutes** les collections rangées après la fautive.
      final keys = syncedCollections().map((c) => c.key).toList();
      expect(
        keys[keys.indexOf(SyncCollectionKey.profiles) + 1],
        SyncCollectionKey.groups,
        reason: 'le test ne vaut que si `groups` suit immédiatement `profiles`',
      );

      server
        ..serveManifest(echangesManifest())
        // `profiles` n'est **pas** scriptée : elle prendra un 404.
        ..serveCollection('groups', groupsPage())
        ..serveCollection('group_members', groupMembersPage())
        ..serveCollection('group_join_requests', groupJoinRequestsPage())
        ..serveCollection('group_messages', groupMessagesPage());

      final report = await engine().synchronize();

      expect(report.skipped, contains(SyncCollectionKey.profiles));
      expect(report.pulled, contains(SyncCollectionKey.groups));
      expect(await db.select(db.profiles).get(), isEmpty);
      expect(await db.select(db.groups).get(), isNotEmpty);
      // **Aucun curseur n'est posé** sur la collection sautée : la prochaine fois,
      // elle repart de zéro.
      expect(await dao.cursorFor(SyncCollectionKey.profiles), isNull);
      // Et les trois rangées après `groups` sont arrivées elles aussi.
      expect(await db.select(db.groupMembers).get(), isNotEmpty);
      expect(await db.select(db.groupJoinRequests).get(), isNotEmpty);
      expect(await db.select(db.groupMessages).get(), isNotEmpty);
    });

    test('le fil reste lisible sans les noms', () async {
      // La contrepartie du précédent, et elle est voulue : un fil dont les profils
      // manquent se rend **quand même**, sans ligne d'auteur. La jointure est
      // tolérante, et l'absence s'affiche comme une absence — jamais un
      // « Utilisateur inconnu », qui ressemblerait à une donnée.
      server
        ..serveManifest(echangesManifest())
        ..serveCollection('groups', groupsPage())
        ..serveCollection('group_members', groupMembersPage())
        ..serveCollection('group_join_requests', groupJoinRequestsPage())
        ..serveCollection('group_messages', groupMessagesPage());
      await engine().synchronize();

      final messages = await repository().thread(kGroupId).first;

      expect(messages, hasLength(4));
      final member =
          messages.firstWhere((m) => m.id == memberMessagePayload['id']);
      expect(member.origin, MessageOrigin.member);
      expect(member.authorName, isNull);
    });
  });

  group('Les groupes à rejoindre', () {
    test('un groupe ouvert dont je ne suis pas membre est proposé', () async {
      serveAll();
      await engine().synchronize();

      final discover = await repository().discoverGroups().first;

      expect(discover.map((g) => g.groupId), [kOpenGroupId]);
      final group = discover.single;
      expect(group.joinPolicy, 'open');
      // L'effectif compté par le serveur, et la demande que j'ai déjà envoyée.
      expect(group.memberCount, 24);
      expect(group.requestStatus, 'pending');
    });

    test('ni mes groupes, ni les tête-à-tête n\'y figurent', () async {
      serveAll();
      await engine().synchronize();

      final ids =
          (await repository().discoverGroups().first).map((g) => g.groupId);

      // Sans cette rangée, le groupe créé au backoffice serait visible de
      // personne (`invite_only` par défaut, roster vide) ; avec elle, mes propres
      // conversations ne doivent pas s'y dédoubler.
      expect(ids, isNot(contains(kGroupId)));
      // Et un tête-à-tête n'est **jamais** découvrable — ni côté serveur, ni ici.
      expect(ids, isNot(contains(kDirectGroupId)));
    });
  });

  group('La lecture des conversations', () {
    test('un tête-à-tête porte le nom de l\'autre, pas celui du groupe',
        () async {
      serveAll();
      await engine().synchronize();

      final direct = (await repository().conversations().first)
          .firstWhere((c) => c.groupId == kDirectGroupId);

      // Le serveur nomme tous les groupes, DM compris, mais ce nom-là n'a pas été
      // écrit pour être lu : « direct:019a1000-019a1000 » serait une fuite
      // d'implémentation à l'écran.
      expect(direct.title, 'Estelle Adjo');
      expect(direct.isDirect, isTrue);
    });

    test('un groupe en diffusion ferme la barre de saisie', () async {
      // Le serveur revérifie à chaque envoi (gardes 3 et 4 de `SendGroupMessage`) ;
      // on le lit ici pour **ne pas offrir** un champ dont chaque appui prendrait
      // un 403.
      final broadcastId = broadcastGroupPayload['id']! as String;
      server
        ..serveManifest(echangesManifest())
        ..serveCollection('profiles', profilesPage())
        ..serveCollection(
          'groups',
          groupsPage(items: const [myGroupPayload, broadcastGroupPayload]),
        )
        ..serveCollection(
          'group_members',
          groupMembersPage(items: [
            myMembershipPayload,
            {...myMembershipPayload, 'id': 9, 'groupId': broadcastId},
          ]),
        )
        ..serveCollection('group_join_requests', groupJoinRequestsPage())
        ..serveCollection('group_messages', groupMessagesPage());
      await engine().synchronize();

      final conversations = await repository().conversations().first;

      expect(
        conversations.firstWhere((c) => c.groupId == kGroupId).canWrite,
        isTrue,
      );
      expect(
        conversations.firstWhere((c) => c.groupId == broadcastId).canWrite,
        isFalse,
        reason: 'un simple membre n\'écrit pas dans un groupe en diffusion',
      );
    });

    test('un animateur écrit même en diffusion', () async {
      // Les deux régimes (diffusion, verrou) sont indépendants et cumulatifs, et
      // un `leader`/`moderator` passe outre les deux. Le même test à l'envers :
      // sans lui, « personne n'écrit » passerait aussi.
      final broadcastId = broadcastGroupPayload['id']! as String;
      server
        ..serveManifest(echangesManifest())
        ..serveCollection('profiles', profilesPage())
        ..serveCollection(
            'groups',
            groupsPage(items: const [
              broadcastGroupPayload,
            ]))
        ..serveCollection(
            'group_members',
            groupMembersPage(items: [
              {
                ...myMembershipPayload,
                'id': 9,
                'groupId': broadcastId,
                'role': 'leader',
              },
            ]))
        ..serveCollection('group_join_requests', groupJoinRequestsPage())
        ..serveCollection('group_messages', groupMessagesPage());
      await engine().synchronize();

      final conversations = await repository().conversations().first;

      expect(
        conversations.firstWhere((c) => c.groupId == broadcastId).canWrite,
        isTrue,
      );
    });
  });
}

String _cursorOf(String key) => switch (key) {
      SyncCollectionKey.profiles => profilesCursor,
      SyncCollectionKey.groups => groupsCursor,
      SyncCollectionKey.groupMembers => groupMembersCursor,
      SyncCollectionKey.groupJoinRequests => groupJoinRequestsCursor,
      _ => groupMessagesCursor,
    };
