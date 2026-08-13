import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/core/config/app_env.dart';
import 'package:maison_du_miracle/core/network/api_client.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/repositories/announcement_repository.dart';
import 'package:maison_du_miracle/data/repositories/branch_repository.dart';
import 'package:maison_du_miracle/data/repositories/gathering_repository.dart';
import 'package:maison_du_miracle/data/repositories/legal_repository.dart';
import 'package:maison_du_miracle/data/repositories/mediatheque_repository.dart';
import 'package:maison_du_miracle/data/repositories/store_legal_repository.dart';
import 'package:maison_du_miracle/l10n/l10n_setup.dart';
import 'package:maison_du_miracle/models/legal_document_view.dart';
import 'package:maison_du_miracle/router/app_router.dart';
import 'package:maison_du_miracle/screens/legal_acceptance_screen.dart';
import 'package:maison_du_miracle/state/announcement_providers.dart';
import 'package:maison_du_miracle/state/auth_providers.dart';
import 'package:maison_du_miracle/state/gathering_providers.dart';
import 'package:maison_du_miracle/state/legal_providers.dart';
import 'package:maison_du_miracle/state/mediatheque_providers.dart';
import 'package:maison_du_miracle/state/playback_progress_providers.dart';
import 'package:maison_du_miracle/state/sync_providers.dart';
import 'package:maison_du_miracle/theme/app_theme.dart';

import '../data/local/local_database_fixtures.dart';
import '../helpers/fake_sync_server.dart';
import '../helpers/playback_doubles.dart';
import '../helpers/signed_in_auth.dart';
import '../helpers/sync_fixtures.dart';

/// **La barrière de consentement se lève-t-elle vraiment quand il le faut, et
/// seulement là ?**
///
/// La question ne se pose nulle part ailleurs, et elle se rate en silence des
/// deux côtés : une garde trop stricte transforme le premier lancement en
/// **écran mort** (magasin vide, aucun document reçu, personne ne peut plus
/// rien faire), une garde trop lâche laisse un fidèle utiliser l'application
/// sous des conditions qu'il n'a jamais acceptées — ce que le traçage
/// existait pour empêcher (ADR-0036).
///
/// Le chemin parcouru est celui de production, du premier au dernier maillon,
/// comme `cold_start_test.dart` :
///
/// `SyncScheduler` → `SyncEngine` → `SyncApi` (intercepteurs réels) →
/// `SyncDao` → magasin → `LegalDao` → `StoreLegalRepository` →
/// `legalDocumentProvider` → `mandatoryLegalVersionsProvider` →
/// `pendingLegalAcceptancesProvider` → le `redirect`.
///
/// Seuls deux points sont doublés, et aucun n'appartient à l'application : le
/// **transport** (`FakeSyncServer`) et le **fichier** de base (une base en
/// mémoire). Le repository légal n'est **pas** surchargé : le choix
/// magasin/mémoire fait partie de ce qu'on vérifie.
void main() {
  late FakeSyncServer server;
  late AppDatabase db;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'jeton-de-test'});
    server = FakeSyncServer()
      ..serveManifest(manifestFromZero())
      ..serveCollection('legal_documents', legalDocumentsPage());
    ApiClient.instance.dio.httpClientAdapter = server;
    db = openTestDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  ProviderContainer containerFor({Map<String, int> accepted = const {}}) {
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        authRepositoryProvider
            .overrideWithValue(SignedInAuthRepository(accepted: accepted)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Abonne la garde **comme le routeur le fait** — et ce n'est pas un détail
  /// de plomberie : c'est ce `listen` qui tient le provider vivant, donc
  /// abonné au flux du magasin, donc capable de répondre **sans attendre**.
  /// Sans lui, chaque lecture repartirait d'un `AsyncValue` en chargement.
  List<String> Function() watchGate(ProviderContainer container) {
    final subscription =
        container.listen(pendingLegalAcceptancesProvider, (_, __) {});
    addTearDown(subscription.close);
    return () => container.read(pendingLegalAcceptancesProvider);
  }

  /// La session s'ouvre de façon asynchrone (cache puis revalidation) ; la
  /// garde ne dit rien de sensé avant.
  Future<void> untilSignedIn(ProviderContainer container) async {
    for (var i = 0; i < 50; i++) {
      if (container.read(authProvider).isAuthenticated) return;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    fail('la session ne s\'est jamais ouverte');
  }

  /// Le déclencheur « ouverture », celui qu'`app.dart` appelle au premier
  /// frame.
  Future<void> syncFromCold(ProviderContainer container) async {
    final scheduler = container.read(syncSchedulerProvider);
    addTearDown(scheduler.dispose);
    final report = await scheduler.start();
    expect(report, isNotNull,
        reason: 'le cycle a échoué : ${scheduler.lastFailure}');
    expect(report!.pulled, contains('legal_documents'));
    // Laisse le flux Drift ré-émettre vers l'écouteur.
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }

  test('magasin vide : aucune barrière, l\'app se comporte comme avant',
      () async {
    // Le drapeau n'est pas touché : c'est sa valeur de production, et c'est
    // elle qui décide du magasin. Le vérifier ici évite un test rassurant qui
    // courrait en réalité sur le double en mémoire.
    expect(AppEnv.useBackend, isTrue);
    final container = containerFor();
    expect(
      container.read(legalRepositoryProvider),
      isA<StoreLegalRepository>(),
      reason: 'avec backend, la barrière lit le magasin, pas SampleData',
    );

    final gate = watchGate(container);
    await untilSignedIn(container);

    // Aucune synchronisation n'a eu lieu : pas de document, donc pas de
    // plancher, donc pas de barrière. C'est le premier lancement, et il ne
    // doit surtout pas être un écran mort.
    expect(container.read(mandatoryLegalVersionsProvider), isEmpty);
    expect(gate(), isEmpty);
  });

  test('plancher présent et jamais accepté : barrière, sans « about »',
      () async {
    final container = containerFor();
    final gate = watchGate(container);
    await untilSignedIn(container);
    await syncFromCold(container);

    // Les planchers viennent du magasin, que la synchronisation a rempli.
    expect(
      container.read(mandatoryLegalVersionsProvider),
      {'cgu': 3, 'privacy': 2},
    );
    // Un genre jamais accepté est **absent** du résumé, jamais à zéro : c'est
    // cette absence-là qui bloque. Et « à propos » n'y est pas — il est bien
    // arrivé dans le magasin, il n'entre simplement jamais dans le calcul.
    expect(gate(), ['cgu', 'privacy']);
    expect(gate(), isNot(contains(LegalDocumentKind.about)));
  });

  test('accepté au plancher, et au-delà : pas de barrière', () async {
    final atFloor = containerFor(accepted: {'cgu': 3, 'privacy': 2});
    final gate = watchGate(atFloor);
    await untilSignedIn(atFloor);
    await syncFromCold(atFloor);

    expect(gate(), isEmpty);

    // Une révision plus ancienne que ce qui a été accepté ne rouvre rien : la
    // comparaison est « couvre », pas « égale ».
    final beyond = containerFor(accepted: {'cgu': 9, 'privacy': 9});
    final beyondGate = watchGate(beyond);
    await untilSignedIn(beyond);
    // Le magasin est déjà rempli — même base, second conteneur.
    expect(beyondGate(), isEmpty);
  });

  test('un seul document en retard : une seule case', () async {
    final container = containerFor(accepted: {'cgu': 3, 'privacy': 1});
    final gate = watchGate(container);
    await untilSignedIn(container);
    await syncFromCold(container);

    // La politique est passée de 1 à 2 ; les CGU sont à jour. Une entrée, donc
    // une case et un document à l'écran.
    expect(gate(), ['privacy']);
  });

  test('la comparaison, sans magasin ni session', () {
    // La règle elle-même, écrite une fois et vérifiée sans plomberie.
    expect(
      pendingLegalAcceptances(
        mandatory: {'cgu': 3},
        accepted: const {},
      ),
      ['cgu'],
      reason: 'absence d\'acceptation = jamais accepté, jamais « version 0 »',
    );
    expect(
      pendingLegalAcceptances(
        mandatory: const {},
        accepted: const {},
      ),
      isEmpty,
      reason: 'absence de document = pas de barrière',
    );
    expect(
      pendingLegalAcceptances(
        mandatory: {'cgu': 3},
        accepted: {'cgu': 3},
      ),
      isEmpty,
    );
    expect(
      pendingLegalAcceptances(
        mandatory: {'cgu': 3},
        accepted: {'cgu': 2},
      ),
      ['cgu'],
    );
  });

  testWidgets('le routeur y enferme, puis l\'écran se retire de lui-même',
      (tester) async {
    // Écran haut : la barrière rend deux documents entiers.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        authRepositoryProvider
            .overrideWithValue(SignedInAuthRepository(accepted: const {})),
        branchRepositoryProvider
            .overrideWithValue(const InMemoryBranchRepository()),
        playbackProgressReporterProvider
            .overrideWithValue(FakePlaybackProgressReporter()),
        mediathequeRepositoryProvider
            .overrideWithValue(InMemoryMediathequeRepository()),
        gatheringRepositoryProvider
            .overrideWithValue(InMemoryGatheringRepository()),
        announcementRepositoryProvider
            .overrideWithValue(InMemoryAnnouncementRepository()),
        // Le seul double du chemin de la barrière : il porte les mêmes
        // planchers que la fixture serveur, sans dépendre d'un cycle de
        // synchronisation à horloge simulée (voir l'en-tête de
        // `cold_start_test.dart`).
        legalRepositoryProvider.overrideWithValue(
          InMemoryLegalRepository(documents: _requiredDocuments),
        ),
      ],
    );
    addTearDown(container.dispose);

    // **Le routeur est écouté, pas seulement lu** — comme `app.dart`, qui en
    // fait un `ref.watch`. Ce n'est pas une précaution de test : un provider
    // que personne n'écoute est **inactif**, et Riverpod 3 met alors en pause
    // les abonnements qu'il tient — dont celui de la garde au flux du magasin.
    // Le document n'arriverait jamais, et la barrière ne se lèverait pas.
    container.listen(routerProvider, (_, __) {});
    final router = container.read(routerProvider);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light,
          locale: const Locale('fr'),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: appSupportedLocales,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    // La session s'ouvre sur `/home`… et la garde la détourne aussitôt.
    expect(find.byType(LegalAcceptanceScreen), findsOneWidget);
    expect(
      router.state.matchedLocation,
      '/legal/accept',
    );

    // **Aucune sortie** : ni le retour Android, ni une navigation explicite.
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(LegalAcceptanceScreen), findsOneWidget);

    router.go('/home');
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(
      router.state.matchedLocation,
      '/legal/accept',
      reason: 'la garde ramène à la barrière, quoi qu\'on demande',
    );

    // L'accord enregistré : c'est l'état qui change, personne ne navigue.
    await container
        .read(authProvider.notifier)
        .applyAcceptedLegal({'cgu': 3, 'privacy': 2});
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(LegalAcceptanceScreen), findsNothing);
    expect(
      router.state.matchedLocation,
      '/home',
      reason: 'l\'écran se retire par réévaluation de la garde',
    );
  });
}

/// Les deux documents exigés, avec les mêmes planchers que la fixture serveur.
final List<LegalDocument> _requiredDocuments = [
  const LegalDocument(
    kind: LegalDocumentKind.terms,
    version: 3,
    lastMandatoryVersion: 3,
    sections: [
      LegalSection(
        key: 'objet',
        heading: {'fr': 'Objet'},
        body: {'fr': 'Le **service**.'},
      ),
    ],
  ),
  const LegalDocument(
    kind: LegalDocumentKind.privacy,
    version: 2,
    lastMandatoryVersion: 2,
    sections: [
      LegalSection(
        key: 'donnees',
        heading: {'fr': 'Vos données'},
        body: {'fr': 'Nous collectons votre nom.'},
      ),
    ],
  ),
];
