import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/core/network/api_client.dart';

void main() {
  group('URL de base du backend', () {
    test('vaut le backend local tant qu\'aucun --dart-define n\'est passé', () {
      // Les tests tournent sans `--dart-define` : c'est la valeur de repli qui
      // s'applique. Elle doit rester une URL de développement.
      expect(kBaseUrl, 'http://localhost:3333');
    });

    test('hors release, une URL en clair passe (dev local)', () {
      expect(kReleaseMode, isFalse);
      expect(ApiClient.ensureSecureBaseUrl, returnsNormally);
      expect(
        () => ApiClient.ensureSecureBaseUrl(url: 'http://192.168.1.20:3333'),
        returnsNormally,
      );
    });

    test('en release, une URL HTTPS passe', () {
      expect(
        () => ApiClient.ensureSecureBaseUrl(
          url: 'https://api.example.org',
          releaseMode: true,
        ),
        returnsNormally,
      );
    });

    test('en release, une URL en clair fait échouer le démarrage', () {
      for (final url in [
        'http://localhost:3333',
        'http://api.example.org',
        'HTTPS://api.example.org', // le schéma est sensible à la casse
        '',
      ]) {
        expect(
          () => ApiClient.ensureSecureBaseUrl(url: url, releaseMode: true),
          throwsA(isA<StateError>()),
          reason: 'attendu : refus de « $url » en release',
        );
      }
    });

    test('le message d\'erreur est explicite', () {
      Object? caught;
      try {
        ApiClient.ensureSecureBaseUrl(
          url: 'http://exemple.org',
          releaseMode: true,
        );
      } catch (e) {
        caught = e;
      }

      final message = caught.toString();
      expect(message, contains('API_BASE_URL'));
      expect(message, contains('HTTPS'));
      expect(message, contains('http://exemple.org'));
      expect(message, contains('--dart-define'));
    });
  });
}
