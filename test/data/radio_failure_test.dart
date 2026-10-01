import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/radio/radio_failure.dart';

/// Les **trois** phrases du bouton d'antenne, et ce qui les départage.
///
/// Elles se jugent **ici**, sur des échecs construits à la main, plutôt qu'à
/// l'écran seul : un test d'écran prouve que la phrase arrive, celui-ci prouve
/// qu'elle est la bonne — et il le prouve sur les formes qu'un téléphone produit
/// vraiment, qu'aucun harnais ne sait fabriquer autrement.
///
/// ⚠️ **Les deux premiers groupes n'ont pas bougé avec #110, et c'est le point.**
/// La troisième phrase remplace le **repli** — « vérifiez votre connexion » faute
/// de mieux —, jamais l'un des deux cas que le fichier sait reconnaître. Les voir
/// rester verts est ce qui prouve que la règle de #104 tient.
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

    test('ExoPlayer nomme sa panne de transport en clair', () {
      // Les noms d'exceptions Java que `just_audio` recopie dans son message.
      // Ils comptent **depuis que le repli n'est plus « connexion »** : avant, une
      // coupure franche y tombait sans avoir besoin d'être reconnue ; désormais il
      // faut la reconnaître pour continuer à la nommer.
      const messages = [
        'PlayerException: (0) Source error: '
            'java.net.UnknownHostException: Unable to resolve host',
        'PlayerException: (0) Source error: java.net.ConnectException',
        'PlayerException: (0) Source error: java.net.SocketTimeoutException',
        'PlayerException: (0) Source error: javax.net.ssl.SSLHandshakeException',
      ];
      for (final message in messages) {
        expect(
          classifyRadioFailure(message),
          RadioFailureKind.connection,
          reason: message,
        );
      }
    });

    test('le délai du pré-vol, remonté nu', () {
      // `HttpRadioHandshakeResolver.resolve` borne la négociation par `.timeout`,
      // qui lève un `TimeoutException` — sans réponse, donc sans serveur qui ait
      // parlé.
      expect(
        classifyRadioFailure(TimeoutException('', const Duration(seconds: 5))),
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

  group('classifyRadioFailure — « écoute impossible »', () {
    // ⚠️ **Le troisième sens, et c'est le correctif.** Il ne remplace ni l'une ni
    // l'autre des deux phrases de #104 : les deux groupes ci-dessus le prouvent,
    // et c'est exprès qu'ils n'ont pas bougé. Il remplace le **repli**, qui
    // empruntait la voix de la connexion.
    test('la panne opaque d\'AVFoundation ne nomme pas le réseau', () {
      // Le message réel que rend AVPlayer : ni code HTTP, ni nom d'exception de
      // transport. C'est la forme sous laquelle un 401 sur une sous-playlist est
      // arrivé jusqu'au bouton le 2026-10-01, sur un iPhone **connecté**, et où il
      // s'affichait « Vérifiez votre connexion ».
      expect(
        classifyRadioFailure(
          'PlatformException(abort, The operation could not be completed, '
          'AVFoundationErrorDomain, -11800)',
        ),
        RadioFailureKind.unknown,
      );
    });

    test('un échec qu\'on ne sait pas nommer du tout', () {
      expect(
        classifyRadioFailure('PlatformException(abort, null, null, null)'),
        RadioFailureKind.unknown,
      );
    });
  });

  group('looksLikeTransportFailure — ce qu\'elle refuse de reconnaître', () {
    test('elle ne lit rien dans un domaine d\'erreur Apple', () {
      // ⚠️ **C'est un refus, pas un trou.** `-11800` recouvre indifféremment une
      // coupure réseau et un 401 sur une sous-playlist ; l'ajouter ici ferait dire
      // « vérifiez votre connexion » devant un refus du serveur, c'est-à-dire
      // réécrirait la panne que cette tranche corrige. La contrepartie est qu'une
      // coupure franche sur iPhone se dira « écoute impossible », et c'est le prix
      // honnête d'une information qu'on n'a pas.
      expect(
        looksLikeTransportFailure('AVFoundationErrorDomain, -11800'),
        isFalse,
      );
      expect(looksLikeTransportFailure('NSURLErrorDomain, -1009'), isFalse);
    });

    test('elle ne confond pas un mot voisin avec un nom d\'exception', () {
      expect(looksLikeTransportFailure('socket closed'), isFalse);
      expect(looksLikeTransportFailure('timeout'), isFalse);
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
