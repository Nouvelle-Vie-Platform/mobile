/// **L'application entière, sous le régime invité** — le harnais des tests qui
/// portent sur ce que voit quelqu'un qui n'a pas de compte.
///
/// `pumpScreen` ne suffit pas ici, et pour une raison précise : `requireSession()`
/// lit `routerProvider` et **pousse** le parcours de connexion dessus. Un écran
/// monté dans un `MaterialApp(home:)` n'a pas ce routeur sous les pieds, et le
/// geste part dans le vide sans que rien ne rougisse. Il faut donc le vrai
/// routeur, le vrai `redirect`, et les deux abonnements que `app.dart` tient.
///
/// C'est le même montage que `test/state/session_gate_test.dart` et
/// `test/state/guest_guard_test.dart`, sorti en helper parce que trois fichiers
/// d'écran en ont désormais besoin — et qu'une copie de plus finirait par
/// diverger sur le double qu'il faut poser.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:maison_du_miracle/data/legal_notice_store.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/network/network_transport.dart';
import 'package:maison_du_miracle/data/players/status_player.dart';
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
import 'package:maison_du_miracle/state/announcement_providers.dart';
import 'package:maison_du_miracle/state/auth_channels_providers.dart';
import 'package:maison_du_miracle/state/auth_providers.dart';
import 'package:maison_du_miracle/state/calendar_providers.dart';
import 'package:maison_du_miracle/state/downloads_providers.dart';
import 'package:maison_du_miracle/state/gathering_providers.dart';
import 'package:maison_du_miracle/state/legal_notice_providers.dart';
import 'package:maison_du_miracle/state/legal_providers.dart';
import 'package:maison_du_miracle/models/media_preferences.dart';
import 'package:maison_du_miracle/state/media_settings_providers.dart';
import 'package:maison_du_miracle/state/mediatheque_providers.dart';
import 'package:maison_du_miracle/state/playback_progress_providers.dart';
import 'package:maison_du_miracle/state/player_providers.dart';
import 'package:maison_du_miracle/state/session_gate.dart';
import 'package:maison_du_miracle/state/startup_providers.dart';
import 'package:maison_du_miracle/state/sync_providers.dart';
import 'package:maison_du_miracle/state/theme_provider.dart';
import 'package:maison_du_miracle/theme/app_theme.dart';
import 'package:maison_du_miracle/widgets/app_bottom_nav.dart';
import 'package:maison_du_miracle/widgets/home_tab.dart';

import '../data/local/local_database_fixtures.dart';
import 'playback_doubles.dart';

/// Le conteneur de production, aux doubles près — et aucun n'appartient au mode
/// invité.
///
/// Le magasin est **en mémoire** (pas de fichier de base sur la machine), les
/// repositories de contenu sont leurs doubles en mémoire (sans quoi ils
/// ouvriraient une socket, à laquelle `flutter test` répond 400), et les flux
/// Drift des réglages et des téléchargements sont posés **nus** : un flux Drift
/// attendu sous l'horloge factice du harnais fige le montage. Le routeur, sa
/// garde, l'état d'authentification et le porte-intention, eux, sont ceux de
/// l'application.
ProviderContainer guestContainer({
  AuthRepository? auth,
  StartupVault vault = StartupVault.noMemberSession,
  AnnouncementRepository? announcements,
  LegalNoticeStore? legalNotice,
  AuthChannelOffer? authChannels,
  List<Override> extra = const [],
}) {
  final AppDatabase db = openTestDatabase();
  addTearDown(db.close);
  final container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      startupVaultProvider.overrideWithValue(vault),
      authRepositoryProvider.overrideWithValue(auth ?? GuestAuthRepository()),
      branchRepositoryProvider
          .overrideWithValue(const InMemoryBranchRepository()),
      calendarRepositoryProvider
          .overrideWithValue(InMemoryCalendarRepository()),
      mediathequeRepositoryProvider
          .overrideWithValue(InMemoryMediathequeRepository()),
      gatheringRepositoryProvider
          .overrideWithValue(InMemoryGatheringRepository()),
      announcementRepositoryProvider.overrideWithValue(
        announcements ?? InMemoryAnnouncementRepository(),
      ),
      // **Aucun document légal, donc aucun plancher, donc aucune barrière.**
      // Même motif que `guest_guard_test.dart` : la barrière est vérifiée de
      // bout en bout ailleurs, et la faire entrer ici ferait échouer ces tests
      // pour une raison qui n'est pas la leur.
      legalRepositoryProvider
          .overrideWithValue(InMemoryLegalRepository(documents: const [])),
      // Le bandeau du premier lancement est **déjà vu** par défaut : un test
      // d'onglet ou de geste n'a pas à composer avec un bandeau qui se pose
      // entre deux de ses `tap`. Les tests du bandeau passent leur double.
      legalNoticeStoreProvider.overrideWithValue(
        legalNotice ?? InMemoryLegalNoticeStore(seen: true),
      ),
      // **Le lecteur de statuts, inerte.** La coquille monte l'onglet Annonces
      // comme les trois autres ; dès qu'un test l'affiche, le double par défaut
      // (`FakeStatusPlayer`) arme une minuterie de 50 ms qui survit au démontage
      // et fait rougir le test sur un « pending timer » sans rapport avec lui.
      statusPlayerProvider.overrideWithValue(InertStatusPlayer()),
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
      // [authChannels] est un **paramètre nommé** et non un `Override` de plus :
      // Riverpod 3 refuse deux surcharges du même provider dans un conteneur.
      authChannelsProvider.overrideWith(
        (ref) => Stream.value(authChannels ?? AuthChannelOffer.emailOnly),
      ),
      themePreferencesProvider
          .overrideWith((ref) => Stream.value(const ThemePreferences())),
      downloadForContentProvider
          .overrideWith((ref, contentId) => Stream.value(null)),
      downloadNotificationsProvider.overrideWith(
        (ref) => Stream.value(const <DownloadNotificationRow>[]),
      ),
      // Les surcharges propres au scénario, **après** les repli : Riverpod 3
      // refuse deux surcharges du même provider dans un conteneur, celles-ci
      // doivent donc porter sur des providers que la liste ci-dessus ne touche
      // pas (un contenu de médiathèque, par exemple).
      ...extra,
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// Monte l'application **comme `app.dart` le fait**, et les deux abonnements
/// comptent autant l'un que l'autre :
///
/// - le routeur, sans quoi le pont `authProvider` → `refreshListenable` est mis
///   en pause par Riverpod 3 et la garde n'est jamais réévaluée ;
/// - le **porte-intention**, sans quoi sa réaction à l'ouverture de session
///   n'existe pas. C'est la panne la plus discrète de tout ce mécanisme : le
///   geste est mis de côté, la connexion aboutit, et il ne se passe rien.
Future<GoRouter> pumpGuestApp(
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
  await settle(tester);
  return router;
}

/// Plusieurs images : le changement d'état, le retour à l'origine, puis le
/// geste. `SessionGate._grant` les étale exprès (voir son commentaire) ; un seul
/// `pump` ne verrait que la moitié du chemin.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }
}

/// Le seul chemin réel vers une session : vérifier un code. On passe par le
/// contrôleur et non par un `state =` posé à la main — c'est l'ouverture de
/// session elle-même qui déclenche la reprise du geste.
Future<void> signIn(ProviderContainer container) async {
  await container.read(authProvider.notifier).verifyCode(
        identifier: 'jean.kossi@email.com',
        code: '123456',
      );
}

/// La session s'ouvre de façon asynchrone (cache puis revalidation) ; la garde
/// ne dit rien de sensé avant.
Future<void> untilSignedIn(
  WidgetTester tester,
  ProviderContainer container,
) async {
  for (var i = 0; i < 20; i++) {
    if (container.read(authProvider).isAuthenticated) return;
    await tester.pump(const Duration(milliseconds: 50));
  }
  fail('la session ne s\'est jamais ouverte');
}

/// **L'onglet réellement affiché par la coquille** — un nom, pas un numéro.
///
/// L'index n'est plus que le véhicule de l'`IndexedStack` : on le retraduit ici,
/// une fois pour toutes, de sorte qu'aucun test n'ait plus à savoir que
/// « Échanges » se trouve en troisième position. C'est exactement l'erreur qu'on
/// cherche à rendre impossible : un test qui attend `2` passe toujours après un
/// réordonnancement, et il ne prouve plus rien.
///
/// `IndexedStack.index` est nullable, et son nul a un sens : « n'affiche aucun
/// enfant ». La coquille en pose toujours un, donc un nul ici n'est pas une
/// absence légitime — c'est une coquille qui a cessé de choisir. Ça mérite une
/// phrase, et non l'exception nue d'un `!` : un test d'onglets qui échoue sur un
/// « Null check operator used on a null value » ne dit pas ce qui s'est passé.
///
/// **`skipOffstage: false`, et c'est le cœur du helper.** `requireSession()`
/// *pousse* le parcours de connexion par-dessus la coquille : celle-ci reste
/// montée — c'est précisément ce qui permet à l'onglet demandé de s'ouvrir après
/// coup — mais elle n'est plus peinte, et le finder par défaut l'écarte. Avec le
/// défaut, « l'onglet n'a pas bougé pendant que la connexion est ouverte »
/// deviendrait intestable (« Bad state: No element »), soit l'inverse de ce qu'on
/// veut : la question porte justement sur l'état de la coquille **sous** le
/// parcours. La clé étant unique dans l'arbre, lever le filtre n'introduit
/// aucune ambiguïté.
HomeTab shellTab(WidgetTester tester) {
  final index = tester
      .widget<IndexedStack>(find.byKey(HomeShell.tabsKey, skipOffstage: false))
      .index;
  expect(index, isNotNull,
      reason: 'la coquille n\'affiche aucun onglet du tout');
  return HomeTab.values[index!];
}

/// **L'écran que la coquille affiche**, et non l'onglet qu'elle croit afficher.
///
/// Les deux ne se valent pas : `shellTab` lit l'intention de la coquille, celui-ci
/// lit ce qui est réellement posé devant le fidèle. C'est la seule façon de
/// prouver qu'une entrée du tiroir ouvre **l'écran qu'elle nomme** — un test qui
/// se contente du numéro d'onglet passerait encore le jour où ce numéro désigne
/// un autre écran, ce qui est précisément le bug que ce chantier efface.
Widget shellScreen(WidgetTester tester) {
  final stack = tester
      .widget<IndexedStack>(find.byKey(HomeShell.tabsKey, skipOffstage: false));
  expect(stack.index, isNotNull,
      reason: 'la coquille n\'affiche aucun onglet du tout');
  return stack.children[stack.index!];
}

/// Un libellé **de la barre du bas**, et de nulle part ailleurs.
///
/// Indispensable : le tiroir latéral porte aussi « Accueil », et le hub des
/// conversations porte « Échanges » dans son bandeau — or l'`IndexedStack`
/// construit ses quatre onglets, donc ce bandeau existe dans l'arbre même
/// lorsqu'il n'est pas peint. Un `find.text` nu trouverait deux widgets et le
/// `tap` échouerait pour une raison sans rapport avec ce qu'on teste.
Finder navTab(String label) => find.descendant(
      of: find.byType(AppBottomNav),
      matching: find.text(label),
    );

/// Un invité qui **peut** devenir membre en vérifiant un code.
///
/// `InMemoryAuthRepository` ne convient pas tel quel : son `currentUser()`
/// attend 300 ms et rend l'utilisateur en mémoire, ce qui suffit, mais rien n'y
/// garantit l'invité au départ. Ce double-ci le dit explicitement, et son
/// `verifyCode` n'a ni délai ni code magique — le parcours d'authentification
/// n'est pas le sujet de ces tests.
class GuestAuthRepository extends InMemoryAuthRepository {
  GuestAuthRepository({bool signedIn = false})
      : _user = signedIn ? member : null;

  /// Le membre que la connexion ouvre. `profileComplete` est **vrai** exprès :
  /// un profil incomplet ferait apparaître `ProfileCompletionBanner` sur
  /// l'accueil, qui porte son propre bouton vers `/profile/edit` et brouillerait
  /// les tests de geste.
  static const User member = User(
    id: 'u_1',
    email: 'jean.kossi@email.com',
    firstName: 'Jean',
    status: UserStatus.affiliated,
    profileComplete: true,
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
    _user = member;
    return const Session(token: 'oat_test', user: member, isNewUser: false);
  }
}
