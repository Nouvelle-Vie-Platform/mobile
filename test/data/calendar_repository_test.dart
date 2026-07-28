import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/core/network/api_client.dart';
import 'package:maison_du_miracle/data/repositories/calendar_repository.dart';
import 'package:maison_du_miracle/data/repositories/http_calendar_repository.dart';
import 'package:maison_du_miracle/models/models.dart';

import '../helpers/event_payloads.dart';
import '../helpers/fake_api.dart';

/// Réponse type de `GET /events` : les occurrences **et** l'horizon.
Map<String, dynamic> eventsPayload({
  List<Map<String, dynamic>> items = const [],
  String? horizon = '2027-07-28',
}) =>
    {
      'items': items,
      if (horizon != null) 'horizon': horizon,
    };

void main() {
  late FakeAdapter adapter;
  late ApiClient api;
  late HttpCalendarRepository repository;

  void serve(ResponseBody Function(RequestOptions options) reply) {
    adapter = FakeAdapter(reply);
    api.dio.httpClientAdapter = adapter;
  }

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    api = ApiClient.instance;
    repository = HttpCalendarRepository(client: api);
    serve((_) => jsonReply(200, eventsPayload()));
  });

  group('GET /events', () {
    test('envoie la fenêtre demandée, en ISO8601 UTC', () async {
      await repository.events(
        // Un instant volontairement **non-UTC** : c'est au repository de le
        // normaliser, pas à l'appelant d'y penser à chaque site d'appel.
        from: DateTime.utc(2026, 8, 1).toLocal(),
        to: DateTime.utc(2026, 9, 1),
        branchId: 3,
        limit: 20,
      );

      expect(adapter.lastRequest.method, 'GET');
      expect(adapter.lastRequest.path, '/events');
      expect(adapter.lastRequest.queryParameters, {
        'from': '2026-08-01T00:00:00.000Z',
        'to': '2026-09-01T00:00:00.000Z',
        'branch_id': 3,
        'limit': 20,
      });
    });

    test('les paramètres facultatifs absents ne partent pas sur le fil',
        () async {
      await repository.events(from: DateTime.utc(2026, 8, 1));

      // « Les trois prochains » n'a pas de borne haute : envoyer `to: null`
      // ferait filtrer le serveur sur une valeur que l'appelant n'a pas voulue.
      expect(adapter.lastRequest.queryParameters.keys, ['from']);
    });

    test('parse un item complet et un item minimal dans la même réponse',
        () async {
      serve(
        (_) => jsonReply(
          200,
          eventsPayload(items: [fullEventPayload, minimalEventPayload]),
        ),
      );

      final window = await repository.events(from: DateTime.utc(2026, 8));

      expect(window.items, hasLength(2));

      final full = window.items.first;
      expect(full.startsAt, DateTime.utc(2026, 8, 3, 17, 30));
      expect(full.endsAt, DateTime.utc(2026, 8, 3, 19));
      expect(full.timezone, 'Africa/Lome');
      expect(full.branchId, 3);
      expect(full.title['fr'], 'Prière de zone');
      expect(full.place, 'Temple Central');
      expect(full.category?.tone, 'culte');

      final minimal = window.items.last;
      expect(minimal.startsAt.isUtc, isTrue);
      expect(minimal.endsAt, isNull);
      expect(minimal.branchId, isNull); // portée nationale
      expect(minimal.body, isNull);
      expect(minimal.place, isNull);
      expect(minimal.category, isNull);
    });

    test('un `starts_at` suffixé Z traverse la couche réseau en UTC', () async {
      serve((_) => jsonReply(200, eventsPayload(items: [fullEventPayload])));

      final window = await repository.events(from: DateTime.utc(2026, 8));

      // Le même contrôle qu'au niveau du modèle, mais après le vrai chemin
      // (dio → jsonDecode → intercepteurs → fromJson) : c'est là que la
      // conversion silencieuse se glisserait.
      expect(window.items.single.startsAt.isUtc, isTrue);
      expect(window.items.single.startsAt.hour, 17);
      expect(
        window.items.single.startsAt.toIso8601String(),
        '2026-08-03T17:30:00.000Z',
      );
    });

    test('remonte l\'horizon du serveur, en UTC et à minuit', () async {
      final window = await repository.events(from: DateTime.utc(2026, 8));

      expect(window.horizon, DateTime.utc(2027, 7, 28));
      expect(window.horizon!.isUtc, isTrue);
    });

    test('horizon absent → null, et la navigation reste ouverte', () async {
      serve((_) => jsonReply(200, eventsPayload(horizon: null)));

      final window = await repository.events(from: DateTime.utc(2026, 8));

      expect(window.horizon, isNull);
      // Sans borne annoncée, on ne bride rien : « inconnu » n'est pas « fin ».
      expect(window.covers(DateTime.utc(2099)), isTrue);
    });

    test('un mois vide n\'est pas un mois au-delà de l\'horizon', () async {
      final window = await repository.events(from: DateTime.utc(2026, 8));

      expect(window.isEmpty, isTrue);
      // Août 2026 est vide **et** couvert : l'écran doit dire « rien de prévu ».
      expect(window.covers(DateTime.utc(2026, 9)), isTrue);
      // Août 2027 est au-delà : le serveur n'affirme rien, l'écran ne doit pas
      // prétendre qu'il n'y a rien.
      expect(window.covers(DateTime.utc(2027, 8)), isFalse);
    });

    test('charge utile inattendue → fenêtre vide plutôt qu\'un plantage',
        () async {
      serve((_) => jsonReply(200, {'horizon': '2027-07-28'}));

      final window = await repository.events(from: DateTime.utc(2026, 8));

      expect(window.items, isEmpty);
      expect(window.horizon, DateTime.utc(2027, 7, 28));
    });
  });

  group('erreurs', () {
    test('serveur injoignable → CalendarErrorCode.network', () async {
      serve((options) => throw DioException.connectionError(
            requestOptions: options,
            reason: 'réseau coupé',
          ));

      await expectLater(
        repository.events(from: DateTime.utc(2026, 8)),
        throwsA(
          isA<CalendarException>()
              .having((e) => e.code, 'code', CalendarErrorCode.network),
        ),
      );
    });

    test('401 → CalendarErrorCode.unauthorized, distinct du réseau', () async {
      serve((_) => errorReply(401, 'E_UNAUTHORIZED_ACCESS', 'Non autorisé'));

      await expectLater(
        repository.events(from: DateTime.utc(2026, 8)),
        throwsA(
          isA<CalendarException>()
              .having((e) => e.code, 'code', CalendarErrorCode.unauthorized),
        ),
      );
    });

    test('5xx → CalendarErrorCode.server : le serveur, lui, répond', () async {
      serve((_) => errorReply(503, 'E_INTERNAL', 'Maintenance'));

      await expectLater(
        repository.events(from: DateTime.utc(2026, 8)),
        throwsA(
          isA<CalendarException>()
              .having((e) => e.code, 'code', CalendarErrorCode.server)
              .having((e) => e.message, 'message', 'Maintenance'),
        ),
      );
    });

    test('une réponse 4xx autre que 401 reste une erreur serveur', () async {
      serve((_) => errorReply(422, 'E_VALIDATION_ERROR'));

      await expectLater(
        repository.events(from: DateTime.utc(2026, 8)),
        throwsA(
          isA<CalendarException>()
              .having((e) => e.code, 'code', CalendarErrorCode.server),
        ),
      );
    });

    test('aucune DioException brute ne franchit le repository', () async {
      serve((_) => errorReply(500, 'E_INTERNAL'));

      await expectLater(
        repository.events(from: DateTime.utc(2026, 8)),
        throwsA(isNot(isA<DioException>())),
      );
    });
  });

  group('parseHorizon', () {
    test('une date nue devient minuit UTC', () {
      expect(parseHorizon('2027-07-28'), DateTime.utc(2027, 7, 28));
      expect(parseHorizon('2027-07-28')!.isUtc, isTrue);
    });

    test('un instant complet est ramené à sa date', () {
      expect(
        parseHorizon('2027-07-28T23:59:59Z'),
        DateTime.utc(2027, 7, 28),
      );
    });

    test('absent, vide ou illisible → null', () {
      expect(parseHorizon(null), isNull);
      expect(parseHorizon('  '), isNull);
      expect(parseHorizon('bientôt'), isNull);
      expect(parseHorizon(2027), isNull);
    });
  });

  group('InMemoryCalendarRepository', () {
    final janvier = ChurchEvent(
      id: 'a',
      startsAt: DateTime.utc(2026, 1, 4, 9),
      timezone: 'Africa/Lome',
      title: const {'fr': 'Culte'},
      branchId: 1,
    );
    final fevrier = ChurchEvent(
      id: 'b',
      startsAt: DateTime.utc(2026, 2, 1, 18),
      timezone: 'Africa/Lome',
      title: const {'fr': 'Veillée'},
      branchId: 2,
    );
    final mars = ChurchEvent(
      id: 'c',
      startsAt: DateTime.utc(2026, 3, 8, 10),
      timezone: 'Africa/Lome',
      title: const {'fr': 'Convention'},
    );

    late InMemoryCalendarRepository mock;

    setUp(() {
      // Volontairement dans le désordre : le double doit trier, comme le
      // serveur.
      mock = InMemoryCalendarRepository(
        events: [mars, janvier, fevrier],
        horizon: DateTime.utc(2027, 7, 28),
      );
    });

    test('rend la fenêtre demandée, triée chronologiquement', () async {
      final window = await mock.events(
        from: DateTime.utc(2026),
        to: DateTime.utc(2026, 3),
      );

      expect(window.items.map((e) => e.id), ['a', 'b']);
      expect(window.horizon, DateTime.utc(2027, 7, 28));
    });

    test('la borne haute est exclue, la borne basse incluse', () async {
      final window = await mock.events(
        from: DateTime.utc(2026, 2, 1, 18),
        to: DateTime.utc(2026, 3, 8, 10),
      );

      expect(window.items.map((e) => e.id), ['b']);
    });

    test('sans `to`, tout ce qui suit `from` remonte, plafonné par `limit`',
        () async {
      final window = await mock.events(from: DateTime.utc(2026), limit: 2);

      expect(window.items.map((e) => e.id), ['a', 'b']);
    });

    test('filtrer sur une branche garde les évènements nationaux', () async {
      final window = await mock.events(from: DateTime.utc(2026), branchId: 1);

      // `c` n'a pas de branche : portée nationale, elle concerne tout le monde.
      expect(window.items.map((e) => e.id), ['a', 'c']);
    });

    test('sans horizon annoncé, le double ne borne rien', () async {
      final window = await InMemoryCalendarRepository(events: [mars]).events(
        from: DateTime.utc(2026),
      );

      expect(window.horizon, isNull);
      expect(window.covers(DateTime.utc(2099)), isTrue);
    });

    test('la liste rendue est non modifiable', () async {
      final window = await mock.events(from: DateTime.utc(2026));

      expect(() => window.items.clear(), throwsUnsupportedError);
    });
  });
}
