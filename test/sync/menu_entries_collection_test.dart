/// **La collection `menu_entries`, de bout en bout** (#82).
///
/// Ce que ce fichier vérifie n'est pas l'affichage — c'est le **voyage** : que le
/// menu réglé au portail arrive, qu'il arrive **avant les listes qu'il
/// intitule**, que les trente et une clés traversent sans se perdre, qu'un
/// serveur qui ne connaît pas encore la collection ne coûte **rien**, et qu'une
/// sous-entrée orpheline ne fait pas échouer la page qui la portait.
///
/// Les DAO s'écrivent ici par le **moteur**, jamais par un insert nu : c'est la
/// seule façon de prouver que la forme servie par le serveur traverse réellement
/// `sync_rows.dart` et le magasin.
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/core/network/api_client.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/local/sync_dao.dart';
import 'package:maison_du_miracle/data/sync/branch_filter.dart';
import 'package:maison_du_miracle/data/sync/sync_api.dart';
import 'package:maison_du_miracle/data/sync/sync_engine.dart';
import 'package:maison_du_miracle/data/sync/synced_collection.dart';

import '../data/local/local_database_fixtures.dart';
import '../helpers/fake_sync_server.dart';
import '../helpers/sync_fixtures.dart';

void main() {
  late FakeSyncServer server;
  late Dio dio;
  late AppDatabase db;
  late SyncDao dao;

  setUp(() {
    server = FakeSyncServer();
    dio = Dio(BaseOptions(baseUrl: 'https://eenv.brainsial.com'))
      ..interceptors.add(unwrapEnvelopeInterceptor)
      ..httpClientAdapter = server;
    db = openTestDatabase();
    dao = db.syncDao;
  });

  tearDown(() => db.close());

  /// Le manifeste de la seule collection qui nous intéresse, `partition:
  /// 'reference'` — un menu n'appartient à aucune branche.
  Map<String, Object?> menuManifest() => {
        'scope_version': 1,
        'collections': [
          manifestEntry(
            SyncCollectionKey.menuEntries,
            partition: 'reference',
            currentCursor: menuEntriesCursor,
            hasChanges: true,
            fromZero: true,
          ),
        ],
      };

  SyncEngine engine({
    List<String>? only,
    Future<int?> Function()? branchId,
  }) =>
      SyncEngine(
        api: SyncApi(dio: dio),
        dao: dao,
        collections: syncedCollections()
            .where((c) =>
                only?.contains(c.key) ?? c.key == SyncCollectionKey.menuEntries)
            .toList(growable: false),
        branchId: branchId,
      );

  group('Le registre', () {
    test('la collection est là, rangée avant tout contenu', () {
      final keys = syncedCollections().map((c) => c.key).toList();

      expect(keys, contains(SyncCollectionKey.menuEntries));
      // Un menu doit arriver **avant les listes qu'il intitule** : c'est lui qui
      // dit quels onglets existent et ce que chacun filtre. Et toute erreur autre
      // qu'un 404 emporte les collections rangées après la fautive.
      for (final content in [
        SyncCollectionKey.teachings,
        SyncCollectionKey.gatherings,
        SyncCollectionKey.announcements,
      ]) {
        expect(
          keys.indexOf(SyncCollectionKey.menuEntries),
          lessThan(keys.indexOf(content)),
          reason: '« $content » ne doit jamais précéder le menu',
        );
      }
    });

    test('elle n\'est pas filtrée par la préférence de branche', () {
      // Il n'y a pas une barre d'onglets de Lomé et une autre d'Aného : le menu
      // est **global**, et `scopeFilter` est vide côté serveur.
      expect(
        kBranchScopedCollections,
        isNot(contains(SyncCollectionKey.menuEntries)),
      );
      expect(isBranchScoped(SyncCollectionKey.menuEntries), isFalse);
    });
  });

  group('Le tirage', () {
    test('l\'entrée livrée entre au magasin, entière, avec son curseur',
        () async {
      server
        ..serveManifest(menuManifest())
        ..serveCollection('menu_entries', menuEntriesPage());

      final report = await engine().synchronize();

      expect(report.pulled, [SyncCollectionKey.menuEntries]);

      final row = (await db.select(db.menuEntries).get()).single;
      // La PK est un **SERIAL** : un entier, pas la chaîne du vocabulaire.
      expect(row.id, 5);
      // `label = null` **et** `labelKey` renseigné : les deux champs sont
      // indissociables, et ce `null` veut dire « le libellé du dépôt ». Stocker
      // une carte vide à sa place perdrait l'information.
      expect(row.label, isNull);
      expect(row.labelKey, 'public.nav.mediatheque');
      // L'entrée indélébile de la médiathèque est une **page**, pas un
      // catalogue : c'est ainsi que `menu_seed.ts` la sème (garde-fou 2).
      expect(row.destinationKind, 'page');
      expect(row.destinationPage, 'mediatheque');
      expect(row.destinationFamily, isNull);
      // Les quatre cases de filtre reprises de ce que `/mediatheque` offrait.
      expect(row.filterSearch, isTrue);
      expect(row.filterRubric, isTrue);
      // La surface médiathèque est allumée, l'accueil non — l'état livré, et la
      // raison pour laquelle l'accueil reste piloté par les rubriques.
      expect(row.mediaVisible, isTrue);
      expect(row.homeVisible, isFalse);
      expect(row.homeLayout, isNull);
      // Aucune fenêtre : l'entrée paraît tout le temps.
      expect(row.publishedFrom, isNull);
      expect(row.publishedUntil, isNull);
      // Le jeton d'écriture est posé par le magasin, pas par le serveur.
      expect(row.syncStamp, greaterThan(0));
      expect(
        await dao.cursorFor(SyncCollectionKey.menuEntries),
        menuEntriesCursor,
      );
    });

    test('les champs d\'une entrée complète traversent sans se perdre',
        () async {
      // La forme la plus chargée que le portail puisse servir : un catalogue
      // filtré, une fenêtre, un gabarit d'accueil, un libellé surchargé et le lot
      // éditorial. Chaque clé est relevée sur `menu_entry_transformer.ts`.
      server
        ..serveManifest(menuManifest())
        ..serveCollection(
          'menu_entries',
          menuEntriesPage(rows: [
            menuEntryPayload(
              id: 12,
              labelKey: 'public.nav.teachings',
              label: const {'fr': 'Prières', 'en': 'Prayers'},
              icon: 'hand-heart',
              featured: true,
              divided: true,
              destinationFamily: 'teaching',
              destinationRubric: 'prieres',
              destinationSearch: 'intercession',
              filterSearch: true,
              mediaPosition: 3,
              homeVisible: true,
              homePosition: 2,
              homeLayout: 'list',
              publishedFrom: '2026-01-01T00:00:00.000Z',
              publishedUntil: '2027-01-01T00:00:00.000Z',
              pageTitle: const {'fr': 'Moments de prière'},
              pageDescription: const {'fr': 'Prier ensemble, chaque semaine.'},
            ),
          ]),
        );

      await engine().synchronize();

      final row = (await db.select(db.menuEntries).get()).single;
      // La carte de traduction est stockée **entière** : c'est `pick` qui
      // choisira la langue à la lecture (ADR-0023).
      expect(row.label, {'fr': 'Prières', 'en': 'Prayers'});
      expect(row.icon, 'hand-heart');
      expect(row.featured, isTrue);
      expect(row.divided, isTrue);
      expect(row.destinationKind, 'catalogue');
      expect(row.destinationFamily, 'teaching');
      // Un **slug**, jamais un identifiant : c'est ce que porte l'URL publique,
      // et ce que le client retrouve sur ses lignes de `teaching_types`.
      expect(row.destinationRubric, 'prieres');
      expect(row.destinationSearch, 'intercession');
      expect(row.homeLayout, 'list');
      expect(row.pageTitle, {'fr': 'Moments de prière'});
      expect(row.pageDescription, {'fr': 'Prier ensemble, chaque semaine.'});
      // ⚠️ Des **instants**, pas des jours : le serveur sert des `timestamp`, et
      // c'est à `DateTime.now()` que le client les comparera. `seasons`, elle,
      // porte des chaînes `YYYY-MM-DD` comparées comme des chaînes.
      // `.toUtc()` des deux côtés : Drift range un instant en secondes epoch et
      // le rend en heure **locale**. C'est l'instant qui est le contrat, jamais
      // son étiquette de fuseau — et c'est aussi pour cela que
      // `StoreMenuRepository` compare en UTC.
      expect(row.publishedFrom!.toUtc(), DateTime.utc(2026, 1, 1));
      expect(row.publishedUntil!.toUtc(), DateTime.utc(2027, 1, 1));
      // Le rang voyage, mais ce n'est **pas** un numéro stable : `SaveMenu`
      // renumérote `1..n` par surface. On ne vérifie donc que l'ordre, et jamais
      // une valeur — sauf ici, où c'est le transport qui est en cause.
      expect(row.mediaPosition, 3);
      expect(row.homePosition, 2);
    });

    test('une sous-entrée dont le parent manque n\'échoue pas', () async {
      // `parentId` est un **entier nu, sans contrainte** (règle 4 du magasin) :
      // les collections arrivent et se resynchronisent séparément, et une
      // contrainte ferait échouer la page **entière** — donc les entrées que le
      // client sait rendre. L'orpheline paraîtra au cycle suivant.
      server
        ..serveManifest(menuManifest())
        ..serveCollection(
          'menu_entries',
          menuEntriesPage(rows: [
            menuEntryPayload(
                id: 20, parentId: 999, destinationRubric: 'priere'),
          ]),
        );

      final report = await engine().synchronize();

      expect(report.pulled, [SyncCollectionKey.menuEntries]);
      expect((await db.select(db.menuEntries).get()).single.parentId, 999);
    });

    test('une destination de type inconnu entre quand même au magasin',
        () async {
      // « On stocke ce que le serveur envoie » (ADR-0026 décision 3). Refuser la
      // ligne ici coûterait la page entière, donc les entrées que ce binaire sait
      // rendre — et le masquage d'un type inconnu est une décision de
      // **lecture**, pas d'écriture.
      server
        ..serveManifest(menuManifest())
        ..serveCollection(
          'menu_entries',
          menuEntriesPage(rows: [
            menuEntryPayload(
              id: 30,
              destinationKind: 'podcast',
              destinationFamily: null,
            ),
          ]),
        );

      await engine().synchronize();

      expect(
        (await db.select(db.menuEntries).get()).single.destinationKind,
        'podcast',
        reason:
            'la chaîne est stockée telle quelle : un enum côté client serait '
            'une décision figée à l\'écriture',
      );
    });

    test('aucun `branch_id` ne part, même avec une préférence posée', () async {
      server
        ..serveManifest(menuManifest())
        ..serveCollection('menu_entries', menuEntriesPage());

      await engine(branchId: () async => 3).synchronize();

      expect(
        server.requestsFor('menu_entries').last.queryParameters['branch_id'],
        isNull,
      );
    });
  });

  group('Un serveur en retard d\'une version', () {
    test('le 404 saute la collection et ne coupe pas celle d\'après', () async {
      // `FakeSyncServer` répond **404** à une collection jamais scriptée, comme
      // le registre serveur le fait d'une clé non enregistrée.
      //
      // ⚠️ La collection témoin est **`decor`**, et ce choix n'est pas
      // indifférent : c'est celle qui suit immédiatement `menu_entries` dans le
      // registre. Viser `teachings` sauterait trois collections et prouverait
      // beaucoup moins.
      server
        ..serveManifest(manifestFromZero())
        ..serveCollection('decor', decorPage());

      final report = await engine(only: [
        SyncCollectionKey.menuEntries,
        SyncCollectionKey.decor,
      ]).synchronize();

      expect(report.skipped, contains(SyncCollectionKey.menuEntries));
      expect(report.pulled, contains(SyncCollectionKey.decor));
      expect(await db.select(db.menuEntries).get(), isEmpty);
      expect(await db.select(db.decor).get(), isNotEmpty);
      // Rien de posé : la prochaine fois, la collection repart de zéro.
      expect(await dao.cursorFor(SyncCollectionKey.menuEntries), isNull);
    });
  });

  group('Pas de tombstone', () {
    test('une entrée supprimée au portail reste en magasin', () async {
      // `tombstoneColumn: null` : `SaveMenu` écrit le menu en entier, et une
      // entrée que le tableau posté ne nomme plus est supprimée **durement**. La
      // ligne cesse simplement d'apparaître au flux, sans rien annoncer.
      //
      // Ce test fixe le **manque**, pas un comportement souhaitable : il dit
      // qu'aucun mécanisme de retrait ne voyage, et c'est précisément pourquoi la
      // réparation appartient au client, sur le patron « pas de contenu, pas de
      // section » (voir `test/data/local/menu_dao_test.dart`).
      server
        ..serveManifest(menuManifest())
        ..servePages('menu_entries', [
          menuEntriesPage(
            rows: [menuEntryPayload(id: 40, destinationRubric: 'priere')],
          ),
          // Le cycle suivant ne la nomme plus — et ne dit rien d'elle.
          menuEntriesPage(rows: const []),
        ]);
      await engine().synchronize();
      expect(await db.select(db.menuEntries).get(), hasLength(1));

      await engine().synchronize();

      expect(
        await db.select(db.menuEntries).get(),
        hasLength(1),
        reason: 'le flux ne porte aucune rétractation : seul « pas de contenu, '
            'pas de section » peut retirer cette entrée de l\'écran',
      );
    });
  });
}
