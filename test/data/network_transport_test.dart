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

  Future<void> subscribe(List<ConnectivityResult> current) async {
    subscription =
        ConnectivityNetworkStatus(_FakeConnectivity(os.stream, current))
            .onTransportChanged
            .listen(signals.add);
    await Future<void>.delayed(Duration.zero);
  }

  setUp(() async {
    os = StreamController<List<ConnectivityResult>>.broadcast();
    signals = [];
    await subscribe([ConnectivityResult.wifi]);
  });

  tearDown(() async {
    await subscription.cancel();
    await os.close();
  });

  Future<void> report(List<ConnectivityResult> results) async {
    os.add(results);
    await Future<void>.delayed(Duration.zero);
  }

  test('l\'état courant republié à l\'abonnement n\'est pas un changement',
      () async {
    await report([ConnectivityResult.wifi]);
    expect(signals, isEmpty);
  });

  test(
      'abonné PENDANT la coupure, sans rien de publié : le retour du réseau '
      'émet', () async {
    await subscription.cancel();
    // Android ne publie rien à l'abonnement quand il n'y a aucun réseau.
    await subscribe([ConnectivityResult.none]);
    await report([ConnectivityResult.wifi]);
    expect(signals, hasLength(1));
  });

  test('le retour du réseau et le changement de tuyau émettent', () async {
    await report([ConnectivityResult.none]);
    await report([ConnectivityResult.wifi]);
    expect(signals, hasLength(1), reason: 'le réseau revient');
    await report([ConnectivityResult.mobile]);
    expect(signals, hasLength(2), reason: 'le wifi cède aux données');
  });

  test('la perte du réseau n\'émet jamais', () async {
    await report([ConnectivityResult.none]);
    expect(signals, isEmpty);
  });

  test('chaque abonnement a son propre point de départ', () async {
    await report([ConnectivityResult.mobile]);
    expect(signals, hasLength(1), reason: 'le wifi cède aux données');
    await subscription.cancel();
    signals.clear();
    await subscribe([ConnectivityResult.mobile]);
    // L'état courant republié à l'abonnement n'est pas un changement.
    await report([ConnectivityResult.mobile]);
    expect(signals, isEmpty);
  });
}

class _FakeConnectivity implements Connectivity {
  _FakeConnectivity(this._changes, this._current);

  final Stream<List<ConnectivityResult>> _changes;
  final List<ConnectivityResult> _current;

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged => _changes;

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => _current;
}
