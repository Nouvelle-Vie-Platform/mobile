import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/core/network/api_client.dart';
import 'package:maison_du_miracle/data/devices/device_identity.dart';
import 'package:maison_du_miracle/data/devices/device_repository.dart';
import 'package:maison_du_miracle/data/devices/http_device_repository.dart';
import 'package:maison_du_miracle/data/repositories/http_auth_repository.dart';

import '../helpers/fake_api.dart';

/// Charge utile de `POST /devices/anonymous`, telle que le serveur la sérialise
/// (enveloppe `data` posée par `jsonReply`).
Map<String, dynamic> devicePayload(String token) => {
      'token': token,
      'type': 'device',
      'expiresAt': '2026-12-26T10:00:00.000Z',
      'lastSeenAt': '2026-09-27T10:00:00.000Z',
    };

void main() {
  late FakeAdapter adapter;
  late ApiClient api;
  late HttpDeviceRepository device;
  late int minted;
  late int issued;

  void serve(ResponseBody Function(RequestOptions options) reply) {
    adapter = FakeAdapter(reply);
    api.dio.httpClientAdapter = adapter;
  }

  // Nombre d'ouvertures de session vues sur le fil. Une fonction et non un
  // getter : Dart n'en déclare pas localement.
  int sessionRequests() =>
      adapter.requests.where((r) => r.path == '/devices/anonymous').length;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    api = ApiClient.instance;
    // Le singleton survit d'un test à l'autre : on repart d'un client neuf de
    // tout câblage.
    api.onUnauthorized = null;
    api.deviceSession = null;
    minted = 0;
    issued = 0;
    device = HttpDeviceRepository(
      client: api,
      identity: DeviceIdentity(mintId: () => 'appareil-de-test-${++minted}'),
    );
    api.deviceSession = device;
    serve((_) => jsonReply(200, devicePayload('oat_1.appareil-${++issued}')));
  });

  // Les graines de ces tests dépassent toutes `kMinDeviceIdLength` (16), et ce
  // n'est pas de la décoration : une graine plus courte est relue comme une
  // valeur **abîmée** et régénérée, si bien que le test du redémarrage
  // éprouverait le plancher au lieu de la persistance. Un vrai identifiant est un
  // UUID de 36 caractères — le cas réaliste est donc la graine longue.
  group('identifiant d\'appareil', () {
    test('généré à la première ouverture, puis réutilisé tel quel', () async {
      final identity =
          DeviceIdentity(mintId: () => 'appareil-memorise-${++minted}');

      final first = await identity.current();
      final second = await identity.current();

      expect(first, 'appareil-memorise-1');
      expect(second, first);
      // Le point entier : une seule fabrication, pas une par appel.
      expect(minted, 1);
    });

    test('rangé dans le coffre, et relu par une instance neuve (redémarrage)',
        () async {
      await DeviceIdentity(mintId: () => 'appareil-stable-0123456789')
          .current();

      const storage = FlutterSecureStorage();
      expect(
        await storage.read(key: kDeviceIdKey),
        'appareil-stable-0123456789',
      );

      // Instance neuve, fabrique différente : si elle fabriquait au lieu de
      // lire, l'appareil compterait double côté serveur à chaque lancement.
      final afterRestart =
          await DeviceIdentity(mintId: () => 'appareil-jamais-utilise')
              .current();
      expect(afterRestart, 'appareil-stable-0123456789');
    });

    test('un vrai identifiant ressemble à un UUID', () async {
      final id = await DeviceIdentity().current();

      expect(id, matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4')));
      expect(id.length, 36);
    });

    test('une valeur abîmée dans le coffre se régénère', () async {
      FlutterSecureStorage.setMockInitialValues({kDeviceIdKey: 'x'});

      final id =
          await DeviceIdentity(mintId: () => 'appareil-refait-0123456789')
              .current();

      expect(id, 'appareil-refait-0123456789');
      // Et le coffre porte désormais la valeur refaite : on ne régénère pas à
      // chaque lecture.
      const storage = FlutterSecureStorage();
      expect(
        await storage.read(key: kDeviceIdKey),
        'appareil-refait-0123456789',
      );
    });
  });

  group('ouverture de session', () {
    test('poste le deviceId et range le jeton dans le coffre', () async {
      final session = await device.openSession();

      expect(adapter.lastRequest.method, 'POST');
      expect(adapter.lastRequest.path, '/devices/anonymous');
      expect(adapter.lastBody, {'deviceId': 'appareil-de-test-1'});
      // La route est publique : aucun porteur, même s'il en traînait un.
      expect(adapter.lastRequest.headers.containsKey('Authorization'), isFalse);

      expect(session.token, 'oat_1.appareil-1');
      expect(await api.readToken(), 'oat_1.appareil-1');
      expect(await api.readTokenKind(), AuthTokenKind.device);
    });

    test('la requête suivante part avec l\'en-tête Authorization', () async {
      await device.openSession();
      serve((_) => jsonReply(200, {'items': <dynamic>[]}));

      await api.dio.get<Map<String, dynamic>>('/sync');

      expect(adapter.lastRequest.path, '/sync');
      expect(
        adapter.lastRequest.headers['Authorization'],
        'Bearer oat_1.appareil-1',
      );
    });

    test('rejouée, elle réutilise le même deviceId', () async {
      await device.openSession();
      await device.openSession();

      expect(adapter.requests.map((r) => r.data), [
        {'deviceId': 'appareil-de-test-1'},
        {'deviceId': 'appareil-de-test-1'},
      ]);
      // Un jeton neuf remplace l'ancien : un seul jeton à la fois dans le coffre.
      expect(await api.readToken(), 'oat_1.appareil-2');
    });

    test('ensureSession n\'ouvre rien quand un jeton est déjà là', () async {
      await api.saveToken('oat_1.deja-membre');

      expect(await device.ensureSession(), isTrue);
      expect(sessionRequests(), 0);
      expect(await api.readToken(), 'oat_1.deja-membre');
    });

    test('ensureSession ouvre une session quand le coffre est vide', () async {
      expect(await device.ensureSession(), isTrue);

      expect(sessionRequests(), 1);
      expect(await api.readTokenKind(), AuthTokenKind.device);
    });
  });

  group('deviceId refusé par le serveur', () {
    test('un 422 ne laisse pas croire qu\'on a un jeton', () async {
      serve((_) => errorReply(
            422,
            'E_VALIDATION_ERROR',
            'deviceId is too short',
          ));

      await expectLater(
        device.openSession(),
        throwsA(isA<DeviceSessionException>().having(
          (e) => e.code,
          'code',
          DeviceSessionErrorCode.rejectedDeviceId,
        )),
      );

      // Rien rangé, et surtout pas de marqueur « appareil » : l'application ne
      // prétend pas avoir une session qu'elle n'a pas.
      expect(await api.readToken(), isNull);
      expect(await api.readTokenKind(), AuthTokenKind.member);
    });

    test('un 422 ne fabrique pas un nouvel identifiant', () async {
      serve((_) => errorReply(422, 'E_VALIDATION_ERROR'));

      await expectLater(device.openSession(), throwsA(anything));

      // Se « soigner » en changeant d'identifiant gonflerait le compteur
      // d'appareils du serveur à chaque refus.
      expect(await device.deviceId(), 'appareil-de-test-1');
      expect(minted, 1);
    });

    test('serveur injoignable : échec réseau, coffre intact', () async {
      await api.saveToken('oat_1.membre');
      serve((options) => throw DioException.connectionError(
            requestOptions: options,
            reason: 'réseau coupé',
          ));

      await expectLater(
        device.openSession(),
        throwsA(isA<DeviceSessionException>().having(
          (e) => e.code,
          'code',
          DeviceSessionErrorCode.network,
        )),
      );
      expect(await api.readToken(), 'oat_1.membre');
    });
  });

  group('cycle de vie autour de la connexion', () {
    late HttpAuthRepository auth;

    setUp(() {
      auth = HttpAuthRepository(client: api, device: device);
    });

    test('la connexion remplace le jeton d\'appareil par celui du membre',
        () async {
      await device.openSession();
      final deviceToken = await api.readToken();

      serve((_) => jsonReply(200, {
            'token': 'oat_1.membre',
            'user': userPayload,
            'isNewUser': false,
          }));
      await auth.verifyCode(identifier: '+22890123456', code: '123456');

      // La requête de connexion doit partir **avec** le jeton d'appareil : c'est
      // de ce porteur que le serveur déduit l'appareil à révoquer.
      expect(
          adapter.lastRequest.headers['Authorization'], 'Bearer $deviceToken');
      expect(await api.readToken(), 'oat_1.membre');
      // Un seul jeton à la fois, et sa nature a suivi.
      expect(await api.readTokenKind(), AuthTokenKind.member);
    });

    test('la déconnexion reprend un jeton d\'appareil, même identifiant',
        () async {
      await device.openSession();
      serve((_) => jsonReply(200, {
            'token': 'oat_1.membre',
            'user': userPayload,
            'isNewUser': false,
          }));
      await auth.verifyCode(identifier: '+22890123456', code: '123456');

      serve((options) => options.path == '/devices/anonymous'
          ? jsonReply(200, devicePayload('oat_1.appareil-apres-deconnexion'))
          : jsonReply(200, null));
      await auth.signOut();

      expect(adapter.requests.map((r) => r.path),
          ['/auth/sign-out', '/devices/anonymous']);
      // Le même identifiant : l'appareil ne se dédouble pas côté serveur.
      expect(adapter.lastBody, {'deviceId': 'appareil-de-test-1'});
      expect(await api.readToken(), 'oat_1.appareil-apres-deconnexion');
      expect(await api.readTokenKind(), AuthTokenKind.device);
      // L'identité de l'appareil survit à la session.
      expect(
        await DeviceIdentity(mintId: () => 'jamais-utilise').current(),
        'appareil-de-test-1',
      );
    });

    test('déconnexion hors ligne : pas de jeton, mais le coffre l\'attend',
        () async {
      await device.openSession();
      serve((_) => jsonReply(200, {
            'token': 'oat_1.membre',
            'user': userPayload,
            'isNewUser': false,
          }));
      await auth.verifyCode(identifier: '+22890123456', code: '123456');

      // Mode avion : ni la révocation ni la reprise n'aboutissent.
      serve((options) => throw DioException.connectionError(
            requestOptions: options,
            reason: 'réseau coupé',
          ));
      await auth.signOut();

      expect(await api.readToken(), isNull);
      // Le marqueur reste « appareil » : le prochain 401 relancera la reprise en
      // silence, au lieu d'éjecter vers l'écran de connexion.
      expect(await api.readTokenKind(), AuthTokenKind.device);
    });

    test('sans porteur d\'appareil câblé, la déconnexion vide le coffre',
        () async {
      // Non-régression du comportement d'avant le mode invité.
      final withoutDevice = HttpAuthRepository(client: api);
      await api.saveToken('oat_1.membre');
      serve((_) => jsonReply(200, null));

      await withoutDevice.signOut();

      expect(adapter.requests.map((r) => r.path), ['/auth/sign-out']);
      expect(await api.readToken(), isNull);
      expect(await api.readTokenKind(), AuthTokenKind.member);
    });
  });
}
