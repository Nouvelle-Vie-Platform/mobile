import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/repositories/announcement_repository.dart';
import 'package:maison_du_miracle/data/repositories/auth_repository.dart';
import 'package:maison_du_miracle/data/repositories/branch_repository.dart';
import 'package:maison_du_miracle/data/repositories/gathering_repository.dart';
import 'package:maison_du_miracle/data/repositories/mediatheque_repository.dart';
import 'package:maison_du_miracle/l10n/l10n_setup.dart';
import 'package:maison_du_miracle/state/announcement_providers.dart';
import 'package:maison_du_miracle/state/auth_providers.dart';
import 'package:maison_du_miracle/state/gathering_providers.dart';
import 'package:maison_du_miracle/state/mediatheque_providers.dart';
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
Future<void> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  List<Override> overrides = const [],
  MediathequeRepository? mediatheque,
  GatheringRepository? gatherings,
  AnnouncementRepository? announcements,
}) async {
  final database = AppDatabase(NativeDatabase.memory());
  addTearDown(database.close);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        playbackProgressReporterProvider
            .overrideWithValue(FakePlaybackProgressReporter()),
        authRepositoryProvider.overrideWithValue(InMemoryAuthRepository()),
        branchRepositoryProvider
            .overrideWithValue(const InMemoryBranchRepository()),
        mediathequeRepositoryProvider
            .overrideWithValue(mediatheque ?? InMemoryMediathequeRepository()),
        gatheringRepositoryProvider
            .overrideWithValue(gatherings ?? InMemoryGatheringRepository()),
        announcementRepositoryProvider.overrideWithValue(
          announcements ?? InMemoryAnnouncementRepository(),
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
