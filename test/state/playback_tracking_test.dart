/// **Le suivi d'écoute global** (#115) — la position de reprise et la mesure
/// d'écoute, quel que soit l'écran affiché.
///
/// Elles vivaient sur la fiche d'un enseignement, attachées à son cycle de vie :
/// un enseignement lancé depuis une carte de l'accueil n'enregistrait rien, et
/// quitter la fiche coupait le suivi d'un prêche qui continuait de sonner. Elles
/// vivent désormais dans le contrôleur global de lecture, qui suit ce qui est
/// **chargé**.
///
/// Tout se joue sur l'application montée par `pumpRouter` — l'accueil et la
/// fiche réels, derrière un vrai `GoRouter` —, avec un [InertContentPlayer], un
/// magasin en mémoire et des rapporteurs muets. Ce qui est vérifié est toujours
/// observable : ce que le lecteur a reçu, ce que contient le magasin, ce que les
/// rapporteurs ont entendu. Jamais la façon dont le contrôleur s'y prend.
///
/// ⚠️ **Jamais `pumpAndSettle`** : l'accueil monte le bouton de l'antenne, qui
/// porte une animation continue.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:maison_du_miracle/core/config/radio_config.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/players/content_player.dart';
import 'package:maison_du_miracle/data/radio/radio_repository.dart';
import 'package:maison_du_miracle/data/repositories/calendar_repository.dart';
import 'package:maison_du_miracle/data/repositories/gathering_repository.dart';
import 'package:maison_du_miracle/data/repositories/mediatheque_repository.dart';
import 'package:maison_du_miracle/models/mediatheque_view.dart';
import 'package:maison_du_miracle/models/models.dart';
import 'package:maison_du_miracle/router/app_router.dart';
import 'package:maison_du_miracle/screens/home_screen.dart';
import 'package:maison_du_miracle/screens/teaching_detail_screen.dart';
import 'package:maison_du_miracle/state/calendar_providers.dart';
import 'package:maison_du_miracle/state/mediatheque_providers.dart';
import 'package:maison_du_miracle/state/playback_controller.dart';
import 'package:maison_du_miracle/state/player_providers.dart';
import 'package:maison_du_miracle/state/radio_providers.dart';
import 'package:maison_du_miracle/state/sync_providers.dart';
import 'package:maison_du_miracle/widgets/home/home_content_cards.dart';
import 'package:maison_du_miracle/widgets/home/home_teaching_section.dart';

import '../helpers/playback_doubles.dart';
import '../helpers/pump_screen.dart';
import '../helpers/radio_doubles.dart';

const _id = '019f7000-0000-7000-8000-0000000000a1';
const _url = 'https://exemple.test/la-foi/master.m3u8';
const _title = 'La foi qui déplace';

final _sermon = Teaching(
  id: _id,
  title: _title,
  author: 'Pasteur Samuel',
  teachingTypeId: 1,
  recordedAt: DateTime.utc(2026, 9, 27),
  publishedAt: DateTime.utc(2026, 9, 27, 8),
  playlistUrl: _url,
);

/// Une rubrique en carrousel : c'est la forme qui porte le bouton « Écouter ».
const _rubrique = TeachingType(
  id: 1,
  label: {'fr': 'Dimanche'},
  slug: 'dimanche',
  layout: 'carousel',
);

/// **Le catalogue, et la rétractation qu'il sait jouer.**
///
/// Un double en mémoire pour tout le reste — l'accueil n'est pas le sujet —,
/// mais un `teachingById` **vivant** : il rejoue la valeur courante à chaque
/// changement, comme un `watch()` Drift, ce qui permet de retirer le contenu
/// pendant qu'il joue.
class _Catalogue extends InMemoryMediathequeRepository {
  _Catalogue() : super(teachings: [_sermon], types: const [_rubrique]);

  final _changes = StreamController<void>.broadcast();
  bool _retracted = false;

  /// Ce que produit `{ id, deletedAt }` dans le flux delta : le contenu quitte
  /// le magasin.
  void retract() {
    _retracted = true;
    _changes.add(null);
  }

  void dispose() => _changes.close();

  @override
  Stream<TeachingView?> teachingById(
    String id, {
    required String locale,
  }) async* {
    final view = await super.teachingById(id, locale: locale).first;
    yield _retracted ? null : view;
    await for (final _ in _changes.stream) {
      yield _retracted ? null : view;
    }
  }
}

/// L'agenda neutralisé : la section « À venir » n'est pas le sujet.
class _EmptyCalendar implements CalendarRepository {
  @override
  Future<EventWindow> events({
    required DateTime from,
    DateTime? to,
    int? branchId,
    int? limit,
  }) async =>
      EventWindow.empty;
}

void main() {
  late InertContentPlayer player;
  late FakePlaybackProgressReporter progress;
  late FakePlayReporter plays;
  late _Catalogue catalogue;
  late GoRouter router;
  late ProviderContainer container;

  setUp(() {
    player = InertContentPlayer();
    progress = FakePlaybackProgressReporter();
    plays = FakePlayReporter();
    catalogue = _Catalogue();
  });

  tearDown(() {
    player.dispose();
    catalogue.dispose();
  });

  /// L'accueil et la fiche **réels**, derrière un vrai routeur.
  GoRouter buildRouter() => GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const Scaffold(body: HomeScreen()),
          ),
          GoRoute(
            name: AppRoute.teachingDetail,
            path: '/teaching/:id',
            builder: (_, state) =>
                TeachingDetailScreen(teachingId: state.pathParameters['id']!),
          ),
        ],
      );

  Future<void> pumpApp(
    WidgetTester tester, {
    RadioRepository radio = const FixedRadioRepository(kTestAntennaOnAir),
  }) async {
    // Écran haut : les listes de l'accueil sont paresseuses, et une carte jamais
    // construite ne peut pas être touchée.
    tester.view.physicalSize = const Size(900, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    router = buildRouter();
    await pumpRouter(
      tester,
      router,
      mediatheque: catalogue,
      gatherings:
          InMemoryGatheringRepository(gatherings: const [], types: const []),
      radio: radio,
      progress: progress,
      plays: plays,
      overrides: [
        contentPlayerProvider.overrideWithValue(player),
        calendarRepositoryProvider.overrideWithValue(_EmptyCalendar()),
      ],
    );
    container = ProviderScope.containerOf(
      tester.element(find.byType(HomeScreen)),
    );
  }

  AppDatabase database() => container.read(appDatabaseProvider);

  PlaybackController controller() =>
      container.read(playbackControllerProvider.notifier);

  /// Laisse passer les requêtes au magasin — résolution du téléchargement,
  /// lecture de la reprise, écritures de position — sans jamais attendre une
  /// stabilisation que l'animation du bouton d'antenne n'offrirait pas.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
    await tester.pump();
  }

  /// Le bouton « Écouter » de la carte, dans la rubrique — l'étagère des
  /// derniers enseignements peut porter le même prêche.
  Finder listenButton() => find.descendant(
        of: find.byType(HomeTeachingSection),
        matching: find.byKey(HomeCarouselCard.playButtonKey(_id)),
      );

  /// **Lance l'enseignement depuis sa carte de l'accueil** — le chemin qui
  /// n'enregistrait rien avant #115.
  Future<void> launchFromHome(WidgetTester tester) async {
    await tester.tap(listenButton());
    await settle(tester);
    expect(player.value.contentId, _id,
        reason: 'prémisse : le prêche est chargé');
    expect(player.value.isPlaying, isTrue, reason: 'prémisse : il joue');
  }

  /// Pousse une position au lecteur, comme le moteur le fait en jouant.
  Future<void> reach(
    WidgetTester tester,
    Duration position, {
    Duration? duration,
  }) async {
    player.emit(player.value.copyWith(position: position, duration: duration));
    await tester.pump();
  }

  /// Joue de [from] à [to] secondes, par pas de deux — le rythme d'un lecteur
  /// réel, sous la tolérance de saut de la mesure d'écoute.
  Future<void> playThrough(WidgetTester tester, int from, int to) async {
    for (var at = from; at <= to; at += 2) {
      player.emit(player.value.copyWith(position: Duration(seconds: at)));
      await tester.pump();
    }
  }

  Future<int?> savedSeconds(WidgetTester tester) async {
    await settle(tester);
    final row = await database().playbackDao.localPositionFor(_id);
    return row?.positionSeconds;
  }

  group('Lancé depuis une carte de l\'accueil', () {
    testWidgets('une pause laisse la position dans le magasin local', (
      tester,
    ) async {
      await pumpApp(tester);
      await launchFromHome(tester);
      await reach(tester, const Duration(seconds: 12));

      // Le même bouton met en pause : c'est le geste de l'accueil.
      await tester.tap(listenButton());
      await settle(tester);

      expect(player.value.isPlaying, isFalse);
      expect(await savedSeconds(tester), 12);
      // Douze secondes : sous le pas du rapport périodique. Ce qui part ne peut
      // venir que de la pause.
      expect(progress.reports, hasLength(1));
      expect(progress.reports.single.contentId, _id);
      expect(progress.reports.single.positionSeconds, 12);
    });

    testWidgets('elle reprend où le fidèle s\'était arrêté', (tester) async {
      await pumpApp(tester);
      await database().playbackDao.saveLocalPosition(
            contentId: _id,
            progressId: '019f7000-0000-7000-8000-0000000000ff',
            positionSeconds: 754,
          );

      await launchFromHome(tester);

      // Une carte qui repartait de zéro aurait, maintenant que le suivi est
      // global, écrit zéro par-dessus la place du fidèle — et « la plus récente
      // gagne ».
      expect(player.value.position, const Duration(seconds: 754));
    });

    testWidgets('plus de trente secondes jouées comptent une écoute, une seule',
        (tester) async {
      await pumpApp(tester);
      await launchFromHome(tester);

      await playThrough(tester, 0, 28);
      expect(plays.reported, isEmpty, reason: 'le seuil n\'est pas atteint');

      await playThrough(tester, 30, 600);
      await settle(tester);

      expect(plays.reported, [_id]);
    });

    testWidgets('un saut n\'est pas une écoute', (tester) async {
      await pumpApp(tester);
      await launchFromHome(tester);

      // Tirer le curseur jusqu'à la fin ne fabrique pas une écoute — y compris
      // hors de la fiche, à coups de « +30 s ».
      for (var i = 0; i < 20; i++) {
        controller().skipForward();
        await tester.pump();
      }
      await settle(tester);

      expect(plays.reported, isEmpty);
    });
  });

  group('Le contenu arrêté ou remplacé enregistre sa position', () {
    testWidgets('un arrêt par le contrôleur', (tester) async {
      await pumpApp(tester);
      await launchFromHome(tester);
      await reach(tester, const Duration(seconds: 12));

      // La croix du mini-lecteur : le son s'arrête sans pause préalable.
      controller().stop();
      await settle(tester);

      expect(player.value, const ContentPlayback());
      expect(await savedSeconds(tester), 12);
      expect(progress.reports.single.positionSeconds, 12);
    });

    testWidgets('la radio qui prend le lecteur', (tester) async {
      await pumpApp(tester);
      await launchFromHome(tester);
      await reach(tester, const Duration(seconds: 12));

      final starting = container
          .read(radioListeningProvider.notifier)
          .start(title: 'New Life Radio');
      await settle(tester);
      await starting;
      await settle(tester);

      // La prémisse : l'antenne a **remplacé** l'enseignement — il n'y a qu'un
      // lecteur, et le prêche n'y laisse plus aucune trace de sa position.
      expect(player.value.contentId, RadioConfig.contentId);
      // Et pourtant la position du prêche est là : elle a été écrite avant que
      // le lecteur ne change de main.
      expect(await savedSeconds(tester), 12);
      expect(progress.reports.single.contentId, _id);
      expect(progress.reports.single.positionSeconds, 12);
    });

    testWidgets('l\'antenne n\'est jamais suivie ni comptée', (tester) async {
      await pumpApp(tester);

      final starting = container
          .read(radioListeningProvider.notifier)
          .start(title: 'New Life Radio');
      await settle(tester);
      await starting;
      player.emit(player.value.copyWith(isPlaying: true, hasStarted: true));
      await playThrough(tester, 0, 120);
      container.read(radioListeningProvider.notifier).stop();
      await settle(tester);

      // Un direct n'a pas de position à reprendre, et la route des écoutes veut
      // un identifiant d'enseignement.
      expect(plays.reported, isEmpty);
      expect(progress.reports, isEmpty);
      expect(
        await database().playbackDao.localPositionFor(RadioConfig.contentId),
        isNull,
      );
    });
  });

  group('La fin de lecture hors de la fiche', () {
    testWidgets('à trente secondes de la fin, l\'enseignement est terminé', (
      tester,
    ) async {
      await pumpApp(tester);
      await launchFromHome(tester);

      await reach(
        tester,
        const Duration(minutes: 39, seconds: 40),
        duration: const Duration(minutes: 40),
      );
      await settle(tester);

      final row = await database().playbackDao.localPositionFor(_id);
      expect(row?.completed, isTrue);
      expect(progress.reports.last.completed, isTrue);
    });

    testWidgets('jamais sur une durée inconnue — seul l\'état terminal tranche',
        (tester) async {
      await pumpApp(tester);
      await launchFromHome(tester);

      // HLS sur iOS : la durée n'arrive jamais. Une position avancée ne dit pas
      // que le prêche est fini.
      expect(player.value.duration, isNull, reason: 'prémisse');
      await reach(tester, const Duration(minutes: 39, seconds: 40));
      await settle(tester);
      expect(
        (await database().playbackDao.localPositionFor(_id))?.completed,
        isFalse,
      );

      // L'état terminal du lecteur, lui, est un fait observé.
      player.emit(player.value.copyWith(isCompleted: true));
      await settle(tester);

      expect(
        (await database().playbackDao.localPositionFor(_id))?.completed,
        isTrue,
      );
      expect(progress.reports.last.completed, isTrue);
    });
  });

  testWidgets(
      'mené à son terme hors de la fiche, il reste terminé jusqu\'à « Rejouer »',
      (tester) async {
    await pumpApp(tester);
    await launchFromHome(tester);

    player.emit(
      player.value.copyWith(
        position: const Duration(minutes: 40),
        duration: const Duration(minutes: 40),
        isCompleted: true,
      ),
    );
    await settle(tester);

    // Le mini-lecteur (#116) lit cet état pour afficher la barre pleine et
    // « Rejouer » : le suivi global marque le prêche terminé, mais ne remet pas
    // le lecteur à zéro — c'est le geste « Rejouer » qui le fera.
    expect(player.value.isCompleted, isTrue);
    expect(player.value.position, const Duration(minutes: 40));
    expect(
      (await database().playbackDao.localPositionFor(_id))?.completed,
      isTrue,
    );
    expect(progress.reports.last.completed, isTrue);
  });

  group('La rétractation hors de la fiche', () {
    testWidgets('un contenu retiré pendant l\'écoute arrête le son', (
      tester,
    ) async {
      await pumpApp(tester);
      await launchFromHome(tester);
      await reach(tester, const Duration(seconds: 12));

      catalogue.retract();
      await settle(tester);

      // Aucune fiche n'est ouverte : avant #115, personne n'aurait coupé, et le
      // titre d'un enseignement dépublié serait resté sur l'écran verrouillé.
      expect(find.byType(TeachingDetailScreen), findsNothing);
      expect(player.value, const ContentPlayback());
      expect(player.loadedUrl, isNull);
      expect(player.loadedTitle, isNull);
      // L'arrêt garde la place, comme tout arrêt.
      expect(await savedSeconds(tester), 12);
    });

    testWidgets('une resynchronisation, elle, ne coupe rien', (tester) async {
      await pumpApp(tester);
      await launchFromHome(tester);

      // Le provider repasse par « chargement » en gardant sa valeur : le
      // déclencheur est la valeur, jamais l'`AsyncValue`.
      container.invalidate(teachingByIdProvider(_id));
      await settle(tester);

      expect(player.value.contentId, _id);
      expect(player.value.isPlaying, isTrue);
    });
  });

  group('Le passage en arrière-plan', () {
    testWidgets('enregistre la position sans arrêter la lecture', (
      tester,
    ) async {
      await pumpApp(tester);
      await launchFromHome(tester);
      await reach(tester, const Duration(seconds: 12));

      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
        ..handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await settle(tester);

      expect(progress.reports.single.positionSeconds, 12);
      expect(await savedSeconds(tester), 12);
      // Le fidèle range son téléphone dans sa poche : couper ici serait la
      // panne la plus visible de tout le suivi.
      expect(player.value.isPlaying, isTrue);

      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });
  });

  group('Un seul suivi, quel que soit l\'écran', () {
    testWidgets('la fiche n\'écrit pas une seconde fois', (tester) async {
      await pumpApp(tester);
      await launchFromHome(tester);
      await reach(tester, const Duration(seconds: 12));

      router.pushNamed(AppRoute.teachingDetail, pathParameters: {'id': _id});
      await settle(tester);
      expect(find.byType(TeachingDetailScreen), findsOneWidget);
      // Ouvrir la fiche d'un prêche en cours ne le recharge pas.
      expect(player.loadCount, 1);

      await tester.tap(find.byIcon(Icons.pause));
      await settle(tester);

      // Une pause, un rapport : deux suivis en auraient produit deux.
      expect(progress.reports, hasLength(1));
      expect(progress.reports.single.positionSeconds, 12);
    });

    testWidgets('quitter la fiche n\'arrête ni le son ni le suivi', (
      tester,
    ) async {
      await pumpApp(tester);
      await launchFromHome(tester);

      router.pushNamed(AppRoute.teachingDetail, pathParameters: {'id': _id});
      await settle(tester);
      await playThrough(tester, 0, 10);

      router.pop();
      await settle(tester);
      expect(find.byType(TeachingDetailScreen), findsNothing);

      // La sortie d'écran n'est plus un déclencheur : rien n'est rapporté, et
      // le prêche continue — compté, une fois le seuil franchi hors de la fiche.
      expect(progress.reports, isEmpty);
      expect(player.value.isPlaying, isTrue);
      await playThrough(tester, 12, 40);
      await settle(tester);
      expect(plays.reported, [_id]);
    });
  });
}
