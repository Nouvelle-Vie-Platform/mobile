import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/network/network_transport.dart';
import 'package:maison_du_miracle/data/repositories/announcement_repository.dart';
import 'package:maison_du_miracle/data/repositories/auth_repository.dart';
import 'package:maison_du_miracle/data/repositories/branch_repository.dart';
import 'package:maison_du_miracle/data/repositories/gathering_repository.dart';
import 'package:maison_du_miracle/data/repositories/group_repository.dart';
import 'package:maison_du_miracle/data/repositories/in_memory_group_repository.dart';
import 'package:maison_du_miracle/data/repositories/inert_group_messaging.dart';
import 'package:maison_du_miracle/data/repositories/mediatheque_repository.dart';
import 'package:maison_du_miracle/l10n/l10n_setup.dart';
import 'package:maison_du_miracle/state/announcement_providers.dart';
import 'package:maison_du_miracle/state/auth_providers.dart';
import 'package:maison_du_miracle/state/group_providers.dart';
import 'package:maison_du_miracle/state/downloads_providers.dart';
import 'package:maison_du_miracle/state/gathering_providers.dart';
import 'package:maison_du_miracle/state/media_settings_providers.dart';
import 'package:maison_du_miracle/models/theme_preferences.dart';
import 'package:maison_du_miracle/state/mediatheque_providers.dart';
import 'package:maison_du_miracle/state/theme_provider.dart';
import 'package:maison_du_miracle/state/playback_progress_providers.dart';
import 'package:maison_du_miracle/state/sync_providers.dart';
import 'package:maison_du_miracle/theme/app_theme.dart';

import 'playback_doubles.dart';

/// Monte un écran isolé dans un environnement minimal (ProviderScope + thème).
///
/// Utilise `pump()` (et non `pumpAndSettle`) car certains écrans affichent des
/// animations infinies (ex. le spinner du splash) qui ne se stabilisent jamais.
///
/// [overrides] permet d'injecter des providers de test (ex. un faux
/// repository) pour vérifier le câblage des données. Ils sont appliqués
/// **après** les repli ci-dessous, et peuvent donc les remplacer.
///
/// Les repositories d'auth et de branches sont forcés sur leurs
/// implémentations **en mémoire** : les versions HTTP ouvriraient une socket
/// dès le montage (`GET /auth/me`, `GET /sync/branches`) et `flutter test`
/// répond **400 à tout accès réseau**.
///
/// Celui de la médiathèque l'est pour une raison voisine mais distincte : son
/// implémentation par défaut lit le **magasin Drift**, qui ouvrirait un fichier
/// de base de données sur la machine de test. Un test d'écran n'a pas à laisser
/// de trace sur le disque ; ceux qui veulent le vrai magasin surchargent
/// `appDatabaseProvider` par une base en mémoire (voir `test/data/local/`).
/// [mediatheque] remplace ce double par un autre. C'est un paramètre nommé et
/// non un `Override` de plus : Riverpod 3 **refuse** deux surcharges du même
/// provider dans un même conteneur, un test ne peut donc pas simplement
/// « repasser par-dessus » celui posé ici.
///
/// Celui des **rassemblements** ([gatherings]) est posé de la même façon et pour
/// la même raison : la seconde famille de la médiathèque lit le même magasin
/// Drift, et l'accueil la rend désormais.
///
/// Celui des **annonces** ([announcements]) aussi, et il est le plus facile à
/// oublier : `HomeShell` monte les quatre onglets dans un `IndexedStack`, donc
/// la visionneuse de statuts vit dès qu'un test monte la coquille — et
/// ouvrirait le magasin Drift sans que le test parle jamais d'annonces.
///
/// Le magasin lui-même est posé **en mémoire**, et non simplement contourné :
/// tous les chemins ne passent pas par un repository. La reprise de lecture
/// (#43), branchée sur le lecteur par #40, lit et écrit son `PlaybackDao` en
/// direct — un écran de lecture ouvrirait donc un fichier de base sur la
/// machine de test, et sur un harnais sans canal de plugin il n'en ouvrirait
/// même pas : il lèverait. Une base en mémoire ne coûte rien tant que personne
/// ne l'interroge (Drift ouvre à la première requête).
///
/// Le **rapporteur de progression** est posé muet pour la raison qui vaut déjà
/// pour l'auth : son implémentation par défaut est HTTP dès que
/// `AppEnv.useBackend` est vrai — et il l'est hors surcharge.
/// Monte un **routeur** plutôt qu'un écran isolé, dans le même environnement.
///
/// Nécessaire dès qu'un test porte sur la navigation : `context.pop()` et
/// `context.canPop()` sont les extensions de **go_router**, qui consultent sa
/// pile à lui. Un test bâti sur un `Navigator.push` nu passerait à côté de ce
/// que fait réellement l'application.
Future<void> pumpRouter(
  WidgetTester tester,
  GoRouter router, {
  List<Override> overrides = const [],
  AppDatabase? database,
  AuthRepository? auth,
  ThemePreferences? theme,
  GroupRepository? groupRepository,
}) async {
  final db = database ?? AppDatabase(NativeDatabase.memory());
  if (database == null) addTearDown(db.close);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ..._commonOverrides(
          db,
          auth: auth,
          theme: theme,
          groupRepository: groupRepository,
        ),
        ...overrides,
      ],
      child: MaterialApp.router(
        theme: AppTheme.light,
        locale: const Locale('fr'),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: appSupportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

/// Les surcharges que tout montage partage — voir l'en-tête pour le pourquoi
/// de chacune.
List<Override> _commonOverrides(
  AppDatabase db, {
  AuthRepository? auth,
  ThemePreferences? theme,
  MediathequeRepository? mediatheque,
  GatheringRepository? gatherings,
  AnnouncementRepository? announcements,
  GroupRepository? groupRepository,
  List<DownloadNotificationRow> notifications = const [],
}) =>
    [
      appDatabaseProvider.overrideWithValue(db),
      playbackProgressReporterProvider
          .overrideWithValue(FakePlaybackProgressReporter()),
      networkTransportProvider.overrideWithValue(FixedNetworkTransport()),
      // Les réglages d'apparence sont posés **par un flux nu**, et pour la
      // raison la plus coûteuse de ce dépôt : lus depuis le magasin, ils
      // ouvrent un flux Drift, et un flux Drift attendu sous l'horloge factice
      // du harnais fige le montage — processus à 0 % de CPU jusqu'à expiration.
      // L'onglet Profil les lit, donc tout test qui monte la coquille les lit.
      themePreferencesProvider.overrideWith(
          (ref) => Stream.value(theme ?? const ThemePreferences())),
      // Le bouton de téléchargement de `ContentPlayerView` (#192) observe ce
      // flux Drift, et un écran de lecture le monte donc dès qu'il offre le
      // téléchargement (l'enseignement). Posé **par un flux nu**, exactement
      // comme les réglages d'apparence et pour la même raison : un flux Drift
      // attendu sous l'horloge factice du harnais fige le montage — 0 % de CPU
      // jusqu'à expiration. Les tests qui veulent le vrai magasin surchargent
      // eux-mêmes ce provider (voir `test/widgets/content_download_button_test`).
      downloadForContentProvider
          .overrideWith((ref, contentId) => Stream.value(null)),
      // Le bandeau de purge de la page Téléchargements (#194) observe ce flux
      // Drift. Posé **par un flux nu** pour la même raison que les autres : un
      // flux Drift attendu sous l'horloge factice du harnais fige le montage.
      // Les tests qui veulent le vrai magasin surchargent eux-mêmes.
      downloadNotificationsProvider
          .overrideWith((ref) => Stream.value(notifications)),
      authRepositoryProvider
          .overrideWithValue(auth ?? InMemoryAuthRepository()),
      branchRepositoryProvider
          .overrideWithValue(const InMemoryBranchRepository()),
      mediathequeRepositoryProvider
          .overrideWithValue(mediatheque ?? InMemoryMediathequeRepository()),
      gatheringRepositoryProvider
          .overrideWithValue(gatherings ?? InMemoryGatheringRepository()),
      announcementRepositoryProvider
          .overrideWithValue(announcements ?? InMemoryAnnouncementRepository()),
      // La messagerie de groupe lit le **magasin Drift** (flux `.watch()`), qui
      // fige le montage sous l'horloge factice du harnais — la même panne que
      // les réglages d'apparence et le bouton de téléchargement. Le double en
      // mémoire rend des flux **nus** (`Stream.value`), qui ne figent rien ; et
      // `HomeShell` monte l'onglet Échanges dans son `IndexedStack`, donc tout
      // test qui monte la coquille ouvrirait ces flux sans parler de groupes.
      groupRepositoryProvider.overrideWithValue(
          groupRepository ?? const InMemoryGroupRepository()),
      // L'écriture est HTTP dès que `AppEnv.useBackend` est vrai (il l'est hors
      // surcharge) : posée inerte pour qu'un envoi ne parte pas sur une socket.
      groupMessagingProvider.overrideWithValue(const InertGroupMessaging()),
    ];

Future<void> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  List<Override> overrides = const [],
  MediathequeRepository? mediatheque,
  GatheringRepository? gatherings,
  AnnouncementRepository? announcements,
  GroupRepository? groupRepository,
  AppDatabase? database,
  AuthRepository? auth,
  ThemePreferences? theme,
  List<DownloadNotificationRow> notifications = const [],
}) async {
  // Paramètres nommés et non `Override` de plus, pour la raison déjà donnée
  // ci-dessus : Riverpod 3 refuse deux surcharges du même provider. [database]
  // existe pour les tests qui doivent **relire** le magasin après coup — la
  // suppression de compte le vide, et on ne peut le vérifier que sur
  // l'instance que l'écran a réellement utilisée.
  final db = database ?? AppDatabase(NativeDatabase.memory());
  if (database == null) addTearDown(db.close);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ..._commonOverrides(
          db,
          auth: auth,
          theme: theme,
          mediatheque: mediatheque,
          gatherings: gatherings,
          announcements: announcements,
          groupRepository: groupRepository,
          notifications: notifications,
        ),
        ...overrides,
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('fr'),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: appSupportedLocales,
        home: screen,
      ),
    ),
  );
  await tester.pump();
  // Laisse expirer les minuteries de résolution de session (mock ~300 ms, via
  // `authProvider`) pour éviter les « pending timer » au teardown. On avance
  // l'horloge plutôt que `pumpAndSettle` (certains écrans animent à l'infini).
  await tester.pump(const Duration(seconds: 1));
}
