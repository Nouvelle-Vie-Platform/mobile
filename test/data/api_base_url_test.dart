import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/core/network/api_client.dart';

void main() {
  group('URL de base du backend', () {
    test('vaut le serveur de l\'église tant qu\'aucun --dart-define n\'est passé',
        () {
      // Les tests tournent sans `--dart-define` : c'est la valeur de repli qui
      // s'applique. Elle **n'est plus une URL de développement** — le repli
      // pointe désormais la production, en HTTPS, ce qui est aussi ce qui le
      // rend acceptable en release. Un `--dart-define=API_BASE_URL=…` reste le
      // chemin pour viser un backend local.
      expect(kBaseUrl, 'https://eenv.brainsial.com');
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
        // Le repli de développement en est une : `kBaseUrl` est HTTPS depuis
        // qu'il pointe le serveur de l'église, mais c'est le **schéma** qui est
        // jugé ici, pas l'hôte — et une URL en clair doit rester refusée.
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
