/// **La collection `teaching_guests`, de bout en bout** (#77).
///
/// Ce que ce fichier vérifie n'est pas l'affichage : c'est qu'un crédit arrive,
/// et surtout qu'un crédit **retiré s'en va**. C'est le seul point où cette
/// collection se distingue de ses voisines — elle porte un tombstone, et la
/// raison est que la ligne périmée est **un nom affiché sur un écran**. Un
/// intervenant décrédité qui resterait sur les téléphones jusqu'à une
/// resynchronisation complète y resterait des semaines, et rien côté serveur ne
/// repasserait derrière : il n'y a pas d'écriture à revérifier, il n'y a qu'un
/// nom.
///
/// Le manifeste est écrit **à la main** ici, entrée par entrée, plutôt que tiré
/// de `kSyncCollections` : cette carte-là est un instantané d'un registre
/// serveur à dix-neuf collections, et le registre en compte davantage
/// aujourd'hui (`seasons` et `decor` y manquent déjà). L'y ajouter aurait fait
/// dire à son test « vingt collections » un nombre tout aussi faux.
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
  /// 'reference'` — le pivot ne porte pas de `branch_id`.
  Map<String, Object?> guestsManifest({String? cursor}) => {
        'scope_version': 1,
        'collections': [
          manifestEntry(
            SyncCollectionKey.teachingGuests,
            partition: 'reference',
            currentCursor: cursor ?? teachingGuestsCursor,
            hasChanges: true,
            fromZero: cursor == null,
          ),
        ],
      };

  SyncEngine engine({Future<int?> Function()? branchId}) => SyncEngine(
        api: SyncApi(dio: dio),
        dao: dao,
        collections: syncedCollections()
            .where((c) => c.key == SyncCollectionKey.teachingGuests)
            .toList(growable: false),
        branchId: branchId,
      );

  group('Le registre', () {
    test('la collection est là, après `contributors` et après `teachings`', () {
      final keys = syncedCollections().map((c) => c.key).toList();

      expect(keys, contains(SyncCollectionKey.teachingGuests));
      // Un **pivot** : ses deux colonnes ne désignent rien par elles-mêmes, et
      // il ne s'affiche qu'en joignant les deux collections qu'il relie. Le
      // tirer avant l'une ou l'autre donnerait, à la toute première
      // synchronisation, une liste d'invités que le magasin ne saurait pas
      // nommer.
      expect(
        keys.indexOf(SyncCollectionKey.contributors),
        lessThan(keys.indexOf(SyncCollectionKey.teachingGuests)),
      );
      expect(
        keys.indexOf(SyncCollectionKey.teachings),
        lessThan(keys.indexOf(SyncCollectionKey.teachingGuests)),
      );
    });

    test('elle n\'est pas filtrée par la préférence de branche', () {
      // `partition: 'reference'` côté serveur : le pivot n'a pas de
      // `branch_id`. Le filtrer exigerait une jointure sur son parent pour un
      // résultat que le client obtient gratuitement en joignant contre sa copie
      // de `teachings` — un crédit dont l'enseignement a été filtré ne
      // s'affiche nulle part, puisque c'est l'enseignement qui ouvre l'écran.
      expect(
        kBranchScopedCollections,
        isNot(contains(SyncCollectionKey.teachingGuests)),
      );
      expect(isBranchScoped(SyncCollectionKey.teachingGuests), isFalse);
    });
  });

  group('Le tirage', () {
    setUp(() {
      server
        ..serveManifest(guestsManifest())
        ..serveCollection('teaching_guests', teachingGuestsPage());
    });

    test('les trois crédits entrent au magasin, avec leur curseur', () async {
      final report = await engine().synchronize();

      expect(report.pulled, [SyncCollectionKey.teachingGuests]);

      final rows = await db.select(db.teachingGuests).get();
      expect(rows.map((r) => r.id), unorderedEquals([1, 2, 3]));
      expect(
        await dao.cursorFor(SyncCollectionKey.teachingGuests),
        teachingGuestsCursor,
      );
    });

    test('la ligne porte deux identifiants et un rang, et rien d\'autre',
        () async {
      await engine().synchronize();

      final row = (await db.select(db.teachingGuests).get())
          .firstWhere((r) => r.id == 1);
      expect(row.teachingId, '019f2c40-0000-7000-8000-000000000001');
      expect(row.contributorId, 7);
      expect(row.position, 1);
      // Le jeton d'écriture est posé par le magasin, pas par le serveur : il
      // est alloué, donc non nul.
      expect(row.syncStamp, greaterThan(0));
    });

    test('aucun `branch_id` ne part, même avec une préférence posée', () async {
      await engine(branchId: () async => 3).synchronize();

      // Le filtre suit le descripteur, jamais une condition écrite dans le
      // moteur. Envoyer `branch_id` sur une collection que le serveur déclare
      // `reference` reviendrait à filtrer sur une colonne qui n'existe pas.
      expect(
        server.requestsFor('teaching_guests').last.queryParameters['branch_id'],
        isNull,
      );
    });
  });

  group('Le tombstone', () {
    test('un invité décrédité quitte le magasin au cycle suivant', () async {
      server
        ..serveManifests([
          guestsManifest(),
          guestsManifest(cursor: teachingGuestsCursorAfterRetraction),
        ])
        ..servePages('teaching_guests', [
          teachingGuestsPage(),
          teachingGuestRetractionPage(),
        ]);

      await engine().synchronize();
      expect(await db.select(db.teachingGuests).get(), hasLength(3));

      await engine().synchronize();

      // **Sans attendre une resynchronisation complète** : c'est tout l'objet du
      // tombstone. La ligne repasse dans le flux avec son drapeau, et le crédit
      // s'en va.
      final rows = await db.select(db.teachingGuests).get();
      expect(rows.map((r) => r.id), unorderedEquals([1, 3]));
      expect(
        await dao.cursorFor(SyncCollectionKey.teachingGuests),
        teachingGuestsCursorAfterRetraction,
      );
    });

    test('rien du retrait ne reste en magasin', () async {
      server
        ..serveManifests([
          guestsManifest(),
          guestsManifest(cursor: teachingGuestsCursorAfterRetraction),
        ])
        ..servePages('teaching_guests', [
          teachingGuestsPage(),
          teachingGuestRetractionPage(),
        ]);

      await engine().synchronize();
      await engine().synchronize();

      // La table ne porte **aucune** colonne `deleted_at` : le retrait est une
      // suppression locale, et pas une ligne marquée que chaque lecture devrait
      // penser à filtrer. Une seule lecture qui l'oublierait afficherait un
      // crédit retiré.
      expect(
        db.teachingGuests.columnsByName.keys,
        isNot(contains('deleted_at')),
      );
      expect(
        (await db.select(db.teachingGuests).get()).where((r) => r.id == 2),
        isEmpty,
      );
    });

    test('remis, le même invité revient par la même ligne', () async {
      // L'unicité serveur porte sur la paire tombstones comprise : remettre
      // l'invité réanime la ligne `id: 2` (`deleted_at → NULL`), qui repasse
      // dans le flux. Le client n'a donc jamais à départager deux lignes pour la
      // même paire.
      server
        ..serveManifests([
          guestsManifest(),
          guestsManifest(cursor: teachingGuestsCursorAfterRetraction),
          guestsManifest(cursor: teachingGuestsCursorAfterRetraction),
        ])
        ..servePages('teaching_guests', [
          teachingGuestsPage(),
          teachingGuestRetractionPage(),
          deltaPage(
            items: const [secondTeachingGuestPayload],
            nextCursor: teachingGuestsCursorAfterRetraction,
          ),
        ]);

      await engine().synchronize();
      await engine().synchronize();
      await engine().synchronize();

      final rows = await db.select(db.teachingGuests).get();
      expect(rows.map((r) => r.id), unorderedEquals([1, 2, 3]));
      expect(rows.firstWhere((r) => r.id == 2).position, 2);
    });
  });

  group('Le resync complet', () {
    test('un crédit que le cycle ne revoit pas est balayé à la fin', () async {
      // Le filet de sécurité derrière le tombstone : si un retrait a été purgé
      // (fenêtre de rétention dépassée) et que le serveur réclame un
      // remplacement, le balayage final emporte ce que le cycle n'a pas revu —
      // sans jamais vider la table d'abord.
      server
        ..serveManifests([
          guestsManifest(),
          {
            'scope_version': 1,
            'collections': [
              manifestEntry(
                SyncCollectionKey.teachingGuests,
                partition: 'reference',
                currentCursor: teachingGuestsCursor,
                hasChanges: true,
                fullResyncRequired: true,
              ),
            ],
          },
        ])
        ..servePages('teaching_guests', [
          teachingGuestsPage(),
          deltaPage(
            items: const [teachingGuestPayload, otherTeachingGuestPayload],
            nextCursor: teachingGuestsCursor,
          ),
        ]);

      await engine().synchronize();
      await engine().synchronize();

      final rows = await db.select(db.teachingGuests).get();
      expect(rows.map((r) => r.id), unorderedEquals([1, 3]));
    });
  });
}
