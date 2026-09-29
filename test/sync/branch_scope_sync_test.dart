/// **La préférence de branche sur le fil, et le nettoyage qu'elle déclenche.**
///
/// Deux choses se vérifient ici, et la seconde est **le test le plus important
/// de la tranche** : c'est la seule qui tienne un contrat que le serveur ne peut
/// pas vérifier.
///
/// 1. **`branch_id` part sur les quatre collections filtrées, et sur elles
///    seules.** Le serveur ne s'en plaindrait pas s'il partait ailleurs : il
///    ignorerait le paramètre, ou filtrerait une collection qui n'a pas de
///    branche. La faute serait donc muette.
/// 2. **Changer la préférence remet à zéro les curseurs des quatre, et
///    seulement des quatre.** Le serveur ne détecte pas une préférence changée —
///    il filtre sur le paramètre de la requête, il n'a aucune mémoire de ce que
///    le client demandait au cycle précédent. Un curseur est un keyset : il ne
///    repasse jamais derrière sa borne. Si le client oublie ce nettoyage,
///    **rien ne le rattrapera** : il gardera des lignes hors périmètre, ou
///    manquera pour toujours celles qu'il aurait dû voir, sans qu'aucune erreur
///    ne soit levée et sans qu'aucun écran ne paraisse en panne.
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/core/network/api_client.dart';
import 'package:maison_du_miracle/data/branch_scope/branch_scope_store.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/local/sync_dao.dart';
import 'package:maison_du_miracle/data/sync/branch_filter.dart';
import 'package:maison_du_miracle/data/sync/sync_api.dart';
import 'package:maison_du_miracle/data/sync/sync_engine.dart';
import 'package:maison_du_miracle/data/sync/synced_collection.dart';

import '../data/local/local_database_fixtures.dart';
import '../helpers/fake_sync_server.dart';
import '../helpers/sync_fixtures.dart';

/// Les collections tirées dans ces tests : **une de chaque famille**.
///
/// Quatre filtrées (`official_accounts`, `teachings`, `gatherings`,
/// `announcements`) et quatre non filtrées — un référentiel de contenu
/// (`teaching_types`), un référentiel d'assemblées (`branches`), et les deux
/// `private` (`official_account_memberships`, `playback_progress`). Prendre une
/// de chaque plutôt que les douze garde le test lisible tout en couvrant chaque
/// raison qu'une collection a d'être dans la liste ou non.
const List<String> _keys = [
  'teaching_types',
  'official_accounts',
  'official_account_memberships',
  'branches',
  'teachings',
  'gatherings',
  'announcements',
  'playback_progress',
];

void main() {
  late FakeSyncServer server;
  late Dio dio;
  late AppDatabase db;
  late SyncDao dao;
  late BranchScopeStore store;

  setUp(() {
    server = FakeSyncServer();
    dio = Dio(BaseOptions(baseUrl: 'https://eenv.brainsial.com'))
      ..interceptors.add(unwrapEnvelopeInterceptor)
      ..httpClientAdapter = server;
    db = openTestDatabase();
    dao = db.syncDao;
    store = BranchScopeStore(db);

    // **Le manifeste n'est PAS scripté ici.** Chaque groupe le fait, dans
    // l'ordre qu'il veut : le double sert ses réponses en file et répète la
    // dernière, donc un manifeste posé d'office empêcherait tout test de faire
    // refuser la **première** requête d'un cycle — or c'est exactement là que le
    // 422 de branche inconnue se produit.
    server
      ..serveCollection('teaching_types', teachingTypesPage())
      ..serveCollection('official_accounts', officialAccountsPage())
      ..serveCollection('official_account_memberships', membershipsPage())
      ..serveCollection('branches', branchesPage())
      ..serveCollection('teachings', mixedTeachingsPage())
      ..serveCollection('gatherings', mixedGatheringsPage())
      ..serveCollection('announcements', mixedAnnouncementsPage())
      ..serveCollection('playback_progress', playbackProgressPage());
  });

  tearDown(() => db.close());

  SyncEngine engine() => SyncEngine(
        api: SyncApi(dio: dio),
        dao: dao,
        collections: syncedCollections()
            .where((collection) => _keys.contains(collection.key))
            .toList(growable: false),
        branchId: store.read,
        onUnknownBranch: (_) => store.forget(),
      );

  /// Le manifeste nominal, servi une fois — et répété ensuite, comme un serveur
  /// stable à qui l'on redemanderait la même chose.
  void nominalManifest() => server.serveManifest(manifestFromZero());

  /// Le `branch_id` réellement parti sur une collection, `null` s'il n'y était
  /// pas. On lit la **query string**, pas une intention.
  Object? sentBranchFor(String collection) =>
      server.requestsFor(collection).last.queryParameters['branch_id'];

  group('Le registre des collections filtrées', () {
    test('quatre, nommées, et ni `events` ni le mur de prière', () {
      // Le registre est la source de vérité de trois consommateurs — ce que
      // `SyncApi` envoie, ce que `SyncEngine` filtre, ce que le magasin remet à
      // zéro. Le figer ici est ce qui empêche qu'un cinquième nom s'y glisse sans
      // que la remise à zéro le suive.
      expect(kBranchScopedCollections, hasLength(4));
      expect(
        kBranchScopedCollections,
        containsAll([
          SyncCollectionKey.officialAccounts,
          SyncCollectionKey.teachings,
          SyncCollectionKey.gatherings,
          SyncCollectionKey.announcements,
        ]),
      );
      // `events` et le mur de prière gardent le cloisonnement du serveur. Ils ne
      // sont d'ailleurs pas répliqués par ce client, et l'agenda porte son propre
      // `branch_id` sur sa route REST — deux réglages voisins qu'il ne faut pas
      // confondre.
      expect(kBranchScopedCollections, isNot(contains('events')));
      expect(kBranchScopedCollections, isNot(contains('prayer_wall')));
      // Les appartenances sont scopées sur l'acteur : les filtrer par branche
      // retirerait à quelqu'un ses propres comptes.
      expect(
        kBranchScopedCollections,
        isNot(contains(SyncCollectionKey.officialAccountMemberships)),
      );
      expect(
        kBranchScopedCollections,
        isNot(contains(SyncCollectionKey.playbackProgress)),
      );
      // Le pivot des invités (#77) est `partition: 'reference'` côté serveur :
      // il ne porte pas de `branch_id`. Le filtrer exigerait une jointure sur
      // son parent, pour un résultat que le client obtient gratuitement en
      // joignant contre sa copie de `teachings`.
      expect(
        kBranchScopedCollections,
        isNot(contains(SyncCollectionKey.teachingGuests)),
      );
      expect(kBranchScopedCollections, isNot(contains('branches')));
    });

    test('le descripteur dérive du registre, il ne le recopie pas', () {
      for (final collection in syncedCollections()) {
        expect(
          collection.branchScoped,
          isBranchScoped(collection.key),
          reason: '${collection.key} : deux définitions divergentes du filtre '
              'feraient filtrer une collection dont on ne nettoie pas le curseur',
        );
      }
      expect(
        syncedCollections().where((c) => c.branchScoped).map((c) => c.key),
        unorderedEquals(kBranchScopedCollections),
      );
    });
  });

  group('Sans préférence', () {
    test('aucun paramètre ne part, ni sur le manifeste ni sur un tirage',
        () async {
      nominalManifest();
      final report = await engine().synchronize();

      expect(
        server.manifestRequests.single.queryParameters.containsKey('branch_id'),
        isFalse,
        reason: 'un `branch_id: null` explicite serait un paramètre de plus '
            'à valider côté serveur, pour dire ce que son absence dit déjà',
      );
      for (final key in _keys) {
        expect(
          sentBranchFor(key),
          isNull,
          reason: '$key ne doit porter aucun filtre',
        );
      }
      // Et tout arrive.
      expect(report.pulled, unorderedEquals(_keys));
      expect(report.skipped, isEmpty);
    });
  });

  group('Avec une préférence', () {
    setUp(() async {
      nominalManifest();
      await store.choose(4);
      // Le choix pose des jetons de resync ; on les lève pour que ce groupe
      // observe un **régime delta** ordinaire et non un remplacement.
      await db.delete(db.resyncTokens).go();
    });

    test('le manifeste porte le filtre', () async {
      await engine().synchronize();

      // Sur le manifeste, il change ce que le serveur déclare avoir de neuf :
      // sans lui, une collection annoncerait `has_changes` pour des lignes que
      // le tirage filtré ne rendrait pas — et le client tournerait à vide.
      expect(server.manifestRequests.single.queryParameters['branch_id'], 4);
    });

    test('les quatre filtrées le portent, les quatre autres non', () async {
      await engine().synchronize();

      for (final key in _keys) {
        expect(
          sentBranchFor(key),
          isBranchScoped(key) ? 4 : isNull,
          reason: key,
        );
      }
    });

    test('rien ne part vers `events` ni vers le mur de prière', () async {
      await engine().synchronize();

      // Le manifeste les liste (ils sont dans le registre serveur), le moteur ne
      // les tire pas : ils n'ont pas de table locale. Le filtre n'a donc aucune
      // occasion de les atteindre, et ce test le constate plutôt que de le
      // supposer.
      expect(server.requestsFor('events'), isEmpty);
      expect(server.requestsFor('prayer_wall'), isEmpty);
    });

    test('un remplacement porte le filtre lui aussi', () async {
      // Un resync re-tire **depuis zéro** : s'il partait sans filtre, il
      // reconstruirait le magasin sur le périmètre large, et le geste du fidèle
      // serait annulé par le premier `full_resync_required` du serveur.
      await dao.markForReplacement([SyncCollectionKey.teachings]);
      await engine().synchronize();

      expect(sentBranchFor('teachings'), 4);
      expect(server.requestsFor('teachings').first.queryParameters['since'],
          isNull);
    });
  });

  group('Changer la préférence remet les curseurs à zéro', () {
    setUp(() async {
      nominalManifest();
      // Un premier cycle complet : chaque collection a son curseur.
      await engine().synchronize();
      for (final key in _keys) {
        expect(await dao.cursorFor(key), isNotNull, reason: key);
      }
    });

    test('les quatre filtrées sont marquées, et **seulement** elles', () async {
      await store.choose(4);

      for (final collection in syncedCollections()) {
        expect(
          await dao.resyncToken(collection.key),
          isBranchScoped(collection.key) ? isNotNull : isNull,
          reason: '${collection.key} : marquer une collection de trop coûte un '
              're-tirage complet inutile ; en oublier une laisse des lignes '
              'hors périmètre que rien ne viendra chercher',
        );
      }
    });

    test('le curseur n\'est PAS effacé — c\'est le remplacement qui l\'écrase',
        () async {
      final before = await dao.cursorFor(SyncCollectionKey.teachings);
      await store.choose(4);

      // Effacer le curseur ferait re-tirer, donc **ré-écrire**, mais n'effacerait
      // **rien** : seul `finishResync` supprime. Et une coupure entre le geste et
      // le cycle laisserait un magasin sans borne et sans ses lignes, là où le
      // curseur laissé en place le laisse exactement où il était.
      expect(await dao.cursorFor(SyncCollectionKey.teachings), before);
    });

    test('recocher la même ligne ne déclenche rien', () async {
      await store.choose(4);
      await db.delete(db.resyncTokens).go();

      expect(await store.choose(4), isFalse);
      // Sans cette garde, ouvrir le panneau et re-cocher son assemblée
      // relancerait un remplacement complet de quatre collections — tout le
      // catalogue, en 3G, pour une étourderie.
      expect(await db.select(db.resyncTokens).get(), isEmpty);
    });

    test('revenir à « toutes » remet aussi les curseurs à zéro', () async {
      await store.choose(4);
      await db.delete(db.resyncTokens).go();

      expect(await store.choose(null), isTrue);
      // Le sens **élargissant** est le plus traître : rien ne manque à l'écran,
      // tout a l'air normal, et les enseignements des autres assemblées
      // antérieurs au curseur n'arriveront jamais.
      for (final key in kBranchScopedCollections) {
        expect(await dao.resyncToken(key), isNotNull, reason: key);
      }
      expect(await store.read(), isNull);
    });

    test('oublier une branche morte marque les quatre, comme un choix',
        () async {
      await store.choose(4);
      await db.delete(db.resyncTokens).go();

      await store.forget();

      // C'est ce que le moteur appelle sur un 422, et le nettoyage doit être le
      // même : les lignes tirées sous le filtre mort sont à **remplacer**, pas à
      // compléter.
      expect(await store.read(), isNull);
      for (final collection in syncedCollections()) {
        expect(
          await dao.resyncToken(collection.key),
          isBranchScoped(collection.key) ? isNotNull : isNull,
          reason: collection.key,
        );
      }
    });
  });

  group('Le remplacement balaie ce qui est sorti du périmètre', () {
    test('la ligne hors périmètre quitte le magasin, les autres restent',
        () async {
      // Deux pages scriptées d'avance pour `teachings` : celle du premier cycle,
      // puis **une page vide** pour le remplacement. L'ordre est explicite plutôt
      // que dépendant de la règle « la dernière réponse se répète » — un test dont
      // on doit deviner quelle réponse est servie ne prouve rien.
      nominalManifest();
      server.serveCollection('teachings', emptyPageFromZero());

      await engine().synchronize();
      expect(await db.select(db.teachings).get(), isNotEmpty);
      expect(await dao.cursorFor(SyncCollectionKey.teachings), isNotNull);

      // Une ligne que le nouveau périmètre ne contient plus. Elle est dans le
      // magasin, **derrière le curseur** : sans remise à zéro, plus jamais un
      // tirage delta ne repasserait dessus.
      await db.into(db.teachings).insert(
            teachingRow(
              '019f2c40-0000-7000-8000-0000000000de',
              title: 'Prêche d\'une autre assemblée',
            ),
          );

      await store.choose(4);
      await engine().synchronize();

      final remaining = await db.select(db.teachings).get();
      expect(
        remaining.map((row) => row.id),
        isNot(contains('019f2c40-0000-7000-8000-0000000000de')),
        reason: 'la ligne hors périmètre doit avoir été balayée par la '
            'transaction finale du remplacement',
      );
      // Le remplacement a bien eu lieu **depuis zéro**, et le jeton est levé.
      expect(
        server.requestsFor('teachings').last.queryParameters['since'],
        isNull,
      );
      expect(await dao.resyncToken(SyncCollectionKey.teachings), isNull);
      // Et les collections non filtrées n'ont rien perdu au passage.
      expect(await db.select(db.branches).get(), isNotEmpty);
      expect(await db.select(db.teachingTypes).get(), isNotEmpty);
      expect(await db.select(db.playbackProgress).get(), isNotEmpty);
    });
  });

  group('Une branche que le serveur ne connaît pas', () {
    test('422 : la préférence est oubliée et le cycle rejoué sans filtre',
        () async {
      await store.choose(99);
      await db.delete(db.resyncTokens).go();
      // **Le refus d'abord, la réponse saine ensuite** : le double consomme sa
      // file dans l'ordre, et répète la dernière. La première requête du cycle
      // porte donc `branch_id=99` et reçoit 422 ; la seconde, sans filtre, passe.
      server
        ..serveErrorOnManifest()
        ..serveManifest(manifestFromZero());

      final report = await engine().synchronize();

      // La branche est oubliée — sinon **tous** les cycles à venir échoueraient,
      // et toutes les collections avec eux, sans un mot à l'écran.
      expect(await store.read(), isNull);
      // Et le second passage part sans filtre.
      expect(server.manifestRequests, hasLength(2));
      expect(server.manifestRequests.first.queryParameters['branch_id'], 99);
      expect(
        server.manifestRequests.last.queryParameters.containsKey('branch_id'),
        isFalse,
      );
      expect(report.pulled.isNotEmpty || report.resynced.isNotEmpty, isTrue);
    });

    test('un 422 sans préférence remonte, il n\'invente pas de repli',
        () async {
      server.serveErrorOnManifest();

      // Sans `branch_id` envoyé, un 422 n'est pas un refus de branche : c'est une
      // panne de validation quelconque. La confondre ferait perdre au fidèle un
      // réglage qu'il n'a pas touché, en silence — et un seul rattrapage muet de
      // ce genre suffit à rendre tout ce dossier inexplicable.
      await expectLater(engine().synchronize(), throwsA(isA<DioException>()));
      expect(server.manifestRequests, hasLength(1));
    });
  });
}
