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
import 'package:maison_du_miracle/screens/auth/identifier_screen.dart';
import 'package:maison_du_miracle/state/announcement_providers.dart';
import 'package:maison_du_miracle/state/auth_channels_providers.dart';
import 'package:maison_du_miracle/state/auth_providers.dart';
import 'package:maison_du_miracle/state/calendar_providers.dart';
import 'package:maison_du_miracle/state/downloads_providers.dart';
import 'package:maison_du_miracle/state/gathering_providers.dart';
import 'package:maison_du_miracle/state/legal_providers.dart';
import 'package:maison_du_miracle/state/media_settings_providers.dart';
import 'package:maison_du_miracle/state/mediatheque_providers.dart';
import 'package:maison_du_miracle/state/playback_progress_providers.dart';
import 'package:maison_du_miracle/state/session_gate.dart';
import 'package:maison_du_miracle/state/startup_providers.dart';
import 'package:maison_du_miracle/state/sync_providers.dart';
import 'package:maison_du_miracle/state/theme_provider.dart';
import 'package:maison_du_miracle/theme/app_theme.dart';

import '../data/local/local_database_fixtures.dart';
import '../helpers/playback_doubles.dart';

/// **`requireSession()` : le geste survit-il à la connexion ?**
///
/// C'est la contrepartie de la garde inversée. Puisque l'application ne demande
/// plus de compte à l'entrée, elle doit le demander au moment du **geste** — et
/// surtout reprendre ce geste. Une connexion qui aboutit et ramène sur
/// l'accueil sans rien faire est le pire des deux échecs : la personne a donné
/// son identifiant, reçu un code, et n'a pas obtenu ce qu'elle demandait.
void main() {
  testWidgets('la connexion s\'ouvre, le geste suit', (tester) async {
    final container = _container();
    final router = await _pumpApp(tester, container);

    // On part d'un écran de la surface invitée, et **pas de l'accueil** : c'est
    // ce qui rend le retour à l'origine visible. Revenir sur `/home` serait
    // indiscernable de ce que fait déjà l'écran du code.
    router.go('/media');
    await _settle(tester);
    expect(router.state.matchedLocation, '/media');

    var gestes = 0;
    final gate = container.read(sessionGateProvider.notifier);
    final granted = gate.require(action: () => gestes++);

    // `false` = « il a fallu ouvrir la connexion ». L'appelant n'a **rien** à
    // faire de plus : le geste ne doit surtout pas partir maintenant.
    expect(granted, isFalse);
    expect(gestes, 0);

    await _settle(tester);
    expect(router.state.matchedLocation, '/auth');
    expect(find.byType(IdentifierScreen), findsOneWidget);

    // La connexion aboutit. C'est le seul déclencheur : le geste est adossé à
    // l'ouverture de session, pas à un rappel de l'écran du code.
    await _signIn(container);
    await _settle(tester);

    expect(gestes, 1, reason: 'l\'action demandée s\'exécute d\'elle-même');
    expect(
      router.state.matchedLocation,
      '/media',
      reason: 'et l\'on revient là où on l\'avait demandée',
    );
    // Une intention ne vaut qu'une fois : sans cette reprise, une revalidation
    // de fond ou une mise à jour de profil rejouerait le geste.
    expect(container.read(sessionGateProvider), isNull);
  });

  testWidgets('il abandonne : rien ne s\'exécute', (tester) async {
    final container = _container();
    final router = await _pumpApp(tester, container);
    router.go('/media');
    await _settle(tester);

    var gestes = 0;
    final gate = container.read(sessionGateProvider.notifier);
    gate.require(action: () => gestes++);
    await _settle(tester);
    expect(router.state.matchedLocation, '/auth');

    // **L'abandon, c'est un retour en arrière** — et rien d'autre. Le parcours
    // est *poussé* par-dessus l'écran d'origine, donc renoncer n'a aucun geste
    // propre à apprendre : retour Android, flèche de l'en-tête, balayage.
    router.pop();
    await _settle(tester);

    expect(router.state.matchedLocation, '/media');
    expect(gestes, 0);
    expect(
      container.read(sessionGateProvider),
      isNull,
      reason: 'une intention abandonnée ne traîne pas',
    );

    // Et elle ne ressuscite pas : la connexion suivante — faite pour une autre
    // raison, depuis le Profil — ne doit pas rejouer un geste dont la personne
    // s'est détournée. C'est le cas qui rendrait le mécanisme effrayant.
    await _signIn(container);
    await _settle(tester);
    expect(gestes, 0);
  });

  testWidgets('un membre : le geste part tout de suite', (tester) async {
    final container = _container(
      vault: StartupVault.memberSession,
      signedIn: true,
    );
    final router = await _pumpApp(tester, container);
    await _untilSignedIn(tester, container);

    var gestes = 0;
    final gate = container.read(sessionGateProvider.notifier);
    final granted = gate.require(action: () => gestes++);

    expect(granted, isTrue);
    expect(gestes, 1);
    await _settle(tester);
    // Rien n'a été poussé : `requireSession` est transparent pour un membre.
    expect(router.state.matchedLocation, isNot('/auth'));
    expect(container.read(sessionGateProvider), isNull);
  });

  testWidgets('l\'application tuée oublie l\'intention', (tester) async {
    // **Le cas qui ne se joue pas dans un test**, et qu'il faut quand même
    // écrire. Une intention vit en mémoire seule, exprès : un `VoidCallback`
    // n'a pas de forme sérialisable, et surtout un geste rejoué après un
    // redémarrage agirait dans le dos de la personne — publier une annonce,
    // envoyer une demande, sur un écran qu'elle n'a plus devant elle.
    //
    // Ce que ce test peut prouver, c'est qu'**aucune reprise n'existe** : un
    // conteneur neuf — ce qu'est une application relancée — part sans
    // intention, et rien ne va la chercher nulle part. Le jour où quelqu'un la
    // persisterait, c'est ici que la décision serait contredite.
    final container = _container();
    await _pumpApp(tester, container);
    expect(container.read(sessionGateProvider), isNull);
  });
}

/// Plusieurs images : le changement d'état, le retour à l'origine, puis le
/// geste. `SessionGate._grant` les étale exprès (voir son commentaire) ; un
/// seul `pump` ne verrait que la moitié du chemin.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }
}

/// Le seul chemin réel vers une session : vérifier un code.
Future<void> _signIn(ProviderContainer container) async {
  await container.read(authProvider.notifier).verifyCode(
        identifier: 'jean.kossi@email.com',
        code: '123456',
      );
}

/// Un invité qui devient membre en vérifiant un code.
class _Auth extends InMemoryAuthRepository {
  _Auth({bool signedIn = false}) : _user = signedIn ? _member : null;

  static const User _member = User(
    id: 'u_1',
    email: 'jean.kossi@email.com',
    firstName: 'Jean',
    status: UserStatus.newcomer,
    profileComplete: false,
  );

  User? _user;

  @override
  Future<User?> cachedUser() async => _user;

  @override
  Future<User?> currentUser() async => _user;

  @override
  Future<Session> verifyCode({
    required String identifier,
    required String code,
  }) async {
    _user = _member;
    return const Session(token: 'oat_test', user: _member, isNewUser: false);
  }
}

/// Le conteneur de production, aux doubles près — voir l'en-tête de
/// `guest_guard_test.dart`, qui les pose pour les mêmes raisons.
ProviderContainer _container({
  StartupVault vault = StartupVault.noMemberSession,
  bool signedIn = false,
}) {
  final AppDatabase db = openTestDatabase();
  addTearDown(db.close);
  final container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      startupVaultProvider.overrideWithValue(vault),
      authRepositoryProvider.overrideWithValue(_Auth(signedIn: signedIn)),
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
      legalRepositoryProvider
          .overrideWithValue(InMemoryLegalRepository(documents: const [])),
      playbackProgressReporterProvider
          .overrideWithValue(FakePlaybackProgressReporter()),
      networkTransportProvider.overrideWithValue(FixedNetworkTransport()),
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

/// Monte l'application **comme `app.dart` le fait**, et les deux abonnements
/// comptent autant l'un que l'autre :
///
/// - le routeur, sans quoi le pont `authProvider` → `refreshListenable` est mis
///   en pause par Riverpod 3 ;
/// - le **porte-intention**, sans quoi sa réaction à l'ouverture de session
///   n'existe pas. C'est la panne la plus discrète de tout ce mécanisme : le
///   geste est mis de côté, la connexion aboutit, et il ne se passe rien.
Future<GoRouter> _pumpApp(
  WidgetTester tester,
  ProviderContainer container,
) async {
  container.listen(routerProvider, (_, __) {});
  container.listen(sessionGateProvider, (_, __) {});
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
  await _settle(tester);
  return router;
}

/// La session s'ouvre de façon asynchrone (cache puis revalidation).
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
