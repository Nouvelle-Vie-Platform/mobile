// **Le contrat d'enregistrement d'appareil push**, écrit sur un adaptateur Dio
// factice — `flutter test` répond 400 à tout accès réel, aucune socket ne
// s'ouvre, la requête traverse les intercepteurs d'`ApiClient` et s'arrête à
// l'adaptateur (voir `test/helpers/fake_api.dart`).
//
// Ce qui est vérifié :
// - `register` POSTe le **bon corps camelCase** sur `POST /devices/tokens` ;
// - `unregister` purge par `POST /auth/sign-out` + `deviceToken` — pas de
//   `DELETE`, choix serveur délibéré (voir `device_registrar.dart`) ;
// - **best-effort** : un échec serveur ne lève pas ;
// - la table de traduction `mapDeviceRegistrarError` ;
// - `InertDeviceRegistrar` est un no-op muet.

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/core/network/api_client.dart';
import 'package:maison_du_miracle/data/push/device_registrar.dart';
import 'package:maison_du_miracle/data/push/push_transport.dart';

import '../../helpers/fake_api.dart';

/// Une inscription FCM de référence (le cas nominal : iOS / Android GMS / web).
const PushRegistration _fcm = PushRegistration(
  token: 'fMEQ4t-abc:APA91bH-xyz',
  platform: 'android',
  transport: kPushTransportFcm,
);

void main() {
  late FakeAdapter adapter;
  late ApiClient api;
  late HttpDeviceRegistrar registrar;

  void serve(ResponseBody Function(RequestOptions options) reply) {
    adapter = FakeAdapter(reply);
    api.dio.httpClientAdapter = adapter;
  }

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    api = ApiClient.instance;
    registrar = HttpDeviceRegistrar(client: api);
    serve((_) => jsonReply(200, null));
  });

  group('register', () {
    test('POST /devices/tokens — corps camelCase { token, platform, transport }',
        () async {
      await registrar.register(_fcm);

      expect(adapter.lastRequest.method, 'POST');
      expect(adapter.lastRequest.path, '/devices/tokens');
      expect(adapter.lastBody, {
        'token': 'fMEQ4t-abc:APA91bH-xyz',
        'platform': 'android',
        'transport': 'fcm',
      });
    });

    test('le transport UnifiedPush part tel quel (endpoint comme token)',
        () async {
      const up = PushRegistration(
        token: 'https://ntfy.example.org/up1a2b3c4d',
        platform: 'android',
        transport: kPushTransportUnifiedPush,
      );

      await registrar.register(up);

      expect(adapter.lastBody, {
        'token': 'https://ntfy.example.org/up1a2b3c4d',
        'platform': 'android',
        'transport': 'unifiedpush',
      });
    });

    test('best-effort : un 500 ne lève pas', () async {
      serve((_) => jsonReply(500, null));
      await expectLater(registrar.register(_fcm), completes);
    });
  });

  group('unregister', () {
    test('purge par POST /auth/sign-out avec deviceToken (pas de DELETE)',
        () async {
      await registrar.unregister(_fcm);

      expect(adapter.lastRequest.method, 'POST');
      expect(adapter.lastRequest.path, '/auth/sign-out');
      expect(adapter.lastBody, {'deviceToken': 'fMEQ4t-abc:APA91bH-xyz'});
    });

    test('best-effort : un 401 (session déjà révoquée) ne lève pas', () async {
      serve((_) => jsonReply(401, null));
      await expectLater(registrar.unregister(_fcm), completes);
    });
  });

  group('mapDeviceRegistrarError', () {
    DioException http(int status, [Object? body]) => DioException(
          requestOptions: RequestOptions(path: '/devices/tokens'),
          response: Response(
            requestOptions: RequestOptions(path: '/devices/tokens'),
            statusCode: status,
            data: body,
          ),
        );

    test('sans réponse → network', () {
      final noResponse = DioException(
        requestOptions: RequestOptions(path: '/devices/tokens'),
        type: DioExceptionType.connectionError,
      );
      expect(
        mapDeviceRegistrarError(noResponse).code,
        DeviceRegistrarRefusalCode.network,
      );
    });

    test('une annulation → unknown', () {
      final cancelled = DioException(
        requestOptions: RequestOptions(path: '/devices/tokens'),
        type: DioExceptionType.cancel,
      );
      expect(
        mapDeviceRegistrarError(cancelled).code,
        DeviceRegistrarRefusalCode.unknown,
      );
    });

    test('les statuts se traduisent en codes', () {
      expect(mapDeviceRegistrarError(http(401)).code,
          DeviceRegistrarRefusalCode.unauthorized);
      expect(mapDeviceRegistrarError(http(422)).code,
          DeviceRegistrarRefusalCode.rejected);
      expect(mapDeviceRegistrarError(http(500)).code,
          DeviceRegistrarRefusalCode.server);
    });

    test('le message du serveur est retenu comme détail', () {
      final refusal = mapDeviceRegistrarError(
        http(422, {'message': 'transport invalide'}),
      );
      expect(refusal.detail, 'transport invalide');
    });
  });

  group('InertDeviceRegistrar', () {
    test('register / unregister sont des no-op muets', () async {
      const inert = InertDeviceRegistrar();
      await expectLater(inert.register(_fcm), completes);
      await expectLater(inert.unregister(_fcm), completes);
    });
  });
}
