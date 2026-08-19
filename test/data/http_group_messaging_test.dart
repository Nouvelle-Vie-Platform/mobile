// **Le contrat d'écriture de la messagerie de groupe**, écrit sur un adaptateur
// factice. `POST /groups/:id/messages`, `/join`, `/leave` sont figés
// (`docs/human/groups.md`) ; les `join-requests` (création + approve/reject)
// sont dérivés du PRD `messagerie-groupes-officiels.md` (décision D12) et
// **à réconcilier** avec l'agent serveur.
//
// Le corps est en `camelCase`, comme tous les corps de cette API : son
// `snake_case` ne concerne que les query strings et l'enveloppe `/sync`.

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/core/network/api_client.dart';
import 'package:maison_du_miracle/data/repositories/group_messaging.dart';
import 'package:maison_du_miracle/data/repositories/http_group_messaging.dart';

import '../helpers/fake_api.dart';

void main() {
  late FakeAdapter adapter;
  late ApiClient api;
  late HttpGroupMessaging messaging;

  void serve(ResponseBody Function(RequestOptions options) reply) {
    adapter = FakeAdapter(reply);
    api.dio.httpClientAdapter = adapter;
  }

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    api = ApiClient.instance;
    messaging = HttpGroupMessaging(client: api);
    serve((_) => jsonReply(201, null));
  });

  group('endpoints', () {
    test('envoi de message — corps camelCase, id d\'idempotence', () async {
      await messaging.sendMessage(
        'grp-1',
        body: 'Que la paix soit avec vous',
        clientMessageId: 'cid-42',
        clientCreatedAt: DateTime.utc(2026, 8, 17, 10, 30),
      );
      expect(adapter.lastRequest.method, 'POST');
      expect(adapter.lastRequest.path, '/groups/grp-1/messages');
      expect(adapter.lastBody, {
        'body': 'Que la paix soit avec vous',
        'clientMessageId': 'cid-42',
        'clientCreatedAt': '2026-08-17T10:30:00.000Z',
      });
    });

    test('rejoindre / demander / quitter', () async {
      await messaging.join('grp-2');
      expect(adapter.lastRequest.path, '/groups/grp-2/join');

      await messaging.requestToJoin('grp-2');
      expect(adapter.lastRequest.path, '/groups/grp-2/join-requests');

      await messaging.leave('grp-2');
      expect(adapter.lastRequest.path, '/groups/grp-2/leave');
    });

    test('valider / refuser une demande', () async {
      await messaging.approveJoinRequest('grp-3', 7);
      expect(adapter.lastRequest.path, '/groups/grp-3/join-requests/7/approve');

      await messaging.rejectJoinRequest('grp-3', 7);
      expect(adapter.lastRequest.path, '/groups/grp-3/join-requests/7/reject');
    });
  });

  group('mapGroupWriteError', () {
    DioException http(int status) => DioException(
          requestOptions: RequestOptions(path: '/groups/x/join'),
          response: Response(
            requestOptions: RequestOptions(path: '/groups/x/join'),
            statusCode: status,
          ),
        );

    test('le partage se fait d\'abord sur l\'existence d\'une réponse', () {
      final noResponse = DioException(
        requestOptions: RequestOptions(path: '/groups/x/join'),
        type: DioExceptionType.connectionError,
      );
      expect(
        mapGroupWriteError(noResponse).code,
        GroupWriteErrorCode.network,
      );
    });

    test('les statuts se traduisent en codes', () {
      expect(
          mapGroupWriteError(http(401)).code, GroupWriteErrorCode.unauthorized);
      expect(mapGroupWriteError(http(403)).code, GroupWriteErrorCode.forbidden);
      expect(mapGroupWriteError(http(404)).code, GroupWriteErrorCode.gone);
      expect(mapGroupWriteError(http(409)).code, GroupWriteErrorCode.conflict);
      expect(mapGroupWriteError(http(422)).code, GroupWriteErrorCode.rejected);
      expect(mapGroupWriteError(http(500)).code, GroupWriteErrorCode.server);
    });

    test('l\'envoi remonte une GroupWriteException typée', () async {
      serve((_) => jsonReply(403, {'message': 'diffusion'}));
      expect(
        () => messaging.sendMessage('grp-1', body: 'x'),
        throwsA(
          isA<GroupWriteException>().having(
            (e) => e.code,
            'code',
            GroupWriteErrorCode.forbidden,
          ),
        ),
      );
    });
  });
}
