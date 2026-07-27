import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/core/network/api_client.dart';

/// Fabrique une [DioException] portant le statut HTTP voulu
/// (`null` = erreur réseau, sans réponse du serveur).
DioException errorWithStatus(int? status) {
  final options = RequestOptions(path: '/peu-importe');
  return DioException(
    requestOptions: options,
    response: status == null
        ? null
        : Response<dynamic>(requestOptions: options, statusCode: status),
    type: status == null
        ? DioExceptionType.connectionError
        : DioExceptionType.badResponse,
  );
}

/// Handler d'erreur qui note ce qu'on lui transmet.
///
/// On n'appelle pas `super.next` : le vrai handler complète un `Completer` en
/// erreur, que personne n'écoute hors d'une requête Dio réelle.
class RecordingHandler extends ErrorInterceptorHandler {
  DioException? forwarded;

  @override
  void next(DioException err) => forwarded = err;
}

void main() {
  group('Intercepteur 401 global', () {
    late int reactions;
    late UnauthorizedInterceptor interceptor;

    setUp(() {
      reactions = 0;
      interceptor = UnauthorizedInterceptor(() async => reactions++);
    });

    test('un 401 déclenche la réaction (purge + retour à /auth)', () async {
      await interceptor.onError(errorWithStatus(401), RecordingHandler());

      expect(reactions, 1);
    });

    test('les autres statuts ne déclenchent rien', () async {
      for (final status in [400, 403, 404, 422, 429, 500]) {
        await interceptor.onError(errorWithStatus(status), RecordingHandler());
      }

      expect(reactions, 0);
    });

    test('une erreur réseau (sans réponse) ne déclenche rien', () async {
      await interceptor.onError(errorWithStatus(null), RecordingHandler());

      expect(reactions, 0);
    });

    test('l\'erreur 401 continue sa route vers l\'appelant', () async {
      final handler = RecordingHandler();

      await interceptor.onError(errorWithStatus(401), handler);

      // L'appel en cours doit quand même échouer : l'intercepteur décide du
      // sort du token, pas de celui de la requête.
      expect(handler.forwarded?.response?.statusCode, 401);
    });
  });
}
