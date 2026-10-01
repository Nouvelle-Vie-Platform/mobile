/// **Les en-têtes de présentation, sur le fil.**
///
/// Trois en-têtes — version, plateforme, **identifiant d'appareil** — et quatre
/// choses s'y verrouillent, dont aucune ne se voit ailleurs :
///
/// 1. **Il part sur toutes les requêtes du client, synchronisation comprise.**
///    C'est le point entier de la tranche : un en-tête ne renseigne que sur les
///    requêtes qui le portent, et un dépôt qui le poserait lui-même créerait une
///    seconde vérité. Les deux coutures le prouvent là où elles vivent —
///    `FakeAdapter` pour une route REST, `FakeSyncServer` pour `/sync`, tous deux
///    posés sur le **vrai** `ApiClient.instance.dio`, donc derrière tous les
///    intercepteurs de production.
/// 2. **Il est purement additif.** Une lecture de version qui échoue laisse
///    partir la requête sans en-tête ; elle ne lève pas, et ne fait échouer
///    personne. C'est la règle qui rend l'ajout sûr dans une chaîne qui porte
///    déjà le Bearer, le déballage d'enveloppe et le 401.
/// 3. **Chacun manque seul.** Un coffre illisible fait disparaître le seul
///    `X-Device-Id` ; une version illisible ne l'emporte pas avec elle. Les trois
///    lectures sont indépendantes, et c'est ce qui rend l'ensemble inoffensif.
/// 4. **Rien d'autre ne part.** La charge utile est la version, la plateforme et
///    le système, plus l'identifiant d'appareil **qui existait déjà** dans le
///    coffre — aucun identifiant publicitaire, aucune empreinte dérivée du
///    matériel ou de l'agent utilisateur. La liste des `X-` est vérifiée
///    **positivement** : ni plus, ni moins.
library;

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/core/network/api_client.dart';
import 'package:maison_du_miracle/core/network/app_version_header.dart';
import 'package:maison_du_miracle/data/app_platform.dart';
import 'package:maison_du_miracle/data/app_version.dart';
import 'package:maison_du_miracle/data/sync/sync_api.dart';
import 'package:maison_du_miracle/data/devices/device_identity.dart';
import 'package:maison_du_miracle/data/devices/http_device_repository.dart';

import '../helpers/fake_api.dart';
import '../helpers/fake_sync_server.dart';
import '../helpers/sync_fixtures.dart';

/// Un lecteur qui **lève**, pour éprouver la règle 2. Il n'existe pas en
/// production : `PackageInfoAppVersionReader` rattrape tout. Il est écrit ici
/// parce qu'une implémentation future (ou un double mal écrit) pourrait ne pas
/// le faire, et que l'intercepteur ne doit alors toujours rien casser.
class _ThrowingAppVersionReader implements AppVersionReader {
  const _ThrowingAppVersionReader();

  @override
  Future<AppVersionInfo?> read() async =>
      throw StateError('canal de plugin absent');
}

/// Un coffre **illisible** — keychain verrouillé, canal de plugin absent.
///
/// C'est le seul moyen d'éprouver la règle 3 du côté de l'identifiant :
/// `DeviceIdentity` ne rend jamais `null`, elle lève ce que le coffre lève.
class _UnreadableVault extends FlutterSecureStorage {
  const _UnreadableVault();

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      throw PlatformException(
          code: 'Unavailable', message: 'coffre verrouillé');
}

void main() {
  const version = AppVersionInfo(version: '1.4.0', build: '12');
  const platform = AppPlatformInfo(name: 'android', osVersion: '14');
  // Un vrai identifiant est un UUID v4 : 36 caractères, bien au-delà du
  // plancher de `kMinDeviceIdLength`.
  const deviceId = '7c9e6679-7425-40de-944b-e07fc1f90ae7';

  late ApiClient api;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    api = ApiClient.instance;
    // Le singleton survit d'un test à l'autre : on repart d'un client neuf de
    // tout câblage, lecteurs compris.
    api.onUnauthorized = null;
    api.deviceSession = null;
    api.appVersion = const FixedAppVersionReader(version);
    api.appPlatform = const FixedAppPlatformReader(platform);
    // L'identité est **retenue** une fois lue : la remplacer est le seul moyen
    // de repartir d'un coffre neuf d'un test à l'autre.
    api.deviceIdentity = DeviceIdentity(mintId: () => deviceId);
  });

  tearDown(() async {
    api.appVersion = const PackageInfoAppVersionReader();
    api.appPlatform = const RuntimeAppPlatformReader();
    api.deviceIdentity = DeviceIdentity();
    await api.deleteToken();
  });

  group('la forme de l\'en-tête', () {
    test('version et build en un seul champ, plateforme et système en un autre',
        () async {
      final adapter = FakeAdapter((_) => jsonReply(200, const {'ok': true}));
      api.dio.httpClientAdapter = adapter;

      await api.dio.get<dynamic>('/sync/branches');

      expect(adapter.lastRequest.headers[kAppVersionHeader], '1.4.0+12');
      expect(adapter.lastRequest.headers[kAppPlatformHeader], 'android 14');
    });

    test('l\'identifiant d\'appareil part tel quel, sans rien autour',
        () async {
      final adapter = FakeAdapter((_) => jsonReply(200, const {'ok': true}));
      api.dio.httpClientAdapter = adapter;

      await api.dio.get<dynamic>('/sync/branches');

      // La valeur opaque du coffre, telle quelle : ni préfixe, ni hachage, ni
      // dérivation — c'est elle que le serveur compte, et la même que celle
      // qui ouvre une session d'appareil.
      expect(adapter.lastRequest.headers[kDeviceIdHeader], deviceId);
    });

    test('un système inconnu laisse la plateforme partir seule', () async {
      api.appPlatform = const FixedAppPlatformReader(
        AppPlatformInfo(name: 'web'),
      );
      final adapter = FakeAdapter((_) => jsonReply(200, const {'ok': true}));
      api.dio.httpClientAdapter = adapter;

      await api.dio.get<dynamic>('/sync/branches');

      expect(adapter.lastRequest.headers[kAppPlatformHeader], 'web');
    });

    test('rien d\'autre que ces trois en-têtes n\'est ajouté', () async {
      final adapter = FakeAdapter((_) => jsonReply(200, const {'ok': true}));
      api.dio.httpClientAdapter = adapter;

      await api.dio.get<dynamic>('/sync/branches');

      // Aucun identifiant publicitaire, aucune empreinte d'appareil : la liste
      // des en-têtes posés par ce client doit tenir dans ce qu'on a décidé.
      // **Exactement** celle-ci, ni plus (une empreinte qui se glisserait dans
      // la charge) ni moins (un en-tête qu'on croirait partir).
      final added = adapter.lastRequest.headers.keys
          .where((key) => key.toLowerCase().startsWith('x-'))
          .toList(growable: false);
      expect(
        added,
        unorderedEquals([
          kAppVersionHeader,
          kAppPlatformHeader,
          kDeviceIdHeader,
        ]),
      );
    });

    test('et la liste reste la même une fois connecté', () async {
      await api.saveToken('oat_1.membre');
      final adapter = FakeAdapter((_) => jsonReply(200, const {'ok': true}));
      api.dio.httpClientAdapter = adapter;

      await api.dio.get<dynamic>('/sync/branches');

      final added = adapter.lastRequest.headers.keys
          .where((key) => key.toLowerCase().startsWith('x-'))
          .toList(growable: false);
      expect(
        added,
        unorderedEquals([
          kAppVersionHeader,
          kAppPlatformHeader,
          kDeviceIdHeader,
        ]),
      );
    });
  });

  group('toutes les requêtes le portent', () {
    test('y compris le manifeste et le tirage de la synchronisation', () async {
      final server = FakeSyncServer()
        ..serveManifest(manifestNominal())
        ..serveCollection('branches', deltaPage(items: const []));
      api.dio.httpClientAdapter = server;

      // `SyncApi` sans `dio` : c'est **celui d'`ApiClient`** qu'il prend, donc
      // le chemin de production exact.
      final sync = SyncApi();
      await sync.manifest();
      await sync.pull('branches', limit: 1);

      expect(server.requests, hasLength(2));
      for (final request in server.requests) {
        expect(request.headers[kAppVersionHeader], '1.4.0+12');
        expect(request.headers[kAppPlatformHeader], 'android 14');
        expect(request.headers[kDeviceIdHeader], deviceId);
      }
      expect(server.manifestRequests, hasLength(1));
      expect(server.requestsFor('branches'), hasLength(1));
    });

    test('y compris l\'ouverture de session d\'appareil, qui part sans porteur',
        () async {
      final adapter = FakeAdapter(
        (_) => jsonReply(200, const {
          'token': 'oat_1.appareil',
          'type': 'device',
          'expiresAt': '2026-12-26T10:00:00.000Z',
          'lastSeenAt': '2026-09-27T10:00:00.000Z',
        }),
      );
      api.dio.httpClientAdapter = adapter;

      // **Sans `identity:`** : le dépôt prend celle du client, et c'est le
      // point — une seconde instance pourrait fabriquer un second identifiant.
      await HttpDeviceRepository(client: api).openSession();

      final opened =
          adapter.requests.firstWhere((r) => r.path == '/devices/anonymous');
      // `_AuthInterceptor` lui retire le `Authorization` — et c'est précisément
      // la requête par laquelle le serveur découvre l'appareil, donc celle qui a
      // le plus besoin de dire sa version.
      expect(opened.headers.containsKey('Authorization'), isFalse);
      expect(opened.headers[kAppVersionHeader], '1.4.0+12');
      expect(opened.headers[kAppPlatformHeader], 'android 14');
      // L'en-tête ne remplace pas le porteur absent : il ne prouve rien
      // (ADR-0040), il nomme seulement l'appareil.
      expect(opened.headers[kDeviceIdHeader], deviceId);
      // Et il dit **la même chose que le corps** : une seule vérité, sinon le
      // serveur compterait deux appareils pour un téléphone.
      expect((opened.data as Map)['deviceId'], deviceId);
    });

    test('y compris une requête de membre connecté', () async {
      // Tout l'objet de la tranche : un membre authentifié doit continuer de
      // dire quel téléphone il est, sinon ses deux appareils n'en font qu'un.
      await api.saveToken('oat_1.membre');
      final adapter = FakeAdapter((_) => jsonReply(200, const {'ok': true}));
      api.dio.httpClientAdapter = adapter;

      await api.dio.get<dynamic>('/sync/branches');

      expect(
        adapter.lastRequest.headers['Authorization'],
        'Bearer oat_1.membre',
      );
      // Le porteur reste la seule preuve d'identité ; l'identifiant voyage
      // **à côté** de lui, jamais à sa place.
      expect(adapter.lastRequest.headers[kDeviceIdHeader], deviceId);
    });
  });

  group('purement additif', () {
    test('une version inconnaissable retire l\'en-tête, pas la requête',
        () async {
      api.appVersion = const FixedAppVersionReader(null);
      final adapter = FakeAdapter((_) => jsonReply(200, const {'ok': true}));
      api.dio.httpClientAdapter = adapter;

      final response = await api.dio.get<dynamic>('/sync/branches');

      expect(response.statusCode, 200);
      expect(adapter.requests, hasLength(1));
      expect(
          adapter.lastRequest.headers.containsKey(kAppVersionHeader), isFalse);
      // La plateforme, elle, est toujours connue : les deux en-têtes sont
      // indépendants, et l'un ne tombe pas avec l'autre.
      expect(adapter.lastRequest.headers[kAppPlatformHeader], 'android 14');
    });

    test('une lecture de version qui LÈVE n\'empêche aucune requête', () async {
      api.appVersion = const _ThrowingAppVersionReader();
      final adapter = FakeAdapter((_) => jsonReply(200, const {'ok': true}));
      api.dio.httpClientAdapter = adapter;

      final response = await api.dio.get<dynamic>('/sync/branches');

      expect(response.statusCode, 200);
      expect(adapter.requests, hasLength(1));
      expect(
        adapter.lastRequest.headers.containsKey(kAppVersionHeader),
        isFalse,
      );
      // Et elle n'emporte pas l'identifiant avec elle : les trois lectures sont
      // indépendantes.
      expect(adapter.lastRequest.headers[kDeviceIdHeader], deviceId);
    });

    test('un coffre illisible retire CET en-tête seul, pas la requête',
        () async {
      api.deviceIdentity = DeviceIdentity(storage: const _UnreadableVault());
      final adapter = FakeAdapter((_) => jsonReply(200, const {'ok': true}));
      api.dio.httpClientAdapter = adapter;

      final response = await api.dio.get<dynamic>('/sync/branches');

      expect(response.statusCode, 200);
      expect(adapter.requests, hasLength(1));
      expect(adapter.lastRequest.headers.containsKey(kDeviceIdHeader), isFalse);
      // Les deux autres restent : un coffre verrouillé ne doit pas rendre
      // l'application anonyme sur toute la ligne.
      expect(adapter.lastRequest.headers[kAppVersionHeader], '1.4.0+12');
      expect(adapter.lastRequest.headers[kAppPlatformHeader], 'android 14');
    });

    test('un coffre illisible ne se grave pas : la requête suivante retente',
        () async {
      api.deviceIdentity = DeviceIdentity(storage: const _UnreadableVault());
      final adapter = FakeAdapter((_) => jsonReply(200, const {'ok': true}));
      api.dio.httpClientAdapter = adapter;

      await api.dio.get<dynamic>('/sync/branches');
      // Le coffre redevient lisible (déverrouillage de l'appareil).
      api.deviceIdentity = DeviceIdentity(mintId: () => deviceId);
      await api.dio.get<dynamic>('/sync/branches');

      expect(
        adapter.requests.first.headers.containsKey(kDeviceIdHeader),
        isFalse,
      );
      expect(adapter.requests.last.headers[kDeviceIdHeader], deviceId);
    });

    test('et la synchronisation continue de tourner sans en-tête', () async {
      api.appVersion = const _ThrowingAppVersionReader();
      api.appPlatform = const FixedAppPlatformReader(null);
      final server = FakeSyncServer()..serveManifest(manifestNominal());
      api.dio.httpClientAdapter = server;

      final manifest = await SyncApi().manifest();

      expect(manifest.scopeVersion, 4);
      expect(
          server.lastRequest.headers.containsKey(kAppVersionHeader), isFalse);
      expect(
        server.lastRequest.headers.containsKey(kAppPlatformHeader),
        isFalse,
      );
    });
  });

  group('l\'intercepteur, isolé', () {
    test('la lecture est faite une fois et retenue', () async {
      final identity = DeviceIdentity(mintId: () => deviceId);
      var reads = 0;
      final counting = _CountingAppVersionReader(() => reads++);
      final dio = Dio(BaseOptions(baseUrl: 'https://eenv.brainsial.com'))
        ..interceptors.add(
          AppVersionHeaderInterceptor(
            version: () => counting,
            platform: () => const FixedAppPlatformReader(platform),
            identity: () => identity,
          ),
        );
      final adapter = FakeAdapter((_) => jsonReply(200, const {'ok': true}));
      dio.httpClientAdapter = adapter;

      await dio.get<dynamic>('/a');
      await dio.get<dynamic>('/b');
      await dio.get<dynamic>('/c');

      // Un binaire ne change pas de version pendant qu'il tourne : trois
      // requêtes, un seul aller-retour vers le canal de plugin.
      expect(reads, 1);
      expect(adapter.requests, hasLength(3));
      for (final request in adapter.requests) {
        expect(request.headers[kAppVersionHeader], '1.4.0+12');
      }
    });

    test('un échec ne se met pas en cache : la requête suivante retente',
        () async {
      final identity = DeviceIdentity(mintId: () => deviceId);
      var attempts = 0;
      final flaky = _FlakyAppVersionReader(() => attempts++);
      final dio = Dio(BaseOptions(baseUrl: 'https://eenv.brainsial.com'))
        ..interceptors.add(
          AppVersionHeaderInterceptor(
            version: () => flaky,
            platform: () => const FixedAppPlatformReader(platform),
            identity: () => identity,
          ),
        );
      final adapter = FakeAdapter((_) => jsonReply(200, const {'ok': true}));
      dio.httpClientAdapter = adapter;

      await dio.get<dynamic>('/a');
      await dio.get<dynamic>('/b');

      expect(attempts, 2);
      expect(adapter.requests.first.headers.containsKey(kAppVersionHeader),
          isFalse);
      expect(adapter.requests.last.headers[kAppVersionHeader], '1.4.0+12');
      // La version a manqué, l'identifiant non : chacun manque seul.
      expect(adapter.requests.first.headers[kDeviceIdHeader], deviceId);
    });
  });

  group('la lecture de la plateforme', () {
    test('ne garde du système que son numéro', () {
      // `dart:io` ne normalise rien : Android rend « 14 (API 34) », iOS et macOS
      // rendent « Version 17.0 (Build 21A329) ».
      expect(shortOsVersion('14 (API 34)'), '14');
      expect(shortOsVersion('Version 17.0 (Build 21A329)'), '17.0');
      expect(shortOsVersion('Darwin Kernel 25.5.0'), '25.5.0');
      expect(shortOsVersion('inconnu'), isNull);
    });

    test('l\'implémentation réelle ne lève jamais et se nomme', () {
      // Sous `flutter test` la plateforme est celle de la machine ; on ne
      // vérifie donc que le contrat, pas la valeur.
      final info = const RuntimeAppPlatformReader().read();

      expect(info, isNotNull);
      expect(info!.name, isNotEmpty);
      expect(info.label, startsWith(info.name));
    });
  });
}

/// Compte les lectures — pour prouver que l'intercepteur ne retourne pas au
/// canal de plugin à chaque requête.
class _CountingAppVersionReader implements AppVersionReader {
  const _CountingAppVersionReader(this._onRead);

  final void Function() _onRead;

  @override
  Future<AppVersionInfo?> read() async {
    _onRead();
    return const AppVersionInfo(version: '1.4.0', build: '12');
  }
}

/// Lève une fois, puis répond — pour prouver qu'une absence ne se grave pas.
class _FlakyAppVersionReader implements AppVersionReader {
  _FlakyAppVersionReader(this._onRead);

  final void Function() _onRead;
  bool _failed = false;

  @override
  Future<AppVersionInfo?> read() async {
    _onRead();
    if (_failed) return const AppVersionInfo(version: '1.4.0', build: '12');
    _failed = true;
    throw StateError('canal de plugin absent');
  }
}
