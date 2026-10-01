import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/core/network/api_client.dart';
import 'package:maison_du_miracle/data/push/push_enrolment.dart';
import 'package:maison_du_miracle/data/push/push_registrar.dart';
import 'package:maison_du_miracle/data/push/push_transport.dart';

import '../../helpers/fake_api.dart';

/// **L'enregistrement de la cible de réveil** : le bon corps, sur la bonne route,
/// au bon moment — et son renvoi à chaque rotation de jeton.
///
/// La requête traverse les **intercepteurs de production** (en-têtes de
/// présentation, porteur, déballage d'enveloppe, 401) et s'arrête à l'adaptateur
/// factice : aucune socket, et ce qu'on vérifie est le vrai chemin.
///
/// Rien ici ne touche Firebase : le transport est un double, comme le prévoit la
/// couture de `push_transport.dart`.
void main() {
  late FakeAdapter adapter;
  late ApiClient api;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    api = ApiClient.instance;
    // Le singleton survit d'un test à l'autre : on repart d'un client neuf de tout
    // câblage, comme `device_repository_test.dart`.
    api.onUnauthorized = null;
    api.deviceSession = null;
    adapter = FakeAdapter((_) => jsonReply(200, _receipt));
    api.dio.httpClientAdapter = adapter;
  });

  List<RequestOptions> registrations() =>
      adapter.requests.where((r) => r.path == '/devices/tokens').toList();

  /// Attend qu'une rotation ait traversé **le flux, la chaîne d'intercepteurs de
  /// Dio, et le retour de l'accusé**, au lieu de deviner un nombre de tours de
  /// boucle.
  ///
  /// Un `Future.delayed` d'une durée fixe a été essayé d'abord, et il mentait : il
  /// passait seul et échouait dans la suite entière, où `LogInterceptor` écrit
  /// beaucoup et où `debugPrint` est **étranglé**. Un test qui dépend de la
  /// verbosité de ses voisins n'est pas un test. Le délai d'attente, lui, ne rend
  /// aucune assertion vraie : passé la borne, on vérifie quand même, et on échoue.
  Future<void> waitUntil(bool Function() settled) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (!settled() && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  group('Le corps de `POST /devices/tokens`', () {
    test('porte la cible, la plateforme et le transport — et rien d\'autre',
        () async {
      final registrar = HttpPushRegistrar(dio: api.dio);

      final accepted = await registrar.register(
        token: 'fMEQ4t:APA91bH',
        platform: 'android',
        transport: kFcmTransport,
      );

      expect(accepted, isTrue);
      expect(registrations(), hasLength(1));
      expect(adapter.lastRequest.method, 'POST');
      // Pas de préfixe `/api` — ADR-0004.
      expect(adapter.lastRequest.path, '/devices/tokens');
      expect(adapter.lastBody, {
        'token': 'fMEQ4t:APA91bH',
        'platform': 'android',
        'transport': 'fcm',
      });
    });

    test('n\'emporte AUCUN `deviceId`', () async {
      // ⚠️ L'identité d'appareil est lue sur le jeton d'authentification. Une
      // chaîne fournie par le client est **falsifiable** : l'envoyer permettrait
      // d'accrocher une cible de réveil à l'appareil de quelqu'un d'autre. Le
      // serveur la refuse ; ce test existe pour qu'on ne la « complète » pas ici.
      await HttpPushRegistrar(dio: api.dio).register(
        token: 'cible',
        platform: 'ios',
        transport: kFcmTransport,
      );

      expect(adapter.lastBody.keys, isNot(contains('deviceId')));
      expect(adapter.lastBody.keys, isNot(contains('device_id')));
    });

    test('un refus est muet et rend `false`', () async {
      // Avion, 401, 5xx : l'appel est rejouable par conception (idempotent côté
      // serveur), et une cible non enregistrée coûte un réveil, pas une
      // fonctionnalité. Rien ne lève, rien ne s'affiche.
      adapter = FakeAdapter(
        (_) => errorReply(500, 'E_INTERNAL_SERVER_ERROR'),
      );
      api.dio.httpClientAdapter = adapter;

      final accepted = await HttpPushRegistrar(dio: api.dio).register(
        token: 'cible',
        platform: 'android',
        transport: kFcmTransport,
      );

      expect(accepted, isFalse);
    });
  });

  group('Le moment de l\'enregistrement', () {
    test('la cible obtenue au démarrage part aussitôt', () async {
      final transport = _ScriptedTransport(first: 'cible-1');

      final enrolment = PushEnrolment(
        transport: transport,
        registrar: HttpPushRegistrar(dio: api.dio),
        platform: 'android',
      );
      await enrolment.start();

      expect(registrations(), hasLength(1));
      expect(adapter.lastBody['token'], 'cible-1');
      // La cible est retenue : c'est elle que la déconnexion désabonnera.
      expect(enrolment.target, 'cible-1');
      await enrolment.dispose();
    });

    test('une rotation la renvoie, sous la même plateforme', () async {
      final transport = _ScriptedTransport(first: 'cible-1');

      final enrolment = PushEnrolment(
        transport: transport,
        registrar: HttpPushRegistrar(dio: api.dio),
        platform: 'android',
      );
      await enrolment.start();

      transport.rotate('cible-2');
      await waitUntil(() => enrolment.target == 'cible-2');

      expect(registrations(), hasLength(2));
      expect(adapter.lastBody, {
        'token': 'cible-2',
        'platform': 'android',
        'transport': 'fcm',
      });
      // ⚠️ C'est la panne la plus difficile à constater de la tranche : un jeton
      // périmé ne produit aucune erreur, le téléphone devient simplement
      // injoignable.
      expect(enrolment.target, 'cible-2');
      await enrolment.dispose();
    });

    test('`start()` rejoué ne pose pas un second abonnement', () async {
      final transport = _ScriptedTransport(first: 'cible-1');

      final enrolment = PushEnrolment(
        transport: transport,
        registrar: HttpPushRegistrar(dio: api.dio),
        platform: 'android',
      );
      await enrolment.start();
      await enrolment.start();

      transport.rotate('cible-2');
      await waitUntil(() => registrations().length >= 3);

      // Deux démarrages = deux enregistrements (l'appel est idempotent côté
      // serveur), mais **une** rotation ne doit en produire qu'un : deux
      // abonnements enregistreraient deux fois la même cible.
      expect(registrations(), hasLength(3));
      await enrolment.dispose();
    });

    test('plus rien ne part après `dispose()`', () async {
      final transport = _ScriptedTransport(first: 'cible-1');
      final enrolment = PushEnrolment(
        transport: transport,
        registrar: HttpPushRegistrar(dio: api.dio),
        platform: 'android',
      );
      await enrolment.start();
      await enrolment.dispose();

      transport.rotate('cible-2');
      // Rien à attendre, donc on laisse délibérément la boucle tourner le temps
      // qu'un enregistrement *aurait* mis à partir : sans ce délai, le test
      // passerait aussi sur un abonnement toujours vivant.
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(registrations(), hasLength(1));
      // La cible retenue, elle, survit : une déconnexion arrivant après la
      // fermeture du conteneur doit encore savoir quoi désabonner.
      expect(enrolment.target, 'cible-1');
    });
  });

  group('Ce qui n\'enregistre rien, et ne casse rien', () {
    test('pas de cible — permission refusée, pas de Play Services', () async {
      final enrolment = PushEnrolment(
        transport: _ScriptedTransport(first: null),
        registrar: HttpPushRegistrar(dio: api.dio),
        platform: 'android',
      );

      await enrolment.start();

      expect(registrations(), isEmpty);
      expect(enrolment.target, isNull);
      await enrolment.dispose();
    });

    test('plateforme hors du jeu fermé du serveur', () async {
      // macOS, Linux, Windows : `POST /devices/tokens` rendrait 422. On n'appelle
      // pas, et on ne demande même pas de cible au transport.
      final transport = _ScriptedTransport(first: 'cible-1');
      final enrolment = PushEnrolment(
        transport: transport,
        registrar: HttpPushRegistrar(dio: api.dio),
        platform: null,
      );

      await enrolment.start();

      expect(registrations(), isEmpty);
      expect(transport.asked, 0);
      await enrolment.dispose();
    });

    test('un transport qui lève ne fait pas échouer le démarrage', () async {
      final enrolment = PushEnrolment(
        transport: _ThrowingTransport(),
        registrar: HttpPushRegistrar(dio: api.dio),
        platform: 'ios',
      );

      await expectLater(enrolment.start(), completes);
      expect(registrations(), isEmpty);
      await enrolment.dispose();
    });

    test('le double inerte : aucune requête, aucune cible, aucune minuterie',
        () async {
      // **L'application démarre et s'enregistre sans aucun transport.** C'est l'état
      // du web, de macOS, et d'un Android dé-googlé jusqu'à la tranche 4.
      final enrolment = PushEnrolment(
        transport: const InertPushTransport(),
        registrar: HttpPushRegistrar(dio: api.dio),
        platform: 'android',
      );

      await enrolment.start();

      expect(registrations(), isEmpty);
      expect(enrolment.target, isNull);
      await enrolment.dispose();
    });

    test('le registraire inerte n\'ouvre aucune socket', () async {
      final enrolment = PushEnrolment(
        transport: _ScriptedTransport(first: 'cible-1'),
        registrar: const InertPushRegistrar(),
        platform: 'android',
      );

      await enrolment.start();

      expect(adapter.requests, isEmpty);
      // Rien n'a été accepté : annoncer au serveur une cible qu'il n'a jamais
      // rangée ferait désabonner une ligne qui n'existe pas.
      expect(enrolment.target, isNull);
      await enrolment.dispose();
    });
  });
}

/// L'accusé d'enregistrement, tel que `DeviceTokenTransformer` le sérialise : le
/// jeton **n'y est pas** (le client vient de l'envoyer).
const Map<String, Object?> _receipt = {
  'id': '019a5000-0000-7000-8000-00000000dev1',
  'platform': 'android',
  'transport': 'fcm',
  'lastSeenAt': '2026-10-01T10:00:00.000Z',
  'createdAt': '2026-10-01T09:00:00.000Z',
  'updatedAt': '2026-10-01T10:00:00.000Z',
};

/// Un transport **scripté** : une première cible, puis les rotations qu'on lui
/// demande d'émettre. Aucun canal de greffon.
class _ScriptedTransport implements PushTransport {
  _ScriptedTransport({required this.first});

  final String? first;
  final StreamController<String> _rotations = StreamController<String>();

  /// Combien de fois on lui a demandé une cible.
  int asked = 0;

  void rotate(String token) => _rotations.add(token);

  @override
  String get transport => kFcmTransport;

  @override
  Future<String?> target() async {
    asked++;
    return first;
  }

  @override
  Stream<String> get targetChanges => _rotations.stream;

  @override
  Stream<Map<String, Object?>> get wakes =>
      const Stream<Map<String, Object?>>.empty();
}

class _ThrowingTransport implements PushTransport {
  @override
  String get transport => kFcmTransport;

  @override
  Future<String?> target() async => throw StateError('canal absent');

  @override
  Stream<String> get targetChanges => const Stream<String>.empty();

  @override
  Stream<Map<String, Object?>> get wakes =>
      const Stream<Map<String, Object?>>.empty();
}
