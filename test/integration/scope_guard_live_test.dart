/// **Le garde-fou de périmètre, contre un vrai serveur** (issue #31).
///
/// Le socle (#29) l'a vérifié contre des fixtures, et c'était le maximum
/// possible alors : `full_resync_required` ne se lève que sur les collections
/// `partition: 'branch'`, et aucune n'était consommée. `teachings` en est une,
/// elle est répliquée, et le chemin s'exerce enfin de bout en bout — manifeste
/// réel, tirages réels, `users.scope_version` réellement incrémentée par
/// `PUT /auth/profile`.
///
/// Le scénario, en un seul fil (les tests s'exécutent dans l'ordre déclaré et
/// se passent l'état du magasin) :
///
/// 1. un fidèle synchronise ; son magasin porte les enseignements de sa branche
///    visible ;
/// 2. son périmètre change — Home Branch modifiée ;
/// 3. le manifeste suivant marque les **seules** collections `branch` ;
/// 4. le client **remplace** `teachings`, jamais purger-puis-remplir ;
/// 5. il persiste la nouvelle `scope_version` **en dernier** — une coupure en
///    plein remplacement n'en persiste aucune, et le resync est rejoué ;
/// 6. au cycle suivant, aucun resync n'est redemandé : la boucle est fermée.
///
/// Sauté par défaut (étiquette `live-server`, cf. `dart_test.yaml`) : la CI n'a
/// pas de serveur. Marche à suivre dans `test/integration/README.md`.
@Tags(['live-server'])
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/core/network/api_client.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/local/sync_dao.dart';
import 'package:maison_du_miracle/data/sync/sync_api.dart';
import 'package:maison_du_miracle/data/sync/sync_engine.dart';
import 'package:maison_du_miracle/data/sync/synced_collection.dart';

import '../data/local/local_database_fixtures.dart';
import 'live_server.dart';

void main() {
  late LiveServer server;
  late AppDatabase db;
  late SyncDao dao;
  late Dio clientDio;
  late ManifestWireLog wire;
  late ConnectionCut cut;

  /// Jeton `api` du fidèle dont le périmètre bouge.
  late String memberToken;

  /// Les deux branches du scénario : celle d'où il part, celle où il arrive.
  late int homeBranchId;
  late int farBranchId;

  /// Les enseignements plantés pour ce run.
  ///
  /// **L'ordre de publication porte la démonstration** : ceux de la branche
  /// lointaine sont publiés **en premier**, donc leur rang de curseur est le
  /// plus ancien. Après la première synchronisation, le curseur du fidèle est
  /// posé au-delà d'eux — ils sont **derrière la borne keyset**, et aucun delta
  /// ne les ramènera jamais. C'est exactement le trou que le garde-fou existe
  /// pour combler.
  late List<String> farTeachings;
  late String nationalTeaching;
  late List<String> homeTeachings;

  /// La version de périmètre que le client a retenue après le cycle 1.
  int? retainedScopeVersion;

  /// Son curseur `teachings` après le cycle 1.
  String? teachingsCursor;

  /// Le moteur réel, restreint aux quatre collections que le client enregistre,
  /// tiré à **`limit=1`** : la boucle de rattrapage doit être exercée, et il
  /// faut au moins deux requêtes vers `teachings` pour pouvoir couper au milieu.
  SyncEngine engine() => SyncEngine(
        api: SyncApi(dio: clientDio),
        dao: dao,
        collections: syncedCollections(),
        pageLimit: 1,
      );

  Future<List<String>> storedTeachings() async =>
      (await db.select(db.teachings).get()).map((row) => row.id).toList()
        ..sort();

  List<Map<String, Object?>> entriesOf(Map<String, Object?> manifest) =>
      (manifest['collections']! as List).cast<Map<String, Object?>>();

  Map<String, Object?> entryOf(Map<String, Object?> manifest, String key) =>
      entriesOf(manifest).firstWhere((entry) => entry['key'] == key);

  setUpAll(() async {
    server = LiveServer();

    // ── L'opérateur plante le décor ────────────────────────────────────────
    final operator = await server.signIn(kLiveOperatorIdentifier);

    final branches = await server.collection(operator, 'branches');
    final branchIds = branches.map((row) => row['id']! as int).toList()..sort();
    if (branchIds.length < 2) {
      throw StateError(
        'Le scénario exige au moins deux branches ; la base en compte '
        '${branchIds.length}. Voir test/integration/README.md.',
      );
    }
    // Les deux dernières : le seeder n'en crée qu'une (l'église mère), les
    // suivantes sont celles que le README fait ajouter.
    homeBranchId = branchIds[branchIds.length - 2];
    farBranchId = branchIds.last;

    final contributors = await server.collection(operator, 'contributors');
    final types = await server.collection(operator, 'teaching_types');
    if (contributors.isEmpty || types.isEmpty) {
      throw StateError(
        'Base non amorcée : `node ace db:seed` fournit les intervenants et les '
        'rubriques dont `POST /teachings` a besoin.',
      );
    }
    final contributorId = contributors.first['id']! as int;
    final typeId = types.first['id']! as int;

    Future<String> publish(String title, int? branchId) =>
        server.publishTeaching(
          token: operator,
          title: '[#31] $title',
          branchId: branchId,
          contributorId: contributorId,
          teachingTypeId: typeId,
        );

    // L'ordre compte, cf. le commentaire de `farTeachings`.
    farTeachings = [
      await publish('lointaine — jamais modifiée A', farBranchId),
      await publish('lointaine — jamais modifiée B', farBranchId),
    ];
    nationalTeaching = await publish('nationale — visible de tous', null);
    homeTeachings = [
      await publish('proche — la plus récente C', homeBranchId),
      await publish('proche — la plus récente D', homeBranchId),
    ];

    // ── Le fidèle, sa Home Branch de départ ────────────────────────────────
    memberToken = await server.signIn(kLiveMemberIdentifier);
    await server.setHomeBranch(memberToken, homeBranchId);

    // ── Le client : magasin neuf, `Dio` réel vers le vrai serveur ──────────
    db = openTestDatabase();
    dao = db.syncDao;
    wire = ManifestWireLog();
    cut = ConnectionCut(path: '/sync/teachings', afterRequests: 1)
      ..armed = false;

    clientDio = Dio(
      BaseOptions(
        baseUrl: server.url,
        headers: {'Authorization': 'Bearer $memberToken'},
      ),
    )..interceptors.addAll([wire, cut, unwrapEnvelopeInterceptor]);
  });

  tearDownAll(() async {
    clientDio.close(force: true);
    server.close();
    await db.close();
  });

  group('Garde-fou « périmètre modifié » — serveur réel', () {
    test(
      '1 · une première synchronisation range les enseignements de la branche '
      'visible, et eux seuls',
      () async {
        final report = await engine().synchronize();

        expect(
          report.resynced,
          isEmpty,
          reason: 'Sans `scope_version` transmise, le garde-fou ne se lève pas '
              ': un magasin neuf est déjà couvert par `from_zero`.',
        );

        final stored = await storedTeachings();
        expect(stored, containsAll(homeTeachings));
        expect(stored, contains(nationalTeaching));
        for (final id in farTeachings) {
          expect(
            stored,
            isNot(contains(id)),
            reason: 'Un enseignement hors périmètre ne descend jamais.',
          );
        }

        retainedScopeVersion = await dao.readScopeVersion();
        teachingsCursor = await dao.cursorFor('teachings');
        expect(
          retainedScopeVersion,
          isNotNull,
          reason: 'Le manifeste amorce le client, même à la première synchro '
              '(ADR-0027) — sans quoi il repartirait aveugle.',
        );
        expect(teachingsCursor, isNotNull);
      },
    );

    test(
      '2-3 · le périmètre change : le manifeste rend la version courante et '
      'marque les seules collections `branch`',
      () async {
        // Le geste : la Home Branch bouge. `CompleteOnboarding` incrémente
        // `users.scope_version` — une route de l'API mobile, aucune écriture
        // directe en base.
        await server.setHomeBranch(memberToken, farBranchId);

        // ── Ce que le curseur seul rate ──────────────────────────────────
        // Les deux enseignements de la branche lointaine n'ont **pas** été
        // modifiés : leur `updated_at` n'a pas bougé, ils restent derrière la
        // borne keyset. Le delta ne les verra jamais, et c'est toute la raison
        // d'être du garde-fou.
        final missed = await server.collection(
          memberToken,
          'teachings',
          since: teachingsCursor!,
        );
        expect(
          missed,
          isEmpty,
          reason: 'Le tirage delta ne ramène rien : deux enseignements sont '
              'devenus visibles et deux invisibles, sans qu\'aucune ligne ne '
              'change. Un client qui s\'en tiendrait au curseur garderait '
              'indéfiniment le catalogue de son ancienne branche.',
        );

        // ── Ce que le manifeste, lui, dit ────────────────────────────────
        final manifest = await server.manifest(
          memberToken,
          scopeVersion: retainedScopeVersion,
          cursors: {'teachings': teachingsCursor!},
        );

        expect(
          manifest['scope_version'],
          isNot(retainedScopeVersion),
          reason: 'Le manifeste rend la version **courante**, jamais celle '
              'reçue (ADR-0027 §1). Sans cette restitution, le client ne '
              'pourrait jamais l\'apprendre.',
        );
        expect(
          manifest['scope_version'],
          greaterThan(retainedScopeVersion!),
        );

        for (final entry in entriesOf(manifest)) {
          expect(
            entry['full_resync_required'],
            entry['partition'] == 'branch',
            reason: 'La collection « ${entry['key']} » est en partition '
                '« ${entry['partition']} ».',
          );
        }
        // Nommément, puisque c'est ce que le ticket demande de constater.
        for (final key in const [
          'teaching_types',
          'contributors',
          'branches'
        ]) {
          expect(entryOf(manifest, key)['full_resync_required'], isFalse);
        }
        expect(entryOf(manifest, 'teachings')['full_resync_required'], isTrue);
      },
    );

    test(
      '5 · interrompue en plein resync, la synchronisation ne persiste aucune '
      'version — et le manifeste la redemande',
      () async {
        cut.armed = true;

        await expectLater(
          engine().synchronize(),
          throwsA(isA<DioException>()),
        );

        expect(
          await dao.readScopeVersion(),
          retainedScopeVersion,
          reason: 'Persistée trop tôt, elle éteindrait un resync qui n\'a pas '
              'eu lieu — et le manifeste ne le redemanderait **jamais**.',
        );
        expect(
          await dao.resyncToken('teachings'),
          isNotNull,
          reason: 'Le jeton survit : le remplacement est ouvert, pas terminé.',
        );

        // Le magasin n'a pas été vidé d'abord : les enseignements de l'ancienne
        // branche sont toujours là, et le seront jusqu'au balayage final.
        expect(
          await storedTeachings(),
          containsAll(homeTeachings),
          reason: 'Resync = remplacement, jamais purger-puis-remplir '
              '(ADR-0026).',
        );

        // Et le serveur, lui, le redemande — c'est ce qui rend la coupure
        // rattrapable.
        final manifest = await server.manifest(
          memberToken,
          scopeVersion: await dao.readScopeVersion(),
          cursors: await dao.allCursors(),
        );
        expect(entryOf(manifest, 'teachings')['full_resync_required'], isTrue);
      },
    );

    test(
      '4 · le resync rejoué remplace `teachings` — ce qui entre, ce qui sort',
      () async {
        cut.armed = false;

        final report = await engine().synchronize();

        expect(report.resynced, contains('teachings'));
        for (final reference in const [
          'teaching_types',
          'contributors',
          'branches',
        ]) {
          expect(
            report.resynced,
            isNot(contains(reference)),
            reason: 'Les référentiels ne dépendent pas du périmètre : delta '
                'normal.',
          );
        }

        final stored = await storedTeachings();
        // Le périmètre s'élargit : des lignes jamais modifiées apparaissent.
        expect(
          stored,
          containsAll(farTeachings),
          reason: 'Exactement ce que le curseur seul ratait.',
        );
        expect(stored, contains(nationalTeaching));
        // Le périmètre se rétrécit : elles disparaissent. C'est le sens le plus
        // facile à rater, et le plus grave — du contenu qu'un fidèle n'a plus
        // le droit de voir resterait sur son téléphone.
        for (final id in homeTeachings) {
          expect(stored, isNot(contains(id)));
        }

        expect(await dao.resyncToken('teachings'), isNull);
        expect(
          await dao.readScopeVersion(),
          greaterThan(retainedScopeVersion!),
          reason: 'Persistée **en dernier**, une fois le remplacement terminé.',
        );
        expect(report.scopeVersion, await dao.readScopeVersion());
      },
    );

    test(
      '6 · au cycle suivant, aucun resync n\'est redemandé : la boucle est '
      'fermée',
      () async {
        final before = await storedTeachings();
        final persisted = await dao.readScopeVersion();

        final report = await engine().synchronize();

        expect(
          report.resynced,
          isEmpty,
          reason: 'C\'était le trou d\'ADR-0027 côté serveur : le manifeste '
              'échoait la valeur reçue, et un client en retard se voyait '
              'redemander un resync complet à chaque synchronisation, '
              'indéfiniment.',
        );
        expect(await storedTeachings(), before);
        expect(await dao.readScopeVersion(), persisted);

        final manifest = await server.manifest(
          memberToken,
          scopeVersion: persisted,
          cursors: await dao.allCursors(),
        );
        expect(
          entriesOf(manifest)
              .where((entry) => entry['full_resync_required'] == true),
          isEmpty,
        );

        // La preuve sur le fil : la version neuve n'est rejouée qu'au dernier
        // cycle. Aux deux précédents — celui qui a été coupé et celui qui l'a
        // rattrapé — le client représentait encore l'ancienne.
        expect(
          wire.scopeVersionsSent,
          [null, retainedScopeVersion, retainedScopeVersion, persisted],
        );
      },
    );
  });
}
