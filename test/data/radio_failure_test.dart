import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/radio/radio_failure.dart';

/// Les deux phrases du bouton d'antenne, et ce qui les départage.
///
/// Elles se jugent **ici**, sur des échecs construits à la main, plutôt qu'à
/// l'écran seul : un test d'écran prouve que la phrase arrive, celui-ci prouve
/// qu'elle est la bonne — et il le prouve sur les formes qu'un téléphone produit
/// vraiment, qu'aucun harnais ne sait fabriquer autrement.
void main() {
  final request = RequestOptions(path: '/radio/antenna');

  group('classifyRadioFailure — « vérifiez votre connexion »', () {
    test('personne n\'a répondu : DNS, socket, TLS', () {
      expect(
        classifyRadioFailure(
          DioException(
            requestOptions: request,
            type: DioExceptionType.connectionError,
            error: const SocketException('Failed host lookup'),
          ),
        ),
        RadioFailureKind.connection,
      );
    });

    test('délai dépassé', () {
      for (final type in const [
        DioExceptionType.connectionTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.sendTimeout,
      ]) {
        expect(
          classifyRadioFailure(
            DioException(requestOptions: request, type: type),
          ),
          RadioFailureKind.connection,
          reason: '$type',
        );
      }
    });

    test('une socket nue, hors de Dio', () {
      expect(
        classifyRadioFailure(const SocketException('Connection refused')),
        RadioFailureKind.connection,
      );
    });

    test('un échec qu\'on ne sait pas nommer penche de ce côté-ci', () {
      // Et c'est délibéré : « vérifiez votre connexion » invite à un geste utile,
      // là où « antenne indisponible » **affirmerait** une panne de l'église dont
      // on n'a aucune preuve. Le chemin du lecteur n'a pas pu être mesuré sur
      // appareil — le bloc Caddy de MediaMTX n'est pas posé (`context#6`).
      expect(
        classifyRadioFailure('PlatformException(abort, null, null, null)'),
        RadioFailureKind.connection,
      );
    });
  });

  group('classifyRadioFailure — « antenne indisponible »', () {
    test('le serveur a répondu, quel que soit le statut', () {
      for (final status in const [401, 404, 500]) {
        expect(
          classifyRadioFailure(
            DioException(
              requestOptions: request,
              type: DioExceptionType.badResponse,
              response: Response<Object?>(
                requestOptions: request,
                statusCode: status,
                data: const {'error': 'session not found'},
              ),
            ),
          ),
          RadioFailureKind.antenna,
          reason: '$status',
        );
      }
    });

    test('un statut écrit en clair par la plateforme audio', () {
      // Les deux chaînes que les deux moteurs natifs produisent. On ne peut pas
      // reconnaître la panne par son **type** : `PlayerException` appartient à
      // `just_audio`, qu'aucun autre fichier de `lib/` n'a le droit d'importer.
      expect(
        classifyRadioFailure(
          'PlayerException: (0) Source error: Response code: 401',
        ),
        RadioFailureKind.antenna,
      );
      expect(
        classifyRadioFailure(
          'The operation could not be completed. '
          'Server returned a status code of 404',
        ),
        RadioFailureKind.antenna,
      );
    });

    test('une page HTML là où on attend une playlist', () {
      expect(
        classifyRadioFailure('<!DOCTYPE html><html><body>404</body></html>'),
        RadioFailureKind.antenna,
      );
    });
  });

  group('radioStatusCodeIn — étroit exprès', () {
    test('trouve un statut annoncé comme tel', () {
      expect(radioStatusCodeIn('server replied with code 401: nope'), 401);
      expect(radioStatusCodeIn('Response code: 404'), 404);
      expect(radioStatusCodeIn('status code of 503'), 503);
    });

    test('ignore un nombre qui n\'est pas un statut', () {
      // Sans cette étroitesse, un code d'erreur natif ou un numéro de ligne
      // ferait dire « antenne indisponible » devant une coupure réseau.
      expect(radioStatusCodeIn('PlatformException(-11800, null)'), isNull);
      expect(radioStatusCodeIn('au bout de 404 secondes'), isNull);
      expect(radioStatusCodeIn('code 42'), isNull);
      expect(radioStatusCodeIn('code 700'), isNull);
    });
  });
}
