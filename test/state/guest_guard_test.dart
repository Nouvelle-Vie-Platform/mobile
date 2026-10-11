import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/network/network_transport.dart';
import 'package:maison_du_miracle/data/repositories/announcement_repository.dart';
import 'package:maison_du_miracle/data/repositories/auth_repository.dart';
import 'package:maison_du_miracle/data/repositories/branch_repository.dart';
import 'package:maison_du_miracle/data/repositories/calendar_repository.dart';
import 'package:maison_du_miracle/data/repositories/gathering_repository.dart';
import 'package:maison_du_miracle/data/repositories/legal_repository.dart';
import 'package:maison_du_miracle/data/repositories/mediatheque_repository.dart';
import 'package:maison_du_miracle/l10n/l10n_setup.dart';
import 'package:maison_du_miracle/models/auth_channels.dart';
import 'package:maison_du_miracle/models/models.dart';
import 'package:maison_du_miracle/models/theme_preferences.dart';
import 'package:maison_du_miracle/router/app_router.dart';
import 'package:maison_du_miracle/screens/home_shell.dart';
import 'package:maison_du_miracle/screens/media_library_screen.dart';
import 'package:maison_du_miracle/screens/notes/note_editor_screen.dart';
import 'package:maison_du_miracle/screens/splash_screen.dart';
import 'package:maison_du_miracle/state/announcement_providers.dart';
import 'package:maison_du_miracle/state/auth_channels_providers.dart';
import 'package:maison_du_miracle/state/auth_providers.dart';
import 'package:maison_du_miracle/state/calendar_providers.dart';
import 'package:maison_du_miracle/state/downloads_providers.dart';
import 'package:maison_du_miracle/state/gathering_providers.dart';
import 'package:maison_du_miracle/state/legal_providers.dart';
import 'package:maison_du_miracle/models/media_preferences.dart';
import 'package:maison_du_miracle/state/media_settings_providers.dart';
import 'package:maison_du_miracle/state/mediatheque_providers.dart';
import 'package:maison_du_miracle/state/playback_progress_providers.dart';
import 'package:maison_du_miracle/state/startup_providers.dart';
import 'package:maison_du_miracle/state/sync_providers.dart';
import 'package:maison_du_miracle/state/theme_provider.dart';
import 'package:maison_du_miracle/theme/app_theme.dart';

import '../data/local/local_database_fixtures.dart';
import '../helpers/playback_doubles.dart';
import '../helpers/signed_in_auth.dart';

/// **La garde inversée : l'application est-elle vraiment publique par défaut,
/// et fermée là où il faut ?**
///
/// C'est l'endroit du dépôt où une erreur ne se voit pas. Un écran fermé par
/// accident ne fait rougir aucun test et **personne ne le signale** — on ne
/// réclame pas ce qu'on n'a jamais vu ; un écran ouvert par accident montre au
/// contraire une page qui suppose un compte, et plante ou ment. Les deux
/// fautes sont silencieuses, d'où deux niveaux de vérification :
///
/// 1. la garde **route par route**, dérivée de la table déclarée du routeur —
///    pas d'une liste recopiée ici. Une route ajoutée demain entre donc
///    d'office dans le test, et doit être ouverte ou explicitement réservée ;
/// 2. le **câblage**, à travers le vrai routeur monté : c'est lui qui prouve
///    que l'état d'authentification atteint le `redirect`.
void main() {
  group('la garde, route par route', () {
    late GoRouter router;

    setUp(() {
      router = _container().read(routerProvider);
    });

    test('les écrans réservés désignent tous une route réelle', () {
      // Le piège le plus bête et le plus coûteux : une entrée de
      // `memberOnlyRoutes` qui ne correspond à aucune route — faute de frappe,
      // ou chemin renommé ailleurs. L'écran se rouvre alors sans que rien ne
      // le dise, et la liste continue de prétendre le fermer.
      final declared = _declaredPaths(router).toSet();
      expect(memberOnlyRoutes.difference(declared), isEmpty);
    });

    test('un invité atteint tout, sauf la liste courte', () {
      final closed = <String>[];
      for (final pattern in _declaredPaths(router)) {
        final destination = redirectFor(
          status: AuthStatus.guest,
          location: _concrete(pattern),
          pattern: pattern,
        );
        if (pattern == '/') {
          // Le splash n'a rien à résoudre pour un invité : il va droit à
          // l'accueil, et ne se peint donc pas.
          expect(destination, '/home', reason: 'le splash, pour un invité');
          continue;
        }
        if (destination == null) continue;
        expect(
          destination,
          '/home',
          reason: '$pattern doit ramener à l\'accueil, jamais à /auth',
        );
        closed.add(pattern);
      }

      // **La liste fermée, en entier et rien de plus.** C'est ici qu'un écran
      // fermé par accident se voit : il apparaît dans `closed` et fait échouer
      // l'égalité, au lieu de disparaître silencieusement de l'application.
      expect(closed.toSet(), memberOnlyRoutes);
    });

    test('la surface invitée décidée par le client est ouverte', () {
      // Cette liste-ci **est** la décision, écrite dans ses termes. Elle
      // recoupe la précédente exprès : la première dit « rien d'autre n'est
      // fermé », celle-ci dit « voici ce qui doit être ouvert ». Fermer un
      // écran *et* le retirer de `memberOnlyRoutes` ne peut pas tromper les
      // deux à la fois.
      const surface = <String>[
        '/home', // accueil, annonces en lecture, communauté, profil
        '/bible', // la Bible, poussée depuis l'en-tête de l'accueil
        '/notes', // redirige sur l'onglet Notes de la Bible, qui porte sa porte
        '/media', // médiathèque
        '/teaching/:id', // fiche d'enseignement
        '/gathering/:id', // fiche de rassemblement
        '/agenda',
        '/event',
        '/radio', // New Life Radio
        '/downloads', // téléchargements
        '/donations', // dons
        '/legal/:kind', // CGU et confidentialité, en consultation
        '/about',
        '/media-viewer', // les médias d'une annonce
        '/settings/media', // les réglages de cet appareil-ci
        '/settings/branch', // Mon assemblée, la préférence de cet appareil
      ];
      for (final pattern in surface) {
        expect(
          redirectFor(
            status: AuthStatus.guest,
            location: _concrete(pattern),
            pattern: pattern,
          ),
          isNull,
          reason: '$pattern appartient à la surface invitée',
        );
        expect(
          _declaredPaths(router),
          contains(pattern),
          reason: '$pattern doit exister pour être ouvert',
        );
      }
    });

    test('le parcours d\'authentification reste ouvert', () {
      // C'est là que `requireSession()` emmène un invité : le fermer rendrait
      // la connexion à la demande impossible.
      for (final loc in ['/auth', '/auth/code']) {
        expect(
          redirectFor(
            status: AuthStatus.guest,
            location: loc,
            pattern: loc,
          ),
          isNull,
        );
      }
    });

    test('la barrière légale ne piège jamais un invité', () {
      // Deux verrous, et la redondance est voulue. Le premier :
      // `pendingLegalAcceptancesProvider` rend une liste vide sans
      // utilisateur, donc `legalPending` est faux pour un invité — mais c'est
      // un invariant d'un autre fichier. Le second, ici : même en lui
      // **mentant** sur ce point, la garde renvoie l'invité à l'accueil. Sans
      // quoi il se retrouverait devant un écran dont `PopScope(canPop: false)`
      // ne laisse sortir personne, à cocher des cases qu'aucun serveur
      // n'attend de lui.
      expect(
        redirectFor(
          status: AuthStatus.guest,
          location: '/legal/accept',
          pattern: '/legal/accept',
          legalPending: true,
        ),
        '/home',
      );
      // Et la consultation, elle, reste ouverte : c'est précisément ce qu'on
      // doit pouvoir lire sans compte.
      expect(
        redirectFor(
          status: AuthStatus.guest,
          location: '/legal/cgu',
          pattern: '/legal/:kind',
        ),
        isNull,
      );
    });

    test('un membre ne voit aucun changement', () {
      // La contrainte du client, vérifiée sur les quatre décisions de la
      // branche `authenticated` : splash et parcours d'auth ramènent à
      // l'accueil, la barrière enferme quand quelque chose est exigé,
      // `/legal/accept` se retire de lui-même sinon, et le reste de
      // l'application est libre.
      for (final loc in ['/', '/auth', '/auth/code']) {
        expect(
          redirectFor(
            status: AuthStatus.authenticated,
            location: loc,
            pattern: loc,
          ),
          '/home',
        );
      }
      expect(
        redirectFor(
          status: AuthStatus.authenticated,
          location: '/notes/x',
          pattern: '/notes/:id',
        ),
        isNull,
        reason: 'un écran réservé est le sien',
      );
      expect(
        redirectFor(
          status: AuthStatus.authenticated,
          location: '/notes/x',
          pattern: '/notes/:id',
          legalPending: true,
        ),
        '/legal/accept',
      );
      expect(
        redirectFor(
          status: AuthStatus.authenticated,
          location: '/legal/accept',
          pattern: '/legal/accept',
          legalPending: true,
        ),
        isNull,
      );
      expect(
        redirectFor(
          status: AuthStatus.authenticated,
          location: '/legal/accept',
          pattern: '/legal/accept',
        ),
        '/home',
      );
    });

    test('le splash tient pendant la résolution d\'un membre', () {
      // L'état `unknown` n'existe plus que là : un coffre qui porte une
      // session à résoudre. Son comportement est celui d'avant, à la lettre.
      expect(
        redirectFor(
          status: AuthStatus.unknown,
          location: '/',
          pattern: '/',
        ),
        isNull,
      );
      expect(
        redirectFor(
          status: AuthStatus.unknown,
          location: '/media',
          pattern: '/media',
        ),
        '/',
      );
    });
  });

  group('le câblage, à travers le vrai routeur', () {
    testWidgets('premier lancement : l\'accueil invité', (tester) async {
      final router = await _pumpApp(tester, _container());

      // `initialLocation` est `/`, et la garde l'a réécrit **à sa première
      // évaluation** — avant que go_router ne construise quoi que ce soit. Le
      // splash n'apparaît donc pas une image : c'est la différence entre « pas
      // de splash » et « un splash très court ».
      expect(router.state.matchedLocation, '/home');
      expect(find.byType(SplashScreen), findsNothing);
      expect(find.byType(HomeShell), findsOneWidget);
    });

    testWidgets('un écran réservé ramène à l\'accueil', (tester) async {
      final router = await _pumpApp(tester, _container());

      router.go('/notes/019f7a00-0000-7000-8000-00000000a001');
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // **Et surtout pas `/auth`** : c'est exactement le verrou qu'on retire.
      // Une redirection vers la connexion transformerait un lien partagé en
      // écran de connexion surprise.
      expect(router.state.matchedLocation, '/home');
      expect(find.byType(NoteEditorScreen), findsNothing);
    });

    testWidgets('la médiathèque s\'ouvre sans session', (tester) async {
      final router = await _pumpApp(tester, _container());

      router.go('/media');
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(router.state.matchedLocation, '/media');
      expect(find.byType(MediaLibraryScreen), findsOneWidget);
    });

    testWidgets('un membre garde ses écrans', (tester) async {
      final container = _container(
        auth: SignedInAuthRepository(),
        vault: StartupVault.memberSession,
      );
      // L'éditeur lit le magasin Drift : tout dans un seul `runAsync`.
      await tester.runAsync(() async {
        final router = await _pumpApp(tester, container);
        await _untilSignedIn(tester, container);

        router.go('/notes/019f7a00-0000-7000-8000-00000000a001');
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(
          router.state.matchedLocation,
          '/notes/019f7a00-0000-7000-8000-00000000a001',
        );
      });
    });
  });
}

/// Les chemins que le routeur déclare, tels qu'il les déclare : c'est la
/// **source unique**. Recopier une liste ici la ferait diverger en silence le
/// jour où une route est renommée.
List<String> _declaredPaths(GoRouter router) {
  return [
    for (final route in router.configuration.routes)
      if (route is GoRoute) route.path,
  ];
}

/// Un chemin concret à partir d'un motif : `/teaching/:id` → `/teaching/x`.
/// C'est ce que `matchedLocation` porte à l'exécution, et la garde doit décider
/// sur le **motif**, pas sur lui.
String _concrete(String pattern) {
  final segments = pattern.split('/');
  return segments.map((s) => s.startsWith(':') ? 'x' : s).join('/');
}

/// Un invité : rien dans le coffre, rien en cache, et le réseau n'a rien à
/// dire.
class _GuestAuthRepository extends InMemoryAuthRepository {
  @override
  Future<User?> cachedUser() async => null;

  @override
  Future<User?> currentUser() async => null;
}

/// Le conteneur de production, aux doubles près — et aucun n'appartient à la
/// garde.
///
/// Le magasin est **en mémoire** (pas de fichier de base sur la machine), les
/// repositories de contenu sont leurs doubles en mémoire (sans quoi ils
/// ouvriraient une socket, à laquelle `flutter test` répond 400), et les flux
/// Drift des réglages et des téléchargements sont posés **nus** : un flux Drift
/// attendu sous l'horloge factice du harnais fige le montage. Le routeur, sa
/// garde et l'état d'authentification, eux, sont ceux de l'application.
ProviderContainer _container({
  AuthRepository? auth,
  StartupVault vault = StartupVault.noMemberSession,
}) {
  final AppDatabase db = openTestDatabase();
  addTearDown(db.close);
  final container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      startupVaultProvider.overrideWithValue(vault),
      authRepositoryProvider.overrideWithValue(auth ?? _GuestAuthRepository()),
      branchRepositoryProvider
          .overrideWithValue(const InMemoryBranchRepository()),
      calendarRepositoryProvider
          .overrideWithValue(InMemoryCalendarRepository()),
      mediathequeRepositoryProvider
          .overrideWithValue(InMemoryMediathequeRepository()),
      gatheringRepositoryProvider
          .overrideWithValue(InMemoryGatheringRepository()),
      announcementRepositoryProvider
          .overrideWithValue(InMemoryAnnouncementRepository()),
      // **Aucun document légal, donc aucun plancher, donc aucune barrière.**
      // Ce n'est pas un raccourci : la barrière est vérifiée de bout en bout
      // par `legal_gate_test.dart`, et la faire entrer ici ferait échouer les
      // tests de la garde pour une raison qui n'est pas la leur — un membre de
      // fixture n'a rien accepté de `SampleData`.
      legalRepositoryProvider
          .overrideWithValue(InMemoryLegalRepository(documents: const [])),
      playbackProgressReporterProvider
          .overrideWithValue(FakePlaybackProgressReporter()),
      networkTransportProvider.overrideWithValue(FixedNetworkTransport()),
      // Le choix radio, figé : la vraie valeur ouvre le flux Drift des
      // réglages dès que le bouton d'antenne de l'accueil se monte.
      radioQualityProvider.overrideWithValue(RadioQuality.auto),
      // **L'offre de canaux, par un flux nu** (#83). La coquille monte désormais
      // le formulaire de connexion dans les onglets réservés d'un invité, et ce
      // formulaire lit cette offre : un flux Drift attendu sous l'horloge
      // factice du harnais figerait le montage. Le repli est l'e-mail seul, ce
      // que propose une application qui n'a pas encore synchronisé.
      authChannelsProvider.overrideWith(
        (ref) => Stream.value(AuthChannelOffer.emailOnly),
      ),
      themePreferencesProvider
          .overrideWith((ref) => Stream.value(const ThemePreferences())),
      downloadForContentProvider
          .overrideWith((ref, contentId) => Stream.value(null)),
      downloadNotificationsProvider.overrideWith(
        (ref) => Stream.value(const <DownloadNotificationRow>[]),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// Monte l'application comme `app.dart` le fait : le routeur **écouté**, pas
/// seulement lu.
///
/// Ce n'est pas une précaution de test. Un provider que personne n'écoute est
/// inactif, et Riverpod 3 met alors en pause les abonnements qu'il tient —
/// dont le pont `authProvider` → `refreshListenable`. La garde ne serait
/// jamais réévaluée.
Future<GoRouter> _pumpApp(
  WidgetTester tester,
  ProviderContainer container,
) async {
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
  return router;
}

/// La session s'ouvre de façon asynchrone (cache puis revalidation) ; la garde
/// ne dit rien de sensé avant.
Future<void> _untilSignedIn(
  WidgetTester tester,
  ProviderContainer container,
) async {
  for (var i = 0; i < 20; i++) {
    if (container.read(authProvider).isAuthenticated) return;
    await tester.pump(const Duration(milliseconds: 50));
  }
  fail('la session ne s\'est jamais ouverte');
}
