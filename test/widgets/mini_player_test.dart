import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:maison_du_miracle/core/config/radio_config.dart';
import 'package:maison_du_miracle/data/players/content_player.dart';
import 'package:maison_du_miracle/data/repositories/calendar_repository.dart';
import 'package:maison_du_miracle/data/repositories/gathering_repository.dart';
import 'package:maison_du_miracle/data/repositories/mediatheque_repository.dart';
import 'package:maison_du_miracle/models/models.dart';
import 'package:maison_du_miracle/router/app_router.dart';
import 'package:maison_du_miracle/screens/home_shell.dart';
import 'package:maison_du_miracle/screens/teaching_detail_screen.dart';
import 'package:maison_du_miracle/state/calendar_providers.dart';
import 'package:maison_du_miracle/state/measurement_providers.dart';
import 'package:maison_du_miracle/state/playback_controller.dart';
import 'package:maison_du_miracle/state/player_providers.dart';
import 'package:maison_du_miracle/widgets/app_background.dart';
import 'package:maison_du_miracle/widgets/home/home_content_cards.dart';
import 'package:maison_du_miracle/widgets/mini_player.dart';

import '../helpers/playback_doubles.dart';
import '../helpers/pump_screen.dart';

/// **Le mini-lecteur dans les onglets** (#116).
///
/// Tout passe par `pumpRouter` : l'application entière — la vraie coquille
/// d'onglets, le vrai accueil, la vraie fiche —, un lecteur inerte, un magasin
/// en mémoire et un rapporteur muet. Ce qui est vérifié est ce qu'un fidèle
/// voit et ce que le lecteur reçoit, jamais la forme du widget.
///
/// ⚠️ **Jamais `pumpAndSettle`** : l'accueil porte le bouton de l'antenne, dont
/// l'animation ne s'arrête pas, et la barre indéterminée tourne elle aussi sans
/// fin. On avance l'horloge.
void main() {
  const withSpeaker = '01940000-0000-7000-8000-0000000000a1';
  const withoutSpeaker = '01940000-0000-7000-8000-0000000000a2';
  const radioMarker = 'page-antenne';

  /// Sans image : `flutter test` répond 400 à tout accès réseau.
  final teachings = [
    Teaching(
      id: withSpeaker,
      title: 'La foi qui déplace',
      author: 'Pasteur Josué',
      teachingTypeId: 1,
      recordedAt: DateTime.utc(2026, 9, 20),
      publishedAt: DateTime.utc(2026, 9, 20, 8),
      playlistUrl: 'https://media.test/foi/master.m3u8',
    ),
    Teaching(
      id: withoutSpeaker,
      title: 'Prière du matin',
      author: '',
      teachingTypeId: 1,
      recordedAt: DateTime.utc(2026, 9, 13),
      publishedAt: DateTime.utc(2026, 9, 13, 8),
      playlistUrl: 'https://media.test/priere/master.m3u8',
    ),
  ];

  late InertContentPlayer player;

  setUp(() => player = InertContentPlayer());
  tearDown(() => player.dispose());

  /// Le routeur de l'application, réduit aux routes que le mini-lecteur
  /// touche : les **vrais** écrans d'accueil et de fiche, et une antenne
  /// factice — ce qu'on vérifie est qu'on y va, pas ce qu'elle dessine.
  GoRouter buildRouter() => GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(
            name: AppRoute.home,
            path: '/home',
            builder: (_, __) => const AppBackground(child: HomeShell()),
          ),
          GoRoute(
            name: AppRoute.teachingDetail,
            path: '/teaching/:id',
            builder: (_, state) => AppBackground(
              child: TeachingDetailScreen(
                teachingId: state.pathParameters['id']!,
              ),
            ),
          ),
          GoRoute(
            name: AppRoute.radio,
            path: '/radio',
            builder: (_, __) => const Scaffold(body: Text(radioMarker)),
          ),
          GoRoute(
            name: AppRoute.media,
            path: '/media',
            builder: (_, __) => const Scaffold(body: Text('page-médiathèque')),
          ),
        ],
      );

  Future<void> pumpApp(WidgetTester tester) async {
    // Écran haut : les listes de l'accueil sont paresseuses, et une carte
    // jamais construite ne peut pas être touchée.
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final router = buildRouter();
    addTearDown(router.dispose);
    await pumpRouter(
      tester,
      router,
      mediatheque: InMemoryMediathequeRepository(teachings: teachings),
      gatherings:
          InMemoryGatheringRepository(gatherings: const [], types: const []),
      overrides: [
        contentPlayerProvider.overrideWithValue(player),
        calendarRepositoryProvider
            .overrideWithValue(InMemoryCalendarRepository()),
        playReporterProvider.overrideWithValue(FakePlayReporter()),
        playSpoolProvider.overrideWithValue(FakePlaySpool()),
      ],
    );
    // Démontage explicite : fermer un flux Drift planifie une minuterie à zéro
    // que le démontage implicite ne laisse jamais partir.
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    });
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
  }

  PlaybackController controllerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(HomeShell)))
          .read(playbackControllerProvider.notifier);

  /// Charge comme le ferait la fiche ou une carte : par le contrôleur.
  Future<void> load(
    WidgetTester tester, {
    String contentId = withSpeaker,
    String title = 'La foi qui déplace',
    String? author = 'Pasteur Josué',
    bool isLive = false,
  }) async {
    await controllerOf(tester).load(
      ContentRequest(
        contentId: contentId,
        url: 'https://media.test/$contentId/master.m3u8',
        title: title,
        author: author,
        isLive: isLive,
      ),
    );
    await settle(tester);
  }

  /// Peint l'état que le lecteur réel publierait — l'inerte ne décode rien.
  Future<void> paint(WidgetTester tester, ContentPlayback playback) async {
    player.emit(playback);
    await tester.pump();
  }

  Finder inMini(Finder finder) =>
      find.descendant(of: find.byKey(MiniPlayer.cardKey), matching: finder);

  LinearProgressIndicator bar(WidgetTester tester) => tester
      .widget<LinearProgressIndicator>(find.byKey(MiniPlayer.progressKey));

  group('Présence', () {
    testWidgets('absent quand rien n\'est chargé', (tester) async {
      await pumpApp(tester);

      expect(find.byType(HomeShell), findsOneWidget);
      expect(find.byKey(MiniPlayer.cardKey), findsNothing);
    });

    testWidgets(
        'présent après un lancement depuis une carte de l\'accueil, '
        'avec titre et orateur', (tester) async {
      await pumpApp(tester);

      await tester
          .tap(find.byKey(HomeCarouselCard.playButtonKey(withSpeaker)).first);
      await settle(tester);

      expect(player.loadCount, 1);
      expect(find.byKey(MiniPlayer.cardKey), findsOneWidget);
      expect(inMini(find.text('La foi qui déplace')), findsOneWidget);
      expect(inMini(find.text('Pasteur Josué')), findsOneWidget);
    });

    testWidgets(
        'aucune ligne d\'orateur sans orateur — jamais « Auteur inconnu »',
        (tester) async {
      await pumpApp(tester);

      // Par la carte : l'enseignement porte un orateur vide, et c'est la
      // chaîne réelle (modèle de lecture → requête) qui doit le taire.
      await tester.tap(
          find.byKey(HomeCarouselCard.playButtonKey(withoutSpeaker)).first);
      await settle(tester);

      expect(inMini(find.text('Prière du matin')), findsOneWidget);
      expect(find.byKey(MiniPlayer.authorKey), findsNothing);
      expect(find.textContaining('inconnu'), findsNothing);
    });

    testWidgets('un orateur blanc ne fait pas de ligne non plus',
        (tester) async {
      await pumpApp(tester);
      await load(tester, author: '   ');

      expect(find.byKey(MiniPlayer.cardKey), findsOneWidget);
      expect(find.byKey(MiniPlayer.authorKey), findsNothing);
    });
  });

  group('Transport', () {
    testWidgets('lecture puis pause arrivent au lecteur', (tester) async {
      await pumpApp(tester);
      await load(tester);
      expect(player.value.isPlaying, isFalse);
      expect(inMini(find.byIcon(Icons.play_arrow_rounded)), findsOneWidget);

      await tester.tap(find.byKey(MiniPlayer.mainButtonKey));
      await tester.pump();
      expect(player.value.isPlaying, isTrue);
      expect(inMini(find.byIcon(Icons.pause_rounded)), findsOneWidget);

      await tester.tap(find.byKey(MiniPlayer.mainButtonKey));
      await tester.pump();
      expect(player.value.isPlaying, isFalse);
    });

    testWidgets('−30 s et +30 s, au pas de la notification', (tester) async {
      await pumpApp(tester);
      await load(tester);
      await paint(
        tester,
        const ContentPlayback(
          contentId: withSpeaker,
          position: Duration(minutes: 5),
          duration: Duration(minutes: 40),
          hasStarted: true,
        ),
      );

      await tester.tap(find.byKey(MiniPlayer.skipForwardKey));
      await tester.pump();
      expect(player.value.position, const Duration(minutes: 5, seconds: 30));

      await tester.tap(find.byKey(MiniPlayer.skipBackwardKey));
      await tester.pump();
      await tester.tap(find.byKey(MiniPlayer.skipBackwardKey));
      await tester.pump();
      expect(player.value.position, const Duration(minutes: 4, seconds: 30));
      // Le pas est la constante partagée, et aucune autre.
      expect(
        const Duration(minutes: 5) - player.value.position,
        kContentSkipInterval,
      );
    });

    testWidgets('la ✕ arrête le lecteur et ferme le mini-lecteur',
        (tester) async {
      await pumpApp(tester);
      await load(tester);
      controllerOf(tester).play();
      await tester.pump();

      await tester.tap(find.byKey(MiniPlayer.closeKey));
      await tester.pump();

      // Le lecteur inerte vide ce que le système affiche au `stop`, comme le
      // handler réel retire la notification.
      expect(player.value.contentId, isNull);
      expect(player.value.isPlaying, isFalse);
      expect(player.loadedUrl, isNull);
      expect(find.byKey(MiniPlayer.cardKey), findsNothing);
    });
  });

  group('Ouvrir la fiche', () {
    testWidgets('la vignette ou le titre ouvre /teaching/:id sans recharger',
        (tester) async {
      await pumpApp(tester);
      await load(tester);
      controllerOf(tester).play();
      await paint(
        tester,
        const ContentPlayback(
          contentId: withSpeaker,
          position: Duration(minutes: 12),
          duration: Duration(minutes: 40),
          isPlaying: true,
          hasStarted: true,
        ),
      );
      expect(player.loadCount, 1);

      await tester.tap(find.byKey(MiniPlayer.titleKey));
      await settle(tester);

      expect(find.byType(TeachingDetailScreen), findsOneWidget);
      // **Ni rechargé, ni redémarré** : la fiche reconnaît un contenu que le
      // lecteur tient déjà.
      expect(player.loadCount, 1);
      expect(player.value.contentId, withSpeaker);
      expect(player.value.position, const Duration(minutes: 12));
      expect(player.value.isPlaying, isTrue);
    });

    testWidgets('la vignette mène au même endroit', (tester) async {
      await pumpApp(tester);
      await load(tester);

      await tester.tap(find.byKey(MiniPlayer.artworkKey));
      await settle(tester);

      expect(find.byType(TeachingDetailScreen), findsOneWidget);
      expect(player.loadCount, 1);
    });
  });

  group('Fin de lecture', () {
    testWidgets('reste affiché, barre pleine, et « Rejouer » repart de zéro',
        (tester) async {
      await pumpApp(tester);
      await load(tester);
      await paint(
        tester,
        const ContentPlayback(
          contentId: withSpeaker,
          position: Duration(minutes: 40),
          duration: Duration(minutes: 40),
          isCompleted: true,
          hasStarted: true,
        ),
      );

      expect(find.byKey(MiniPlayer.cardKey), findsOneWidget);
      expect(bar(tester).value, 1.0);
      expect(inMini(find.byIcon(Icons.replay_rounded)), findsOneWidget);

      await tester.tap(find.byKey(MiniPlayer.mainButtonKey));
      await tester.pump();

      expect(player.value.position, Duration.zero);
      expect(player.value.isPlaying, isTrue);
      expect(player.loadCount, 1, reason: 'rejouer ne recharge pas');
    });
  });

  group('Panne', () {
    testWidgets('après démarrage : « Lecture interrompue » et « Reprendre »',
        (tester) async {
      await pumpApp(tester);
      await load(tester);
      await paint(
        tester,
        ContentPlayback(
          contentId: withSpeaker,
          position: const Duration(minutes: 7),
          duration: const Duration(minutes: 40),
          hasStarted: true,
          error: Exception('réseau perdu'),
        ),
      );

      expect(inMini(find.text('Lecture interrompue')), findsOneWidget);
      // La phrase prend la place de l'orateur, elle ne s'y ajoute pas.
      expect(find.byKey(MiniPlayer.authorKey), findsNothing);

      final semantics = tester.ensureSemantics();
      expect(inMini(find.bySemanticsLabel('Reprendre')), findsOneWidget);
      semantics.dispose();

      await tester.tap(find.byKey(MiniPlayer.mainButtonKey));
      await tester.pump();

      expect(player.resumeCount, 1);
      // Reprendre, c'est à la position — jamais au début.
      expect(player.value.position, const Duration(minutes: 7));
      expect(player.value.hasError, isFalse);
      expect(player.loadCount, 1);
    });

    testWidgets('avant tout son : « Écoute impossible hors ligne »',
        (tester) async {
      await pumpApp(tester);
      await load(tester);
      await paint(
        tester,
        ContentPlayback(
          contentId: withSpeaker,
          error: Exception('pas de réseau'),
        ),
      );

      expect(inMini(find.text('Écoute impossible hors ligne')), findsOneWidget);
      expect(inMini(find.text('Lecture interrompue')), findsNothing);
    });
  });

  group('Progression', () {
    testWidgets('une durée inconnue donne une barre indéterminée',
        (tester) async {
      await pumpApp(tester);
      await load(tester);
      await paint(
        tester,
        const ContentPlayback(
          contentId: withSpeaker,
          position: Duration(minutes: 3),
          isPlaying: true,
          hasStarted: true,
        ),
      );

      expect(bar(tester).value, isNull);
    });

    testWidgets('une durée connue donne la part écoulée', (tester) async {
      await pumpApp(tester);
      await load(tester);
      await paint(
        tester,
        const ContentPlayback(
          contentId: withSpeaker,
          position: Duration(minutes: 10),
          duration: Duration(minutes: 40),
          hasStarted: true,
        ),
      );

      expect(bar(tester).value, closeTo(0.25, 1e-9));
    });

    testWidgets(
        'seuls la barre et le bouton suivent la position — '
        'la carte, l\'image et le titre ne se reconstruisent pas',
        (tester) async {
      await pumpApp(tester);
      await load(tester);
      await paint(
        tester,
        const ContentPlayback(
          contentId: withSpeaker,
          position: Duration(minutes: 10),
          duration: Duration(minutes: 40),
          isPlaying: true,
          hasStarted: true,
        ),
      );
      final title = tester.widget(find.byKey(MiniPlayer.titleKey));
      final artwork = tester.widget(find.byKey(MiniPlayer.artworkKey));
      final progress = tester.widget(find.byKey(MiniPlayer.progressKey));

      await paint(
        tester,
        const ContentPlayback(
          contentId: withSpeaker,
          position: Duration(minutes: 20),
          duration: Duration(minutes: 40),
          isPlaying: true,
          hasStarted: true,
        ),
      );

      // Un widget reconstruit est une nouvelle instance ; un widget qui ne
      // l'est pas reste la même.
      expect(identical(tester.widget(find.byKey(MiniPlayer.titleKey)), title),
          isTrue);
      expect(
          identical(tester.widget(find.byKey(MiniPlayer.artworkKey)), artwork),
          isTrue);
      expect(
          identical(
              tester.widget(find.byKey(MiniPlayer.progressKey)), progress),
          isFalse);
      expect(bar(tester).value, closeTo(0.5, 1e-9));
    });
  });

  group('Radio', () {
    Future<void> loadRadio(WidgetTester tester) => load(
          tester,
          contentId: RadioConfig.contentId,
          title: 'New Life Radio',
          author: null,
          isLive: true,
        );

    testWidgets('variante EN DIRECT, sans barre ni sauts', (tester) async {
      await pumpApp(tester);
      await loadRadio(tester);

      expect(inMini(find.text('New Life Radio')), findsOneWidget);
      expect(find.byKey(MiniPlayer.liveBadgeKey), findsOneWidget);
      expect(inMini(find.text('EN DIRECT')), findsOneWidget);
      expect(find.byKey(MiniPlayer.progressKey), findsNothing);
      expect(find.byKey(MiniPlayer.skipBackwardKey), findsNothing);
      expect(find.byKey(MiniPlayer.skipForwardKey), findsNothing);
      expect(find.byKey(MiniPlayer.mainButtonKey), findsOneWidget);
    });

    testWidgets('un appui ouvre /radio', (tester) async {
      await pumpApp(tester);
      await loadRadio(tester);

      await tester.tap(find.byKey(MiniPlayer.titleKey));
      await settle(tester);

      expect(find.text(radioMarker), findsOneWidget);
      expect(find.byType(TeachingDetailScreen), findsNothing);
      expect(player.loadCount, 1);
    });

    testWidgets('la ✕ arrête l\'antenne', (tester) async {
      await pumpApp(tester);
      await loadRadio(tester);
      controllerOf(tester).play();
      await tester.pump();

      await tester.tap(find.byKey(MiniPlayer.closeKey));
      await tester.pump();

      expect(player.value.contentId, isNull);
      expect(player.value.isPlaying, isFalse);
      expect(find.byKey(MiniPlayer.cardKey), findsNothing);
    });
  });

  group('Textes', () {
    testWidgets('les libellés d\'accessibilité viennent des .arb',
        (tester) async {
      await pumpApp(tester);
      await load(tester);

      final semantics = tester.ensureSemantics();
      expect(find.bySemanticsLabel('Reculer de 30 secondes'), findsOneWidget);
      expect(find.bySemanticsLabel('Avancer de 30 secondes'), findsOneWidget);
      expect(find.bySemanticsLabel('Fermer le lecteur'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Ouvrir le lecteur : La foi qui déplace'),
        findsOneWidget,
      );
      semantics.dispose();
    });
  });
}
