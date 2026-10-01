/// **La collection `auth_channels`, de bout en bout** (#83).
///
/// Ce que ce fichier vérifie n'est pas l'affichage — c'est le voyage : que la
/// politique de connexion réglée au portail arrive, qu'elle arrive **avant les
/// contenus**, et qu'un serveur qui ne la connaît pas encore ne coûte rien.
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
import 'package:maison_du_miracle/models/auth_channels.dart';
import 'package:maison_du_miracle/models/models.dart';

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
  /// 'reference'` — une porte d'entrée n'appartient à aucune branche.
  Map<String, Object?> authChannelsManifest() => {
        'scope_version': 1,
        'collections': [
          manifestEntry(
            SyncCollectionKey.authChannels,
            partition: 'reference',
            currentCursor: authChannelsCursor,
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
                c.key == SyncCollectionKey.authChannels)
            .toList(growable: false),
        branchId: branchId,
      );

  group('Le registre', () {
    test('la collection est là, rangée avant tout contenu', () {
      final keys = syncedCollections().map((c) => c.key).toList();

      expect(keys, contains(SyncCollectionKey.authChannels));
      // C'est la première chose qu'un porteur **sans compte** a besoin de
      // savoir, et toute erreur autre qu'un 404 emporte les collections rangées
      // après la fautive.
      for (final content in [
        SyncCollectionKey.teachings,
        SyncCollectionKey.gatherings,
        SyncCollectionKey.announcements,
      ]) {
        expect(
          keys.indexOf(SyncCollectionKey.authChannels),
          lessThan(keys.indexOf(content)),
          reason: '« $content » ne doit jamais précéder les canaux',
        );
      }
    });

    test('elle n\'est pas filtrée par la préférence de branche', () {
      expect(
        kBranchScopedCollections,
        isNot(contains(SyncCollectionKey.authChannels)),
      );
      expect(isBranchScoped(SyncCollectionKey.authChannels), isFalse);
    });
  });

  group('Le tirage', () {
    test('l\'unique ligne entre au magasin, avec son curseur', () async {
      server
        ..serveManifest(authChannelsManifest())
        ..serveCollection('auth_channels', authChannelsPage());

      final report = await engine().synchronize();

      expect(report.pulled, [SyncCollectionKey.authChannels]);

      final row = (await db.select(db.authChannels).get()).single;
      // L'identifiant du singleton : un **entier**, et il vaut 1.
      expect(row.id, 1);
      // Les valeurs livrées par la migration serveur, et ce ne sont pas des
      // défauts prudents : l'e-mail part en SMTP, le canal téléphone n'envoie
      // rien.
      expect(row.emailOpen, isTrue);
      expect(row.phoneOpen, isFalse);
      // `null` voyage : « pas d'annonce », et non « pas encore reçu ».
      expect(row.loginNotice, isNull);
      // Le jeton d'écriture est posé par le magasin, pas par le serveur.
      expect(row.syncStamp, greaterThan(0));
      expect(
        await dao.cursorFor(SyncCollectionKey.authChannels),
        authChannelsCursor,
      );
    });

    test('l\'annonce voyage en carte entière, jamais résolue', () async {
      server
        ..serveManifest(authChannelsManifest())
        ..serveCollection(
          'auth_channels',
          authChannelsPage(row: authChannelsNoticedPayload),
        );

      await engine().synchronize();

      // Toutes les langues servies sont conservées : figer celle de l'appareil
      // à l'écriture laisserait un bandeau français à qui passe son téléphone
      // en éwé, jusqu'au prochain tirage.
      expect((await db.select(db.authChannels).get()).single.loginNotice, {
        'fr': 'La connexion par téléphone rouvrira bientôt.',
        'en': 'Phone sign-in will reopen soon.',
      });
    });

    test('une fermeture voyage sur la ligne, sans tombstone', () async {
      // Le singleton ne se supprime pas : ouvrir puis fermer le téléphone est
      // **la même ligne**, écrite deux fois.
      //
      // ⚠️ Les deux pages sont scriptées **avant** le premier cycle : la file
      // du double rend sa dernière réponse en boucle, et une page ajoutée
      // après coup se range derrière celle qui vient d'être servie — le second
      // cycle rejouerait alors la première.
      server
        ..serveManifest(authChannelsManifest())
        ..servePages('auth_channels', [
          authChannelsPage(row: authChannelsBothOpenPayload),
          authChannelsPage(row: authChannelsEmailOnlyPayload),
        ]);
      await engine().synchronize();
      expect((await db.authChannelsDao.readOffer()).offersChoice, isTrue);

      await engine().synchronize();

      expect(await db.select(db.authChannels).get(), hasLength(1));
      final offer = await db.authChannelsDao.readOffer();
      expect(offer.offersChoice, isFalse);
      expect(offer.soleChannel, IdentifierChannel.email);
    });

    test('aucun `branch_id` ne part, même avec une préférence posée', () async {
      server
        ..serveManifest(authChannelsManifest())
        ..serveCollection('auth_channels', authChannelsPage());

      await engine(branchId: () async => 3).synchronize();

      expect(
        server.requestsFor('auth_channels').last.queryParameters['branch_id'],
        isNull,
      );
    });
  });

  group('Un serveur en retard d\'une version', () {
    test('le 404 saute la collection et ne coupe rien', () async {
      // `FakeSyncServer` répond **404** à une collection jamais scriptée, comme
      // le registre serveur le fait d'une clé non enregistrée. Les canaux sont
      // sautés, `teaching_types` — rangée après eux — est tirée quand même, et
      // l'écran reste sur son repli : l'e-mail seul. Rien ne se dégrade.
      server
        ..serveManifest(manifestFromZero())
        ..serveCollection('teaching_types', teachingTypesPage());

      final report = await engine(only: [
        SyncCollectionKey.authChannels,
        SyncCollectionKey.teachingTypes,
      ]).synchronize();

      expect(report.skipped, contains(SyncCollectionKey.authChannels));
      expect(report.pulled, contains(SyncCollectionKey.teachingTypes));
      expect(await db.select(db.authChannels).get(), isEmpty);
      expect(await db.select(db.teachingTypes).get(), isNotEmpty);
      // Rien de posé : la prochaine fois, la collection repart de zéro.
      expect(await dao.cursorFor(SyncCollectionKey.authChannels), isNull);
      // Et le repli tient : l'e-mail, jamais « tous les canaux ».
      expect(await db.authChannelsDao.readOffer(), AuthChannelOffer.emailOnly);
    });
  });

  group('Le DAO', () {
    test('un magasin jamais synchronisé propose l\'e-mail, et rien d\'autre',
        () async {
      // L'état de départ **légitime**, et le moment où quelqu'un ouvre
      // l'application pour la première fois.
      final offer = await db.authChannelsDao.readOffer();

      expect(offer, AuthChannelOffer.emailOnly);
      expect(offer.emailOpen, isTrue);
      expect(offer.phoneOpen, isFalse);
      expect(offer.offersChoice, isFalse);
      expect(offer.soleChannel, IdentifierChannel.email);
      expect(offer.notice, isNull);
    });

    test('deux canaux ouverts : il y a quelque chose à choisir', () async {
      server
        ..serveManifest(authChannelsManifest())
        ..serveCollection(
          'auth_channels',
          authChannelsPage(row: authChannelsBothOpenPayload),
        );
      await engine().synchronize();

      final offer = await db.authChannelsDao.readOffer();
      expect(offer.offersChoice, isTrue);
      expect(offer.soleChannel, isNull);
      expect(offer.notice?['fr'], isNotNull);
    });

    test('tous les canaux fermés retombe sur l\'e-mail seul', () async {
      // Le serveur l'interdit par un CHECK (`auth_settings_at_least_one_
      // channel`), et le magasin n'a pas à le rejouer — mais il n'a pas non
      // plus à le supposer. Une base bricolée, ou un serveur d'une version
      // future qui fermerait les deux canaux connus de ce client, donnerait
      // sinon un écran **sans aucun champ** : une porte fermée que personne ne
      // peut rouvrir depuis l'application.
      //
      // La ligne entre par le **moteur**, comme toutes les autres : c'est la
      // seule façon de prouver qu'une telle page traverserait réellement
      // `sync_rows.dart` sans rien casser.
      server
        ..serveManifest(authChannelsManifest())
        ..serveCollection(
          'auth_channels',
          deltaPage(
            items: const [
              {
                'id': 1,
                'emailOpen': false,
                'phoneOpen': false,
                'loginNotice': null,
                'createdAt': '2026-09-01T09:00:00.000Z',
                'updatedAt': '2026-09-20T10:20:00.000Z',
              }
            ],
            nextCursor: authChannelsCursor,
          ),
        );
      await engine().synchronize();

      // Le magasin stocke ce que le serveur envoie — c'est la **lecture** qui
      // remet l'offre du côté sûr.
      final row = (await db.select(db.authChannels).get()).single;
      expect(row.emailOpen, isFalse);
      expect(row.phoneOpen, isFalse);

      final offer = await db.authChannelsDao.readOffer();
      expect(offer.emailOpen, isTrue);
      expect(offer.phoneOpen, isFalse);
      expect(offer.soleChannel, IdentifierChannel.email);
    });

    test('l\'offre est observée, et un cycle la met à jour', () async {
      server
        ..serveManifest(authChannelsManifest())
        ..serveCollection(
          'auth_channels',
          authChannelsPage(row: authChannelsBothOpenPayload),
        );

      final seen = db.authChannelsDao.watchOffer();
      final future = seen.firstWhere((offer) => offer.offersChoice);

      await engine().synchronize();

      expect((await future).offersChoice, isTrue);
    });
  });
}
