// Tests de la **mesure d'espace disque** (`BestEffortDiskSpace`, #236).
//
// Le natif ne se teste pas ici : `StatFs` et
// `volumeAvailableCapacityForImportantUsage` demandent un appareil. Ce qui se
// prouve sur la VM Dart, c'est le **décodage** de ce que le canal rend, et
// surtout la règle qui tient tout le pré-check : en cas d'échec on rend `null`
// (inconnu, le manager laisse passer), **jamais `0`** (disque plein, le manager
// bloque). Un `0` rendu par erreur condamnerait tous les téléchargements.
//
// Le nom du canal et celui de la méthode sont écrits en dur : c'est le contrat
// avec `MainActivity.kt` et `AppDelegate.swift`, et un renommage d'un seul côté
// doit faire rougir ce fichier.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/downloads/disk_space.dart';

const MethodChannel _channel = MethodChannel(
  'com.maisondumiracle.maison_du_miracle/disk_space',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];

  /// Branche un faux natif. [reply] rend la valeur, ou lève.
  void mockNative(Object? Function() reply) {
    messenger.setMockMethodCallHandler(_channel, (call) async {
      calls.add(call);
      return reply();
    });
  }

  setUp(calls.clear);
  tearDown(() => messenger.setMockMethodCallHandler(_channel, null));

  test('rend le nombre que le natif mesure, et demande bien freeBytes',
      () async {
    mockNative(() => 4294967296); // 4 Gio : au-delà de 32 bits, exprès.

    expect(await const BestEffortDiskSpace().freeBytes(), 4294967296);
    expect(calls.single.method, 'freeBytes');
  });

  test('zéro est une mesure — disque plein, pas inconnu', () async {
    mockNative(() => 0);

    expect(await const BestEffortDiskSpace().freeBytes(), 0);
  });

  test('pas de canal (web, bureau) : inconnu, pas plein', () async {
    // Aucun gestionnaire branché : le canal lève `MissingPluginException`.
    expect(await const BestEffortDiskSpace().freeBytes(), isNull);
  });

  test('le natif échoue : inconnu, pas plein', () async {
    mockNative(() => throw PlatformException(code: 'statfs'));

    expect(await const BestEffortDiskSpace().freeBytes(), isNull);
  });

  test('valeur négative : inconnu, pas plein', () async {
    mockNative(() => -1);

    expect(await const BestEffortDiskSpace().freeBytes(), isNull);
  });

  test("ce n'est pas un entier : inconnu, pas plein", () async {
    mockNative(() => 'beaucoup');

    expect(await const BestEffortDiskSpace().freeBytes(), isNull);
  });
}
