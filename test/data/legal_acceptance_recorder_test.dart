// **Le contrat d'écriture du consentement**, écrit sur un adaptateur factice.
//
// `POST /legal/accept` existe côté serveur (issue serveur #173, ADR-0036) ;
// ces tests disent ce que le mobile en attend, et ce qu'il en fait.
//
// Trois propriétés y sont protégées, et aucune ne se voit à l'œil nu :
//
// 1. **un seul corps, un tableau** — le serveur écrit en transaction, et deux
//    appels laisseraient une barrière à moitié levée ;
// 2. **la réponse est lue** — elle porte le résumé à jour, ce qui évite un
//    `GET /auth/me` de plus entre « Continuer » et l'application ;
// 3. **aucun refus ne sort en brut** — quatre codes, et le message du serveur
//    ne va nulle part.

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/core/network/api_client.dart';
import 'package:maison_du_miracle/data/repositories/http_legal_acceptance_recorder.dart';
import 'package:maison_du_miracle/data/repositories/legal_acceptance_recorder.dart';

import '../helpers/fake_api.dart';

void main() {
  late FakeAdapter adapter;
  late ApiClient api;
  late HttpLegalAcceptanceRecorder recorder;

  void serve(ResponseBody Function(RequestOptions options) reply) {
    adapter = FakeAdapter(reply);
    api.dio.httpClientAdapter = adapter;
  }

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    api = ApiClient.instance;
    recorder = HttpLegalAcceptanceRecorder(client: api);
    serve((_) => jsonReply(200, {
          'acceptedLegal': {'cgu': 3, 'privacy': 2}
        }));
  });

  group('POST /legal/accept', () {
    test('poste un tableau, en camelCase, en un seul appel', () async {
      await recorder.accept(const [
        LegalAcceptance(kind: 'cgu', version: 3),
        LegalAcceptance(kind: 'privacy', version: 2),
      ]);

      expect(adapter.requests, hasLength(1));
      expect(adapter.lastRequest.method, 'POST');
      expect(adapter.lastRequest.path, '/legal/accept');
      expect(adapter.lastBody, {
        'accepts': [
          {'kind': 'cgu', 'version': 3},
          {'kind': 'privacy', 'version': 2},
        ],
      });
    });

    test('rend le résumé à jour porté par la réponse', () async {
      final summary = await recorder.accept(
        const [LegalAcceptance(kind: 'cgu', version: 3)],
      );

      expect(summary, {'cgu': 3, 'privacy': 2});
    });

    test('un genre absent du résumé le reste — jamais garni à zéro', () {
      // Le serveur omet délibérément les genres jamais acceptés : l'absence et
      // le zéro se confondraient à la lecture, et personne n'a accepté « la
      // version 0 ».
      expect(
        acceptedLegalFrom(const {
          'acceptedLegal': {'cgu': 4}
        }),
        {'cgu': 4},
      );
      expect(
        acceptedLegalFrom(const {
          'acceptedLegal': {'cgu': 4}
        }).containsKey('privacy'),
        isFalse,
      );
    });

    test('une réponse illisible rend une carte vide, sans lever', () {
      // L'écriture a eu lieu — le serveur a répondu 200. Lever ici ferait
      // rejouer un enregistrement déjà fait.
      expect(acceptedLegalFrom(null), isEmpty);
      expect(acceptedLegalFrom(const {'acceptedLegal': 'oui'}), isEmpty);
      expect(acceptedLegalFrom(const {}), isEmpty);
    });
  });

  group('les refus', () {
    Future<LegalAcceptanceException> refusalOn(
      ResponseBody Function(RequestOptions options) reply,
    ) async {
      serve(reply);
      try {
        await recorder.accept(
          const [LegalAcceptance(kind: 'cgu', version: 3)],
        );
      } on LegalAcceptanceException catch (failure) {
        return failure;
      }
      fail('l\'appel aurait dû être refusé');
    }

    test('serveur injoignable → réseau', () async {
      final failure = await refusalOn(
        (_) => throw DioException.connectionError(
          requestOptions: RequestOptions(path: '/legal/accept'),
          reason: 'coupure',
        ),
      );

      // « Le serveur n'a rien dit » et « le serveur a dit non » sont deux
      // choses différentes : la première se règle en retrouvant du réseau.
      expect(failure.code, LegalAcceptanceErrorCode.network);
    });

    test('401 → session expirée', () async {
      final failure = await refusalOn(
        (_) => errorReply(401, 'E_UNAUTHORIZED_ACCESS'),
      );

      expect(failure.code, LegalAcceptanceErrorCode.unauthorized);
    });

    test('422 → version périmée, quel que soit le code du serveur', () async {
      expect(
        (await refusalOn((_) => errorReply(422, 'E_LEGAL_VERSION_OUTDATED')))
            .code,
        LegalAcceptanceErrorCode.outdated,
      );
      // `E_LEGAL_VERSION_NOT_FOUND` dit la même chose au fidèle : le texte
      // affiché n'est pas celui que le serveur connaît, il faut le recharger.
      expect(
        (await refusalOn((_) => errorReply(422, 'E_LEGAL_VERSION_NOT_FOUND')))
            .code,
        LegalAcceptanceErrorCode.outdated,
      );
    });

    test('5xx → panne serveur', () async {
      final failure = await refusalOn((_) => errorReply(500, 'E_INTERNAL'));

      expect(failure.code, LegalAcceptanceErrorCode.server);
    });

    test('le message du serveur est retenu, jamais destiné à l\'écran',
        () async {
      final failure = await refusalOn(
        (_) => errorReply(422, 'E_LEGAL_VERSION_OUTDATED', 'Version dépassée'),
      );

      // Il sert aux journaux et aux tests. L'écran, lui, a ses quatre phrases —
      // un message serveur n'est pas un texte d'interface, et celui-ci
      // s'afficherait sur l'écran dont on ne peut pas sortir.
      expect(failure.message, 'Version dépassée');
      expect(failure.toString(), contains('outdated'));
    });
  });

  test('sans backend, l\'enregistreur refuse et le dit', () async {
    // Le mode maquette n'a rien à quoi bouchonner : l'accord exige le réseau
    // (ADR-0036, décision 2). Un double qui « réussirait » mentirait sur
    // l'existence d'un chemin hors-ligne.
    const unavailable = UnavailableLegalAcceptanceRecorder();

    await expectLater(
      unavailable.accept(const [LegalAcceptance(kind: 'cgu', version: 3)]),
      throwsA(
        isA<LegalAcceptanceException>().having(
          (e) => e.code,
          'code',
          LegalAcceptanceErrorCode.network,
        ),
      ),
    );
  });
}
