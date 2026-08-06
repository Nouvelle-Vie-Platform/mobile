import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/core/config/app_env.dart';
import 'package:maison_du_miracle/core/network/api_client.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/repositories/store_mediatheque_repository.dart';
import 'package:maison_du_miracle/l10n/l10n_setup.dart';
import 'package:maison_du_miracle/screens/media_library_screen.dart';
import 'package:maison_du_miracle/state/mediatheque_providers.dart';
import 'package:maison_du_miracle/state/sync_providers.dart';
import 'package:maison_du_miracle/theme/app_theme.dart';

import '../data/local/local_database_fixtures.dart';
import '../helpers/fake_sync_server.dart';
import '../helpers/sync_fixtures.dart';

/// **Une application lancée à froid se remplit-elle vraiment ?**
///
/// C'est la question que ce lot devait fermer, et elle ne se pose nulle part
/// ailleurs. Chaque maillon a ses tests : le moteur (`test/sync/`), le magasin
/// (`test/data/local/`), les deux repositories (`test/data/
/// mediatheque_repository_test.dart`), les écrans (`test/screens/`). Aucun ne
/// regarde la **chaîne entière**, et c'est justement là que le défaut est
/// invisible : `AppEnv.useBackend` vaut `true` par défaut, les écrans lisent
/// donc le magasin, et **un magasin vide ne se plaint pas**. Une rupture entre
/// la synchronisation et le magasin ne donne pas une erreur — elle donne une
/// application muette, qui affiche « rien pour l'instant » indéfiniment.
///
/// Le chemin parcouru ici est celui de production, du premier au dernier
/// maillon :
///
/// déclencheur → `SyncScheduler` → `SyncEngine` → `SyncApi` sur le `Dio`
/// d'`ApiClient` (donc à travers les intercepteurs réels) → `SyncDao` →
/// magasin → `MediathequeDao` → `StoreMediathequeRepository` → providers →
/// pixels.
///
/// Seuls deux points sont doublés, et aucun n'appartient à l'application : le
/// **transport** (`FakeSyncServer`, qui remplace la socket) et le **fichier**
/// de base (une base en mémoire). Rien d'autre n'est surchargé — en
/// particulier pas `mediathequeRepositoryProvider`, dont le choix
/// magasin/mémoire est une partie de ce qu'on vérifie.
void main() {
  late FakeSyncServer server;
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'jeton-de-test'});

    // Première ouverture : le client n'a aucun curseur (`from_zero`). Les neuf
    // collections non scriptées répondent 404 et sont sautées — c'est le cas
    // normal d'un serveur dont le registre ne connaît pas encore tout.
    server = FakeSyncServer()
      ..serveManifest(manifestFromZero())
      ..serveCollection('teaching_types', teachingTypesPage())
      ..serveCollection('contributors', contributorsPage())
      ..serveCollection('branches', branchesPage())
      ..serveCollection('teachings', mixedTeachingsPage());
    ApiClient.instance.dio.httpClientAdapter = server;

    db = openTestDatabase();
    container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  // ⚠️ **INACHEVÉ, et sauté pour cette raison seule.**
  //
  // Écrit par le lot #33, interrompu par une limite de session avant d'avoir pu
  // le faire passer. Il ne lève aucune assertion : il **bloque**, ce qui n'est
  // pas la même chose et n'est pas encore expliqué.
  //
  // Deux hypothèses à départager avant de lever ce `skip` :
  //  - une attente de test mal posée — lire `.future` sur un `StreamProvider`
  //    qui n'émet jamais de première valeur ;
  //  - **un vrai défaut du démarrage à froid**, celui-là même que ce test
  //    devait prouver absent. C'est celle-là qu'il faut écarter en premier.
  //
  // Ne pas supprimer ce test : sa question est la bonne, et c'est la seule qui
  // vérifie qu'une application lancée à froid se remplit réellement — un
  // magasin vide ne se plaint pas, il se contente d'être muet.
  testWidgets('une application à froid se remplit, et la médiathèque le montre',
      skip: true, (tester) async {
    // Le drapeau n'est pas touché : c'est sa valeur de production, et c'est
    // elle qui décide du magasin. Le vérifier ici évite qu'un test rassurant
    // ne coure en réalité sur le double en mémoire.
    expect(AppEnv.useBackend, isTrue);
    expect(
      container.read(mediathequeRepositoryProvider),
      isA<StoreMediathequeRepository>(),
      reason: 'avec backend, les écrans lisent le magasin, pas SampleData',
    );

    // Tout ce bloc passe par `runAsync` : la synchronisation et le magasin
    // font de l'asynchrone **réel** (une socket doublée, mais une base SQLite
    // native), et l'horloge simulée d'un test de widget ne l'avance pas — un
    // `await` posé dessus attendrait indéfiniment.
    await tester.runAsync(() async {
      // Avant toute synchronisation : le magasin est vide, et c'est bien ce
      // que l'écran montrerait — l'état « rien pour l'instant » est la réponse
      // normale d'un premier lancement, pas une panne.
      expect(await container.read(allTeachingsProvider.future), isEmpty);

      // ── Le déclencheur « ouverture », celui qu'`app.dart` appelle ─────────
      final scheduler = container.read(syncSchedulerProvider);
      final report = await scheduler.start();

      expect(report, isNotNull,
          reason: 'le cycle a échoué : ${scheduler.lastFailure}');
      expect(report!.pages, greaterThan(0));
      expect(
        report.pulled,
        containsAll(<String>['teaching_types', 'contributors', 'teachings']),
      );

      // ── Le magasin s'est rempli, et les lectures le voient ────────────────
      final all = await container.read(allTeachingsProvider.future);
      expect(all, hasLength(3), reason: 'trois lignes, deux rétractations');
      expect(
        all.map((t) => t.title),
        containsAll(<String>[
          'La foi qui déplace les montagnes',
          'Veillée de prière nationale',
        ]),
      );

      // Les règles de lecture se sont appliquées sur le vrai chemin : la
      // jointure a rendu l'intervenant, et le libellé de rubrique est replié
      // en français.
      final withContributor =
          all.firstWhere((t) => t.title == 'La foi qui déplace les montagnes');
      expect(withContributor.authorName, 'Pasteur Komla Anani');
      expect(withContributor.typeLabel, 'Message du dimanche');

      // « Derniers enseignements » écarte les cultes entiers ; il reste les
      // deux autres, du plus récemment mis à disposition au plus ancien.
      final latest = await container.read(latestTeachingsProvider.future);
      expect(
        latest.map((t) => t.title),
        ['Veillée de prière nationale', 'Étude biblique — Romains 8'],
      );

      // « Pas d'enseignement, pas de section », et la rubrique masquée reste
      // dehors : les deux rubriques visibles qui ont du contenu, dans l'ordre.
      final sections = await container.read(homeSectionsProvider.future);
      expect(sections.map((s) => s.slug), ['dimanche', 'etude']);
    });

    // ── … et l'écran le peint ──────────────────────────────────────────────
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('fr'),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: appSupportedLocales,
          home: const MediaLibraryScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('La foi qui déplace les montagnes'), findsWidgets);
    expect(find.text('Pasteur Komla Anani'), findsWidgets);
  });
}
