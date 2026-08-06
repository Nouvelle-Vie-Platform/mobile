import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/core/config/app_env.dart';
import 'package:maison_du_miracle/core/network/api_client.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/repositories/store_mediatheque_repository.dart';
import 'package:maison_du_miracle/l10n/l10n_setup.dart';
import 'package:maison_du_miracle/models/mediatheque_view.dart';
import 'package:maison_du_miracle/screens/media_library_screen.dart';
import 'package:maison_du_miracle/state/mediatheque_providers.dart';
import 'package:maison_du_miracle/state/sync_providers.dart';
import 'package:maison_du_miracle/theme/app_theme.dart';

import '../data/local/local_database_fixtures.dart';
import '../helpers/fake_sync_server.dart';
import '../helpers/sync_fixtures.dart';

/// **Une application lancée à froid se remplit-elle vraiment ?**
///
/// La question ne se pose nulle part ailleurs. Chaque maillon a ses tests : le
/// moteur (`test/sync/`), le magasin (`test/data/local/`), les deux
/// repositories (`test/data/mediatheque_repository_test.dart`), les écrans
/// (`test/screens/`, sur le double en mémoire). Aucun ne regarde la **chaîne
/// entière**, et c'est là que le défaut serait invisible : `AppEnv.useBackend`
/// vaut `true` par défaut, les écrans lisent donc le magasin, et **un magasin
/// vide ne se plaint pas**. Une rupture entre la synchronisation et le magasin
/// ne donne pas une erreur — elle donne une application muette, qui affiche
/// « rien pour l'instant » indéfiniment.
///
/// Le chemin parcouru est celui de production, du premier au dernier maillon :
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
/// magasin/mémoire fait partie de ce qu'on vérifie.
///
/// ## Pourquoi deux tests, et pas un seul qui ferait tout
///
/// Le premier tourne sur l'**horloge réelle** (`test`), le second sur celle,
/// simulée, des tests de widget (`testWidgets`). Ce n'est pas un choix de
/// confort : **un cycle de synchronisation ne va pas au bout tant qu'un flux
/// Drift est écouté depuis l'horloge simulée**. Le cycle écrit en transaction,
/// et la reprise attend un tour d'horloge que `runAsync` ne donne pas — la
/// synchronisation reste suspendue indéfiniment. C'est une impasse du
/// harnais, pas de l'application : le premier test exécute exactement la même
/// chaîne, à horloge réelle, sans jamais s'y heurter.
///
/// La coupure suit donc la propriété vérifiée :
///
/// 1. **le magasin se remplit, et une écoute déjà ouverte le voit** — c'est la
///    propriété du `Stream` : un écran ouvert est un écouteur, et il reçoit ce
///    que la synchronisation écrit **sous ses pieds** ;
/// 2. **les pixels viennent bien du magasin** — la médiathèque montée sur un
///    magasin rempli par la synchronisation affiche son contenu, jointure et
///    repli de langue compris.
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

  /// Lit un `StreamProvider` **comme un écran le lirait** : en s'y abonnant
  /// d'abord.
  ///
  /// Un `StreamProvider` que personne n'écoute ne s'abonne pas à son flux, et
  /// son `.future` ne se termine alors **jamais** (Riverpod 3.3.2) — un test
  /// qui l'oublie ne casse pas, il se fige. Ce n'est pas un défaut de
  /// l'application : aucun `.future` n'est lu dans `lib/`, et un écran monté
  /// est toujours l'écouteur. C'est un piège de test, et il vaut mieux un nom
  /// qu'un commentaire.
  Future<T> readAsAScreenWould<T>(StreamProvider<T> provider) {
    final subscription = container.listen(provider, (_, __) {});
    addTearDown(subscription.close);
    return container.read(provider.future);
  }

  /// Le déclencheur « ouverture », celui qu'`app.dart` appelle au premier
  /// frame — et les vérifications qui disent que le cycle a réellement eu lieu.
  Future<void> syncFromCold() async {
    final scheduler = container.read(syncSchedulerProvider);
    addTearDown(scheduler.dispose);

    final report = await scheduler.start();

    expect(report, isNotNull,
        reason: 'le cycle a échoué : ${scheduler.lastFailure}');
    expect(report!.pages, greaterThan(0));
    expect(
      report.pulled,
      containsAll(<String>['teaching_types', 'contributors', 'teachings']),
      reason: 'référentiels avant contenu, et les quatre sont passés',
    );
  }

  test('le magasin se remplit, et une écoute déjà ouverte le voit', () async {
    // Le drapeau n'est pas touché : c'est sa valeur de production, et c'est
    // elle qui décide du magasin. Le vérifier ici évite qu'un test rassurant
    // ne coure en réalité sur le double en mémoire.
    expect(AppEnv.useBackend, isTrue);
    expect(
      container.read(mediathequeRepositoryProvider),
      isA<StoreMediathequeRepository>(),
      reason: 'avec backend, les écrans lisent le magasin, pas SampleData',
    );

    // **L'écouteur est le sujet du test, pas un détail de plomberie.** C'est
    // ce qu'est un écran ouvert : un abonné au flux du magasin. Il est posé
    // *avant* la synchronisation, comme au lancement — la médiathèque s'ouvre
    // sur un magasin vide, et c'est la synchronisation qui le remplit sous ses
    // pieds.
    final seen = <int>[];
    final subscription = container.listen<AsyncValue<List<TeachingView>>>(
      allTeachingsProvider,
      (_, next) => seen.add(next.value?.length ?? -1),
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    // Magasin neuf : « rien pour l'instant », qui est une réponse, pas une
    // panne.
    expect(await container.read(allTeachingsProvider.future), isEmpty);

    await syncFromCold();
    // Laisse le flux Drift ré-émettre vers l'écouteur.
    await Future<void>.delayed(const Duration(milliseconds: 200));

    // **Ce qu'un écran ouvert aurait vu passer** : le vide, puis les trois
    // enseignements — sans que personne n'ait rien redemandé.
    expect(seen.last, 3);
    expect(seen, contains(0),
        reason: 'le vide a bien été rendu d\'abord, ce n\'est pas un artefact');

    final all = container.read(allTeachingsProvider).value!;
    expect(all, hasLength(3),
        reason: 'trois lignes appliquées, deux rétractations écartées');

    // Les règles de lecture se sont appliquées sur le vrai chemin : la
    // jointure tolérante a rendu l'intervenant, et le libellé de rubrique est
    // replié en français.
    final withContributor =
        all.firstWhere((t) => t.title == 'La foi qui déplace les montagnes');
    expect(withContributor.authorName, 'Pasteur Komla Anani');
    expect(withContributor.typeLabel, 'Message du dimanche');

    // « Derniers enseignements » écarte les cultes entiers ; restent les deux
    // autres, du plus récemment mis à disposition au plus ancien.
    expect(
      (await readAsAScreenWould(latestTeachingsProvider)).map((t) => t.title),
      ['Veillée de prière nationale', 'Étude biblique — Romains 8'],
    );

    // « Pas d'enseignement, pas de section », et la rubrique masquée reste
    // dehors : les deux rubriques visibles qui ont du contenu, dans l'ordre.
    expect(
      (await readAsAScreenWould(homeSectionsProvider)).map((s) => s.slug),
      ['dimanche', 'etude'],
    );
  });

  testWidgets('la médiathèque peint ce que la synchronisation a écrit',
      (tester) async {
    // La synchronisation se fait **avant tout montage**, à horloge réelle :
    // aucun flux n'est encore écouté, et c'est ce qui permet au cycle d'aller
    // au bout (voir l'en-tête de ce fichier).
    await tester.runAsync(syncFromCold);

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
    // Première lecture du magasin par l'écran : asynchrone, mais sans délai
    // réel — un aller-retour par l'horloge réelle suffit à la livrer.
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();

    // Aucune surcharge de `mediathequeRepositoryProvider` ici, et ces textes
    // n'existent nulle part dans `SampleData` : s'ils s'affichent, ils
    // viennent du magasin.
    expect(find.text('La foi qui déplace les montagnes'), findsWidgets);
    expect(find.text('Pasteur Komla Anani'), findsWidgets);
  });
}
