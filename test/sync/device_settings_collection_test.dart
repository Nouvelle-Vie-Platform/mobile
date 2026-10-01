/// **La collection `device_settings`, de bout en bout** (#91).
///
/// Ce que ce fichier vérifie n'est pas l'affichage — c'est le voyage : que le
/// seuil réglé au portail arrive, qu'il arrive **avant les contenus**, qu'un
/// retrait voyage comme une pose, et qu'un serveur qui ne connaît pas encore la
/// collection ne coûte **rien**.
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
  /// 'reference'` — un parc d'appareils n'appartient à aucune branche.
  Map<String, Object?> deviceSettingsManifest() => {
        'scope_version': 1,
        'collections': [
          manifestEntry(
            SyncCollectionKey.deviceSettings,
            partition: 'reference',
            currentCursor: deviceSettingsCursor,
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
                only?.contains(c.key) ??
                c.key == SyncCollectionKey.deviceSettings)
            .toList(growable: false),
        branchId: branchId,
      );

  group('Le registre', () {
    test('la collection est là, rangée avant tout contenu', () {
      final keys = syncedCollections().map((c) => c.key).toList();

      expect(keys, contains(SyncCollectionKey.deviceSettings));
      // Le seuil vaut pour tout le monde, porteur **sans compte** compris, et
      // toute erreur autre qu'un 404 emporte les collections rangées après la
      // fautive.
      for (final content in [
        SyncCollectionKey.teachings,
        SyncCollectionKey.gatherings,
        SyncCollectionKey.announcements,
      ]) {
        expect(
          keys.indexOf(SyncCollectionKey.deviceSettings),
          lessThan(keys.indexOf(content)),
          reason: '« $content » ne doit jamais précéder le réglage du parc',
        );
      }
    });

    test('elle n\'est pas filtrée par la préférence de branche', () {
      // Il n'y a pas une version recommandée à Lomé et une autre à Aného.
      expect(
        kBranchScopedCollections,
        isNot(contains(SyncCollectionKey.deviceSettings)),
      );
      expect(isBranchScoped(SyncCollectionKey.deviceSettings), isFalse);
    });
  });

  group('Le tirage', () {
    test('le seuil réglé au portail entre au magasin, avec son curseur',
        () async {
      server
        ..serveManifest(deviceSettingsManifest())
        ..serveCollection(
          'device_settings',
          deviceSettingsPage(row: deviceSettingsThresholdPayload),
        );

      final report = await engine().synchronize();

      expect(report.pulled, [SyncCollectionKey.deviceSettings]);

      final row = (await db.select(db.deviceSettings).get()).single;
      // L'identifiant du singleton : un **entier**, et il vaut 1.
      expect(row.id, 1);
      // La **chaîne** du portail, telle quelle : la découper ici inventerait une
      // sémantique de version que `compareAppVersions` détient déjà.
      expect(row.updateBannerMinVersion, '1.4.0');
      // Le jeton d'écriture est posé par le magasin, pas par le serveur.
      expect(row.syncStamp, greaterThan(0));
      expect(
        await dao.cursorFor(SyncCollectionKey.deviceSettings),
        deviceSettingsCursor,
      );
      // Et c'est bien ce que le DAO rend — le seul chemin que lise le bandeau.
      expect(await db.deviceSettingsDao.readUpdateBannerMinVersion(), '1.4.0');
    });

    test('la ligne livrée voyage avec son `null`, et ne vaut pas seuil',
        () async {
      // `null` part quand même : c'est ce qui distingue, côté serveur, « je n'ai
      // pas encore reçu les réglages » de « il n'y a pas de seuil ». Côté
      // client, les deux mènent au même repli — et le second est ici prouvé sur
      // une ligne **présente**.
      server
        ..serveManifest(deviceSettingsManifest())
        ..serveCollection('device_settings', deviceSettingsPage());

      await engine().synchronize();

      expect(await db.select(db.deviceSettings).get(), hasLength(1));
      expect(
        await db.deviceSettingsDao.readUpdateBannerMinVersion(),
        isNull,
        reason: 'une ligne au seuil nul se lit « pas de seuil », donc pas de '
            'bandeau — jamais « seuil à zéro »',
      );
    });

    test('un retrait voyage sur la ligne, sans tombstone', () async {
      // Le singleton ne se supprime pas : poser puis retirer le seuil est **la
      // même ligne**, écrite deux fois. Et ce sens-là compte autant que
      // l'autre — se taire après qu'on a retiré le seuil est exactement aussi
      // important que paraître après qu'on l'a posé.
      //
      // ⚠️ Les deux pages sont scriptées **avant** le premier cycle : la file du
      // double rend sa dernière réponse en boucle, et une page ajoutée après
      // coup se range derrière celle qui vient d'être servie — le second cycle
      // rejouerait alors la première.
      server
        ..serveManifest(deviceSettingsManifest())
        ..servePages('device_settings', [
          deviceSettingsPage(row: deviceSettingsThresholdPayload),
          deviceSettingsPage(row: deviceSettingsClearedPayload),
        ]);
      await engine().synchronize();
      expect(await db.deviceSettingsDao.readUpdateBannerMinVersion(), '1.4.0');

      await engine().synchronize();

      expect(await db.select(db.deviceSettings).get(), hasLength(1));
      expect(await db.deviceSettingsDao.readUpdateBannerMinVersion(), isNull);
    });

    test('aucun `branch_id` ne part, même avec une préférence posée', () async {
      server
        ..serveManifest(deviceSettingsManifest())
        ..serveCollection('device_settings', deviceSettingsPage());

      await engine(branchId: () async => 3).synchronize();

      expect(
        server.requestsFor('device_settings').last.queryParameters['branch_id'],
        isNull,
      );
    });
  });

  group('Un serveur en retard d\'une version', () {
    test('le 404 saute la collection et ne coupe rien', () async {
      // `FakeSyncServer` répond **404** à une collection jamais scriptée, comme
      // le registre serveur le fait d'une clé non enregistrée. Le réglage du
      // parc est sauté, `teaching_types` — rangée après lui — est tirée quand
      // même, et le bandeau reste tu : **sans seuil il n'y a pas de bandeau**,
      // donc un serveur en retard d'une version ne dégrade rien du tout.
      server
        ..serveManifest(manifestFromZero())
        ..serveCollection('teaching_types', teachingTypesPage());

      final report = await engine(only: [
        SyncCollectionKey.deviceSettings,
        SyncCollectionKey.teachingTypes,
      ]).synchronize();

      expect(report.skipped, contains(SyncCollectionKey.deviceSettings));
      expect(report.pulled, contains(SyncCollectionKey.teachingTypes));
      expect(await db.select(db.deviceSettings).get(), isEmpty);
      expect(await db.select(db.teachingTypes).get(), isNotEmpty);
      // Rien de posé : la prochaine fois, la collection repart de zéro.
      expect(await dao.cursorFor(SyncCollectionKey.deviceSettings), isNull);
      // Et le repli tient : pas de seuil, donc pas de bandeau.
      expect(await db.deviceSettingsDao.readUpdateBannerMinVersion(), isNull);
    });
  });

  group('Le DAO', () {
    test('un magasin jamais synchronisé n\'a pas de seuil', () async {
      // L'état de départ **légitime**, et le moment où quelqu'un ouvre
      // l'application pour la première fois. Une table vide ne dit pas
      // « seuil à zéro » : elle dit « pas de seuil », donc aucun bandeau.
      expect(await db.select(db.deviceSettings).get(), isEmpty);
      expect(await db.deviceSettingsDao.readUpdateBannerMinVersion(), isNull);
    });

    test('le seuil est observé, et un cycle le met à jour', () async {
      server
        ..serveManifest(deviceSettingsManifest())
        ..serveCollection(
          'device_settings',
          deviceSettingsPage(row: deviceSettingsThresholdPayload),
        );

      final seen = db.deviceSettingsDao.watchUpdateBannerMinVersion();
      final future = seen.firstWhere((threshold) => threshold != null);

      await engine().synchronize();

      expect(await future, '1.4.0');
    });
  });
}
