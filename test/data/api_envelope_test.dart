import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/core/network/api_client.dart';

/// Fait passer un corps de réponse dans [unwrapEnvelopeInterceptor] et rend le
/// `data` tel que le verrait un repository.
///
/// Aucun réseau : l'intercepteur est invoqué directement (`flutter test` répond
/// 400 à tout accès réseau réel).
Object? throughInterceptor(Object? body) {
  final response = Response<dynamic>(
    requestOptions: RequestOptions(path: '/peu-importe'),
    data: body,
  );
  unwrapEnvelopeInterceptor.onResponse(response, ResponseInterceptorHandler());
  return response.data;
}

void main() {
  group('Déballage de l\'enveloppe `data`', () {
    test('une réponse enveloppée arrive à plat', () {
      final data = throughInterceptor({
        'data': {'id': 'u_1', 'email': 'jean@example.org'},
      });

      expect(data, isA<Map>());
      expect((data! as Map)['id'], 'u_1');
      expect((data as Map)['email'], 'jean@example.org');
    });

    test('une réponse déjà à plat n\'est pas altérée', () {
      final body = {'id': 'u_1', 'profileComplete': true};

      expect(throughInterceptor(body), same(body));
    });

    test('une réponse paginée {data, meta} n\'est pas altérée', () {
      final body = {
        'data': [
          {'id': 1},
          {'id': 2},
        ],
        'meta': {'total': 2},
      };

      final data = throughInterceptor(body);

      expect(data, same(body));
      expect((data! as Map)['meta'], isNotNull);
    });

    test('une enveloppe contenant une liste est déballée', () {
      final data = throughInterceptor({
        'data': [
          {'id': 1},
        ],
      });

      expect(data, isA<List>());
      expect((data! as List).length, 1);
    });

    test('une enveloppe de valeur nulle est déballée', () {
      expect(throughInterceptor({'data': null}), isNull);
    });

    test('un corps non-Map traverse sans dommage', () {
      expect(throughInterceptor('texte brut'), 'texte brut');
      expect(throughInterceptor(null), isNull);
    });

    test('une clé unique autre que `data` n\'est pas déballée', () {
      final body = {
        'items': [
          {'id': 1},
        ],
      };

      expect(throughInterceptor(body), same(body));
    });
  });
}
