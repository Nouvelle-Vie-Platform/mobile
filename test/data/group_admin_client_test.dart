/// **Les gestes de groupe, au fil** (#145, tranche M6) : chemins, corps, et la
/// lecture des réponses — surtout celle qui dit « c'est déjà fait ».
///
/// Un geste rejoué (réponse perdue, double appui) ne doit **jamais** se lire
/// comme un échec : le serveur répond 409 « déjà membre » ou « demande déjà en
/// attente », et ce client y lit `done` (piège 5 du plan).
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/core/network/api_client.dart';
import 'package:maison_du_miracle/data/repositories/group_admin_client.dart';
import 'package:maison_du_miracle/data/repositories/group_message_sender.dart';

import '../helpers/fake_api.dart';

void main() {
  late FakeAdapter adapter;
  late ApiClient api;
  late HttpGroupAdminClient client;

  void serve(ResponseBody Function(RequestOptions options) reply) {
    adapter = FakeAdapter(reply);
    api.dio.httpClientAdapter = adapter;
  }

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    api = ApiClient.instance;
    client = HttpGroupAdminClient(client: api);
    serve((_) => jsonReply(200, {}));
  });

  group('Capacités', () {
    test('un responsable : créer, avec le ciblage servi', () async {
      serve((_) => jsonReply(200, {
            'canCreateGroup': true,
            'createBranchIds': [3],
          }));

      final capabilities = await client.capabilities();

      expect(adapter.lastRequest.method, 'GET');
      expect(adapter.lastRequest.path, '/groups/capabilities');
      expect(capabilities.canCreateGroup, isTrue);
      expect(capabilities.createBranchIds, [3]);
    });

    test('une panne n\'offre rien', () async {
      serve((_) => errorReply(500, 'E_INTERNAL'));
      final capabilities = await client.capabilities();
      expect(capabilities.canCreateGroup, isFalse);
    });
  });

  group('Créer un groupe', () {
    test('POST /groups : id client, invite_only, membres choisis', () async {
      serve((_) => jsonReply(201, {'id': 'g-new'}));

      final outcome = await client.createGroup(
        id: '019a0000-0000-7000-8000-000000000001',
        name: '  Équipe louange ',
        description: '   ',
        branchIds: const [3],
        memberIds: const ['u-1', 'u-2'],
      );

      expect(outcome, GroupActionOutcome.done);
      expect(adapter.lastRequest.path, '/groups');
      expect(adapter.lastBody, {
        'id': '019a0000-0000-7000-8000-000000000001',
        'name': 'Équipe louange',
        'joinPolicy': 'invite_only',
        'branchIds': [3],
        'memberIds': ['u-1', 'u-2'],
      });
    });

    test('refusée à un non-responsable : refused', () async {
      serve((_) => errorReply(403, 'E_OUTSIDE_SCOPE'));
      final outcome = await client.createGroup(
        id: 'x',
        name: 'Groupe',
        branchIds: const [],
        memberIds: const [],
      );
      expect(outcome, GroupActionOutcome.refused);
    });
  });

  group('Rejoindre, demander, quitter : rejouer est sûr', () {
    test('rejoindre un groupe dont on est déjà membre : done', () async {
      serve((_) => errorReply(409, 'E_ALREADY_GROUP_MEMBER'));
      expect(await client.join('g-1'), GroupActionOutcome.done);
      expect(adapter.lastRequest.path, '/groups/g-1/join');
    });

    test('redemander une adhésion en attente : done', () async {
      serve((_) => errorReply(409, 'E_GROUP_JOIN_REQUEST_ALREADY_PENDING'));
      expect(await client.requestToJoin('g-1'), GroupActionOutcome.done);
      expect(adapter.lastRequest.path, '/groups/g-1/join-requests');
    });

    test('quitter un groupe qu\'on a déjà quitté : done', () async {
      serve((_) => errorReply(403, 'E_NOT_GROUP_MEMBER'));
      expect(await client.leave('g-1'), GroupActionOutcome.done);
    });

    test('rejoindre un groupe sur invitation : refused', () async {
      serve((_) => errorReply(403, 'E_GROUP_INVITE_ONLY'));
      expect(await client.join('g-1'), GroupActionOutcome.refused);
    });

    test('quitter un tête-à-tête : refused', () async {
      serve((_) => errorReply(422, 'E_DIRECT_GROUP_NOT_LEAVABLE'));
      expect(await client.leave('g-dm'), GroupActionOutcome.refused);
    });

    test('pas de réseau : unreachable', () async {
      serve((_) => throw const SocketException('hors ligne'));
      expect(await client.join('g-1'), GroupActionOutcome.unreachable);
    });
  });

  group('Administrer', () {
    test('ajouter, retirer, nommer : les bons verbes et chemins', () async {
      await client.addMember('g-1', 'u-1');
      expect(adapter.lastRequest.method, 'POST');
      expect(adapter.lastRequest.path, '/groups/g-1/members');
      expect(adapter.lastBody, {'userId': 'u-1'});

      await client.removeMember('g-1', 'u-1');
      expect(adapter.lastRequest.method, 'DELETE');
      expect(adapter.lastRequest.path, '/groups/g-1/members/u-1');

      await client.setRole('g-1', 'u-1', 'moderator');
      expect(adapter.lastRequest.method, 'PATCH');
      expect(adapter.lastRequest.path, '/groups/g-1/members/u-1');
      expect(adapter.lastBody, {'role': 'moderator'});
    });

    test('retirer quelqu\'un qui n\'y est déjà plus : done', () async {
      serve((_) => errorReply(404, 'E_TARGET_NOT_GROUP_MEMBER'));
      expect(
        await client.removeMember('g-1', 'u-1'),
        GroupActionOutcome.done,
      );
    });

    test('retirer l\'animateur : refused', () async {
      serve((_) => errorReply(403, 'E_CANNOT_REMOVE_LEADER'));
      expect(
        await client.removeMember('g-1', 'u-leader'),
        GroupActionOutcome.refused,
      );
    });

    test('la file des demandes, et la décision', () async {
      serve((_) => jsonReply(200, [
            {'id': 7, 'userId': 'u-7', 'displayName': 'Afi Mensah'},
            {'id': 8, 'userId': 'u-8', 'displayName': null},
          ]));
      final requests = await client.joinRequests('g-1');
      expect(adapter.lastRequest.path, '/groups/g-1/join-requests');
      expect(requests!.map((r) => r.id), [7, 8]);
      expect(requests.last.displayName, isNull);

      serve((_) => jsonReply(200, {}));
      await client.decideJoinRequest('g-1', 7, approve: true);
      expect(adapter.lastRequest.path, '/groups/g-1/join-requests/7/approve');
      await client.decideJoinRequest('g-1', 8, approve: false);
      expect(adapter.lastRequest.path, '/groups/g-1/join-requests/8/reject');
    });

    test('une file illisible rend null, pas une liste vide', () async {
      serve((_) => errorReply(403, 'E_INSUFFICIENT_GROUP_ROLE'));
      expect(await client.joinRequests('g-1'), isNull);
    });
  });

  group('Le premier message d\'un tête-à-tête', () {
    test('la clé de fil d\'une personne part à la route directe', () {
      final key = directThreadKey('u-42');
      expect(directTargetOf(key), 'u-42');
      expect(messagesPathFor(key), '/groups/direct/u-42/messages');
    });

    test('un vrai groupe garde sa route', () {
      const groupId = '019a2000-0000-7000-8000-000000grp001';
      expect(directTargetOf(groupId), isNull);
      expect(messagesPathFor(groupId), '/groups/$groupId/messages');
    });

    test('l\'envoyeur poste le premier message à la route directe', () async {
      serve((_) => jsonReply(201, {}));
      final sent = await HttpGroupMessageSender(client: api).send(
        groupId: directThreadKey('u-42'),
        body: 'Bonjour',
        clientMessageId: 'c-1',
        clientCreatedAt: DateTime.utc(2026, 10, 6, 9),
      );
      expect(sent, isTrue);
      expect(adapter.lastRequest.path, '/groups/direct/u-42/messages');
      expect(adapter.lastBody['clientMessageId'], 'c-1');
    });
  });

  group('L\'envoyeur distingue le refus définitif', () {
    Future<bool> sendOnce() => HttpGroupMessageSender(client: api).send(
          groupId: 'g-1',
          body: 'Amen',
          clientMessageId: 'c-1',
          clientCreatedAt: DateTime.utc(2026, 10, 6, 9),
        );

    for (final status in [403, 404, 409, 422]) {
      test('$status : lève GroupMessageRefused', () async {
        serve((_) => errorReply(status, 'E_REFUSED'));
        await expectLater(
          sendOnce(),
          throwsA(
            isA<GroupMessageRefused>()
                .having((e) => e.statusCode, 'statusCode', status),
          ),
        );
      });
    }

    test('500 : « pas parti », sans lever — cela peut changer', () async {
      serve((_) => errorReply(500, 'E_INTERNAL'));
      expect(await sendOnce(), isFalse);
    });

    test('réseau absent : « pas parti », sans lever', () async {
      serve((_) => throw const SocketException('hors ligne'));
      expect(await sendOnce(), isFalse);
    });
  });
}
