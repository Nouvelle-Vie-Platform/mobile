import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/core/network/api_client.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/local/sync_dao.dart';
import 'package:maison_du_miracle/data/sync/sync_api.dart';
import 'package:maison_du_miracle/data/sync/sync_engine.dart';
import 'package:maison_du_miracle/data/sync/sync_rows.dart';
import 'package:maison_du_miracle/data/sync/synced_collection.dart';

import '../data/local/local_database_fixtures.dart';
import '../helpers/fake_sync_server.dart';
import '../helpers/sync_fixtures.dart';

/// **Le moteur, de bout en bout.**
///
/// Le canari du cadrage est `branches` : la collection la plus pauvre du
/// catalogue (un référentiel, une poignée de lignes, aucun périmètre, pas de
/// tombstone). Elle permet de vérifier le manifeste, le curseur, la boucle et
/// l'application transactionnelle **sans que la médiathèque soit en jeu** —
/// donc sans qu'un bug de socle se lise comme un bug de médiathèque.
///
/// Elle se tire à **`limit=1`** : à 200, une poignée de lignes ne produit
/// jamais de seconde page, et la boucle de rattrapage ne serait pas exercée du
/// tout. Le paramètre est déjà accepté par la route.
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

  SyncEngine engineOver(List<String> keys, {int limit = 1}) => SyncEngine(
        api: SyncApi(dio: dio),
        dao: dao,
        collections: syncedCollections()
            .where((collection) => keys.contains(collection.key))
            .toList(growable: false),
        pageLimit: limit,
      );

  group('Le canari : `branches` à `limit=1`', () {
    /// Une troisième branche, pour que la boucle tourne trois fois plutôt que
    /// deux — le cas où l'on oublie d'avancer le curseur passe encore à deux.
    const thirdBranchPayload = <String, Object?>{
      'id': 7,
      'name': 'Maison du Miracle — Kara',
      'isMotherChurch': false,
      'address': 'Kara',
      'email': null,
      'phone': null,
      'postalBox': null,
      'createdAt': '2025-12-01T08:00:00.000Z',
      'updatedAt': '2026-02-02T08:00:00.000Z',
    };

    final cursorPage1 = serverCursor(
      updatedAtIso: '2025-11-02T08:00:00.000Z',
      id: 1,
    );
    final cursorPage2 = serverCursor(
      updatedAtIso: '2026-02-02T08:00:00.000Z',
      id: 7,
    );

    setUp(() {
      server
        ..serveManifest(manifestFromZero())
        ..servePages('branches', [
          deltaPage(
            items: const [motherBranchPayload],
            nextCursor: cursorPage1,
            hasMore: true,
          ),
          deltaPage(
            items: const [thirdBranchPayload],
            nextCursor: cursorPage2,
            hasMore: true,
          ),
          deltaPage(items: const [branchPayload], nextCursor: branchesCursor),
        ]);
    });

    test('trois pages appliquées, chaque curseur rejoué tel quel', () async {
      final report = await engineOver(['branches']).synchronize();

      expect(report.pulled, ['branches']);
      expect(report.pages, 3);

      final sent = server.requestsFor('branches');
      expect(sent, hasLength(3));
      // Le premier tour part **sans** `since` ; les suivants rejouent le
      // curseur **reçu**, jamais un curseur fabriqué (ADR-0026).
      expect(
        sent.map((r) => r.queryParameters['since']),
        [null, cursorPage1, cursorPage2],
      );
      expect(
        sent.map((r) => r.queryParameters['limit']),
        everyElement(1),
        reason: 'sans `limit=1`, la boucle ne serait jamais exercée',
      );
    });

    test('le magasin porte les trois lignes et le dernier curseur', () async {
      await engineOver(['branches']).synchronize();

      final rows = await db.mediathequeDao.allBranches().get();
      expect(rows.map((r) => r.id).toList()..sort(), [1, 3, 7]);
      expect(rows.firstWhere((r) => r.id == 1).isMotherChurch, isTrue);
      expect(await dao.cursorFor(SyncCollectionKey.branches), branchesCursor);
      expect(await dao.readScopeVersion(), 1);
    });

    test('le cycle suivant repart du curseur persisté, pas de zéro', () async {
      await engineOver(['branches']).synchronize();
      // La file du double s'épuise sur sa dernière page, qui se répète : le
      // second cycle applique une page finale et s'arrête.
      await engineOver(['branches']).synchronize();

      expect(
        server.requestsFor('branches').last.queryParameters['since'],
        branchesCursor,
      );
      // Le manifeste du second tour porte ce que le client sait désormais.
      final second = server.manifestRequests.last.queryParameters;
      expect(second['cursors[branches]'], branchesCursor);
      expect(second['scope_version'], 1);
    });
  });

  group('L\'ordre d\'application : référentiels avant contenu', () {
    test('le registre local est ordonné, et c\'est lui la règle', () {
      expect(
        syncedCollections().map((c) => c.key),
        [
          'teaching_types',
          'gathering_types',
          'status_backgrounds',
          'official_accounts',
          'official_account_memberships',
          'legal_documents',
          'seasons',
          'presentation_vocabulary',
          'menu_entries',
          'auth_channels',
          'device_settings',
          'decor',
          'contributors',
          'branches',
          'teachings',
          'teaching_guests',
          'gatherings',
          'announcements',
          'playback_progress',
          // **Mes requêtes** (#148) : privée, et sans dépendance d'ordre — une
          // requête ne joint rien d'autre du magasin.
          'my_interactions',
          // Les cinq d'« Échanges » (#96) ferment la marche, dans l'ordre que le
          // cadrage donne. `profiles` avant `group_messages` est la seule
          // contrainte d'ordre qu'il écrit en toutes lettres : elle nomme ce que
          // les messages désignent. `group_members` après `groups`, par la règle
          // du pivot. Et `group_messages` en dernier — la plus volumineuse des
          // cinq, et celle dont le périmètre se calcule.
          'profiles',
          'groups',
          'group_members',
          'group_join_requests',
          // Ma lecture (#140), **avant** le fil : arrivée après lui, elle
          // allumerait tout l'historique en non-lu le temps d'un tirage.
          'group_reads',
          // Mon rangement (#146, M8) : il ne fait que classer des discussions.
          'group_arrangements',
          'group_messages',
          // L'accusé de mes messages (#142, M3), **après** le fil : une coche
          // n'a de sens que sur un message déjà là.
          'message_receipts',
        ],
        reason: 'ça ne supprime pas la fenêtre où un enseignement arrive sans '
            'son intervenant — la jointure de lecture reste tolérante pour '
            'cette raison — mais ça supprime le cas fréquent : la toute '
            'première synchronisation',
      );
    });

    test('les deux référentiels précèdent leurs deux contenus', () {
      // La règle est « référentiels avant contenu », pas « chaque référentiel
      // juste avant son contenu » : ce qui compte est qu'aucune collection de
      // contenu ne soit tirée avant le référentiel dont elle dépend.
      final keys = syncedCollections().map((c) => c.key).toList();

      expect(
          keys.indexOf('teaching_types'), lessThan(keys.indexOf('teachings')));
      expect(
        keys.indexOf('gathering_types'),
        lessThan(keys.indexOf('gatherings')),
      );
      expect(keys.indexOf('contributors'), lessThan(keys.indexOf('teachings')));
      expect(
          keys.indexOf('contributors'), lessThan(keys.indexOf('gatherings')));
      // Les annonces obéissent à la même règle : une annonce dont le compte
      // manque s'affiche quand même — la jointure est tolérante —, mais elle
      // s'affiche **sans en-tête**, ce qu'un fidèle lit comme une donnée perdue.
      expect(
        keys.indexOf('official_accounts'),
        lessThan(keys.indexOf('announcements')),
      );
      expect(
        keys.indexOf('status_backgrounds'),
        lessThan(keys.indexOf('announcements')),
      );
      // Le pivot des invités (#77) se joint aux **deux** collections qu'il
      // relie, et se range donc après les deux : ses colonnes ne désignent rien
      // par elles-mêmes, et le tirer avant l'une ou l'autre donnerait, à la
      // toute première synchronisation, une liste d'invités que le magasin ne
      // saurait pas nommer.
      expect(
        keys.indexOf('contributors'),
        lessThan(keys.indexOf('teaching_guests')),
      );
      expect(
        keys.indexOf('teachings'),
        lessThan(keys.indexOf('teaching_guests')),
      );
      // Le vocabulaire se range avec les référentiels, et **avant tout
      // contenu** : un mot doit être arrivé avant la liste qu'il intitule,
      // faute de quoi une section s'affiche sous le mot du dépôt puis change de
      // titre sous les yeux du fidèle au cycle suivant.
      expect(
        keys.indexOf('presentation_vocabulary'),
        lessThan(keys.indexOf('teachings')),
      );
      expect(
        keys.indexOf('presentation_vocabulary'),
        lessThan(keys.indexOf('gatherings')),
      );
      expect(
        keys.indexOf('presentation_vocabulary'),
        lessThan(keys.indexOf('announcements')),
      );
      // Les **entrées de menu** (#82) se rangent juste après le vocabulaire, et
      // avant tout contenu : c'est le menu qui dit quels onglets existent et ce
      // que chacun filtre, donc il doit arriver **avant les listes qu'il
      // intitule** — sinon la médiathèque s'ouvre une fois sans aucun onglet,
      // puis en pousse quatre sous les yeux du fidèle.
      expect(
        keys.indexOf('menu_entries'),
        lessThan(keys.indexOf('teachings')),
      );
      expect(
        keys.indexOf('menu_entries'),
        lessThan(keys.indexOf('gatherings')),
      );
      expect(
        keys.indexOf('menu_entries'),
        lessThan(keys.indexOf('announcements')),
      );
      // Les canaux de connexion se rangent avec les référentiels eux aussi, et
      // avant tout contenu : c'est la première chose qu'un porteur **sans
      // compte** a besoin de savoir, et une erreur autre qu'un 404 sur une
      // collection de contenu emporterait tout ce qui est rangé après elle.
      expect(
        keys.indexOf('auth_channels'),
        lessThan(keys.indexOf('teachings')),
      );
      expect(
        keys.indexOf('auth_channels'),
        lessThan(keys.indexOf('announcements')),
      );
      // Le réglage d'exploitation du parc (#91) se range avec les référentiels
      // pour la même raison : une erreur autre qu'un 404 sur une collection de
      // contenu emporterait tout ce qui est rangé après elle, et le seuil du
      // bandeau vaut pour tout le monde — porteur sans compte compris.
      expect(
        keys.indexOf('device_settings'),
        lessThan(keys.indexOf('teachings')),
      );
      expect(
        keys.indexOf('device_settings'),
        lessThan(keys.indexOf('announcements')),
      );
      // La reprise de lecture se joint aux **deux** familles de contenu, et se
      // range donc après elles : une progression arrivée avant son enseignement
      // n'aurait rien à quoi se raccrocher.
      expect(
        keys.indexOf('teachings'),
        lessThan(keys.indexOf('playback_progress')),
      );
      expect(
        keys.indexOf('gatherings'),
        lessThan(keys.indexOf('playback_progress')),
      );
    });

    test(
      'un cycle complet ramène la progression de lecture, telle que servie',
      () async {
        server
          ..serveManifest(manifestFromZero())
          ..serveCollection('playback_progress', playbackProgressPage());

        await engineOver(['playback_progress'], limit: 200).synchronize();

        final rows = await db.select(db.playbackProgress).get();
        expect(rows, hasLength(2));

        final resumed = rows.firstWhere(
          (r) => r.id == '019f6b00-0000-7000-8000-000000000001',
        );
        expect(resumed.teachingId, '019f2c40-0000-7000-8000-000000000001');
        expect(resumed.positionSeconds, 942);
        expect(resumed.completed, isFalse);
        expect(resumed.userId, 'b6f0a1c2-0000-4000-8000-000000000001');

        // `completed` arrive **tel que servi** : le serveur n'a aucune durée,
        // nulle part, et n'a donc pas pu le calculer — il stocke le booléen
        // qu'un client lui a envoyé.
        final finished = rows.firstWhere(
          (r) => r.id == '019f6b00-0000-7000-8000-000000000002',
        );
        expect(finished.completed, isTrue);
        expect(finished.positionSeconds, 3600);
      },
    );

    test(
      'un cycle complet peuple les annonces et leurs deux référentiels',
      () async {
        server
          ..serveManifest(manifestFromZero())
          ..serveCollection('status_backgrounds', statusBackgroundsPage())
          ..serveCollection('official_accounts', officialAccountsPage())
          ..serveCollection('official_account_memberships', membershipsPage())
          ..serveCollection('announcements', mixedAnnouncementsPage());

        await engineOver([
          'status_backgrounds',
          'official_accounts',
          'official_account_memberships',
          'announcements',
        ], limit: 200)
            .synchronize();

        expect(
          (await db.select(db.announcements).get()).map((r) => r.id),
          const [
            '019f5a00-0000-7000-8000-000000000001',
            '019f5a00-0000-7000-8000-000000000002',
          ],
        );
        // La rétractation a été triée avant toute construction : rien n'en est
        // resté, pas même un titre.
        expect(
          (await db.select(db.announcements).get()).map((r) => r.id),
          isNot(contains('019f5a00-0000-7000-8000-000000000009')),
        );

        // Le fond retiré du catalogue est stocké quand même : `isActive` est
        // une donnée, pas un filtre — les annonces qui le portent gardent leur
        // habillage.
        final backgrounds = await db.select(db.statusBackgrounds).get();
        expect(backgrounds, hasLength(3));
        expect(backgrounds.firstWhere((b) => b.id == 3).isActive, isFalse);
        // Les arrêts du dégradé arrivent **dérivés**, et sont stockés bruts.
        final brand = backgrounds.firstWhere((b) => b.id == 1);
        expect(brand.topColor, '#2E4CAE');
        expect(brand.bottomColor, '#16265C');
        expect(brand.ink, 'light');

        expect(await db.select(db.officialAccounts).get(), hasLength(2));
        expect(
          await db.select(db.officialAccountMemberships).get(),
          hasLength(1),
        );
      },
    );

    test(
      'un cycle complet remplit les deux familles sans jamais les mélanger',
      () async {
        server
          ..serveManifest(manifestFromZero())
          ..serveCollection('teaching_types', teachingTypesPage())
          ..serveCollection('gathering_types', gatheringTypesPage())
          ..serveCollection('teachings', mixedTeachingsPage())
          ..serveCollection('gatherings', mixedGatheringsPage());

        await engineOver([
          'teaching_types',
          'gathering_types',
          'teachings',
          'gatherings',
        ], limit: 200)
            .synchronize();

        // Chaque canal a rempli **sa** table, et rien d'autre. C'est ce que
        // garantit « la clé de collection est le discriminant » : la ligne se
        // range d'après le canal par lequel elle est arrivée.
        expect(
          (await db.select(db.teachings).get()).map((r) => r.id),
          containsAll(const [
            '019f2c40-0000-7000-8000-000000000001',
            '019f2c40-0000-7000-8000-000000000003',
          ]),
        );
        expect(
          (await db.select(db.gatherings).get()).map((r) => r.id),
          const [
            '019f3a10-0000-7000-8000-000000000001',
            '019f3a10-0000-7000-8000-000000000002',
          ],
        );

        // Les rétractations des deux flux ont été triées avant toute
        // construction : elles n'ont laissé aucune ligne derrière elles.
        expect(
          (await db.select(db.gatherings).get()).map((r) => r.id),
          isNot(contains('019f3a10-0000-7000-8000-000000000009')),
        );

        // Les deux référentiels sont distincts et chacun a ses curseurs.
        expect(await db.select(db.gatheringTypes).get(), hasLength(2));
        expect(await db.select(db.teachingTypes).get(), hasLength(3));
        expect(await dao.cursorFor(SyncCollectionKey.gatherings), isNotNull);
        expect(
          await dao.cursorFor(SyncCollectionKey.gatheringTypes),
          isNotNull,
        );
      },
    );

    test('les tirages partent dans cet ordre', () async {
      server
        ..serveManifest(manifestFromZero())
        ..serveCollection('teaching_types', teachingTypesPage())
        ..serveCollection('contributors', contributorsPage())
        ..serveCollection('branches', branchesPage())
        ..serveCollection('teachings', mixedTeachingsPage());

      await engineOver([
        'teaching_types',
        'contributors',
        'branches',
        'teachings',
      ]).synchronize();

      expect(
        server.requests.map((r) => r.uri.path),
        [
          '/sync',
          '/sync/teaching_types',
          '/sync/contributors',
          '/sync/branches',
          '/sync/teachings',
        ],
      );
    });
  });

  group('Le manifeste décide, le tirage exécute', () {
    test(
        '`has_changes: false` : aucun tirage, et le `current_cursor` n\'est '
        'pas adopté', () async {
      server.serveManifest(manifestNothingToPull());

      final report = await engineOver(['branches', 'teachings']).synchronize();

      expect(report.untouched, ['branches', 'teachings']);
      expect(server.requestsFor('branches'), isEmpty);
      expect(server.requestsFor('teachings'), isEmpty);
      // Le `current_cursor` du manifeste est la **borne haute du périmètre**,
      // pas un accusé de réception : l'adopter ferait avancer un curseur sur
      // des lignes jamais appliquées.
      expect(await dao.cursorFor(SyncCollectionKey.branches), isNull);
      // La version de périmètre, elle, est retenue : le cycle est allé au bout.
      expect(await dao.readScopeVersion(), 4);
    });

    test('une collection absente du manifeste n\'est pas tirée', () async {
      // Le registre serveur ne connaît pas encore cette clé ; le client ne la
      // devine pas et n'invente pas de requête.
      server.serveManifest({
        'scope_version': 4,
        'collections': [
          manifestEntry('branches', partition: 'reference', hasChanges: true),
        ],
      });
      server.serveCollection('branches', branchesPage());

      final report = await engineOver(['branches', 'teachings']).synchronize();

      expect(report.pulled, ['branches']);
      expect(report.untouched, ['teachings']);
      expect(server.requestsFor('teachings'), isEmpty);
    });
  });

  group('Ce que le magasin reçoit — on stocke ce que le serveur envoie', () {
    setUp(() {
      server
        ..serveManifest(manifestFromZero())
        ..serveCollection('teaching_types', teachingTypesPage())
        ..serveCollection('teachings', mixedTeachingsPage());
    });

    test('la carte de traduction est écrite entière, pas repliée', () async {
      await engineOver(['teaching_types']).synchronize();

      final hero = await (db.select(db.teachingTypes)
            ..where((t) => t.id.equals(1)))
          .getSingle();
      expect(hero.label, {
        'fr': 'Message du dimanche',
        'en': 'Sunday message',
        'ee': 'Kɔsiɖagbe ƒe nya',
      });
    });

    test('une rubrique masquée est stockée, pas filtrée', () async {
      await engineOver(['teaching_types']).synchronize();

      final hidden = await (db.select(db.teachingTypes)
            ..where((t) => t.id.equals(3)))
          .getSingle();
      expect(hidden.visibleOnHome, isFalse);
      expect(hidden.layout, 'list');
    });

    test(
        'la couleur reste brute, le jour reste un jour, l\'image reste '
        'relative', () async {
      await engineOver(['teachings']).synchronize();

      final national = await (db.select(db.teachings)
            ..where(
              (t) => t.id.equals(teachingWithoutColorPayload['id']! as String),
            ))
          .getSingle();

      // `null` = « hérite de ma rubrique » : la cascade se termine à la
      // lecture, jamais à l'écriture.
      expect(national.color, isNull);
      // `null` = **national**, pas « inconnu ».
      expect(national.branchId, isNull);
      // Un jour de calendrier, en texte : le lire en instant le décalerait.
      expect(national.recordedAt, '2026-04-19');
      // Relative : la résolution contre la base d'API appartient au client.
      expect(national.imageLandscapeUrl, startsWith('/uploads/'));

      final sansMedia = await (db.select(db.teachings)
            ..where(
              (t) =>
                  t.id.equals(teachingWithoutPlaylistPayload['id']! as String),
            ))
          .getSingle();
      expect(sansMedia.playlistUrl, isNull);
      expect(sansMedia.isLive, isTrue);
    });

    test('le contrat `download` est stocké entier, ou nul si absent', () async {
      await engineOver(['teachings']).synchronize();

      // L'enseignement complet porte son contrat de téléchargement (ADR-0038) :
      // version, durée, et une rendition par qualité avec url + bytes — les
      // tailles que le moteur de téléchargement connaîtra **hors ligne**.
      final full = await (db.select(db.teachings)
            ..where((t) => t.id.equals(fullTeachingPayload['id']! as String)))
          .getSingle();
      final download = full.download;
      expect(download, isNotNull);
      expect(download!.version, '019f2c40-aac-0001');
      expect(download.durationSeconds, 3600);
      expect(download.renditions.keys.toSet(), {'low', 'mid', 'high'});
      expect(download.renditions['mid']!.bytes, 57600000);
      expect(
        download.renditions['high']!.url,
        endsWith('/high.aac'),
      );

      // Un enseignement sans `.aac` : `download` nul, « pas téléchargeable » —
      // et ça ne casse pas la page (le champ est tolérant, additif).
      final sansMedia = await (db.select(db.teachings)
            ..where(
              (t) =>
                  t.id.equals(teachingWithoutPlaylistPayload['id']! as String),
            ))
          .getSingle();
      expect(sansMedia.download, isNull);
    });

    test('les instants sont analysés, jamais comparés comme des chaînes',
        () async {
      await engineOver(['teachings']).synchronize();

      final row = await (db.select(db.teachings)
            ..where((t) => t.id.equals(fullTeachingPayload['id']! as String)))
          .getSingle();

      // L'orthographe du décalage (`Z` ou `+00:00`) dépend du fuseau du
      // processus serveur et ne fait pas partie du contrat : on compare des
      // **instants**. Le magasin les range en secondes d'époque et les rend
      // dans le fuseau de l'appareil — l'instant, lui, est le bon.
      expect(
        row.publishedAt!.isAtSameMomentAs(DateTime.utc(2026, 4, 5, 18)),
        isTrue,
      );
      expect(
        row.updatedAt!.isAtSameMomentAs(DateTime.utc(2026, 4, 5, 18)),
        isTrue,
      );
    });
  });

  group('`legal_documents` — un référentiel de plus, sans exception', () {
    setUp(() {
      server
        ..serveManifest(manifestFromZero())
        ..serveCollection('legal_documents', legalDocumentsPage());
    });

    test('les trois genres arrivent d\'un coup : aucun filtre de périmètre',
        () async {
      await engineOver(['legal_documents'], limit: 200).synchronize();

      final rows = await db.select(db.legalDocuments).get();
      expect(rows.map((r) => r.kind).toSet(), {'cgu', 'privacy', 'about'});
    });

    test('les sections sont écrites entières, jamais repliées', () async {
      // Le point qui décide de tout le reste : `resolveLegalLocale` a besoin de
      // **voir toutes les cartes** pour trancher (ADR-0035). En figer une à
      // l'écriture rendrait la règle inapplicable — et invisible.
      await engineOver(['legal_documents'], limit: 200).synchronize();

      final terms = await (db.select(db.legalDocuments)
            ..where((t) => t.kind.equals('cgu')))
          .getSingle();

      expect(terms.sections.map((s) => s.key), ['objet', 'contact']);
      expect(terms.sections.first.heading, {
        'fr': 'Objet',
        'en': 'Purpose',
        'ee': 'Taɖodzinu',
      });
    });

    test('`lastMandatoryVersion` traverse, `about` reste à nul', () async {
      await engineOver(['legal_documents'], limit: 200).synchronize();

      final byKind = {
        for (final row in await db.select(db.legalDocuments).get())
          row.kind: row,
      };
      expect(byKind['cgu']!.lastMandatoryVersion, 3);
      expect(byKind['privacy']!.lastMandatoryVersion, 2);
      expect(byKind['about']!.lastMandatoryVersion, isNull);
    });
  });

  group('Le client n\'efface jamais de sa propre initiative', () {
    test('une rétractation ne fait quitter que la ligne rétractée', () async {
      await dao.applyPage(
        dao.contributorsCollection,
        upserts: [contributorRow(7, 'Pasteur Komla Anani')],
        cursor: 'c-contributors',
      );
      await dao.applyPage(
        dao.teachingsCollection,
        upserts: [teachingRow(retractedTeachingPayload['id']! as String)],
        cursor: null,
      );

      server
        ..serveManifest(manifestNominal())
        ..serveCollection(
          'teachings',
          deltaPage(
            items: const [retractedTeachingPayload],
            nextCursor: teachingsCursorPage2,
          ),
        );

      await engineOver(['teachings']).synchronize();

      expect(await db.select(db.teachings).get(), isEmpty);
      // L'intervenant appartient à une **autre collection répliquée** : seul le
      // serveur peut l'en faire sortir, en le faisant voyager dans le flux.
      expect(await db.select(db.contributors).get(), hasLength(1));
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Le garde-fou de `playback_progress` (issue #43)
    //
    // Ce groupe a remplacé un test qui annonçait lui-même sa propre fin : « ce
    // client ne réplique aucune collection `private`, donc aucun chemin
    // d'effacement n'existe ; ce test tombera le jour où l'une d'elles entrera
    // au registre local, et c'est ce jour-là qu'il faudra écrire le vrai
    // garde-fou ». Ce jour est celui-ci. La garantie n'est plus structurelle,
    // elle est vérifiée.
    //
    // Pourquoi elle compte : effacer une progression la perd **sans recours**.
    // Le curseur est déjà passé devant la ligne, elle ne sera **plus jamais**
    // livrée — là où une rétractation d'enseignement se défait couramment, une
    // republication étant chose banale. La progression reste ; la ligne
    // « reprendre la lecture » disparaît d'elle-même faute d'enseignement à
    // joindre (règle 6 du magasin, la jointure tolérante).
    // ─────────────────────────────────────────────────────────────────────────

    test(
      'une rétractation d\'enseignement ne touche pas à la progression de '
      'lecture qui le vise',
      () async {
        const teachingId = '019f2c40-0000-7000-8000-000000000009';
        await dao.applyPage(
          dao.teachingsCollection,
          upserts: [teachingRow(teachingId)],
          cursor: null,
        );
        await dao.applyPage(
          dao.playbackProgressCollection,
          upserts: [
            playbackProgressRowOf({
              ...playbackProgressPayload,
              'teachingId': teachingId,
            }),
          ],
          cursor: 'c-progress',
        );

        server
          ..serveManifest(manifestNominal())
          ..serveCollection(
            'teachings',
            deltaPage(
              items: const [retractedTeachingPayload],
              nextCursor: teachingsCursorPage2,
            ),
          );

        await engineOver(['teachings']).synchronize();

        expect(await db.select(db.teachings).get(), isEmpty);
        // **La progression survit à son contenu**, et c'est tout le propos :
        // l'enseignement peut revenir, la position non.
        final kept = await db.select(db.playbackProgress).get();
        expect(kept, hasLength(1));
        expect(kept.single.teachingId, teachingId);
        expect(kept.single.positionSeconds, 942);
      },
    );

    test(
      'seul le serveur retire une progression, et seulement en la faisant '
      'voyager',
      () async {
        await dao.applyPage(
          dao.playbackProgressCollection,
          upserts: [playbackProgressRowOf(playbackProgressPayload)],
          cursor: 'c-progress',
        );

        server
          ..serveManifest(manifestNominal())
          ..serveCollection(
            'playback_progress',
            deltaPage(
              items: [
                {
                  'id': playbackProgressPayload['id'],
                  'deletedAt': '2026-05-25T09:00:00.000Z',
                },
              ],
              nextCursor: 'c-progress-2',
            ),
          );

        await engineOver(['playback_progress']).synchronize();

        // La règle n'est pas « cette table ne se vide jamais » : c'est « le
        // client ne l'efface jamais **de sa propre initiative** ». Un tombstone
        // reçu s'applique comme partout ailleurs.
        expect(await db.select(db.playbackProgress).get(), isEmpty);
      },
    );

    test(
      'aucun chemin applicatif n\'efface ni n\'écrit une ligne de '
      'playback_progress',
      () {
        // Garde-fou **de source**, sur le modèle de « jamais de polling »
        // (`sync_scheduler_test.dart`). Une écriture applicative dans une
        // collection répliquée ne casse aucun test de comportement : elle est
        // simplement écrasée au cycle suivant, et le bug qui en résulte est
        // irreproductible — la position revient parfois, selon que la synchro
        // est passée ou non.
        //
        // Le moteur, lui, n'écrit **jamais** en nommant la table : il passe par
        // `LocalCollection.table`, donc par `delete(collection.table)` et
        // `into(collection.table)`. Nommer `playbackProgress` dans un `delete`,
        // un `into` ou un `update` est donc, par construction, le fait de
        // quelqu'un d'autre que la synchronisation.
        const forbidden = [
          'delete(playbackProgress)',
          'into(playbackProgress)',
          'update(playbackProgress)',
        ];

        final sources = Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'));

        expect(sources, isNotEmpty);
        for (final source in sources) {
          // Les commentaires sont retirés : ils **parlent** de l'interdiction,
          // ils ne l'enfreignent pas.
          final code = source
              .readAsLinesSync()
              .where((line) => !line.trimLeft().startsWith('//'))
              .join('\n');

          for (final fragment in forbidden) {
            expect(
              code,
              isNot(contains(fragment)),
              reason: '${source.path} écrit dans une collection répliquée : la '
                  'position à chaud va dans `local_playback_positions`, et le '
                  'serveur en est informé par '
                  '`POST /teachings/:teachingId/progress`',
            );
          }
        }
      },
    );
  });

  group('Une ligne mutilée coûte sa page, pas le magasin', () {
    test(
        'un enseignement sans titre rejette la page entière, curseur '
        'compris', () async {
      server
        ..serveManifest(manifestNominal())
        ..serveCollection(
          'teachings',
          deltaPage(
            items: const [
              fullTeachingPayload,
              // Ni une rétractation (pas de `deletedAt`), ni une ligne
              // complète : le serveur n'en sert pas, et si cela arrivait, mieux
              // vaut échouer bruyamment qu'écrire une ligne mutilée dans le
              // magasin qui peint les écrans.
              {'id': '019f2c40-0000-7000-8000-0000000000ee'},
            ],
            nextCursor: teachingsCursorPage3,
          ),
        );

      await expectLater(
        engineOver(['teachings']).synchronize(),
        throwsA(isA<MalformedSyncRow>()),
      );

      expect(await db.select(db.teachings).get(), isEmpty);
      expect(await dao.cursorFor(SyncCollectionKey.teachings), isNull);
      expect(await dao.readScopeVersion(), isNull);
    });
  });
}
