import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/network/network_transport.dart';

/// **L'accélérateur de la reprise radio** (#179) : « un tuyau vient
/// d'apparaître ou de changer », et jamais « plus de réseau ».
void main() {
  late StreamController<List<ConnectivityResult>> os;
  late List<void> signals;
  late StreamSubscription<void> subscription;

  setUp(() {
    os = StreamController<List<ConnectivityResult>>.broadcast();
    signals = [];
    subscription = ConnectivityNetworkStatus(_FakeConnectivity(os.stream))
        .onTransportChanged
        .listen(signals.add);
  });

  tearDown(() async {
    await subscription.cancel();
    await os.close();
  });

  Future<void> report(List<ConnectivityResult> results) async {
    os.add(results);
    await Future<void>.delayed(Duration.zero);
  }

  test('la première valeur est le point de départ, pas un changement',
      () async {
    await report([ConnectivityResult.mobile]);
    expect(signals, isEmpty);
  });

  test('le retour du réseau et le changement de tuyau émettent', () async {
    await report([ConnectivityResult.none]);
    await report([ConnectivityResult.wifi]);
    expect(signals, hasLength(1), reason: 'le réseau revient');
    await report([ConnectivityResult.mobile]);
    expect(signals, hasLength(2), reason: 'le wifi cède aux données');
  });

  test('la perte du réseau n\'émet jamais', () async {
    await report([ConnectivityResult.wifi]);
    await report([ConnectivityResult.none]);
    expect(signals, isEmpty);
  });

  test('chaque abonnement a son propre point de départ', () async {
    await report([ConnectivityResult.wifi]);
    await subscription.cancel();
    final again = <void>[];
    subscription = ConnectivityNetworkStatus(_FakeConnectivity(os.stream))
        .onTransportChanged
        .listen(again.add);
    // L'état courant republié à l'abonnement n'est pas un changement.
    await report([ConnectivityResult.mobile]);
    expect(again, isEmpty);
  });
}

class _FakeConnectivity implements Connectivity {
  _FakeConnectivity(this._changes);

  final Stream<List<ConnectivityResult>> _changes;

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged => _changes;

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async =>
      [ConnectivityResult.wifi];
}
