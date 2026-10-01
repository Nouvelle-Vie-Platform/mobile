import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/core/network/api_client.dart';
import 'package:maison_du_miracle/data/repositories/auth_repository.dart';
import 'package:maison_du_miracle/data/repositories/http_auth_repository.dart';
import 'package:maison_du_miracle/models/models.dart';

import '../helpers/fake_api.dart';

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

    test('désabonne CET appareil du réveil push, et lui seul (#97)', () async {
      // ⚠️ `deviceToken` est **optionnel** côté serveur, et l'omettre laisse
      // l'appareil abonné aux notifications du compte qui vient de partir : sur un
      // téléphone prêté — le cas réel dans une église —, le membre suivant verrait
      // passer celles du précédent. Le serveur ne peut pas le deviner, la cible de
      // réveil ne voyageant dans aucun en-tête.
      final signingOut = HttpAuthRepository(
        client: api,
        pushTarget: () => 'fMEQ4t:APA91bH',
      );
      await api.saveToken('oat_1.token-a-revoquer');
      serve((_) => jsonReply(200, {'revoked': true}));

      await signingOut.signOut();

      expect(adapter.lastRequest.path, '/auth/sign-out');
      expect(adapter.lastBody, {'deviceToken': 'fMEQ4t:APA91bH'});
    });

    test('sans cible enregistrée, le corps reste absent', () async {
      // Le validateur accepte l'absence du champ, pas une chaîne vide
      // (`minLength(1)`) : envoyer `{'deviceToken': ''}` prendrait un 422, et une
      // déconnexion ne doit pas échouer pour un push.
      await api.saveToken('oat_1.token-a-revoquer');
      serve((_) => jsonReply(200, {'revoked': true}));

      await repository.signOut();

      expect(adapter.lastRequest.path, '/auth/sign-out');
      expect(adapter.lastRequest.data, isNull);
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

  // ── Cache local du User ──────────────────────────────────────────────────
  //
  // Tout ce groupe vérifie la même promesse : le prochain démarrage doit
  // pouvoir router **sans réseau**, et ne jamais router avec les données de
  // quelqu'un qui est parti.
  group('cache local', () {
    test('verifyCode remplit le cache, lisible sans le moindre appel',
        () async {
      serve(
        (_) => jsonReply(200, {
          'token': 'oat_1.valide',
          'user': userPayload,
          'isNewUser': false,
        }),
      );
      await repository.verifyCode(identifier: '+22890123456', code: '123456');
      final callsAfterLogin = adapter.requests.length;

      final cached = await repository.cachedUser();

      expect(cached?.id, userPayload['id']);
      expect(cached?.firstName, 'Jean');
      // Le point entier de ce cache : aucune requête supplémentaire.
      expect(adapter.requests.length, callsAfterLogin);
    });

    test('le cache ne contient jamais le token', () async {
      serve(
        (_) => jsonReply(200, {
          'token': 'oat_1.ce-token-ne-doit-pas-fuiter',
          'user': userPayload,
          'isNewUser': false,
        }),
      );
      await repository.verifyCode(identifier: '+22890123456', code: '123456');

      // Le coffre porte deux entrées distinctes : le token, et le User. Aucune
      // valeur du cache ne doit contenir la chaîne du token — sinon il se
      // retrouverait dupliqué là où on ne le purge pas forcément.
      const storage = FlutterSecureStorage();
      final all = await storage.readAll();
      final cacheEntries = Map.of(all)..remove('auth_token');
      expect(cacheEntries, isNotEmpty);
      for (final value in cacheEntries.values) {
        expect(value, isNot(contains('oat_1.ce-token-ne-doit-pas-fuiter')));
      }
    });

    test('une revalidation réussie rafraîchit le cache', () async {
      await api.saveToken('oat_1.valide');
      serve((_) => jsonReply(200, {...userPayload, 'firstName': 'Ama'}));

      await repository.currentUser();

      expect((await repository.cachedUser())?.firstName, 'Ama');
    });

    test('serveur injoignable : le cache survit et la session reste ouverte',
        () async {
      serve(
        (_) => jsonReply(200, {
          'token': 'oat_1.valide',
          'user': userPayload,
          'isNewUser': false,
        }),
      );
      await repository.verifyCode(identifier: '+22890123456', code: '123456');

      // Mode avion.
      serve((options) => throw DioException.connectionError(
            requestOptions: options,
            reason: 'réseau coupé',
          ));

      await expectLater(
        repository.currentUser(),
        throwsA(isA<AuthException>()
            .having((e) => e.code, 'code', AuthErrorCode.network)),
      );
      // C'est ce qui permet d'entrer dans l'app hors ligne.
      expect((await repository.cachedUser())?.id, userPayload['id']);
    });

    test('un 401 efface le cache', () async {
      serve(
        (_) => jsonReply(200, {
          'token': 'oat_1.perime',
          'user': userPayload,
          'isNewUser': false,
        }),
      );
      await repository.verifyCode(identifier: '+22890123456', code: '123456');

      serve((_) => errorReply(401, 'E_UNAUTHORIZED_ACCESS'));
      expect(await repository.currentUser(), isNull);

      expect(await repository.cachedUser(), isNull);
      expect(await api.readToken(), isNull);
    });

    test('signOut efface le token ET le cache', () async {
      serve(
        (_) => jsonReply(200, {
          'token': 'oat_1.valide',
          'user': userPayload,
          'isNewUser': false,
        }),
      );
      await repository.verifyCode(identifier: '+22890123456', code: '123456');

      await repository.signOut();

      expect(await api.readToken(), isNull);
      // Sans ça, le démarrage suivant ouvrirait l'accueil au nom de celui qui
      // vient de se déconnecter.
      expect(await repository.cachedUser(), isNull);
    });

    test('forgetSession oublie tout sans appeler le serveur', () async {
      serve(
        (_) => jsonReply(200, {
          'token': 'oat_1.valide',
          'user': userPayload,
          'isNewUser': false,
        }),
      );
      await repository.verifyCode(identifier: '+22890123456', code: '123456');
      final callsBefore = adapter.requests.length;

      await repository.forgetSession();

      expect(adapter.requests.length, callsBefore);
      expect(await api.readToken(), isNull);
      expect(await repository.cachedUser(), isNull);
    });

    test('un cache sans token ne fait entrer personne', () async {
      serve(
        (_) => jsonReply(200, {
          'token': 'oat_1.valide',
          'user': userPayload,
          'isNewUser': false,
        }),
      );
      await repository.verifyCode(identifier: '+22890123456', code: '123456');

      // Token perdu (restauration de sauvegarde, purge du Keychain) : le cache
      // décrit alors une session qui n'existe plus.
      await api.deleteToken();

      expect(await repository.currentUser(), isNull);
      expect(await repository.cachedUser(), isNull);
    });
  });
}
