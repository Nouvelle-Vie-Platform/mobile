import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/repositories/auth_repository.dart';
import 'package:maison_du_miracle/data/repositories/http_auth_repository.dart';

/// Fabrique la [DioException] que Dio remonte pour une réponse d'erreur du
/// serveur : statut, corps **réel** (`{ code, message }`, hors enveloppe
/// `data`) et en-têtes éventuels.
///
/// Aucun réseau : `mapAuthError` est une fonction pure, on l'appelle avec ce
/// qu'elle verrait en production (`flutter test` répond 400 à tout accès réel).
DioException serverError(
  int status,
  Object? body, {
  Map<String, List<String>> headers = const {},
}) {
  final options = RequestOptions(path: '/auth/verify-code');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response<dynamic>(
      requestOptions: options,
      statusCode: status,
      data: body,
      headers: Headers.fromMap(headers),
    ),
  );
}

/// Panne réseau : Dio lève sans **aucune** réponse du serveur.
DioException transportError(DioExceptionType type) => DioException(
      requestOptions: RequestOptions(path: '/auth/verify-code'),
      type: type,
      message: 'échec de transport',
    );

void main() {
  group('Mapping des erreurs serveur — une ligne du contrat par test', () {
    test('E_INVALID_OTP_CODE (422) → invalidCode', () {
      final error = mapAuthError(
        serverError(422, {
          'code': 'E_INVALID_OTP_CODE',
          'message': 'Le code de vérification est invalide ou a expiré.',
        }),
      );

      expect(error.code, AuthErrorCode.invalidCode);
    });

    test('E_OTP_TOO_MANY_ATTEMPTS (429) → tooManyAttempts', () {
      final error = mapAuthError(
        serverError(429, {
          'code': 'E_OTP_TOO_MANY_ATTEMPTS',
          'message': 'Trop de tentatives. Demandez un nouveau code.',
        }),
      );

      expect(error.code, AuthErrorCode.tooManyAttempts);
    });

    test('E_OTP_RATE_LIMITED (429) → tooManyAttempts', () {
      final error = mapAuthError(
        serverError(429, {
          'code': 'E_OTP_RATE_LIMITED',
          'message': 'Trop de demandes de vérification. '
              'Veuillez patienter avant de réessayer.',
        }),
      );

      expect(error.code, AuthErrorCode.tooManyAttempts);
    });

    test('les deux 429 ne se distinguent pas par le statut', () {
      // Garde-fou : c'est bien le champ `code` qui décide. Un 429 sans corps
      // reconnu ne doit pas être deviné comme « trop d'essais ».
      expect(
        mapAuthError(serverError(429, {'code': 'E_AUTRE_CHOSE'})).code,
        AuthErrorCode.unknown,
      );
    });

    test('E_INVALID_PHONE_NUMBER (422) → unknown + message du serveur', () {
      final error = mapAuthError(
        serverError(422, {
          'code': 'E_INVALID_PHONE_NUMBER',
          'message': "Le numéro de téléphone n'est pas valide.",
        }),
      );

      expect(error.code, AuthErrorCode.unknown);
      // Message déjà localisé côté serveur : on l'affiche tel quel.
      expect(error.message, "Le numéro de téléphone n'est pas valide.");
    });

    test('E_VALIDATION_ERROR (422) → unknown + message du validateur', () {
      final error = mapAuthError(
        serverError(422, {
          'code': 'E_VALIDATION_ERROR',
          'message': 'Le code doit comporter 6 chiffres',
        }),
      );

      expect(error.code, AuthErrorCode.unknown);
      expect(error.message, 'Le code doit comporter 6 chiffres');
    });

    test('E_UNAUTHORIZED_ACCESS (401) n\'est pas une erreur de code', () {
      // Le 401 est traité globalement par `UnauthorizedInterceptor` (purge du
      // token + retour à /auth). Ici il ne doit surtout pas être maquillé en
      // « code invalide » : le code saisi n'y est pour rien.
      final error = mapAuthError(
        serverError(401, {
          'code': 'E_UNAUTHORIZED_ACCESS',
          'message': 'Unauthorized access',
        }),
      );

      expect(error.code, AuthErrorCode.unknown);
      expect(error.code, isNot(AuthErrorCode.invalidCode));
    });

    test('un code serveur inconnu retombe sur unknown', () {
      final error = mapAuthError(
        serverError(500, {'code': 'E_INTERNAL', 'message': 'Boom'}),
      );

      expect(error.code, AuthErrorCode.unknown);
      expect(error.message, 'Boom');
    });

    test('un corps qui n\'est pas un objet ne fait pas planter le mapping', () {
      expect(mapAuthError(serverError(502, '<html>Bad gateway</html>')).code,
          AuthErrorCode.unknown);
      expect(mapAuthError(serverError(500, null)).code, AuthErrorCode.unknown);
    });
  });

  group('Coupure réseau → network, jamais unknown', () {
    test('timeouts et perte de connexion', () {
      const transportFailures = [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.connectionError,
        DioExceptionType.badCertificate,
        // Dio range ici certaines pannes bas niveau, sans réponse serveur.
        DioExceptionType.unknown,
      ];

      for (final type in transportFailures) {
        expect(
          mapAuthError(transportError(type)).code,
          AuthErrorCode.network,
          reason: '$type doit être vu comme une panne réseau',
        );
      }
    });

    test('une requête annulée n\'est pas une panne réseau', () {
      expect(
        mapAuthError(transportError(DioExceptionType.cancel)).code,
        AuthErrorCode.unknown,
      );
    });
  });

  group('retryAfter remonté jusqu\'à l\'UI', () {
    test('lu dans le corps de la réponse (secondes)', () {
      final error = mapAuthError(
        serverError(429, {
          'code': 'E_OTP_RATE_LIMITED',
          'message': 'Patientez avant de redemander un code.',
          'retryAfter': 42,
        }),
      );

      expect(error.retryAfter, const Duration(seconds: 42));
    });

    test('à défaut, lu dans l\'en-tête Retry-After', () {
      final error = mapAuthError(
        serverError(
          429,
          {'code': 'E_OTP_TOO_MANY_ATTEMPTS'},
          headers: {
            'retry-after': ['57'],
          },
        ),
      );

      expect(error.retryAfter, const Duration(seconds: 57));
    });

    test('le corps prime sur l\'en-tête', () {
      final error = mapAuthError(
        serverError(
          429,
          {'code': 'E_OTP_RATE_LIMITED', 'retryAfter': 30},
          headers: {
            'retry-after': ['999'],
          },
        ),
      );

      expect(error.retryAfter, const Duration(seconds: 30));
    });

    test('absent ou illisible → null (l\'UI garde son cooldown)', () {
      // Le serveur ne l'émet pas encore : le mapping doit rester silencieux.
      expect(
        mapAuthError(serverError(429, {'code': 'E_OTP_RATE_LIMITED'}))
            .retryAfter,
        isNull,
      );
      // `Retry-After` peut porter une date HTTP, qu'on ne sait pas lire.
      expect(
        mapAuthError(
          serverError(
            429,
            {'code': 'E_OTP_RATE_LIMITED'},
            headers: {
              'retry-after': ['Wed, 21 Oct 2026 07:28:00 GMT'],
            },
          ),
        ).retryAfter,
        isNull,
      );
      // Valeur négative : sans objet, on préfère ne rien annoncer.
      expect(
        mapAuthError(
          serverError(429, {'code': 'E_OTP_RATE_LIMITED', 'retryAfter': -5}),
        ).retryAfter,
        isNull,
      );
    });

    test('un décimal est arrondi à la seconde', () {
      final error = mapAuthError(
        serverError(429, {'code': 'E_OTP_RATE_LIMITED', 'retryAfter': 12.6}),
      );

      expect(error.retryAfter, const Duration(seconds: 13));
    });
  });
}
