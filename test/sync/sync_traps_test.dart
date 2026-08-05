import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/core/network/api_client.dart';

import '../helpers/fake_sync_server.dart';
import '../helpers/sync_fixtures.dart';

/// **Les formes que le vrai serveur ne sait pas provoquer**, servies par le
/// double et exercées de bout en bout.
///
/// Deux natures de tests ici :
///
/// 1. Ceux qui **passent aujourd'hui** : ils n'ont besoin que du double. Ils
///    prouvent que la boucle de rattrapage, la coupure au milieu d'un cycle et
///    le 404 de collection sont réellement servis — pas seulement décrits.
/// 2. Ceux qui sont **`skip`** : ils exigent le magasin local (issue #26) ou le
///    moteur de synchronisation (issue #29), qui n'existent pas encore. Ils
///    sont écrits maintenant, avec leur raison en clair, et forment la
///    **définition de « fini »** de #29 : le jour où le moteur existe, il
///    suffit de retirer le `skip`.
void main() {
  late FakeSyncServer server;
  late Dio dio;

  setUp(() {
    server = FakeSyncServer();
    dio = Dio(BaseOptions(baseUrl: 'http://localhost:3333'))
      ..interceptors.add(unwrapEnvelopeInterceptor)
      ..httpClientAdapter = server;
  });

  group('Piège n°1 — un resync forcé se lit dans un 200', () {
    test('le corps ne porte aucune marque d\'erreur', () async {
      server.serveCollection('teachings', fullResyncPage());

      final res = await dio.get<dynamic>('/sync/teachings');
      final page = res.data as Map;

      expect(res.statusCode, 200);
      expect(page['full_resync'], isTrue);
      // Ce qu'un client pressé verrait : rien. C'est tout le piège — `items`
      // vide et `has_more` faux ressemblent trait pour trait à « rien de neuf ».
      expect(page['items'], isEmpty);
      expect(page['has_more'], isFalse);
    });

    test(
        '« rien de neuf » et « repars de zéro » ne diffèrent que d\'un drapeau',
        () async {
      server
        ..serveCollection('teachings', fullResyncPage())
        ..serveCollection(
            'events', emptyPageKeepingCursor(teachingsCursorPage2));

      final resync = (await dio.get<dynamic>('/sync/teachings')).data as Map;
      final nothing = (await dio.get<dynamic>('/sync/events')).data as Map;

      expect(resync['items'], nothing['items']);
      expect(resync['has_more'], nothing['has_more']);
      // Seuls `full_resync` et `next_cursor` les séparent. Un client qui ne lit
      // que `items` garde indéfiniment un cache dont il a raté des
      // suppressions, et rien ne le réveillera.
      expect(resync['full_resync'], isNot(nothing['full_resync']));
      expect(resync['next_cursor'], isNull);
      expect(nothing['next_cursor'], isNotNull);
    });

    test(
      'le moteur purge le cache local et re-tire depuis zéro',
      () {},
      skip: 'Moteur de synchronisation — issue #29 (et magasin local #26). '
          'Le double sert déjà la forme (`fullResyncPage`) ; ce qui manque est '
          'le code qui la lit : purger la collection, oublier le curseur, '
          'relancer un tirage sans `since`.',
    );

    test(
      'le manifeste `full_resync_required` déclenche le resync des seules '
      'collections `branch`',
      () {},
      skip: 'Moteur de synchronisation — issue #29. Fixtures prêtes : '
          '`manifestScopeChanged()` lève le drapeau sur les six collections '
          '`branch` et sur aucun référentiel.',
    );

    test(
      'la `scope_version` n\'est retenue qu\'après application du manifeste',
      () {},
      skip: 'Moteur de synchronisation — issue #29 (ADR-0027). Fixture prête : '
          '`manifestScopeVersionProgression()`. Retenir la version avant '
          'd\'avoir appliqué le resync le perd définitivement si le cycle est '
          'interrompu.',
    );
  });

  group('Piège n°2 — rétractation ou ligne, décidé avant toute construction',
      () {
    test('la page mixte arrive telle quelle, sans regroupement', () async {
      server.serveCollection('teachings', mixedTeachingsPage());

      final page = (await dio.get<dynamic>('/sync/teachings')).data as Map;
      final items = (page['items']! as List).cast<Map<String, dynamic>>();

      expect(items, hasLength(5));
      // Le serveur trie sur `(updated_at, id)` : les deux natures sont
      // entrelacées, jamais séparées en deux tableaux.
      expect(items[1].containsKey('deletedAt'), isTrue);
      expect(items[2].containsKey('title'), isTrue);
    });

    test('un désérialiseur strict lèverait sur la première rétractation',
        () async {
      server.serveCollection('teachings', mixedTeachingsPage());

      final page = (await dio.get<dynamic>('/sync/teachings')).data as Map;
      final items = (page['items']! as List).cast<Map<String, dynamic>>();

      // Ce que ferait un `fromJson` qui exige `title` : on le simule ici pour
      // que le coût du raccourci soit visible dans la suite de tests, et non
      // découvert sur un téléphone.
      expect(
        () => items.map((i) => i['title']! as String).toList(),
        throwsA(isA<TypeError>()),
      );
    });

    test(
      'le moteur retire du magasin les lignes rétractées et insère les autres',
      () {},
      skip: 'Magasin local (#26) + moteur (#29). Fixture prête : '
          '`mixedTeachingsPage()` — trois enseignements complets et deux '
          'rétractations, dont une en dernière position.',
    );
  });

  group('Piège n°3 — un 404 de collection n\'est pas fatal', () {
    test('la clé inconnue répond 404, les autres continuent de répondre',
        () async {
      server
        ..serveCollection('teachings', mixedTeachingsPage())
        ..serveCollection('branches', branchesPage());

      final error = await _errorOf(
        () => dio.get<dynamic>('/sync/$kUnregisteredCollection'),
      );
      expect(error.response?.statusCode, 404);

      // Le serveur n'est pas tombé : la collection suivante répond.
      final page = (await dio.get<dynamic>('/sync/branches')).data as Map;
      expect(page['items'], hasLength(2));
    });

    test(
      'le moteur saute la collection inconnue et termine sa synchronisation',
      () {},
      skip: 'Moteur de synchronisation — issue #29. Le mobile demandera un '
          'jour `gatherings` (rassemblements, PRD §5 sexies) avant que le '
          'serveur ne l\'enregistre : un 404 doit coûter une collection '
          'sautée, pas une synchronisation échouée.',
    );
  });

  group('La boucle de pagination, exercée pour de vrai', () {
    test('trois pages à `limit=1`, chaque curseur rejoué tel quel', () async {
      server.servePages('teachings', teachingsPagesAtLimitOne());

      // Boucle minimale — volontairement écrite ici et non dans `lib/` : c'est
      // le moteur (#29) qui portera la vraie. Elle suffit à prouver que le
      // double sert bien une suite de pages, ce que le vrai serveur ne fera
      // jamais à `limit=200` sur une poignée de lignes.
      final collected = <Map<String, dynamic>>[];
      String? cursor;
      var hasMore = true;
      while (hasMore) {
        final res = await dio.get<dynamic>(
          '/sync/teachings',
          queryParameters: {if (cursor != null) 'since': cursor, 'limit': 1},
        );
        final page = res.data as Map;
        collected.addAll((page['items']! as List).cast<Map<String, dynamic>>());
        cursor = page['next_cursor'] as String?;
        hasMore = page['has_more'] as bool;
      }

      expect(collected, hasLength(3));
      expect(server.requestsFor('teachings'), hasLength(3));

      // Le premier tour part sans `since` ; les suivants rejouent le curseur
      // **reçu**, jamais un curseur fabriqué (ADR-0026).
      final sent = server
          .requestsFor('teachings')
          .map((r) => r.queryParameters['since'])
          .toList(growable: false);
      expect(sent, [null, teachingsCursorPage1, teachingsCursorPage2]);
      expect(cursor, teachingsCursorPage3);
    });
  });

  group('Une coupure au milieu d\'un cycle', () {
    test('la page N arrive, la page N+1 lève sans réponse', () async {
      server
        ..serveCollection(
          'teachings',
          deltaPage(
            items: const [fullTeachingPayload],
            nextCursor: teachingsCursorPage1,
            hasMore: true,
          ),
        )
        ..cutConnectionOn('teachings');

      final first = (await dio.get<dynamic>('/sync/teachings')).data as Map;
      expect(first['items'], hasLength(1));

      final error = await _errorOf(
        () => dio.get<dynamic>(
          '/sync/teachings',
          queryParameters: {'since': first['next_cursor'], 'limit': 1},
        ),
      );

      expect(error.type, DioExceptionType.connectionError);
      expect(error.response, isNull);
    });

    test(
      'rien n\'est validé à moitié : ni le curseur, ni les lignes de la page N',
      () {},
      skip: 'Magasin local (#26) + moteur (#29). Le double sait couper '
          '(`cutConnectionOn`) ; ce qui manque est la transaction qui rend le '
          'cycle atomique. Sans elle, le curseur avancerait sur une page dont '
          'les lignes n\'ont pas été écrites — des suppressions perdues pour '
          'de bon.',
    );

    test(
      'le cycle interrompu est rejoué au tour suivant depuis le dernier '
      'curseur validé',
      () {},
      skip: 'Moteur de synchronisation — issue #29.',
    );
  });
}

/// Exécute [call] et rend la [DioException] attendue.
Future<DioException> _errorOf(Future<void> Function() call) async {
  try {
    await call();
  } on DioException catch (e) {
    return e;
  }
  fail('la requête aurait dû échouer');
}
