import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/core/network/api_client.dart';
import 'package:maison_du_miracle/data/devices/device_identity.dart';
import 'package:maison_du_miracle/data/devices/http_device_repository.dart';

import '../helpers/fake_api.dart';

/// Adaptateur factice dont la réponse est **asynchrone** : le pendant de
/// [FakeAdapter] pour les tests où l'ordre des allers-retours compte.
///
/// C'est ce qui rend le test de concurrence déterministe : on peut retarder la
/// réponse du renouvellement et garantir que le second 401 arrive pendant qu'il
/// est en vol, au lieu d'espérer que l'ordonnancement des micro-tâches tombe
/// bien.
class ScriptedAdapter implements HttpClientAdapter {
  ScriptedAdapter(this.reply);

  final Future<ResponseBody> Function(RequestOptions options) reply;

  /// Requêtes vues, **dans l'ordre d'émission** (notées avant toute attente).
  final List<RequestOptions> requests = [];

  List<String> get paths => requests.map((r) => r.path).toList();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return reply(options);
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> devicePayload(String token) => {
      'token': token,
      'type': 'device',
      'expiresAt': '2026-12-26T10:00:00.000Z',
      'lastSeenAt': '2026-09-27T10:00:00.000Z',
    };

void main() {
  late ScriptedAdapter adapter;
  late ApiClient api;
  late HttpDeviceRepository device;

  // Éjections vers `/auth` (ce que `onUnauthorized` déclenche en production).
  late int ejections;
  late int issued;

  void serve(Future<ResponseBody> Function(RequestOptions options) reply) {
    adapter = ScriptedAdapter(reply);
    api.dio.httpClientAdapter = adapter;
  }

  // Une fonction et non un getter : Dart n'en déclare pas localement.
  int sessionRequests() =>
      adapter.requests.where((r) => r.path == '/devices/anonymous').length;

  // Le seul jeton que « le serveur » tient pour valide. `null` = celui que
  // l'invité a dans son coffre est **mort** : c'est l'état de départ de tous ces
  // tests, et ce qui fait qu'un 401 revient.
  String? liveToken;

  // Le scénario courant : l'ouverture de session rend un jeton frais et vivant,
  // tout le reste répond 401 sauf si la requête porte ce jeton-là.
  Future<ResponseBody> renewableThen401(RequestOptions options) async {
    if (options.path == '/devices/anonymous') {
      liveToken = 'oat_1.appareil-${++issued}';
      return jsonReply(200, devicePayload(liveToken!));
    }
    return options.headers['Authorization'] == 'Bearer $liveToken'
        ? jsonReply(200, {'items': <dynamic>[]})
        : errorReply(401, 'E_UNAUTHORIZED_ACCESS');
  }

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    api = ApiClient.instance;
    ejections = 0;
    issued = 0;
    liveToken = null;
    api.onUnauthorized = () => ejections++;
    device = HttpDeviceRepository(
      client: api,
      identity: DeviceIdentity(mintId: () => 'appareil-de-test'),
    );
    api.deviceSession = device;

    // Un invité en place : un jeton d'appareil dans le coffre.
    serve((_) async =>
        jsonReply(200, devicePayload('oat_1.appareil-${++issued}')));
    await device.openSession();
  });

  tearDown(() {
    api.onUnauthorized = null;
    api.deviceSession = null;
  });

  // ── Le test central ──────────────────────────────────────────────────────

  test(
      '401 sur un jeton d\'appareil : renouvelé, requête rejouée, rien à l\'écran',
      () async {
    serve(renewableThen401);

    final res = await api.dio.get<Map<String, dynamic>>('/sync');

    // La requête a réussi du point de vue de l'appelant : il n'a rien à savoir.
    expect(res.data, {'items': <dynamic>[]});
    // Un renouvellement, puis le rejeu — dans cet ordre.
    expect(adapter.paths, ['/sync', '/devices/anonymous', '/sync']);
    // Le rejeu porte le jeton frais, sinon il aurait échoué.
    expect(
      adapter.requests.last.headers['Authorization'],
      'Bearer oat_1.appareil-2',
    );
    expect(await api.readToken(), 'oat_1.appareil-2');
    expect(await api.readTokenKind(), AuthTokenKind.device);
    // Le point du mode invité : personne n'est renvoyé à l'écran de connexion.
    expect(ejections, 0);
  });

  test('l\'ouverture de session garde le même deviceId au renouvellement',
      () async {
    serve(renewableThen401);

    await api.dio.get<Map<String, dynamic>>('/sync');

    final renewal =
        adapter.requests.firstWhere((r) => r.path == '/devices/anonymous');
    expect(renewal.data, {'deviceId': 'appareil-de-test'});
    // Route publique : le renouvellement part nu, un jeton mort ne peut pas
    // empêcher d'en obtenir un vivant.
    expect(renewal.headers.containsKey('Authorization'), isFalse);
  });

  test('une requête sans porteur, coffre en attente, renouvelle en silence',
      () async {
    // L'état d'après une déconnexion hors ligne.
    await api.deleteToken();
    await api.expectDeviceSession();
    serve(renewableThen401);

    final res = await api.dio.get<Map<String, dynamic>>('/sync');

    expect(res.data, {'items': <dynamic>[]});
    expect(sessionRequests(), 1);
    expect(ejections, 0);
  });

  // ── Non-régression : le jeton de membre ──────────────────────────────────

  test('401 sur un jeton de membre : purge et éjection, comme avant', () async {
    await api.saveToken('oat_1.membre');
    serve((_) async => errorReply(401, 'E_UNAUTHORIZED_ACCESS'));

    await expectLater(
      api.dio.get<Map<String, dynamic>>('/sync'),
      throwsA(isA<DioException>()
          .having((e) => e.response?.statusCode, 'statusCode', 401)),
    );

    expect(await api.readToken(), isNull);
    expect(ejections, 1);
    // Surtout : aucun renouvellement silencieux dans le dos d'un membre.
    expect(adapter.paths, ['/sync']);
  });

  test('un renouvellement n\'écrase jamais un jeton de membre tout frais',
      () async {
    // La course réelle : la requête est partie en invité, une connexion aboutit
    // pendant qu'elle est en vol, et son 401 revient après.
    serve((options) async {
      await api.saveToken('oat_1.membre');
      return errorReply(401, 'E_UNAUTHORIZED_ACCESS');
    });

    await expectLater(
      api.dio.get<Map<String, dynamic>>('/sync'),
      throwsA(isA<DioException>()),
    );

    // Écraser ce jeton déconnecterait quelqu'un sans le lui dire.
    expect(await api.readToken(), 'oat_1.membre');
    expect(sessionRequests(), 0);
    // Et l'on n'éjecte pas non plus : la requête fautive était celle d'un invité.
    expect(ejections, 0);
  });

  test('sans garde câblé, un 401 retombe sur l\'ancien comportement', () async {
    // Mode invité non installé (`HttpDeviceRepository.wire` jamais appelé) :
    // se taire rendrait l'application muette pour toujours.
    api.deviceSession = null;
    serve((_) async => errorReply(401, 'E_UNAUTHORIZED_ACCESS'));

    await expectLater(
      api.dio.get<Map<String, dynamic>>('/sync'),
      throwsA(isA<DioException>()),
    );

    expect(ejections, 1);
    expect(await api.readToken(), isNull);
  });

  // ── Les deux pièges de production ────────────────────────────────────────

  group('requêtes concurrentes', () {
    test('trois renouvellements demandés d\'un coup n\'en lancent qu\'un',
        () async {
      serve(renewableThen401);

      final results = await Future.wait([
        device.renew(),
        device.renew(),
        device.renew(),
      ]);

      expect(results, [true, true, true]);
      expect(sessionRequests(), 1);
    });

    test('deux requêtes qui échouent en même temps : un seul renouvellement',
        () async {
      serve((options) async {
        if (options.path == '/devices/anonymous') {
          // Le renouvellement traîne : les deux 401 sont sûrs d'arriver pendant
          // qu'il est en vol.
          await Future<void>.delayed(const Duration(milliseconds: 30));
          return jsonReply(200, devicePayload('oat_1.appareil-${++issued}'));
        }
        return options.headers['Authorization'] == 'Bearer oat_1.appareil-2'
            ? jsonReply(200, {'items': <dynamic>[]})
            : errorReply(401, 'E_UNAUTHORIZED_ACCESS');
      });

      final responses = await Future.wait([
        api.dio.get<Map<String, dynamic>>('/sync'),
        api.dio.get<Map<String, dynamic>>('/events'),
      ]);

      expect(responses.map((r) => r.data), [
        {'items': <dynamic>[]},
        {'items': <dynamic>[]},
      ]);
      // Cinq jetons pour un appareil, c'est ce qui se voit dans le plafond
      // journalier du serveur.
      expect(sessionRequests(), 1);
      expect(ejections, 0);
    });
  });

  group('la boucle est bornée', () {
    test('un renouvellement qui échoue ne relance rien', () async {
      serve((options) async => options.path == '/devices/anonymous'
          ? errorReply(500, 'E_INTERNAL_SERVER_ERROR')
          : errorReply(401, 'E_UNAUTHORIZED_ACCESS'));

      await expectLater(
        api.dio.get<Map<String, dynamic>>('/sync'),
        throwsA(isA<DioException>()
            .having((e) => e.response?.statusCode, 'statusCode', 401)),
      );

      expect(adapter.paths, ['/sync', '/devices/anonymous']);
      expect(ejections, 0);
      // Le jeton mort reste : c'est le prochain renouvellement qui le remplacera,
      // et le coffre continue de dire « appareil ».
      expect(await api.readToken(), 'oat_1.appareil-1');
      expect(await api.readTokenKind(), AuthTokenKind.device);
    });

    test('une seconde requête ne redemande pas un jeton tout de suite',
        () async {
      serve((options) async => options.path == '/devices/anonymous'
          ? errorReply(500, 'E_INTERNAL_SERVER_ERROR')
          : errorReply(401, 'E_UNAUTHORIZED_ACCESS'));

      await expectLater(
          api.dio.get<Map<String, dynamic>>('/sync'), throwsA(anything));
      await expectLater(
          api.dio.get<Map<String, dynamic>>('/sync'), throwsA(anything));

      // Le plancher de réessai borne le nombre d'appels quand ça va mal.
      expect(sessionRequests(), 1);
      expect(ejections, 0);
    });

    test('le plancher de réessai expire, et une nouvelle tentative part',
        () async {
      var clock = DateTime.utc(2026, 9, 27, 10);
      final impatient = HttpDeviceRepository(
        client: api,
        identity: DeviceIdentity(mintId: () => 'appareil-de-test'),
        retryFloor: const Duration(seconds: 30),
        now: () => clock,
      );
      api.deviceSession = impatient;
      serve((_) async => errorReply(500, 'E_INTERNAL_SERVER_ERROR'));

      expect(await impatient.renew(), isFalse);
      expect(await impatient.renew(), isFalse);
      expect(sessionRequests(), 1);

      clock = clock.add(const Duration(seconds: 31));
      expect(await impatient.renew(), isFalse);
      expect(sessionRequests(), 2);
    });

    test('un rejeu qui échoue à son tour remonte, sans second renouvellement',
        () async {
      // Jeton révoqué juste après avoir été émis : le cas où l'on pourrait
      // boucler indéfiniment.
      serve((options) async => options.path == '/devices/anonymous'
          ? jsonReply(200, devicePayload('oat_1.appareil-${++issued}'))
          : errorReply(401, 'E_UNAUTHORIZED_ACCESS'));

      await expectLater(
        api.dio.get<Map<String, dynamic>>('/sync'),
        throwsA(isA<DioException>()
            .having((e) => e.response?.statusCode, 'statusCode', 401)),
      );

      // Au plus un renouvellement et un rejeu par requête d'origine.
      expect(adapter.paths, ['/sync', '/devices/anonymous', '/sync']);
      expect(sessionRequests(), 1);
      expect(ejections, 0);
    });
  });
}
