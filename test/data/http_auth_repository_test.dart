import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/core/network/api_client.dart';
import 'package:maison_du_miracle/data/repositories/auth_repository.dart';
import 'package:maison_du_miracle/data/repositories/http_auth_repository.dart';
import 'package:maison_du_miracle/models/models.dart';

/// Adaptateur Dio factice : note ce qui part sur le fil et rend la réponse
/// décidée par le test.
///
/// Indispensable ici — `flutter test` répond **400 à tout accès réseau réel**.
/// Aucune socket n'est ouverte : la requête traverse bien tous les
/// intercepteurs d'`ApiClient` (Bearer, enveloppe `data`, 401), mais s'arrête
/// à cet adaptateur.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.reply);

  /// Réponse à rendre, ou exception à lever pour simuler une panne.
  final ResponseBody Function(RequestOptions options) reply;

  /// Requêtes vues, dans l'ordre — pour vérifier chemin, verbe et corps.
  final List<RequestOptions> requests = [];

  RequestOptions get lastRequest => requests.last;

  Map<String, dynamic> get lastBody =>
      (lastRequest.data as Map).cast<String, dynamic>();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return reply(options);
  }

  @override
  void close({bool force = false}) {}
}

/// Réponse JSON du serveur, enveloppe `data` comprise (elle est déballée par
/// l'intercepteur d'`ApiClient`, comme en production).
ResponseBody jsonReply(int status, Object? data) => ResponseBody.fromString(
      jsonEncode({'data': data}),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

/// Réponse d'erreur du serveur : `{ code, message }`, **hors** enveloppe.
ResponseBody errorReply(int status, String code, [String? message]) =>
    ResponseBody.fromString(
      jsonEncode({'code': code, if (message != null) 'message': message}),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

/// Charge utile d'un `User` telle que la sérialise le serveur.
const Map<String, dynamic> userPayload = {
  'id': 'b6f0a1c2-0000-4000-8000-000000000001',
  'phone': '+22890123456',
  'email': null,
  'title': 'brother',
  'firstName': 'Jean',
  'lastName': 'Kossi',
  'branchId': 3,
  'status': 'affiliated',
  'avatarUrl': null,
  'profileComplete': true,
};

void main() {
  late FakeAdapter adapter;
  late HttpAuthRepository repository;
  late ApiClient api;

  /// Branche l'adaptateur factice sur le client global et repart d'un coffre
  /// vide (le vrai Keychain n'existe pas sous `flutter test`).
  void serve(ResponseBody Function(RequestOptions options) reply) {
    adapter = FakeAdapter(reply);
    api.dio.httpClientAdapter = adapter;
  }

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    api = ApiClient.instance;
    repository = HttpAuthRepository(client: api);
    serve((_) => jsonReply(200, null));
  });

  group('requestCode', () {
    test('poste identifier + channel `phone`', () async {
      serve((_) => jsonReply(202, {'status': 'sent'}));

      await repository.requestCode(
        identifier: '+22890123456',
        channel: IdentifierChannel.phone,
      );

      expect(adapter.lastRequest.method, 'POST');
      expect(adapter.lastRequest.path, '/auth/request-code');
      expect(adapter.lastBody, {
        'identifier': '+22890123456',
        // « phone » désigne un type d'identifiant, pas un transport : surtout
        // pas « sms » (contrat v2).
        'channel': 'phone',
      });
    });

    test('poste channel `email` pour un email', () async {
      serve((_) => jsonReply(202, {'status': 'sent'}));

      await repository.requestCode(
        identifier: 'jean@example.org',
        channel: IdentifierChannel.email,
      );

      expect(adapter.lastBody['channel'], 'email');
    });

    test('un identifiant refusé remonte le message du serveur', () async {
      serve(
        (_) => errorReply(
          422,
          'E_INVALID_PHONE_NUMBER',
          "Le numéro de téléphone n'est pas valide.",
        ),
      );

      await expectLater(
        repository.requestCode(
          identifier: '00',
          channel: IdentifierChannel.phone,
        ),
        throwsA(
          isA<AuthException>()
              .having((e) => e.code, 'code', AuthErrorCode.unknown)
              .having(
                (e) => e.message,
                'message',
                "Le numéro de téléphone n'est pas valide.",
              ),
        ),
      );
    });
  });

  group('verifyCode', () {
    test('stocke le token opaque tel quel, sans le décoder', () async {
      serve(
        (_) => jsonReply(200, {
          'token': 'oat_1.aBcDeF0123456789',
          'user': userPayload,
          'isNewUser': true,
        }),
      );

      final session = await repository.verifyCode(
        identifier: '+22890123456',
        code: '123456',
      );

      expect(adapter.lastRequest.path, '/auth/verify-code');
      expect(
          adapter.lastBody, {'identifier': '+22890123456', 'code': '123456'});
      expect(session.isNewUser, isTrue);
      expect(session.user.firstName, 'Jean');
      // Le token part et revient à l'identique : aucune tentative de lecture.
      expect(session.token, 'oat_1.aBcDeF0123456789');
      expect(await api.readToken(), 'oat_1.aBcDeF0123456789');
    });

    test('un mauvais code donne invalidCode de bout en bout', () async {
      // Chemin complet : erreur Dio → intercepteurs d'ApiClient → mapping.
      serve(
        (_) => errorReply(
          422,
          'E_INVALID_OTP_CODE',
          'Le code de vérification est invalide ou a expiré.',
        ),
      );

      await expectLater(
        repository.verifyCode(identifier: '+22890123456', code: '000000'),
        throwsA(
          isA<AuthException>()
              .having((e) => e.code, 'code', AuthErrorCode.invalidCode),
        ),
      );
      expect(await api.readToken(), isNull);
    });

    test('un 429 remonte tooManyAttempts et son décompte', () async {
      serve(
        (_) => ResponseBody.fromString(
          jsonEncode({
            'code': 'E_OTP_TOO_MANY_ATTEMPTS',
            'message': 'Trop de tentatives.',
            'retryAfter': 90,
          }),
          429,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        ),
      );

      await expectLater(
        repository.verifyCode(identifier: '+22890123456', code: '123456'),
        throwsA(
          isA<AuthException>()
              .having((e) => e.code, 'code', AuthErrorCode.tooManyAttempts)
              .having(
                (e) => e.retryAfter,
                'retryAfter',
                const Duration(seconds: 90),
              ),
        ),
      );
    });
  });

  group('updateProfile', () {
    test('envoie firstName, lastName, branchId entier, status et title',
        () async {
      serve((_) => jsonReply(200, userPayload));

      final user = await repository.updateProfile(
        title: UserTitle.brother,
        firstName: 'Jean',
        lastName: 'Kossi',
        branchId: 3,
        status: UserStatus.affiliated,
      );

      expect(adapter.lastRequest.method, 'PUT');
      expect(adapter.lastRequest.path, '/auth/profile');
      expect(adapter.lastBody, {
        'title': 'brother',
        'firstName': 'Jean',
        'lastName': 'Kossi',
        'branchId': 3,
        'status': 'affiliated',
      });
      // Entier, pas chaîne : `branchId` se compare directement à `Branch.id`.
      expect(adapter.lastBody['branchId'], isA<int>());
      expect(user.branchId, 3);
    });

    test('mise à jour partielle : les champs absents ne partent pas', () async {
      serve((_) => jsonReply(200, userPayload));

      await repository.updateProfile(firstName: 'Ama');

      expect(adapter.lastBody, {'firstName': 'Ama'});
    });
  });

  group('signOut', () {
    test('supprime le token local même si le serveur répond 500', () async {
      await api.saveToken('oat_1.token-a-revoquer');
      serve((_) => errorReply(500, 'E_INTERNAL_SERVER_ERROR'));

      await repository.signOut();

      expect(adapter.lastRequest.path, '/auth/sign-out');
      expect(await api.readToken(), isNull);
    });

    test('supprime le token local même si le serveur est injoignable',
        () async {
      await api.saveToken('oat_1.token-a-revoquer');
      serve((options) => throw DioException.connectionError(
            requestOptions: options,
            reason: 'réseau coupé',
          ));

      // Aucune exception ne doit remonter : l'utilisateur a demandé à partir.
      await repository.signOut();

      expect(await api.readToken(), isNull);
    });

    test('révoque côté serveur quand tout va bien', () async {
      await api.saveToken('oat_1.token-a-revoquer');
      serve((_) => jsonReply(200, null));

      await repository.signOut();

      expect(adapter.lastRequest.method, 'POST');
      // Le token révoqué doit accompagner la requête, sinon le serveur ne sait
      // pas quelle session fermer.
      expect(
        adapter.lastRequest.headers['Authorization'],
        'Bearer oat_1.token-a-revoquer',
      );
      expect(await api.readToken(), isNull);
    });
  });

  group('currentUser', () {
    test('sans token, aucune requête n\'est émise', () async {
      expect(await repository.currentUser(), isNull);
      expect(adapter.requests, isEmpty);
    });

    test('avec un token, revalide auprès de /auth/me', () async {
      await api.saveToken('oat_1.valide');
      serve((_) => jsonReply(200, userPayload));

      final user = await repository.currentUser();

      expect(adapter.lastRequest.path, '/auth/me');
      expect(user?.id, userPayload['id']);
    });

    test('un 401 dit simplement « personne n\'est connecté »', () async {
      await api.saveToken('oat_1.perime');
      serve((_) => errorReply(401, 'E_UNAUTHORIZED_ACCESS'));

      // La purge du token et le retour à /auth appartiennent à
      // l'intercepteur global : ici, pas d'AuthException.
      expect(await repository.currentUser(), isNull);
    });
  });
}
