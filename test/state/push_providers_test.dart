// **Le câblage Riverpod du réveil push** — la consolidation du lot.
//
// Ce test prouve l'**assemblage** du squelette (les unités elles-mêmes sont
// couvertes par `test/data/push/*`) : que les providers rendent bien les doubles
// **inertes** tant que le maillon natif n'est pas posé, que l'enregistreur suit
// `AppEnv.useBackend`, et que le service est **gaté par la session** (pas de
// session → inerte, `start()` no-op). Aucun plugin natif, aucun réseau : une base
// Drift **en mémoire** couvre le seul provider qui ouvre le magasin
// (`pushWakeHandlerProvider` via `groupDao`).
//
// Ces assertions sont la sentinelle du jour où le transport réel arrivera : si un
// `pushTransportProvider` réel est branché sans être scopé sur la session, le
// test « pas de session → service inerte » le dira.

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/core/config/app_env.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/push/device_registrar.dart';
import 'package:maison_du_miracle/data/push/inert_push_transport.dart';
import 'package:maison_du_miracle/data/push/local_notifier.dart';
import 'package:maison_du_miracle/data/push/platform_push_capabilities.dart';
import 'package:maison_du_miracle/data/push/push_wake_handler.dart';
import 'package:maison_du_miracle/state/push_providers.dart';
import 'package:maison_du_miracle/state/sync_providers.dart';

void main() {
  late AppDatabase db;
  late bool savedUseBackend;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    savedUseBackend = AppEnv.useBackend;
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    AppEnv.useBackend = savedUseBackend;
    await db.close();
  });

  ProviderContainer buildContainer() {
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('Les doubles inertes tant que Firebase n\'est pas debout', () {
    test('le transport, les capacités et le notifieur sont inertes/figés', () {
      final container = buildContainer();

      expect(container.read(pushTransportProvider), isA<InertPushTransport>());
      expect(
        container.read(platformPushCapabilitiesProvider),
        isA<FixedPushCapabilities>(),
      );
      expect(container.read(localNotifierProvider), isA<InertLocalNotifier>());
    });
  });

  group('L\'enregistreur suit AppEnv.useBackend', () {
    test('backend → HttpDeviceRegistrar (déjà réel, sans plugin natif)', () {
      AppEnv.useBackend = true;
      final container = buildContainer();
      expect(
        container.read(deviceRegistrarProvider),
        isA<HttpDeviceRegistrar>(),
      );
    });

    test('maquette → InertDeviceRegistrar', () {
      AppEnv.useBackend = false;
      final container = buildContainer();
      expect(
        container.read(deviceRegistrarProvider),
        isA<InertDeviceRegistrar>(),
      );
    });
  });

  group('Le service est gaté par la session', () {
    test('sans session (maquette) → service inerte, start() n\'enregistre rien',
        () async {
      AppEnv.useBackend = false;
      final container = buildContainer();

      final service = container.read(pushRegistrationServiceProvider);
      await service.start();

      // Transport inerte → obtainRegistration() rend null → rien à enregistrer.
      expect(service.current, isNull);
    });
  });

  group('Le wake handler est exposé (mais pas déclenché ici)', () {
    test('le provider construit un PushWakeHandler', () {
      AppEnv.useBackend = false;
      final container = buildContainer();
      expect(container.read(pushWakeHandlerProvider), isA<PushWakeHandler>());
    });
  });
}
