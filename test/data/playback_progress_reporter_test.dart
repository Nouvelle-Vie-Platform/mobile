// **Le contrat de rapport de la reprise de lecture**, écrit sur un adaptateur
// factice.
//
// Deux choses à protéger, et la seconde est la plus fragile.
//
// **Le corps.** Trois clés en `camelCase` — `id`, `positionSeconds`,
// `completed` — sur `POST /teachings/:teachingId/progress`. L'identifiant du
// contenu voyage dans le **chemin**, jamais dans le corps ; le `snake_case` de
// ce serveur ne concerne que les query strings et l'enveloppe `/sync`.
//
// **Le silence.** Hors ligne, 401, 409, 5xx : rien ne remonte. C'est une
// exigence qui se perd au premier « rendons quand même l'erreur, on verra
// bien » — et le régressif serait invisible : personne ne remarque une
// exception qui n'est plus avalée tant que quelqu'un n'écoute pas un prêche
// dans un taxi.

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/core/network/api_client.dart';
import 'package:maison_du_miracle/data/repositories/http_playback_progress_reporter.dart';
import 'package:maison_du_miracle/data/repositories/playback_progress_reporter.dart';

import '../helpers/fake_api.dart';

const String _contentId = '019f2c40-0000-7000-8000-000000000001';
const String _progressId = '019f6b00-0000-7000-8000-000000000001';

PlaybackProgressReport _report({
  String contentId = _contentId,
  int positionSeconds = 942,
  bool completed = false,
}) =>
    PlaybackProgressReport(
      contentId: contentId,
      progressId: _progressId,
      positionSeconds: positionSeconds,
      completed: completed,
    );

void main() {
  late FakeAdapter adapter;
  late ApiClient api;
  late HttpPlaybackProgressReporter reporter;

  void serve(ResponseBody Function(RequestOptions options) reply) {
    adapter = FakeAdapter(reply);
    api.dio.httpClientAdapter = adapter;
  }

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    api = ApiClient.instance;
    reporter = HttpPlaybackProgressReporter(client: api);
    serve((_) => jsonReply(200, null));
  });

  group('POST /teachings/:teachingId/progress', () {
    test('le contenu est dans le chemin, les trois champs dans le corps',
        () async {
      await reporter.report(_report());

      expect(adapter.lastRequest.method, 'POST');
      expect(adapter.lastRequest.path, '/teachings/$_contentId/progress');
      expect(adapter.lastBody, {
        'id': _progressId,
        'positionSeconds': 942,
        'completed': false,
      });
    });

    test('rien d\'autre ne part, sous aucune graphie', () async {
      await reporter.report(_report());

      // `teachingId` est dans le chemin : l'envoyer aussi dans le corps ferait
      // deux sources pour la même chose, qui finiraient par diverger.
      expect(adapter.lastBody.keys, isNot(contains('teachingId')));
      // Le serveur n'a **aucune durée**, nulle part : lui en envoyer une serait
      // inventer un champ que son validateur refuserait.
      expect(adapter.lastBody.keys, isNot(contains('duration')));
      expect(adapter.lastBody.keys, isNot(contains('durationSeconds')));
      // Et jamais sous l'ancienne convention : un serveur tolérant aux deux
      // graphies laisserait passer ce qu'on croit interdire.
      expect(adapter.lastBody.keys, isNot(contains('position_seconds')));
    });

    test('un rassemblement passe par la même route', () async {
      // `teachings` et `gatherings` sont la **même table** côté serveur,
      // discriminée par `family` : il n'y a pas de
      // `POST /gatherings/:id/progress`, et il n'en faut pas.
      //
      // ⚠️ Le point est démontré par le code serveur mais **prouvé par aucun
      // test serveur** (question ouverte de l'issue #43, PRD
      // `miracle-house-server#151`). Ce test-ci garde le comportement du
      // client, il ne clôt pas la question.
      const gatheringId = '019f2c41-0000-7000-8000-000000000001';
      await reporter.report(_report(contentId: gatheringId));

      expect(adapter.lastRequest.path, '/teachings/$gatheringId/progress');
    });

    test('« terminé » part explicitement, et vaut true quand il le faut',
        () async {
      await reporter.report(_report(completed: true));

      expect(adapter.lastBody['completed'], isTrue);
    });

    test('un rejeu envoie exactement la même chose', () async {
      // L'upsert serveur est owner-scopé et idempotent (ADR-0018) : c'est
      // l'identifiant **stable** qui le rend possible. Un identifiant refrappé
      // à chaque envoi créerait une ligne par rapport.
      final report = _report();
      await reporter.report(report);
      await reporter.report(report);

      expect(adapter.requests, hasLength(2));
      expect(
        (adapter.requests.first.data as Map)['id'],
        (adapter.requests.last.data as Map)['id'],
      );
    });
  });

  group('Le rapport est muet', () {
    test('hors ligne : rien ne remonte', () async {
      serve((options) => throw DioException.connectionError(
            requestOptions: options,
            reason: 'réseau injoignable',
          ));

      await expectLater(reporter.report(_report()), completes);
      expect(reporter.lastFailure, isA<DioException>());
    });

    test('401 : rien ne remonte non plus', () async {
      // À la différence du composeur d'annonces, qui **remonte** le 401 : là,
      // l'auteur attend que son envoi aboutisse. Ici personne n'a rien demandé,
      // et l'intercepteur d'`ApiClient` a déjà purgé le token de son côté.
      serve((_) => errorReply(401, 'E_UNAUTHORIZED'));

      await expectLater(reporter.report(_report()), completes);
      expect(reporter.lastFailure, isA<DioException>());
    });

    test('409 — la ligne est à quelqu\'un d\'autre : rien ne remonte',
        () async {
      serve((_) => errorReply(409, 'E_OWNER_CONFLICT'));

      await expectLater(reporter.report(_report()), completes);
      expect(reporter.lastFailure, isA<DioException>());
    });

    test('5xx : rien ne remonte, et le rapport suivant repart', () async {
      serve((_) => errorReply(503, 'E_UNAVAILABLE'));
      await reporter.report(_report());
      expect(reporter.lastFailure, isNotNull);

      // L'échec n'enferme pas le rapporteur : le déclencheur suivant repart.
      serve((_) => jsonReply(200, null));
      await reporter.report(_report(positionSeconds: 1000));

      expect(reporter.lastFailure, isNull);
      expect(adapter.lastBody['positionSeconds'], 1000);
    });

    test('un succès efface la trace de l\'échec précédent', () async {
      serve((_) => errorReply(503, 'E_UNAVAILABLE'));
      await reporter.report(_report());

      serve((_) => jsonReply(200, null));
      await reporter.report(_report());

      expect(reporter.lastFailure, isNull);
    });
  });
}
