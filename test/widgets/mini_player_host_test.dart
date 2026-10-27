import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:maison_du_miracle/data/app_version.dart';
import 'package:maison_du_miracle/data/legal_notice_store.dart';
import 'package:maison_du_miracle/data/players/content_player.dart';
import 'package:maison_du_miracle/data/players/status_player.dart';
import 'package:maison_du_miracle/data/repositories/announcement_repository.dart';
import 'package:maison_du_miracle/data/repositories/auth_repository.dart';
import 'package:maison_du_miracle/data/repositories/calendar_repository.dart';
import 'package:maison_du_miracle/data/repositories/gathering_repository.dart';
import 'package:maison_du_miracle/data/repositories/mediatheque_repository.dart';
import 'package:maison_du_miracle/models/announcement_view.dart';
import 'package:maison_du_miracle/models/models.dart';
import 'package:maison_du_miracle/router/app_router.dart';
import 'package:maison_du_miracle/screens/home_screen.dart';
import 'package:maison_du_miracle/screens/announcements_screen.dart';
import 'package:maison_du_miracle/screens/groups_screen.dart';
import 'package:maison_du_miracle/screens/home_shell.dart';
import 'package:maison_du_miracle/screens/media_library_screen.dart';
import 'package:maison_du_miracle/screens/profile_screen.dart';
import 'package:maison_du_miracle/screens/teaching_detail_screen.dart';
import 'package:maison_du_miracle/state/app_version_providers.dart';
import 'package:maison_du_miracle/state/calendar_providers.dart';
import 'package:maison_du_miracle/state/playback_controller.dart';
import 'package:maison_du_miracle/state/player_providers.dart';
import 'package:maison_du_miracle/widgets/app_background.dart';
import 'package:maison_du_miracle/widgets/app_bottom_nav.dart';
import 'package:maison_du_miracle/widgets/app_update_banner.dart';
import 'package:maison_du_miracle/widgets/legal_notice_banner.dart';
import 'package:maison_du_miracle/widgets/mini_player.dart';
import 'package:maison_du_miracle/widgets/mini_player_host.dart';

import '../helpers/pump_screen.dart';
import '../helpers/signed_in_auth.dart';

/// **Le mini-lecteur partout** (#117) : monté au-dessus du `Navigator`, il
/// suit le fidèle sur les écrans poussés, s'efface là où il ferait doublon ou
/// gênerait, et écarte le bas des listes.
///
/// Tout passe par `pumpRouter`, qui pose `MiniPlayerHost` exactement comme
/// `app.dart` : la vraie coquille, le vrai accueil, la vraie médiathèque, la
/// vraie fiche, un lecteur inerte, un magasin en mémoire et un rapporteur muet.
///
/// ⚠️ **Jamais `pumpAndSettle`** : l'accueil porte le bouton de l'antenne, dont
/// l'animation ne s'arrête pas. On avance l'horloge.
///
/// ⚠️ Les rapporteurs d'écoute (`playReporterProvider`, `playSpoolProvider`)
/// ne se surchargent **pas** ici : `pumpRouter` les pose déjà, et Riverpod 3
/// refuse deux surcharges du même provider.
void main() {
  const radioMarker = 'page-antenne';
  const authMarker = 'page-connexion';
  const legalMarker = 'page-barrière';

  String idOf(int i) =>
      '01940000-0000-7000-8000-${(0xb00 + i).toRadixString(16).padLeft(12, '0')}';
  String titleOf(int i) => 'Enseignement ${i.toString().padLeft(2, '0')}';

  /// Assez d'enseignements pour que la médiathèque déborde de l'écran. Les
  /// dates décroissent : le dernier de la liste est le seizième.
  final teachings = [
    for (var i = 1; i <= 16; i++)
      Teaching(
        id: idOf(i),
        title: titleOf(i),
        author: 'Pasteur Josué',
        teachingTypeId: 1,
        recordedAt: DateTime.utc(2026, 9, 30 - i),
        publishedAt: DateTime.utc(2026, 9, 30 - i, 8),
        playlistUrl: 'https://media.test/$i/master.m3u8',
      ),
  ];

  late InertContentPlayer player;
  late GoRouter router;

  setUp(() => player = InertContentPlayer());
  tearDown(() => player.dispose());

  /// Le routeur de l'application, réduit aux routes que le mini-lecteur
  /// touche — avec l'observateur des fenêtres surgissantes, comme
  /// `routerProvider`.
  GoRouter buildRouter() => GoRouter(
        initialLocation: '/home',
        observers: [MiniPlayerPopupObserver()],
        routes: [
          GoRoute(
            name: AppRoute.home,
            path: '/home',
            builder: (_, __) => const AppBackground(child: HomeShell()),
          ),
          GoRoute(
            name: AppRoute.media,
            path: '/media',
            builder: (_, __) =>
                const AppBackground(child: MediaLibraryScreen()),
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
            name: AppRoute.authIdentifier,
            path: '/auth',
            builder: (_, __) => const Scaffold(body: Text(authMarker)),
          ),
          GoRoute(
            name: AppRoute.legalAccept,
            path: '/legal/accept',
            builder: (_, __) => const Scaffold(body: Text(legalMarker)),
          ),
        ],
      );

  Future<void> pumpApp(
    WidgetTester tester, {
    AuthRepository? auth,
    AnnouncementRepository? announcements,
    LegalNoticeStore? legalNotice,
    String? updateThreshold,
  }) async {
    // Un téléphone : la médiathèque doit déborder pour avoir un « dernier
    // élément » à atteindre.
    tester.view.physicalSize = const Size(420, 860);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    router = buildRouter();
    addTearDown(router.dispose);
    await pumpRouter(
      tester,
      router,
      auth: auth,
      announcements: announcements ??
          InMemoryAnnouncementRepository(announcements: const []),
      legalNotice: legalNotice,
      updateThreshold: updateThreshold,
      mediatheque: InMemoryMediathequeRepository(teachings: teachings),
      gatherings:
          InMemoryGatheringRepository(gatherings: const [], types: const []),
      overrides: [
        contentPlayerProvider.overrideWithValue(player),
        statusPlayerProvider.overrideWithValue(InertStatusPlayer()),
        calendarRepositoryProvider
            .overrideWithValue(InMemoryCalendarRepository()),
        appVersionReaderProvider.overrideWithValue(
          const FixedAppVersionReader(
            AppVersionInfo(version: '1.0.0', build: '1'),
          ),
        ),
      ],
    );
    // Démontage explicite : fermer un flux Drift planifie une minuterie à zéro
    // que le démontage implicite ne laisse jamais partir.
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    });
  }

  /// Une image pour la navigation, une pour l'hôte qui se recale après elle,
  /// une pour la mesure de la carte.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
  }

  PlaybackController controllerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(MiniPlayerHost)))
          .read(playbackControllerProvider.notifier);

  Future<void> load(WidgetTester tester, {int index = 1}) async {
    await controllerOf(tester).load(
      ContentRequest(
        contentId: idOf(index),
        url: 'https://media.test/$index/master.m3u8',
        title: titleOf(index),
        author: 'Pasteur Josué',
      ),
    );
    await settle(tester);
  }

  final mini = find.byKey(MiniPlayer.cardKey);

  Future<void> openMedia(WidgetTester tester) async {
    // **Le bouton central, inchangé** : il ouvre toujours la médiathèque.
    await tester.tap(find.byType(FloatingActionButton));
    await settle(tester);
    expect(find.byType(MediaLibraryScreen), findsOneWidget);
  }

  Future<void> back(WidgetTester tester) async {
    router.pop();
    await settle(tester);
  }

  /// Les scénarios qui valent pour tous : un invité et un membre voient le même
  /// mini-lecteur.
  for (final member in [false, true]) {
    final who = member ? 'membre' : 'invité';
    AuthRepository auth() =>
        member ? SignedInAuthRepository() : InMemoryAuthRepository();

    group('Écrans empilés ($who)', () {
      testWidgets('la médiathèque poussée garde le mini-lecteur, pilotable',
          (tester) async {
        await pumpApp(tester, auth: auth());
        await load(tester);
        await openMedia(tester);

        expect(mini, findsOneWidget);
        expect(find.byType(AppBottomNav), findsNothing);
        // **En bas, dans la zone sûre** — plus au-dessus d'une barre absente.
        final screen = tester.getSize(find.byType(MediaLibraryScreen));
        expect(
          tester.getRect(mini).bottom,
          closeTo(screen.height - MiniPlayerHost.stackedMargin.bottom, 1),
        );

        await tester.tap(find.byKey(MiniPlayer.mainButtonKey));
        await tester.pump();
        expect(player.value.isPlaying, isTrue);
        await tester.tap(find.byKey(MiniPlayer.mainButtonKey));
        await tester.pump();
        expect(player.value.isPlaying, isFalse);
      });

      testWidgets('la fiche le masque, il revient au dépilement',
          (tester) async {
        await pumpApp(tester, auth: auth());
        await load(tester);
        await openMedia(tester);

        await tester.tap(find.byKey(MiniPlayer.titleKey));
        await settle(tester);
        expect(find.byType(TeachingDetailScreen), findsOneWidget);
        expect(mini, findsNothing);
        expect(player.loadCount, 1);

        await back(tester);
        expect(find.byType(MediaLibraryScreen), findsOneWidget);
        expect(mini, findsOneWidget);
      });

      testWidgets('/radio le masque, il revient au dépilement', (tester) async {
        await pumpApp(tester, auth: auth());
        await load(tester);

        router.pushNamed(AppRoute.radio);
        await settle(tester);
        expect(find.text(radioMarker), findsOneWidget);
        expect(mini, findsNothing);

        await back(tester);
        expect(find.byType(HomeShell), findsOneWidget);
        expect(mini, findsOneWidget);
      });
    });
  }

  group('Masquage', () {
    testWidgets(
        'les parcours bloquants le masquent : authentification et '
        'barrière de consentement', (tester) async {
      await pumpApp(tester);
      await load(tester);

      router.pushNamed(AppRoute.authIdentifier);
      await settle(tester);
      expect(find.text(authMarker), findsOneWidget);
      expect(mini, findsNothing);
      await back(tester);
      expect(mini, findsOneWidget);

      router.pushNamed(AppRoute.legalAccept);
      await settle(tester);
      expect(find.text(legalMarker), findsOneWidget);
      expect(mini, findsNothing);
    });

    testWidgets(
        'la visionneuse d\'Annonces le masque, même sur un statut image, '
        'et il revient quand on la quitte', (tester) async {
      // Une **image**, pas une vidéo : c'est toute la visionneuse qui masque la
      // carte, pas la condition qui estompe le bouton central.
      await pumpApp(
        tester,
        announcements: InMemoryAnnouncementRepository(
          announcements: [
            AnnouncementView(
              id: 'statut-image',
              publishedAt: DateTime.utc(2026, 10, 1),
              accountName: 'Maison du Miracle',
              backgroundImageUrl: 'https://media.test/statut.jpg',
            ),
          ],
        ),
      );
      await load(tester);
      expect(mini, findsOneWidget);

      Finder tab(String label) => find.descendant(
            of: find.byType(AppBottomNav),
            matching: find.text(label),
          );
      await tester.tap(tab('Annonces'));
      await settle(tester);
      expect(mini, findsNothing);
      // Masqué, pas arrêté : la lecture continue sous la visionneuse.
      expect(
        ProviderScope.containerOf(tester.element(find.byType(MiniPlayerHost)))
            .read(playbackControllerProvider),
        isNotNull,
      );

      await tester.tap(tab('Accueil'));
      await settle(tester);
      expect(mini, findsOneWidget);
    });

    testWidgets('le menu latéral ouvert le masque', (tester) async {
      await pumpApp(tester);
      await load(tester);

      await tester.tap(find.byKey(HomeScreen.menuButtonKey));
      await settle(tester);

      expect(mini, findsNothing);
    });

    testWidgets('un dialogue le masque, il revient à sa fermeture',
        (tester) async {
      await pumpApp(tester);
      await load(tester);

      final navigator = router.routerDelegate.navigatorKey.currentContext!;
      showDialog<void>(
        context: navigator,
        builder: (_) => const AlertDialog(content: Text('dialogue')),
      );
      await settle(tester);
      expect(find.text('dialogue'), findsOneWidget);
      expect(mini, findsNothing);

      Navigator.of(navigator).pop();
      await settle(tester);
      expect(mini, findsOneWidget);
    });

    testWidgets('le clavier ouvert le masque', (tester) async {
      await pumpApp(tester);
      await load(tester);
      await openMedia(tester);
      expect(mini, findsOneWidget);

      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await settle(tester);

      expect(mini, findsNothing);
    });
  });

  group('Marges des listes', () {
    testWidgets(
        'médiathèque : le dernier enseignement reste touchable sous le '
        'mini-lecteur', (tester) async {
      await pumpApp(tester);
      await load(tester);
      await openMedia(tester);

      final last = find.text(titleOf(16));
      await tester.dragUntilVisible(
        last,
        find.byType(MediaLibraryScreen),
        const Offset(0, -200),
      );
      // Au bout de la liste, et non simplement en vue. Le geste part du
      // milieu de l'écran : parti du titre, il pourrait tomber sur la carte.
      await tester.drag(
        find.byType(MediaLibraryScreen),
        const Offset(0, -2000),
      );
      await settle(tester);

      final row = find.ancestor(of: last, matching: find.byType(InkWell)).first;
      expect(
        tester.getRect(row).bottom,
        lessThanOrEqualTo(tester.getRect(mini).top),
      );

      await tester.tap(last);
      await settle(tester);
      final detail = tester
          .widget<TeachingDetailScreen>(find.byType(TeachingDetailScreen));
      expect(detail.teachingId, idOf(16));
    });

    testWidgets('accueil : la marge basse dégage le mini-lecteur',
        (tester) async {
      await pumpApp(tester);
      final list = find
          .descendant(
            of: find.byType(HomeScreen),
            matching: find.byType(ListView),
          )
          .first;
      final before =
          (tester.widget<ListView>(list).padding! as EdgeInsets).bottom;

      await load(tester);
      expect(mini, findsOneWidget);

      // La fin du contenu, liste tirée jusqu'au bout : le bas de la vue moins
      // sa marge basse. Elle doit tomber au-dessus de la carte.
      final padding =
          (tester.widget<ListView>(list).padding! as EdgeInsets).bottom;
      final contentEnd = tester.getRect(list).bottom - padding;
      expect(padding, greaterThan(before));
      expect(contentEnd, lessThanOrEqualTo(tester.getRect(mini).top));
    });
  });

  group('Marges des onglets', () {
    Finder tab(String label) => find.descendant(
          of: find.byType(AppBottomNav),
          matching: find.text(label),
        );

    /// La marge basse de la liste verticale de [screen] — la première
    /// `ListView` rencontrée, avant les rangées horizontales qu'elle porte.
    Finder listOf(Type screen) => find
        .descendant(of: find.byType(screen), matching: find.byType(ListView))
        .first;

    double bottomPadding(WidgetTester tester, Finder list) =>
        (tester.widget<ListView>(list).padding! as EdgeInsets).bottom;

    /// **La carte au-dessus de la barre**, et descendue dans le haut du bouton
    /// central, qui passe devant elle par l'encoche — la même règle que sur
    /// l'accueil.
    void expectAboveBar(WidgetTester tester) {
      final bar = tester.getRect(find.byType(AppBottomNav));
      expect(mini, findsOneWidget);
      expect(tester.getRect(mini).bottom, lessThanOrEqualTo(bar.top));
      expect(tester.getRect(mini).bottom, greaterThan(bar.top - 56 / 2));
      expect(bar.height, lessThan(AppBottomNav.barHeight + 1));
    }

    /// **La fin du contenu**, liste tirée jusqu'au bout, tombe au-dessus de la
    /// carte : le bas de la vue moins sa marge basse — et cette marge a grandi
    /// quand la carte est apparue.
    Future<void> expectListClears(
      WidgetTester tester, {
      required String label,
      required Type screen,
    }) async {
      await tester.tap(tab(label));
      await settle(tester);
      final before = bottomPadding(tester, listOf(screen));

      await load(tester);
      expectAboveBar(tester);
      final list = listOf(screen);
      final padding = bottomPadding(tester, list);
      expect(padding, greaterThan(before));
      expect(
        tester.getRect(list).bottom - padding,
        lessThanOrEqualTo(tester.getRect(mini).top),
      );
    }

    testWidgets('Échanges : au-dessus de la barre, la liste dégagée',
        (tester) async {
      await pumpApp(tester, auth: SignedInAuthRepository());
      await expectListClears(tester, label: 'Échanges', screen: GroupsScreen);
    });

    testWidgets('Profil : au-dessus de la barre, la liste dégagée',
        (tester) async {
      await pumpApp(tester, auth: SignedInAuthRepository());
      await expectListClears(tester, label: 'Profil', screen: ProfileScreen);
    });

    testWidgets(
        'Annonces, mur vide : pas de visionneuse, donc la carte reste, '
        'au-dessus de la barre et sous le message', (tester) async {
      // `pumpApp` pose un mur vide par défaut.
      await pumpApp(tester);
      await tester.tap(tab('Annonces'));
      await settle(tester);
      expect(find.text('Aucune annonce'), findsOneWidget);

      await load(tester);

      expect(find.byType(AnnouncementsScreen), findsOneWidget);
      expectAboveBar(tester);
      // Le message du mur vide n'est pas recouvert.
      expect(
        tester.getRect(find.text('Aucune annonce')).bottom,
        lessThanOrEqualTo(tester.getRect(mini).top),
      );
    });
  });

  group('Dans la coquille', () {
    testWidgets(
        'au-dessus de la barre ; les bandeaux de mise à jour et de mention '
        'légale au-dessus de lui', (tester) async {
      await pumpApp(
        tester,
        legalNotice: InMemoryLegalNoticeStore(),
        updateThreshold: '9.0.0',
      );
      await load(tester);

      final update = find.byKey(AppUpdateBanner.bannerKey);
      final notice = find.byKey(LegalNoticeBanner.bannerKey);
      expect(update, findsOneWidget);
      expect(notice, findsOneWidget);
      expect(mini, findsOneWidget);

      final bar = tester.getRect(find.byType(AppBottomNav));
      final card = tester.getRect(mini);
      // La carte descend dans le haut du bouton central (qui passe devant
      // par l'encoche), sans recouvrir la barre.
      expect(card.bottom, lessThanOrEqualTo(bar.top));
      expect(card.bottom, greaterThan(bar.top - 56 / 2));
      expect(
        tester.getRect(notice).bottom,
        lessThanOrEqualTo(card.top),
      );
      // Le bandeau de mise à jour reste au-dessus de la carte. La mention
      // légale, elle, se pose par-dessus toute la coquille (elle bloque
      // l'application) : le bandeau est alors derrière sa barrière.
      expect(
        tester.getRect(update).bottom,
        lessThanOrEqualTo(card.top),
      );
      // La barre ne grandit pas de la place de la carte.
      expect(bar.height, lessThan(AppBottomNav.barHeight + 1));
    });
  });

  group('Hors trame', () {
    testWidgets(
        'une route qui change pendant une construction hors trame ne lève '
        'pas — le garde ne peut pas se fier à la phase', (tester) async {
      await pumpApp(tester);
      await load(tester);

      // **La fenêtre que `pumpWidget` ne sait pas ouvrir.**
      //
      // `runApp` monte l'arbre **hors trame** : `RootWidget.attach` ouvre un
      // `buildScope` synchrone, et `schedulerPhase` y vaut `idle`. Le `Router`
      // s'y monte **sous** l'hôte, y appelle `setInitialRoutePath`, donc le
      // délégué prévient ses auditeurs en pleine construction — avec une phase
      // qui n'est pas `persistentCallbacks`.
      //
      // `tester.pumpWidget` ne reproduit pas cette fenêtre : le `rootElement`
      // du binding de test existe déjà, l'attache se réduit à un
      // `markNeedsBuild`, et toute la construction retombe dans la trame
      // (mesuré : `persistentCallbacks`). On rejoue donc la condition
      // elle-même, avec une navigation ordinaire pour la déclencher.
      //
      // La cible de cette construction est le `MediaQuery` que l'hôte pose
      // **autour du `Router`** : la place exacte d'où le `Router` se monte au
      // démarrage. L'hôte y est un *ancêtre* — c'est ce que `setState`
      // interdit —, et le `Router` un *descendant*, donc exempté comme il
      // l'est pendant son propre montage.
      final target = tester.element(
        find
            .ancestor(
              of: find.byType(Router<Object>),
              matching: find.byType(MediaQuery),
            )
            .first,
      );
      tester.binding.buildOwner!.buildScope(target, () {
        expect(SchedulerBinding.instance.schedulerPhase, SchedulerPhase.idle);
        router.goNamed(AppRoute.media);
      });
      await settle(tester);

      // Et la carte suit bien la nouvelle route.
      expect(find.byType(MediaLibraryScreen), findsOneWidget);
      expect(mini, findsOneWidget);
    });

    testWidgets('différer sans demander l\'image figerait la carte',
        (tester) async {
      await pumpApp(tester);
      await load(tester);
      // `/radio` **à la place** de l'accueil, pas par-dessus : la coquille
      // démontée, plus rien n'anime l'écran, et le binding se tait. C'est la
      // seule façon de voir qui demande l'image.
      router.goNamed(AppRoute.radio);
      await settle(tester);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.binding.hasScheduledFrame, isFalse);

      // Une fenêtre surgissante annoncée à l'observateur : le seul réveil de
      // l'hôte qui ne passe **pas** par un `setState` du `Router` ou du
      // `Navigator`. Reporter la reconstruction après l'image sans réclamer
      // cette image, et elle n'arrive jamais.
      MiniPlayerPopupObserver.of(router)!.didPush(
        RawDialogRoute<void>(
          pageBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
        null,
      );

      expect(tester.binding.hasScheduledFrame, isTrue);
    });
  });
}
