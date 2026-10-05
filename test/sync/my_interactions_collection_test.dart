/// **La collection `my_interactions`, de bout en bout** (#148).
///
/// Le voyage, pas l'affichage : que mes requêtes arrivent avec leur genre et
/// leur état, qu'un changement d'état et une rétractation voyagent, qu'un
/// serveur qui ne connaît pas encore la collection ne coûte rien — et que le
/// magasin, qui survit à la déconnexion, ne montre jamais les requêtes d'une
/// autre personne.
///
/// Les lignes s'écrivent ici par le **moteur**, jamais par un insert nu : c'est
/// la seule façon de prouver que la forme servie traverse `sync_rows.dart`.
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
import 'package:maison_du_miracle/models/my_request_view.dart';

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

  Map<String, Object?> manifest({String? cursor}) => {
        'scope_version': 1,
        'collections': [
          manifestEntry(
            SyncCollectionKey.myInteractions,
            partition: 'private',
            currentCursor: cursor ?? myInteractionsCursor,
            hasChanges: true,
            fromZero: cursor == null,
          ),
        ],
      };

  SyncEngine engine() => SyncEngine(
        api: SyncApi(dio: dio),
        dao: dao,
        collections: syncedCollections()
            .where((c) => c.key == SyncCollectionKey.myInteractions)
            .toList(growable: false),
      );

  Future<List<MyRequestView>> mine(String? actor) =>
      db.interactionDao.watchMine(actor).first;

  group('Le registre', () {
    test('la collection est là, et n\'est pas filtrée par branche', () {
      expect(
        syncedCollections().map((c) => c.key),
        contains(SyncCollectionKey.myInteractions),
      );
      expect(isBranchScoped(SyncCollectionKey.myInteractions), isFalse);
      expect(kSyncCollections[SyncCollectionKey.myInteractions], 'private');
    });
  });

  group('Le tirage', () {
    test('mes requêtes entrent au magasin, avec genre, état et date', () async {
      server
        ..serveManifest(manifest())
        ..serveCollection('my_interactions', myInteractionsPage());

      final report = await engine().synchronize();
      expect(report.pulled, [SyncCollectionKey.myInteractions]);
      expect(
        await dao.cursorFor(SyncCollectionKey.myInteractions),
        myInteractionsCursor,
      );

      final requests = await mine(myRequestsAuthorId);
      // Les plus récentes d'abord : la prière (2 oct.) avant la suggestion
      // (28 sept.).
      expect(requests.map((r) => r.id), [
        myAnonymousPrayerPayload['id'],
        mySuggestionPayload['id'],
      ]);

      final prayer = requests.first;
      expect(prayer.kind, RequestKind.prayer);
      expect(prayer.status, RequestStatus.received);
      expect(prayer.isAnonymous, isTrue);
      // Sans horodatage du téléphone, la date est celle du serveur.
      expect(prayer.sentAt!.toUtc(), DateTime.utc(2026, 10, 2, 9));

      final suggestion = requests.last;
      expect(suggestion.kind, RequestKind.suggestion);
      expect(suggestion.status, RequestStatus.inProgress);
      expect(suggestion.title, 'Horaires du culte');
      // L'horodatage du téléphone l'emporte : c'est l'instant où j'ai envoyé.
      expect(suggestion.sentAt!.toUtc(), DateTime.utc(2026, 9, 28, 8));
    });

    test('un changement d\'état remplace la ligne', () async {
      server
        ..serveManifests([manifest(), manifest(cursor: 'c2')])
        ..servePages('my_interactions', [
          myInteractionsPage(),
          myInteractionsPage(items: [
            {...mySuggestionPayload, 'status': 'resolved'},
          ]),
        ]);

      await engine().synchronize();
      await engine().synchronize();

      final requests = await mine(myRequestsAuthorId);
      expect(requests, hasLength(2));
      expect(
        requests.firstWhere((r) => r.id == mySuggestionPayload['id']).status,
        RequestStatus.resolved,
      );
    });

    test('une rétractation retire la requête', () async {
      server
        ..serveManifests([manifest(), manifest(cursor: 'c2')])
        ..servePages('my_interactions', [
          myInteractionsPage(),
          myInteractionsPage(items: [
            {
              'id': mySuggestionPayload['id'],
              'deletedAt': '2026-10-03T10:00:00.000Z',
            },
          ]),
        ]);

      await engine().synchronize();
      await engine().synchronize();

      expect(
        (await mine(myRequestsAuthorId)).map((r) => r.id),
        [myAnonymousPrayerPayload['id']],
      );
    });

    test('un état ou un genre inconnu se lit sans faire tomber la liste',
        () async {
      server
        ..serveManifest(manifest())
        ..serveCollection(
          'my_interactions',
          myInteractionsPage(items: [
            {
              ...mySuggestionPayload,
              'type': 'testimony',
              'status': 'escalated',
            },
          ]),
        );

      await engine().synchronize();

      final request = (await mine(myRequestsAuthorId)).single;
      expect(request.kind, RequestKind.unknown);
      expect(request.status, RequestStatus.unknown);
    });

    test('le 404 d\'un serveur en retard saute la collection', () async {
      // `FakeSyncServer` répond 404 à une collection jamais scriptée.
      server.serveManifest(manifest());

      final report = await engine().synchronize();

      expect(report.pulled, isNot(contains(SyncCollectionKey.myInteractions)));
      expect(await mine(myRequestsAuthorId), isEmpty);
    });
  });

  group('La lecture ne montre que les miennes', () {
    test('une ligne d\'une autre personne reste muette', () async {
      // Le serveur ne sert que les miennes ; mais le magasin survit à la
      // déconnexion, et la personne suivante sur ce téléphone ne doit pas lire
      // ce que la précédente a confié.
      server
        ..serveManifest(manifest())
        ..serveCollection(
          'my_interactions',
          myInteractionsPage(items: [
            mySuggestionPayload,
            {
              ...myAnonymousPrayerPayload,
              'authorId': 'c0ffee00-0000-4000-8000-000000000001',
            },
          ]),
        );

      await engine().synchronize();

      expect(
        (await mine(myRequestsAuthorId)).map((r) => r.id),
        [mySuggestionPayload['id']],
      );
      expect(
        (await mine('c0ffee00-0000-4000-8000-000000000001')).map((r) => r.id),
        [myAnonymousPrayerPayload['id']],
      );
    });

    test('sans acteur, rien ne se lit', () async {
      server
        ..serveManifest(manifest())
        ..serveCollection('my_interactions', myInteractionsPage());
      await engine().synchronize();

      expect(await mine(null), isEmpty);
    });
  });
}
