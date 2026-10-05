/// **`Accept-Language` sur le fil** (#131).
///
/// Trois choses s'y verrouillent, toutes sur le **vrai** `ApiClient.instance`
/// (derrière tous les intercepteurs de production, `FakeAdapter` au bout) :
///
/// 1. **L'en-tête porte la langue courante** — celle que le lecteur rend, sans
///    région ni pondération.
/// 2. **Il suit un changement de langue** sans redémarrage : le lecteur est
///    relu à chaque requête, jamais retenu.
/// 3. **Il part sur la demande de code de connexion** — la requête qui a fait
///    ouvrir le ticket : le mail du code partait en anglais pour tout le monde.
///
/// Et la règle qui rend l'ajout sûr : sans lecteur, ou avec un lecteur qui
/// lève, la requête part **sans** en-tête plutôt que de ne pas partir.
///
/// Le câblage de l'application — le lecteur branché sur la locale que
/// `MaterialApp` a résolue — est vérifié dans `test/widget_test.dart`, là où
/// l'application entière est montée.
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/core/network/accept_language_header.dart';
import 'package:maison_du_miracle/core/network/api_client.dart';
import 'package:maison_du_miracle/data/app_platform.dart';
import 'package:maison_du_miracle/data/app_version.dart';
import 'package:maison_du_miracle/data/repositories/http_auth_repository.dart';
import 'package:maison_du_miracle/models/models.dart';

import '../helpers/fake_api.dart';

void main() {
  late ApiClient api;
  late FakeAdapter adapter;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    api = ApiClient.instance;
    api.onUnauthorized = null;
    api.deviceSession = null;
    // Les en-têtes de présentation ne sont pas l'objet ici : des lecteurs fixes
    // évitent le canal de plugin.
    api.appVersion = const FixedAppVersionReader(
      AppVersionInfo(version: '1.4.0', build: '12'),
    );
    api.appPlatform = const FixedAppPlatformReader(
      AppPlatformInfo(name: 'android', osVersion: '14'),
    );
    adapter = FakeAdapter((_) => jsonReply(200, const {'ok': true}));
    api.dio.httpClientAdapter = adapter;
  });

  tearDown(() async {
    api.interfaceLanguage = null;
    api.appVersion = const PackageInfoAppVersionReader();
    api.appPlatform = const RuntimeAppPlatformReader();
    await api.deleteToken();
  });

  group('la langue courante', () {
    test('l\'en-tête porte la langue que rend le lecteur', () async {
      api.interfaceLanguage = () => 'en';

      await api.dio.get<dynamic>('/sync/branches');

      expect(adapter.lastRequest.headers[kAcceptLanguageHeader], 'en');
    });

    test('l\'éwé part tel quel : le serveur décide de son propre repli',
        () async {
      api.interfaceLanguage = () => 'ee';

      await api.dio.get<dynamic>('/sync/branches');

      expect(adapter.lastRequest.headers[kAcceptLanguageHeader], 'ee');
    });
  });

  group('un changement de langue', () {
    test('est suivi dès la requête suivante, sans rien recâbler', () async {
      var language = 'fr';
      api.interfaceLanguage = () => language;

      await api.dio.get<dynamic>('/sync/branches');
      language = 'en';
      await api.dio.get<dynamic>('/sync/branches');
      language = 'ee';
      await api.dio.get<dynamic>('/sync/branches');

      expect(
        adapter.requests.map((r) => r.headers[kAcceptLanguageHeader]),
        ['fr', 'en', 'ee'],
      );
    });
  });

  group('la demande de code de connexion', () {
    test('POST /auth/request-code dit la langue de l\'interface', () async {
      api.interfaceLanguage = () => 'en';
      adapter = FakeAdapter((_) => jsonReply(202, const {'status': 'sent'}));
      api.dio.httpClientAdapter = adapter;

      await HttpAuthRepository(client: api).requestCode(
        identifier: 'jean@example.org',
        channel: IdentifierChannel.email,
      );

      expect(adapter.lastRequest.path, '/auth/request-code');
      expect(adapter.lastRequest.headers[kAcceptLanguageHeader], 'en');
    });
  });

  group('purement additif', () {
    test('sans lecteur câblé, la requête part sans en-tête', () async {
      api.interfaceLanguage = null;

      await api.dio.get<dynamic>('/sync/branches');

      expect(adapter.requests, hasLength(1));
      expect(
        adapter.lastRequest.headers.containsKey(kAcceptLanguageHeader),
        isFalse,
      );
    });

    test('une langue vide ne part pas', () async {
      api.interfaceLanguage = () => '  ';

      await api.dio.get<dynamic>('/sync/branches');

      expect(
        adapter.lastRequest.headers.containsKey(kAcceptLanguageHeader),
        isFalse,
      );
    });

    test('un lecteur qui lève ne fait échouer personne', () async {
      api.interfaceLanguage = () => throw StateError('conteneur détruit');

      final res = await api.dio.get<dynamic>('/sync/branches');

      expect(res.statusCode, 200);
      expect(
        adapter.lastRequest.headers.containsKey(kAcceptLanguageHeader),
        isFalse,
      );
    });
  });
}
