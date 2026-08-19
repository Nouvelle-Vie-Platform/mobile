// **Le cycle d'enregistrement push**, prouvé avec des doubles — aucun réseau,
// aucun plugin natif. Un [PushTransport] factice (contrôlable : inscription,
// rotations, panne) et un [DeviceRegistrar] factice (qui note ce qu'on lui
// demande) suffisent à couvrir tout le service.
//
// Ce qui est vérifié :
// - au démarrage, l'inscription obtenue est enregistrée ;
// - `null` (pas de push, décision D4) → rien n'est enregistré ;
// - une rotation réenregistre la nouvelle cible, jamais la même ;
// - la déconnexion purge la dernière cible, et rien si l'appareil n'en avait pas ;
// - une panne d'obtention ne lève pas (best-effort) ;
// - `dispose` relâche l'abonnement et le transport, sans purger.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/push/device_registrar.dart';
import 'package:maison_du_miracle/data/push/push_registration_service.dart';
import 'package:maison_du_miracle/data/push/push_transport.dart';

const PushRegistration _first = PushRegistration(
  token: 'token-un',
  platform: 'android',
  transport: kPushTransportFcm,
);

const PushRegistration _rotated = PushRegistration(
  token: 'token-deux',
  platform: 'android',
  transport: kPushTransportFcm,
);

/// Registrar factice : enregistre ce qu'on lui demande, ne parle à personne.
class _RecordingRegistrar implements DeviceRegistrar {
  final List<PushRegistration> registered = [];
  final List<PushRegistration> unregistered = [];

  @override
  Future<void> register(PushRegistration registration) async =>
      registered.add(registration);

  @override
  Future<void> unregister(PushRegistration registration) async =>
      unregistered.add(registration);
}

/// Transport factice et pilotable : on choisit ce que rend `obtainRegistration`
/// (ou on le fait échouer), on pousse des rotations à la main, on observe le
/// `dispose`.
class _FakeTransport implements PushTransport {
  _FakeTransport({this.registration, this.failObtain = false});

  PushRegistration? registration;
  bool failObtain;
  bool disposed = false;

  final StreamController<PushRegistration> _rotations =
      StreamController<PushRegistration>.broadcast();

  void rotate(PushRegistration next) => _rotations.add(next);

  @override
  Future<PushRegistration?> obtainRegistration() async {
    if (failObtain) throw StateError('jeton indisponible');
    return registration;
  }

  @override
  Stream<PushRegistration> get onRefresh => _rotations.stream;

  @override
  Future<void> dispose() async {
    disposed = true;
    await _rotations.close();
  }
}

void main() {
  late _RecordingRegistrar registrar;

  setUp(() => registrar = _RecordingRegistrar());

  test('au démarrage, l\'inscription obtenue est enregistrée', () async {
    final transport = _FakeTransport(registration: _first);
    final service =
        PushRegistrationService(transport: transport, registrar: registrar);

    await service.start();

    expect(registrar.registered, [_first]);
    expect(service.current, _first);
  });

  test('pas d\'inscription (D4) → rien n\'est enregistré', () async {
    final transport = _FakeTransport(registration: null);
    final service =
        PushRegistrationService(transport: transport, registrar: registrar);

    await service.start();

    expect(registrar.registered, isEmpty);
    expect(service.current, isNull);
  });

  test('une rotation réenregistre la nouvelle cible', () async {
    final transport = _FakeTransport(registration: _first);
    final service =
        PushRegistrationService(transport: transport, registrar: registrar);
    await service.start();

    transport.rotate(_rotated);
    await pumpEventQueue();

    expect(registrar.registered, [_first, _rotated]);
    expect(service.current, _rotated);
  });

  test('une rotation qui rend la même cible ne repost pas', () async {
    final transport = _FakeTransport(registration: _first);
    final service =
        PushRegistrationService(transport: transport, registrar: registrar);
    await service.start();

    transport.rotate(_first); // même token/platform/transport
    await pumpEventQueue();

    expect(registrar.registered, [_first]);
  });

  test('la déconnexion purge la dernière cible enregistrée', () async {
    final transport = _FakeTransport(registration: _first);
    final service =
        PushRegistrationService(transport: transport, registrar: registrar);
    await service.start();

    await service.signOut();

    expect(registrar.unregistered, [_first]);
    expect(service.current, isNull);
  });

  test('déconnexion sans push : rien à purger', () async {
    final transport = _FakeTransport(registration: null);
    final service =
        PushRegistrationService(transport: transport, registrar: registrar);
    await service.start();

    await service.signOut();

    expect(registrar.unregistered, isEmpty);
  });

  test('une panne d\'obtention ne lève pas et n\'enregistre rien', () async {
    final transport = _FakeTransport(failObtain: true);
    final service =
        PushRegistrationService(transport: transport, registrar: registrar);

    await expectLater(service.start(), completes);
    expect(registrar.registered, isEmpty);
  });

  test('start est idempotent : l\'abonnement n\'est armé qu\'une fois', () async {
    final transport = _FakeTransport(registration: _first);
    final service =
        PushRegistrationService(transport: transport, registrar: registrar);

    await service.start();
    await service.start(); // ré-appel (ex. reconnexion)

    // Deux enregistrements (un par appel), mais une seule rotation propagée.
    expect(registrar.registered, [_first, _first]);

    transport.rotate(_rotated);
    await pumpEventQueue();
    expect(registrar.registered, [_first, _first, _rotated]);
  });

  test('dispose relâche l\'abonnement et le transport, sans purger', () async {
    final transport = _FakeTransport(registration: _first);
    final service =
        PushRegistrationService(transport: transport, registrar: registrar);
    await service.start();

    await service.dispose();

    expect(transport.disposed, isTrue);
    expect(registrar.unregistered, isEmpty); // dispose ne purge jamais
  });
}
