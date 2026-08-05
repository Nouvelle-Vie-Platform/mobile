import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/core/network/api_client.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/local/sync_dao.dart';
import 'package:maison_du_miracle/data/sync/sync_api.dart';
import 'package:maison_du_miracle/data/sync/sync_engine.dart';
import 'package:maison_du_miracle/data/sync/synced_collection.dart';

import '../data/local/local_database_fixtures.dart';
import '../helpers/fake_sync_server.dart';
import '../helpers/sync_fixtures.dart';

/// **Les formes que le vrai serveur ne sait pas provoquer**, servies par le
/// double et exercées de bout en bout.
///
/// Deux natures de tests ici :
///
/// 1. Ceux qui n'ont besoin que du **double** : ils prouvent que la boucle de
///    rattrapage, la coupure au milieu d'un cycle et le 404 de collection sont
///    réellement servis — pas seulement décrits.
/// 2. Ceux qui exercent le **moteur** (issue #29) contre le magasin local
///    (issue #26). Ils étaient `skip` avant que le moteur n'existe, et ils
///    formaient la définition de « fini » de #29 ; ils sont désormais levés.
///
/// Un seul intitulé a changé en les levant, et il est signalé sur place : « le
/// moteur **purge** le cache local » est devenu « le moteur **remplace** »,
/// parce qu'ADR-0026 interdit précisément de vider avant d'avoir reconstruit.
/// L'état final vérifié est le même ; le chemin, non — et un test qui exigeait
/// une purge aurait fait écrire le bug que l'ADR décrit.
void main() {
  late FakeSyncServer server;
  late Dio dio;
  late AppDatabase db;
  late SyncDao dao;

  setUp(() {
    server = FakeSyncServer();
    dio = Dio(BaseOptions(baseUrl: 'http://localhost:3333'))
      ..interceptors.add(unwrapEnvelopeInterceptor)
      ..httpClientAdapter = server;
    db = openTestDatabase();
    dao = db.syncDao;
  });

  tearDown(() => db.close());

  /// Le moteur, restreint aux collections que le scénario met en jeu et tiré à
  /// **`limit=1`** : à 200, une poignée de lignes ne produit jamais de seconde
  /// page, et la boucle de rattrapage ne serait pas exercée.
  SyncEngine engineOver(List<String> keys, {int limit = 1}) => SyncEngine(
        api: SyncApi(dio: dio),
        dao: dao,
        collections: syncedCollections()
            .where((collection) => keys.contains(collection.key))
            .toList(growable: false),
        pageLimit: limit,
      );

  Future<List<String>> teachingIds() async =>
      (await db.select(db.teachings).get()).map((row) => row.id).toList()
        ..sort();

  /// Les curseurs `since` réellement envoyés à une collection, dans l'ordre.
  List<String?> cursorsSentTo(String collection) => server
      .requestsFor(collection)
      .map((r) => r.queryParameters['since'] as String?)
      .toList(growable: false);

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

    // Intitulé d'origine : « le moteur **purge** le cache local et re-tire
    // depuis zéro ». Le verbe est corrigé, pas le test : ADR-0026 (décision 2,
    // invariant « un resync forcé se lit dans un 200 ») interdit explicitement
    // de vider d'abord — vider est une transaction, re-tirer en est N, et entre
    // les deux le magasin qui peint les écrans serait partiellement vide. Ce
    // qu'on vérifie ici est donc l'**état final** d'une purge, obtenu par un
    // remplacement : le test suivant vérifie qu'aucune purge n'a eu lieu.
    test('le moteur remplace le cache local et re-tire depuis zéro', () async {
      // Un catalogue déjà en magasin, à un curseur déjà avancé.
      await dao.applyPage(
        dao.teachingsCollection,
        upserts: [teachingRow('t-perimee'), teachingRow('t-autre')],
        cursor: teachingsCursorPage1,
      );

      server
        ..serveManifest(manifestNominal())
        ..servePages('teachings', [
          fullResyncPage(),
          deltaPage(
            items: const [fullTeachingPayload],
            nextCursor: teachingsCursorPage1,
          ),
        ]);

      final report = await engineOver(['teachings']).synchronize();

      expect(report.resynced, ['teachings']);
      // Ce que le re-tirage n'a pas revu a quitté le magasin — c'est le
      // balayage final, pas une purge initiale, qui l'a fait.
      expect(await teachingIds(), [fullTeachingPayload['id']]);
      expect(await dao.cursorFor(SyncCollectionKey.teachings),
          teachingsCursorPage1);
      expect(await dao.resyncToken(SyncCollectionKey.teachings), isNull);

      // Le premier tirage rejoue le curseur persisté ; le re-tirage repart
      // **sans `since`**. C'est ça, « depuis zéro ».
      expect(cursorsSentTo('teachings'), [teachingsCursorPage1, null]);
    });

    test(
        'le magasin n\'est jamais vidé d\'abord : une coupure en plein '
        'remplacement laisse l\'ancien catalogue intact', () async {
      await dao.applyPage(
        dao.teachingsCollection,
        upserts: [teachingRow('t-perimee'), teachingRow('t-autre')],
        cursor: teachingsCursorPage1,
      );

      server
        ..serveManifest(manifestNominal())
        ..servePages('teachings', [
          fullResyncPage(),
          deltaPage(
            items: const [fullTeachingPayload],
            nextCursor: teachingsCursorPage1,
            hasMore: true,
          ),
        ])
        ..cutConnectionOn('teachings');

      await expectLater(
        engineOver(['teachings']).synchronize(),
        throwsA(isA<DioException>()),
      );

      // Le fidèle était hors ligne avec son catalogue trente secondes plus
      // tôt : il l'a toujours, augmenté de ce que le re-tirage a déjà livré.
      expect(
        await teachingIds(),
        <String>['t-autre', 't-perimee', fullTeachingPayload['id']! as String]
          ..sort(),
      );
      // Ni le curseur ni la version de périmètre n'ont bougé, et le jeton
      // survit : le cycle recommencera entièrement.
      expect(await dao.cursorFor(SyncCollectionKey.teachings),
          teachingsCursorPage1);
      expect(await dao.readScopeVersion(), isNull);
      expect(await dao.resyncToken(SyncCollectionKey.teachings), isNotNull);
    });

    test(
        'le manifeste `full_resync_required` déclenche le resync des seules '
        'collections `branch`', () async {
      // Quatre collections déjà peuplées, chacune à son curseur.
      await dao.applyPage(dao.branchesCollection,
          upserts: [branchRow(99, 'Branche périmée')], cursor: 'c-branches');
      await dao.applyPage(dao.contributorsCollection,
          upserts: [contributorRow(99, 'Intervenant périmé')],
          cursor: 'c-contributors');
      await dao.applyPage(dao.teachingTypesCollection,
          upserts: [
            teachingTypeRow(99, label: const {'fr': 'Périmée'})
          ],
          cursor: 'c-teaching_types');
      await dao.applyPage(dao.teachingsCollection,
          upserts: [teachingRow('t-perimee')], cursor: 'c-teachings');

      // `manifestScopeChanged()` lève le drapeau sur les six collections
      // `branch` et sur aucun référentiel. Des quatre que ce client réplique,
      // seule `teachings` est `branch`.
      server
        ..serveManifest(manifestScopeChanged())
        ..serveCollection('teaching_types', teachingTypesPage())
        ..serveCollection('contributors', contributorsPage())
        ..serveCollection('branches', branchesPage())
        ..serveCollection(
          'teachings',
          deltaPage(
            items: const [fullTeachingPayload],
            nextCursor: teachingsCursorPage1,
          ),
        );

      final report = await engineOver([
        'teaching_types',
        'contributors',
        'branches',
        'teachings',
      ]).synchronize();

      expect(report.resynced, ['teachings']);
      expect(report.pulled, ['teaching_types', 'contributors', 'branches']);

      // Le resync repart sans `since` ; les référentiels rejouent le leur.
      expect(cursorsSentTo('teachings'), [null]);
      expect(cursorsSentTo('branches'), ['c-branches']);
      expect(cursorsSentTo('contributors'), ['c-contributors']);
      expect(cursorsSentTo('teaching_types'), ['c-teaching_types']);

      // Seule la collection resynchronisée a balayé ce que le cycle n'a pas
      // revu. Un référentiel en régime delta ne supprime **jamais** de sa
      // propre initiative : sa ligne périmée est toujours là.
      expect(await teachingIds(), [fullTeachingPayload['id']]);
      expect(
        (await db.select(db.branches).get()).map((r) => r.id),
        containsAll(<int>[99, 1, 3]),
      );
      expect(
        (await db.select(db.contributors).get()).map((r) => r.id),
        contains(99),
      );
      expect(
        (await db.select(db.teachingTypes).get()).map((r) => r.id),
        contains(99),
      );
    });

    test('la `scope_version` n\'est retenue qu\'après application du manifeste',
        () async {
      // Trois manifestes successifs : nominal en 4 ; la Home Branch change et
      // la version courante passe à 5 en réclamant le resync des `branch` ;
      // puis plus rien à tirer, toujours en 5.
      server.serveManifests(manifestScopeVersionProgression());
      server
        // Cycle 1 — régime delta.
        ..serveCollection(
          'teachings',
          deltaPage(
            items: const [fullTeachingPayload],
            nextCursor: teachingsCursorPage1,
          ),
        )
        // Cycle 2 — le resync commence…
        ..serveCollection(
          'teachings',
          deltaPage(
            items: const [teachingWithoutPlaylistPayload],
            nextCursor: teachingsCursorPage2,
            hasMore: true,
          ),
        )
        // … et la connexion tombe avant `has_more: false`.
        ..cutConnectionOn('teachings')
        // Cycle 3 — le resync est rejoué, et va au bout.
        ..serveCollection(
          'teachings',
          deltaPage(
            items: const [teachingWithoutColorPayload],
            nextCursor: teachingsCursorPage3,
          ),
        );

      // Cycle 1 : la version 4 est appliquée jusqu'au bout, donc retenue.
      await engineOver(['teachings']).synchronize();
      expect(await dao.readScopeVersion(), 4);

      // Cycle 2 : le resync est interrompu. **Rien** n'est persisté.
      await expectLater(
        engineOver(['teachings']).synchronize(),
        throwsA(isA<DioException>()),
      );
      expect(
        await dao.readScopeVersion(),
        4,
        reason: 'retenir 5 ici éteindrait un resync qui n\'a pas eu lieu, et '
            'le manifeste ne le redemanderait jamais',
      );
      expect(await dao.resyncToken(SyncCollectionKey.teachings), isNotNull);

      // Cycle 3 : le resync se rejoue et se termine ; **alors** 5 est retenue.
      await engineOver(['teachings']).synchronize();
      expect(await dao.readScopeVersion(), 5);
      expect(await dao.resyncToken(SyncCollectionKey.teachings), isNull);
      expect(await teachingIds(), [teachingWithoutColorPayload['id']]);

      // La preuve côté fil : le troisième manifeste présente encore **4**. Un
      // client qui aurait retenu trop tôt aurait présenté 5 et le serveur
      // n'aurait plus jamais réclamé le resync.
      expect(
        server.manifestRequests
            .map((r) => r.queryParameters['scope_version'])
            .toList(growable: false),
        [null, 4, 4],
      );
    });
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
        'le moteur retire du magasin les lignes rétractées et insère les '
        'autres', () async {
      // Les deux lignes que la page va rétracter sont déjà en magasin — sans
      // quoi le test ne prouverait rien : supprimer ce qui n'existe pas est
      // gratuit.
      await dao.applyPage(
        dao.teachingsCollection,
        upserts: [
          teachingRow(retractedTeachingPayload['id']! as String),
          teachingRow(otherRetractedTeachingPayload['id']! as String),
          teachingRow('t-que-le-serveur-n-a-pas-mentionnee'),
        ],
        cursor: teachingsCursorPage1,
      );

      server
        ..serveManifest(manifestNominal())
        ..serveCollection('teachings', mixedTeachingsPage());

      final report = await engineOver(['teachings']).synchronize();

      expect(report.pulled, ['teachings']);
      expect(
        await teachingIds(),
        <String>[
          fullTeachingPayload['id']! as String,
          teachingWithoutPlaylistPayload['id']! as String,
          teachingWithoutColorPayload['id']! as String,
          't-que-le-serveur-n-a-pas-mentionnee',
        ]..sort(),
        reason: 'les trois enseignements complets sont écrits, les deux '
            'rétractations quittent le magasin, et ce dont le serveur n\'a '
            'rien dit **reste** — le client n\'efface jamais de sa propre '
            'initiative une ligne d\'une collection répliquée',
      );

      // Et les lignes complètes, elles, ont bien été construites — la page
      // mixte n'a pas été rejetée en bloc par un désérialiseur qui aurait levé
      // sur la rétractation en deuxième position.
      final applied = await (db.select(db.teachings)
            ..where((t) => t.id.equals(fullTeachingPayload['id']! as String)))
          .getSingle();
      expect(applied.title, fullTeachingPayload['title']);
      expect(applied.recordedAt, fullTeachingPayload['recordedAt']);

      // La page appliquée a validé ses lignes **et** son curseur.
      expect(await dao.cursorFor(SyncCollectionKey.teachings),
          teachingsCursorPage3);
    });
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
        'le moteur saute la collection inconnue et termine sa '
        'synchronisation', () async {
      // `contributors` n'est **pas enregistrée** sur ce double : elle répond
      // 404, exactement comme le registre serveur le fera de `gatherings` le
      // jour où le mobile la demandera avant que le serveur ne l'ajoute
      // ([kUnregisteredCollection]). Les trois autres répondent normalement.
      server
        ..serveManifest(manifestNominal())
        ..serveCollection('teaching_types', teachingTypesPage())
        ..serveCollection('branches', branchesPage())
        ..serveCollection('teachings', mixedTeachingsPage());

      final report = await engineOver([
        'teaching_types',
        'contributors',
        'branches',
        'teachings',
      ]).synchronize();

      expect(report.skipped, ['contributors']);
      expect(report.pulled, ['teaching_types', 'branches', 'teachings']);

      // La synchronisation est allée **au bout** : la version de périmètre est
      // retenue, et les collections postérieures à la sautée ont été tirées.
      expect(report.scopeVersion, 4);
      expect(await dao.readScopeVersion(), 4);
      expect(await teachingIds(), hasLength(3));
      expect(await db.select(db.branches).get(), hasLength(2));
      expect(await db.select(db.teachingTypes).get(), hasLength(3));

      // Rien n'a été écrit pour la collection sautée — pas même un curseur.
      expect(await dao.cursorFor(SyncCollectionKey.contributors), isNull);
    });
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

    /// **Le cas s'est produit contre le vrai serveur** (issue #31, sur
    /// `branches`) : le curseur composé encode `updated_at` en
    /// **millisecondes** alors que PostgreSQL stocke des **microsecondes**, si
    /// bien qu'une ligne à `…089887` satisfait sa propre borne keyset
    /// (`…089887 > …089`) et revient à chaque page. Le serveur annonçait
    /// `has_more` en resservant le même curseur, indéfiniment.
    ///
    /// Le garde-fou du moteur a fait exactement son travail — et n'était
    /// couvert par aucun test. Il l'est ici, dans les deux régimes : c'est la
    /// seule chose qui sépare un défaut serveur visible d'une application qui
    /// tourne en rond jusqu'à épuiser la batterie.
    test(
        'un serveur qui redemande le même curseur en annonçant `has_more` '
        'arrête la boucle au lieu de tourner sans fin', () async {
      server
        ..serveManifest(manifestNominal())
        ..serveCollection(
          'teachings',
          deltaPage(
            items: const [fullTeachingPayload],
            nextCursor: teachingsCursorPage1,
            hasMore: true,
          ),
        );

      await expectLater(
        engineOver(['teachings']).synchronize(),
        throwsA(isA<SyncStalled>()),
      );

      // Deux requêtes, pas mille : le moteur s'arrête au premier curseur
      // rejoué à l'identique.
      expect(server.requestsFor('teachings'), hasLength(2));
      expect(
        await dao.readScopeVersion(),
        isNull,
        reason: 'Un cycle qui lève ne persiste aucune version.',
      );
    });

    test(
        'même arrêt pendant un resync de périmètre, où la boucle est ouverte '
        'depuis zéro', () async {
      server
        ..serveManifest(manifestScopeChanged())
        ..serveCollection(
          'teachings',
          deltaPage(
            items: const [fullTeachingPayload],
            nextCursor: teachingsCursorPage1,
            hasMore: true,
          ),
        );

      await expectLater(
        engineOver(['teachings']).synchronize(),
        throwsA(isA<SyncStalled>()),
      );

      expect(server.requestsFor('teachings'), hasLength(2));
      expect(
        await dao.resyncToken(SyncCollectionKey.teachings),
        isNotNull,
        reason: 'Le remplacement reste ouvert : le cycle suivant le rejoue.',
      );
      expect(await dao.readScopeVersion(), isNull);
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
        'rien n\'est validé à moitié : ni le curseur, ni les lignes de la '
        'page N', () async {
      // La deuxième page du scénario à `limit=1` est une **rétractation** :
      // c'est la forme la plus coûteuse à perdre. Si son curseur avançait sans
      // que la suppression ait eu lieu, le keyset ne repasserait jamais
      // derrière la borne et la ligne resterait au magasin pour toujours.
      await dao.applyPage(
        dao.teachingsCollection,
        upserts: [teachingRow(retractedTeachingPayload['id']! as String)],
        cursor: null,
      );

      server
        ..serveManifest(manifestNominal())
        ..servePages('teachings', teachingsPagesAtLimitOne());

      // La panne frappe **à l'intérieur** de la transaction de la page 2, entre
      // l'écriture de ses lignes et celle de son curseur — l'instant précis que
      // l'invariant protège, et le seul qu'une coupure réseau ne sait pas
      // produire.
      var pages = 0;
      dao.crashBetweenRowsAndCursor = () async {
        if (++pages == 2) throw const _Coupure();
      };

      await expectLater(
        engineOver(['teachings']).synchronize(),
        throwsA(isA<_Coupure>()),
      );

      // La page 1, elle, a été validée entière : sa ligne **et** son curseur.
      expect(
        await teachingIds(),
        <String>[
          fullTeachingPayload['id']! as String,
          retractedTeachingPayload['id']! as String,
        ]..sort(),
        reason: 'la rétractation de la page 2 a été annulée avec sa '
            'transaction : la ligne est toujours là, et elle sera relivrée',
      );
      expect(
        await dao.cursorFor(SyncCollectionKey.teachings),
        teachingsCursorPage1,
        reason: 'le curseur s\'arrête à la dernière page réellement appliquée',
      );
      // Et la version de périmètre n'a rien retenu du cycle interrompu.
      expect(await dao.readScopeVersion(), isNull);
    });

    test(
        'le cycle interrompu est rejoué au tour suivant depuis le dernier '
        'curseur validé', () async {
      final pages = teachingsPagesAtLimitOne();

      server.serveManifest(manifestNominal());
      server
        // Premier cycle : la page 1 passe, la page 2 tombe.
        ..serveCollection('teachings', pages[0])
        ..cutConnectionOn('teachings')
        // Second cycle : le serveur reprend là où le client s'était arrêté.
        ..serveCollection('teachings', pages[1])
        ..serveCollection('teachings', pages[2]);

      await expectLater(
        engineOver(['teachings']).synchronize(),
        throwsA(isA<DioException>()),
      );
      expect(await dao.cursorFor(SyncCollectionKey.teachings),
          teachingsCursorPage1);
      expect(await dao.readScopeVersion(), isNull);

      final report = await engineOver(['teachings']).synchronize();

      expect(report.pages, 2, reason: 'deux pages restaient à appliquer');
      expect(await dao.cursorFor(SyncCollectionKey.teachings),
          teachingsCursorPage3);
      expect(await dao.readScopeVersion(), 4);
      expect(
          await teachingIds(),
          <String>[
            fullTeachingPayload['id']! as String,
            teachingWithoutColorPayload['id']! as String,
          ]..sort());

      // La preuve : le second cycle **repart du dernier curseur validé**, ni
      // de zéro (tout serait retiré) ni du curseur de la page perdue (elle ne
      // serait jamais appliquée).
      expect(cursorsSentTo('teachings'), [
        null,
        teachingsCursorPage1,
        teachingsCursorPage1,
        teachingsCursorPage2,
      ]);
    });
  });
}

/// Panne provoquée **à l'intérieur** d'une transaction du magasin : ce qu'une
/// mort de processus fait entre l'écriture des lignes d'une page et celle de
/// son curseur. Aucune coupure réseau ne sait produire cet instant-là.
class _Coupure implements Exception {
  const _Coupure();
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
