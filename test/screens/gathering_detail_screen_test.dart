import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/repositories/auth_repository.dart';
import 'package:maison_du_miracle/data/repositories/branch_repository.dart';
import 'package:maison_du_miracle/data/repositories/gathering_repository.dart';
import 'package:maison_du_miracle/data/repositories/mediatheque_repository.dart';
import 'package:maison_du_miracle/l10n/l10n_setup.dart';
import 'package:maison_du_miracle/models/gathering_view.dart';
import 'package:maison_du_miracle/models/models.dart';
import 'package:maison_du_miracle/router/app_router.dart';
import 'package:maison_du_miracle/screens/gathering_detail_screen.dart';
import 'package:maison_du_miracle/screens/teaching_detail_screen.dart';
import 'package:maison_du_miracle/state/auth_providers.dart';
import 'package:maison_du_miracle/state/gathering_providers.dart';
import 'package:maison_du_miracle/state/mediatheque_providers.dart';
import 'package:maison_du_miracle/state/playback_progress_providers.dart';
import 'package:maison_du_miracle/state/sync_providers.dart';
import 'package:maison_du_miracle/theme/app_theme.dart';
import 'package:maison_du_miracle/widgets/content_absence.dart';

import '../helpers/playback_doubles.dart';

/// **Les rassemblements à l'écran** — l'écran de détail et sa route.
///
/// Rien n'y est neuf : la route porte l'identifiant, l'écran relit le magasin à
/// chaque build, une rétractation retire le contenu de l'écran ouvert et
/// l'absence est l'une des quatre variantes existantes. Ce sont les règles de la
/// médiathèque, et c'est **exactement le point** — ce fichier les rejoue sur
/// l'autre famille, plus ce qui n'existait pas avant : la **cloison** entre les
/// deux routes.

/// Rassemblements de test **sans image** : `flutter test` répond 400 à tout
/// accès réseau.
///
/// Avec `playlistUrl`, **sauf le dernier** : depuis #40 c'est elle que le
/// lecteur charge, et un rassemblement qui n'en porte pas décrit un contenu
/// publié **sans média**. La branche « média absent » (#41) vaut pour les deux
/// familles — le lecteur ne connaît aucune famille —, et le troisième est là
/// pour le prouver sur celle-ci.
final _gatherings = [
  Teaching(
    id: '019f3a10-0000-7000-8000-000000000001',
    title: 'Nuit de gloire',
    author: 'Chorale Harmonie',
    teachingTypeId: 11,
    recordedAt: DateTime.utc(2026, 5, 2),
    publishedAt: DateTime.utc(2026, 5, 3),
    playlistUrl: 'https://exemple.test/nuit-de-gloire/master.m3u8',
  ),
  Teaching(
    id: '019f3a10-0000-7000-8000-000000000002',
    title: 'Convention nationale',
    author: '',
    teachingTypeId: 12,
    recordedAt: DateTime.utc(2026, 4, 20),
    publishedAt: DateTime.utc(2026, 4, 21),
    playlistUrl: 'https://exemple.test/convention/master.m3u8',
  ),
  Teaching(
    id: '019f3a10-0000-7000-8000-000000000003',
    title: 'Croisade de la moisson',
    author: 'Évangéliste Paul',
    teachingTypeId: 13,
    recordedAt: DateTime.utc(2026, 4, 12),
    publishedAt: DateTime.utc(2026, 4, 13),
    // **Gardé sans média, délibérément** — voir le commentaire ci-dessus.
  ),
];

/// Rassemblements **pilotés par le test**, et surtout **rejouables** : le flux
/// ré-émet, seul moyen de reproduire ce qui justifie la navigation par
/// identifiant — une rétractation qui arrive pendant que l'écran est ouvert.
class _FakeGatherings implements GatheringRepository {
  _FakeGatherings(List<Teaching> gatherings)
      : _controller = StreamController<List<Teaching>>.broadcast() {
    _latest = gatherings;
  }

  final StreamController<List<Teaching>> _controller;
  late List<Teaching> _latest;

  void dispose() => _controller.close();

  /// Ce que produit `{ id, deletedAt }` dans le flux delta (ADR-0025).
  void retract(String id) =>
      emit(_latest.where((g) => g.id != id).toList(growable: false));

  void emit(List<Teaching> gatherings) {
    _latest = gatherings;
    _controller.add(gatherings);
  }

  /// Rejoue la dernière valeur connue puis suit les suivantes — le
  /// comportement d'un `watch()` Drift, qui émet immédiatement.
  Stream<List<Teaching>> get _stream async* {
    yield _latest;
    yield* _controller.stream;
  }

  @override
  Stream<List<GatheringView>> latestGatherings({
    required String locale,
    int? limit,
  }) =>
      _stream.map((rows) => rows.map((g) => _view(g, locale)).toList());

  @override
  Stream<List<GatheringView>> gatheringsOfType(
    int gatheringTypeId, {
    required String locale,
  }) =>
      _stream.map(
        (rows) => rows
            .where((g) => g.teachingTypeId == gatheringTypeId)
            .map((g) => _view(g, locale))
            .toList(),
      );

  @override
  Stream<GatheringView?> gatheringById(String id, {required String locale}) =>
      _stream.map((rows) {
        for (final gathering in rows) {
          if (gathering.id == id) return _view(gathering, locale);
        }
        return null;
      });

  @override
  Stream<List<GatheringSectionView>> homeSections({required String locale}) =>
      _stream.map((_) => const <GatheringSectionView>[]);

  GatheringView _view(Teaching gathering, String locale) =>
      GatheringView.resolve(
        id: gathering.id,
        title: gathering.title,
        locale: locale,
        contributorName: gathering.author,
        teachingTypeId: gathering.teachingTypeId,
        playlistUrl: gathering.playlistUrl,
        publishedAt: gathering.publishedAt,
        recordedAt: gathering.recordedAt,
      );
}

/// Repository d'auth déjà connecté : le routeur n'ouvre les routes internes
/// qu'une fois la session résolue (garde `redirect`).
class _SignedInAuthRepository extends InMemoryAuthRepository {
  static const _user = User(
    id: 'u_test',
    email: 'test@example.com',
    firstName: 'Test',
    branchId: 1,
    profileComplete: true,
  );

  @override
  Future<User?> cachedUser() async => _user;

  @override
  Future<User?> currentUser() async => _user;
}

void main() {
  group('Route /gathering/:id', () {
    testWidgets('la route porte l\'identifiant, et l\'écran le résout',
        (tester) async {
      final router = await _pumpApp(tester);
      router.goNamed(
        AppRoute.gatheringDetail,
        pathParameters: {'id': _gatherings[1].id},
      );
      await _settle(tester);

      expect(find.byType(GatheringDetailScreen), findsOneWidget);
      expect(find.text('Convention nationale'), findsOneWidget);
      expect(find.text('Nuit de gloire'), findsNothing);
    });

    testWidgets('un identifiant inconnu s\'affiche comme un contenu retiré',
        (tester) async {
      final router = await _pumpApp(tester);
      router.goNamed(
        AppRoute.gatheringDetail,
        pathParameters: {'id': 'jamais-vu'},
      );
      await _settle(tester);

      // On n'éjecte pas le fidèle de l'écran qu'il avait ouvert, et on n'écrit
      // pas de cinquième variante d'absence : `retracted` existe déjà.
      expect(find.byType(GatheringDetailScreen), findsOneWidget);
      expect(find.byType(ContentAbsenceView), findsOneWidget);
      expect(
        find.text('Ce rassemblement n\'est plus disponible'),
        findsOneWidget,
      );
    });

    testWidgets('le surtitre dit « Rassemblement », jamais « Événement »',
        (tester) async {
      final router = await _pumpApp(tester);
      router.goNamed(
        AppRoute.gatheringDetail,
        pathParameters: {'id': _gatherings[0].id},
      );
      await _settle(tester);

      // Le calendrier (collection `events`) est une autre chose : des
      // occurrences datées. Un rassemblement de médiathèque est un contenu
      // enregistré.
      expect(find.text('RASSEMBLEMENT'), findsOneWidget);
      expect(find.textContaining('ÉVÈNEMENT'), findsNothing);
      expect(find.textContaining('ÉVÉNEMENT'), findsNothing);
    });
  });

  group('La cloison entre les deux routes', () {
    testWidgets(
        'l\'identifiant d\'un rassemblement ne résout rien sur '
        '/teaching/:id', (tester) async {
      final router = await _pumpApp(tester);
      router.goNamed(
        AppRoute.teachingDetail,
        pathParameters: {'id': _gatherings[0].id},
      );
      await _settle(tester);

      // Deux collections, deux providers : la route de la médiathèque lit
      // `teachings` et rien d'autre. Un rassemblement n'y existe pas — et ça
      // s'affiche comme un contenu retiré, pas comme une panne.
      expect(find.byType(TeachingDetailScreen), findsOneWidget);
      expect(find.byType(ContentAbsenceView), findsOneWidget);
      expect(find.text('Nuit de gloire'), findsNothing);
    });

    testWidgets(
        'l\'identifiant d\'un enseignement ne résout rien sur '
        '/gathering/:id', (tester) async {
      final router = await _pumpApp(tester);
      router.goNamed(
        AppRoute.gatheringDetail,
        pathParameters: {'id': 'un-enseignement-quelconque'},
      );
      await _settle(tester);

      expect(find.byType(GatheringDetailScreen), findsOneWidget);
      expect(find.byType(ContentAbsenceView), findsOneWidget);
    });
  });

  group('Rétractation pendant la consultation', () {
    testWidgets('le contenu retiré remplace le lecteur, sans fermer l\'écran',
        (tester) async {
      final repository = _FakeGatherings(_gatherings);
      addTearDown(repository.dispose);
      final router = await _pumpApp(tester, repository: repository);
      router.goNamed(
        AppRoute.gatheringDetail,
        pathParameters: {'id': _gatherings[0].id},
      );
      await _settle(tester);

      expect(find.text('Nuit de gloire'), findsOneWidget);
      expect(find.byIcon(Icons.pause), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);

      repository.retract(_gatherings[0].id);
      await tester.pump();
      await tester.pump();

      // L'écran reste ouvert, la copie n'est pas gelée, la lecture s'arrête.
      expect(find.byType(GatheringDetailScreen), findsOneWidget);
      expect(find.text('Nuit de gloire'), findsNothing);
      expect(find.byIcon(Icons.pause), findsNothing);
      expect(find.byType(Slider), findsNothing);
      expect(find.byType(ContentAbsenceView), findsOneWidget);
      expect(find.byKey(ContentAbsenceView.backKey), findsOneWidget);
    });

    testWidgets('la lecture ne redémarre pas si le contenu réapparaît',
        (tester) async {
      final repository = _FakeGatherings(_gatherings);
      addTearDown(repository.dispose);
      final router = await _pumpApp(tester, repository: repository);
      router.goNamed(
        AppRoute.gatheringDetail,
        pathParameters: {'id': _gatherings[0].id},
      );
      await _settle(tester);

      repository.retract(_gatherings[0].id);
      await tester.pump();
      // Une resynchronisation le rend : l'écran le réaffiche, à l'arrêt.
      // Reprendre le son tout seul serait une surprise sonore.
      repository.emit(_gatherings);
      // Deux `pump` : le premier livre l'évènement au `StreamProvider`, le
      // second reconstruit l'écran sous le routeur.
      await tester.pump();
      await tester.pump();

      expect(find.text('Nuit de gloire'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      expect(find.byIcon(Icons.pause), findsNothing);
    });
  });

  group('Publié sans média', () {
    testWidgets('la branche « média absent » vaut aussi pour cette famille',
        (tester) async {
      final router = await _pumpApp(tester);
      router.goNamed(
        AppRoute.gatheringDetail,
        pathParameters: {'id': _gatherings[2].id},
      );
      await _settle(tester);

      expect(tester.takeException(), isNull);
      // Le lecteur ne connaît aucune famille : le même cadre, le même surtitre
      // qu'ailleurs, et la même déclaration d'attente.
      expect(find.byType(GatheringDetailScreen), findsOneWidget);
      expect(find.text('RASSEMBLEMENT'), findsOneWidget);
      expect(find.byType(ContentAbsenceView), findsOneWidget);
      expect(find.text('Enregistrement à venir'), findsOneWidget);
      expect(find.byType(Slider), findsNothing);
      // Et ce n'est pas « contenu retiré » : rien n'a été supprimé.
      expect(
        find.text('Ce rassemblement n\'est plus disponible'),
        findsNothing,
      );
      expect(find.byIcon(ContentAbsence.retracted.icon), findsNothing);
    });
  });

  group('L\'absence s\'affiche comme une absence', () {
    testWidgets('sans intervenant, aucune ligne d\'auteur n\'est inventée',
        (tester) async {
      final router = await _pumpApp(tester);
      router.goNamed(
        AppRoute.gatheringDetail,
        pathParameters: {'id': _gatherings[1].id},
      );
      await _settle(tester);

      expect(find.text('Convention nationale'), findsOneWidget);
      expect(find.textContaining('inconnu'), findsNothing);
      expect(find.textContaining('Inconnu'), findsNothing);
    });
  });
}

/// Monte l'application réelle (routeur compris), session déjà ouverte.
///
/// C'est le `builder` de la route qu'on vérifie — le vrai, avec sa garde
/// `redirect` — et non un routeur reconstruit pour l'occasion.
Future<GoRouter> _pumpApp(
  WidgetTester tester, {
  _FakeGatherings? repository,
}) async {
  final gatherings = repository ?? _FakeGatherings(_gatherings);
  if (repository == null) addTearDown(gatherings.dispose);

  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  // Magasin **en mémoire** : l'écran de lecture ouvre un enregistreur de
  // progression (#43), qui lit et écrit son `PlaybackDao` sans passer par un
  // repository. Sans cette surcharge, le test ouvrirait un fichier de base sur
  // la machine — quand il ne lèverait pas, faute de canal de plugin.
  final database = AppDatabase(NativeDatabase.memory());
  addTearDown(database.close);

  final container = ProviderContainer.test(
    overrides: [
      appDatabaseProvider.overrideWithValue(database),
      playbackProgressReporterProvider
          .overrideWithValue(FakePlaybackProgressReporter()),
      authRepositoryProvider.overrideWithValue(_SignedInAuthRepository()),
      branchRepositoryProvider
          .overrideWithValue(const InMemoryBranchRepository()),
      // La médiathèque est vide : ce fichier vérifie l'autre famille, et un
      // catalogue d'enseignements n'y prouverait rien — sauf pour la cloison,
      // où c'est précisément le vide qui compte.
      mediathequeRepositoryProvider.overrideWithValue(
        InMemoryMediathequeRepository(teachings: const [], types: const []),
      ),
      gatheringRepositoryProvider.overrideWithValue(gatherings),
    ],
  );
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

/// `pump` et jamais `pumpAndSettle` : plusieurs écrans de l'app animent en
/// boucle (splash, squelettes) et ne se stabilisent jamais.
///
/// Trois passes depuis #40 : l'écran de lecture demande sa **reprise** au
/// magasin avant de charger le média, et cette lecture est asynchrone. Deux
/// frames livraient le contenu mais pas toujours le son.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
}
