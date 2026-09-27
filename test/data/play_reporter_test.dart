// **Le contrat de la remontée d'écoute**, écrit sur un adaptateur factice.
//
// Trois choses à protéger, et les deux dernières sont celles qui se perdent
// sans bruit.
//
// **La route.** `POST /teachings/:teachingId/plays`, et **aucun corps**. Elle
// se distingue de `…/progress` par une lettre ; les confondre ferait écrire une
// mesure d'audience dans la reprise de lecture de quelqu'un.
//
// **Le silence.** Hors ligne, 401, 404, 5xx : rien ne remonte. Le régressif
// serait invisible — personne ne remarque une exception qui n'est plus avalée
// tant que quelqu'un n'écoute pas un prêche dans un taxi.
//
// **L'aveu d'échec.** Muet ne veut pas dire aveugle : `report` doit rendre
// `false`, sinon la file d'attente ne se remplit jamais et les écoutes hors
// ligne disparaissent en silence — un bug qui ne se lit que dans les chiffres
// du portail, trois mois plus tard.

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/core/network/api_client.dart';
import 'package:maison_du_miracle/data/measurement/http_play_reporter.dart';

import '../helpers/fake_api.dart';

const String _contentId = '019f2c40-0000-7000-8000-000000000001';

void main() {
  late FakeAdapter adapter;
  late ApiClient api;
  late HttpPlayReporter reporter;

  void serve(ResponseBody Function(RequestOptions options) reply) {
    adapter = FakeAdapter(reply);
    api.dio.httpClientAdapter = adapter;
  }

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    api = ApiClient.instance;
    reporter = HttpPlayReporter(client: api);
    serve((_) => jsonReply(200, {'counted': true}));
  });

  group('POST /teachings/:teachingId/plays', () {
    test('le contenu est dans le chemin, et rien ne part dans le corps',
        () async {
      expect(await reporter.report(_contentId), isTrue);

      expect(adapter.lastRequest.method, 'POST');
      expect(adapter.lastRequest.path, '/teachings/$_contentId/plays');
      // Aucun corps : le porteur est dans l'en-tête, la date est celle du
      // serveur. Tout champ ajouté ici serait une chose que le client prétend
      // savoir mieux que lui — l'horodatage en particulier, qui lui donnerait la
      // main sur le jour auquel l'écoute est imputée, donc sur la déduplication.
      expect(adapter.lastRequest.data, isNull);
    });

    test('ce n\'est PAS la route de la reprise de lecture', () async {
      await reporter.report(_contentId);

      // La séparation, vérifiée et non affirmée : deux routes voisines, deux
      // régimes de conservation, et une lettre de différence.
      expect(adapter.lastRequest.path, isNot(contains('/progress')));
      expect(adapter.requests, hasLength(1));
      expect(playPath(_contentId), '/teachings/$_contentId/plays');
    });

    test('`counted: false` du serveur n\'est pas un échec', () async {
      // Le serveur déduplique au plus une écoute par porteur, par contenu et par
      // jour. Un rejeu rend `200 { counted: false }` : l'événement est **arrivé**,
      // il n'a simplement pas incrémenté. Le lire comme un échec le remettrait en
      // file d'attente et le ferait rejouer indéfiniment.
      serve((_) => jsonReply(200, {'counted': false}));

      expect(await reporter.report(_contentId), isTrue);
      expect(reporter.lastFailure, isNull);
    });
  });

  group('Le silence', () {
    test('hors ligne : rien ne lève, `false` est rendu', () async {
      serve(
        (options) => throw DioException.connectionError(
          requestOptions: options,
          reason: 'avion',
        ),
      );

      expect(await reporter.report(_contentId), isFalse);
      // Visible au diagnostic, invisible à l'écran : sans ce témoin, un
      // rapporteur qui n'enverrait plus rien du tout passerait pour discret.
      expect(reporter.lastFailure, isNotNull);
    });

    test('401, 404 et 5xx sont avalés de la même façon', () async {
      for (final status in [401, 404, 500, 503]) {
        serve((_) => errorReply(status, 'E_WHATEVER'));
        expect(
          await reporter.report(_contentId),
          isFalse,
          reason: '$status ne doit ni lever ni réussir',
        );
      }
    });

    test('un envoi qui repasse efface le témoin d\'échec', () async {
      serve((_) => errorReply(500, 'E_INTERNAL_SERVER_ERROR'));
      await reporter.report(_contentId);
      expect(reporter.lastFailure, isNotNull);

      serve((_) => jsonReply(200, {'counted': true}));
      expect(await reporter.report(_contentId), isTrue);
      expect(reporter.lastFailure, isNull);
    });
  });
}
