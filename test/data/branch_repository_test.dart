import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/core/network/api_client.dart';
import 'package:maison_du_miracle/data/repositories/branch_repository.dart';

import '../helpers/fake_api.dart';

void main() {
  late FakeAdapter adapter;
  late ApiClient api;
  late HttpBranchRepository repository;

  void serve(ResponseBody Function(RequestOptions options) reply) {
    adapter = FakeAdapter(reply);
    api.dio.httpClientAdapter = adapter;
  }

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    api = ApiClient.instance;
    repository = HttpBranchRepository(client: api);
    serve((_) => jsonReply(200, null));
  });

  test('interroge /sync/branches, sans `since` ni curseur', () async {
    serve(
      (_) => jsonReply(200, {
        'items': [
          {
            'id': 1,
            'name': 'Eglise Evangélique Nouvelle Vie Lomé',
            'address': 'Lomé',
            'isMotherChurch': true,
          },
        ],
        'next_cursor': 'MjAyNi0wNy0yOA==',
        'has_more': false,
        'full_resync': true,
      }),
    );

    final branches = await repository.branches();

    expect(adapter.lastRequest.method, 'GET');
    // Il n'y a **pas** de `GET /branches` : le référentiel est servi par le
    // module de synchronisation, et un endpoint doublon voudrait dire deux
    // chemins vers la même donnée.
    expect(adapter.lastRequest.path, '/sync/branches');
    // Jalon en cours : appel unique, sans paramètre de delta.
    expect(adapter.lastRequest.queryParameters, isEmpty);

    expect(branches, hasLength(1));
    expect(branches.single.id, 1);
    expect(branches.single.name, 'Eglise Evangélique Nouvelle Vie Lomé');
    expect(branches.single.isMotherChurch, isTrue);
    // `Branch.id` est un entier, comparable directement à `User.branchId`.
    expect(branches.single.id, isA<int>());
  });

  test('le curseur est ignoré : une seule requête part', () async {
    serve(
      (_) => jsonReply(200, {
        'items': const [],
        'next_cursor': 'page-suivante',
        // Même annoncée, la suite n'est pas demandée : le protocole delta
        // viendra avec la synchro complète, pas ici.
        'has_more': true,
        'full_resync': false,
      }),
    );

    await repository.branches();

    expect(adapter.requests, hasLength(1));
  });

  test('référentiel vide → liste vide, pas d\'erreur', () async {
    serve((_) => jsonReply(200, {'items': const [], 'has_more': false}));

    expect(await repository.branches(), isEmpty);
  });

  test('charge utile inattendue → liste vide plutôt qu\'un plantage', () async {
    serve((_) => jsonReply(200, {'has_more': false}));

    expect(await repository.branches(), isEmpty);
  });

  test('un serveur injoignable remonte l\'erreur à l\'appelant', () async {
    serve((options) => throw DioException.connectionError(
          requestOptions: options,
          reason: 'réseau coupé',
        ));

    // L'erreur n'est pas avalée ici : c'est l'`AsyncValue` du provider qui la
    // porte, et l'écran profil qui décide de rester utilisable.
    await expectLater(repository.branches(), throwsA(isA<DioException>()));
  });

  test('le mock sert la seule branche existante', () async {
    const mock = InMemoryBranchRepository();

    final branches = await mock.branches();

    expect(branches, hasLength(1));
    expect(branches.single.isMotherChurch, isTrue);
  });
}
