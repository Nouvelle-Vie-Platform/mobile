/// **L'envoi d'une requête** (#148) — le corps de `POST /interactions` et la
/// lecture de ses échecs.
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/repositories/http_request_submitter.dart';
import 'package:maison_du_miracle/data/repositories/my_requests_repository.dart';
import 'package:maison_du_miracle/models/my_request_view.dart';

void main() {
  final now = DateTime.utc(2026, 10, 5, 9, 30);

  group('Le corps envoyé', () {
    test('une prière porte sa visibilité, en camelCase', () {
      const draft = RequestDraft(
        kind: RequestKind.prayer,
        title: 'Pour ma mère',
        content: 'Sa guérison.',
        isAnonymous: true,
        shareWithCommunity: true,
      );

      expect(draft.toJson(id: 'id-1', now: now), {
        'id': 'id-1',
        'type': 'prayer_request',
        'title': 'Pour ma mère',
        'content': 'Sa guérison.',
        'isAnonymous': true,
        'visibility': 'community',
        'clientCreatedAt': '2026-10-05T09:30:00.000Z',
      });
    });

    test('une prière gardée pour l\'équipe pastorale part en private', () {
      const draft = RequestDraft(
        kind: RequestKind.prayer,
        title: 'Pour ma mère',
        content: 'Sa guérison.',
        isAnonymous: false,
      );

      expect(draft.toJson(id: 'id', now: now)['visibility'], 'private');
    });

    test('une suggestion ou une réclamation ne porte aucune visibilité', () {
      // Le serveur la force en `private` (ADR-0014) : l'envoyer laisserait
      // croire qu'elle se choisit.
      for (final kind in [RequestKind.suggestion, RequestKind.complaint]) {
        final body = RequestDraft(
          kind: kind,
          title: 'Objet',
          content: 'Message',
          isAnonymous: false,
          shareWithCommunity: true,
        ).toJson(id: 'id', now: now);

        expect(body.containsKey('visibility'), isFalse, reason: kind.name);
        expect(body['type'], kind.wire);
      }
    });
  });

  group('Les échecs', () {
    DioException failure(int? status, [Object? body]) => DioException(
          requestOptions: RequestOptions(path: '/interactions'),
          response: status == null
              ? null
              : Response<Object?>(
                  requestOptions: RequestOptions(path: '/interactions'),
                  statusCode: status,
                  data: body,
                ),
        );

    test('sans réponse : le réseau', () {
      expect(mapRequestSubmitError(failure(null)).code,
          RequestSubmitErrorCode.network);
    });

    test('401, 422, et le reste', () {
      expect(mapRequestSubmitError(failure(401)).code,
          RequestSubmitErrorCode.unauthorized);
      expect(mapRequestSubmitError(failure(422)).code,
          RequestSubmitErrorCode.invalid);
      final server = mapRequestSubmitError(
        failure(409, {'code': 'E_OWNER_CONFLICT', 'message': 'Conflit'}),
      );
      expect(server.code, RequestSubmitErrorCode.server);
      expect(server.message, 'Conflit');
    });
  });
}
