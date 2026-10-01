import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:maison_du_miracle/data/repositories/auth_repository.dart';
import 'package:maison_du_miracle/data/repositories/branch_repository.dart';
import 'package:maison_du_miracle/data/repositories/calendar_repository.dart';
import 'package:maison_du_miracle/l10n/l10n_setup.dart';
import 'package:maison_du_miracle/models/models.dart';
import 'package:maison_du_miracle/router/app_router.dart';
import 'package:maison_du_miracle/screens/home_screen.dart';
import 'package:maison_du_miracle/state/auth_providers.dart';
import 'package:maison_du_miracle/state/calendar_providers.dart';
import 'package:maison_du_miracle/theme/app_theme.dart';
import 'package:maison_du_miracle/widgets/app_empty_state.dart';
import 'package:maison_du_miracle/widgets/app_error_state.dart';
import 'package:maison_du_miracle/widgets/app_list_skeleton.dart';

import '../helpers/pump_screen.dart';

/// Repository d'agenda espion : note chaque fenêtre demandée et rend ce que le
/// test a préparé.
///
/// Aucun réseau — `flutter test` répond 400 à tout accès réel, et `GET /events`
/// n'est de toute façon pas encore déployé (issue serveur #80).
class _SpyCalendarRepository implements CalendarRepository {
  /// Réponses successives, consommées dans l'ordre. Vide, [window] est rendue.
  final List<EventWindow> replies = [];

  /// Réponse par défaut, une fois [replies] épuisée.
  EventWindow window = EventWindow.empty;

  /// Échec levé à la place de la réponse, quand le test veut une panne.
  CalendarException? failure;

  /// Quand il est posé, la réponse attend que le test l'ouvre — c'est ainsi
  /// qu'on observe l'état de chargement sans minuterie en attente au teardown.
  Completer<void>? gate;

  /// Bornes basses (`from`) reçues, dans l'ordre : une par appel.
  final List<DateTime> froms = [];

  /// Plafonds (`limit`) reçus, dans l'ordre.
  final List<int?> limits = [];

  int get callCount => froms.length;

  @override
  Future<EventWindow> events({
    required DateTime from,
    DateTime? to,
    int? branchId,
    int? limit,
  }) async {
    froms.add(from);
    limits.add(limit);
    final pending = gate;
    if (pending != null) await pending.future;
    final error = failure;
    if (error != null) throw error;
    return replies.isEmpty ? window : replies.removeAt(0);
  }
}

/// Occurrence minimale : ce que rend le serveur pour une prière de zone.
ChurchEvent _event(String id, DateTime startsAt, String title) => ChurchEvent(
      id: id,
      startsAt: startsAt,
      timezone: 'Africa/Lome',
      title: {'fr': title},
      place: 'Temple Central',
    );

DateTime _inHours(int hours) =>
    DateTime.now().toUtc().add(Duration(hours: hours));

DateTime _hoursAgo(int hours) =>
    DateTime.now().toUtc().subtract(Duration(hours: hours));

/// Monte l'accueil avec le repository d'agenda espion.
Future<void> _pumpHome(
  WidgetTester tester,
  _SpyCalendarRepository repository,
) =>
    pumpScreen(
      tester,
      const Scaffold(body: HomeScreen()),
      overrides: [
        calendarRepositoryProvider.overrideWithValue(repository),
      ],
    );

/// Enchaîne une mise en veille complète puis un réveil.
///
/// La séquence est celle du système (`resumed → inactive → hidden → paused`,
/// puis retour) : le cycle de vie n'accepte pas les sauts d'état.
Future<void> _sleepAndResume(WidgetTester tester) async {
  const cycle = [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ];
  for (final state in cycle) {
    tester.binding.handleAppLifecycleStateChanged(state);
    await tester.pump();
  }
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  late _SpyCalendarRepository repository;

  setUp(() => repository = _SpyCalendarRepository());

  group('Accueil — section « À venir »', () {
    testWidgets('affiche les prochaines occurrences, la plus proche en tête',
        (tester) async {
      repository.window = EventWindow(items: [
        _event('evt-1', _inHours(3), 'Culte de Gloire'),
        _event('evt-2', _inHours(30), 'Veillée de Prière'),
        _event('evt-3', _inHours(80), 'Étude biblique'),
      ]);

      await _pumpHome(tester, repository);

      expect(find.text('Culte de Gloire'), findsOneWidget);
      expect(find.text('Veillée de Prière'), findsOneWidget);
      expect(find.text('Étude biblique'), findsOneWidget);
      // Ordre chronologique servi par le serveur, conservé à l'écran.
      expect(
        tester.getTopLeft(find.text('Culte de Gloire')).dx,
        lessThan(tester.getTopLeft(find.text('Veillée de Prière')).dx),
      );
      expect(
        tester.getTopLeft(find.text('Veillée de Prière')).dx,
        lessThan(tester.getTopLeft(find.text('Étude biblique')).dx),
      );
    });

    testWidgets('demande les trois prochaines à partir de maintenant',
        (tester) async {
      final before = DateTime.now().toUtc();
      repository.window =
          EventWindow(items: [_event('evt-1', _inHours(3), 'Culte')]);

      await _pumpHome(tester, repository);

      expect(repository.callCount, 1);
      expect(repository.limits.single, kUpcomingEventsLimit);
      expect(repository.froms.single.isBefore(before), isFalse);
    });

    testWidgets('aucune occurrence déjà commencée ne s\'affiche',
        (tester) async {
      // Le serveur a répondu il y a des heures : sa première occurrence a
      // commencé depuis.
      repository.window = EventWindow(items: [
        _event('evt-passe', _hoursAgo(2), 'Culte déjà commencé'),
        _event('evt-a-venir', _inHours(5), 'Culte à venir'),
      ]);

      await _pumpHome(tester, repository);

      expect(find.text('Culte déjà commencé'), findsNothing);
      expect(find.text('Culte à venir'), findsOneWidget);
    });

    testWidgets('le retour au premier plan recharge la fenêtre',
        (tester) async {
      repository.replies.add(
        EventWindow(items: [_event('evt-1', _inHours(3), 'Culte de Gloire')]),
      );
      repository.window =
          EventWindow(items: [_event('evt-2', _inHours(9), 'Veillée')]);

      await _pumpHome(tester, repository);
      expect(repository.callCount, 1);
      expect(find.text('Culte de Gloire'), findsOneWidget);

      await _sleepAndResume(tester);

      expect(repository.callCount, 2);
      // La fenêtre repart de « maintenant », pas du « maintenant » figé au
      // premier chargement.
      expect(repository.froms[1].isBefore(repository.froms[0]), isFalse);
      expect(find.text('Veillée'), findsOneWidget);
    });

    testWidgets(
        'une fenêtre entièrement périmée recharge au lieu de s\'annoncer vide',
        (tester) async {
      repository.replies.addAll([
        // Réponse périmée : tout a commencé depuis la requête.
        EventWindow(items: [_event('evt-passe', _hoursAgo(1), 'Culte passé')]),
        EventWindow(items: [_event('evt-frais', _inHours(4), 'Culte frais')]),
      ]);

      await _pumpHome(tester, repository);

      expect(repository.callCount, 2);
      expect(find.text('Culte passé'), findsNothing);
      expect(find.text('Culte frais'), findsOneWidget);
      expect(find.byType(AppEmptyState), findsNothing);
    });

    testWidgets('un serveur qui rend toujours du passé ne fait pas boucler',
        (tester) async {
      repository.window = EventWindow(
          items: [_event('evt-passe', _hoursAgo(1), 'Culte passé')]);

      await _pumpHome(tester, repository);
      await tester.pump(const Duration(seconds: 2));

      // Un seul rechargement de rattrapage, puis l'écran s'arrête et le dit.
      expect(repository.callCount, 2);
      expect(find.byType(AppEmptyState), findsOneWidget);
    });
  });

  group('Accueil — états asynchrones de « À venir »', () {
    testWidgets('chargement : squelette, ni vide ni erreur', (tester) async {
      repository.gate = Completer<void>();

      await _pumpHome(tester, repository);

      expect(find.byType(AppListSkeleton), findsOneWidget);
      expect(find.byType(AppEmptyState), findsNothing);
      expect(find.byType(AppErrorState), findsNothing);

      repository.gate!.complete();
      await tester.pump();
      await tester.pump();
    });

    testWidgets('réseau coupé : état d\'erreur, jamais une section vide',
        (tester) async {
      repository.failure = CalendarException(CalendarErrorCode.network);

      await _pumpHome(tester, repository);

      expect(find.byType(AppErrorState), findsOneWidget);
      expect(find.byType(AppEmptyState), findsNothing);
      expect(find.text('Connexion perdue'), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);
    });

    testWidgets('erreur serveur : la cause annoncée est celle du serveur',
        (tester) async {
      repository.failure = CalendarException(CalendarErrorCode.server);

      await _pumpHome(tester, repository);

      expect(
        find.textContaining('Le serveur ne répond pas'),
        findsOneWidget,
      );
    });

    testWidgets('un 401 ne dit PAS « vérifiez votre connexion internet »',
        (tester) async {
      // **Le défaut signalé par l'utilisateur, à l'endroit exact où il l'a vu.**
      // Le serveur refusait le jeton d'invité sur `GET /events` ; `mapCalendarError`
      // rangeait bien ce 401 en `unauthorized`, et c'est cet écran-ci qui l'écrasait
      // — son ternaire ne nommait que `server` et rabattait tout le reste sur le
      // message réseau. Le téléphone était connecté, et l'application lui disait
      // le contraire.
      repository.failure = CalendarException(CalendarErrorCode.unauthorized);

      await _pumpHome(tester, repository);

      expect(find.byType(AppErrorState), findsOneWidget);
      expect(
        find.textContaining('Vérifiez votre connexion internet'),
        findsNothing,
        reason: 'le serveur a répondu : ce n\'est pas une panne de réseau',
      );
      expect(
        find.textContaining('n\'est pas accessible pour l\'instant'),
        findsOneWidget,
      );
    });

    testWidgets('« Réessayer » relance le chargement et affiche le contenu',
        (tester) async {
      repository.failure = CalendarException(CalendarErrorCode.network);

      await _pumpHome(tester, repository);
      expect(find.byType(AppErrorState), findsOneWidget);

      repository.failure = null;
      repository.window =
          EventWindow(items: [_event('evt-1', _inHours(3), 'Culte de Gloire')]);

      await tester.tap(find.byKey(AppErrorState.retryKey));
      await tester.pump();
      await tester.pump();

      expect(repository.callCount, 2);
      expect(find.byType(AppErrorState), findsNothing);
      expect(find.text('Culte de Gloire'), findsOneWidget);
    });

    testWidgets(
        'aucun évènement à venir : vide explicite, distinct de l\'erreur',
        (tester) async {
      repository.window = EventWindow.empty;

      await _pumpHome(tester, repository);

      expect(find.byType(AppEmptyState), findsOneWidget);
      expect(find.byType(AppErrorState), findsNothing);
      expect(find.text('Aucun rassemblement à venir'), findsOneWidget);
      expect(
        find.textContaining('Le calendrier n\'annonce rien pour le moment'),
        findsOneWidget,
      );
    });

    testWidgets('vide sous horizon : la borne annoncée par le serveur est dite',
        (tester) async {
      repository.window = EventWindow(
        items: const [],
        horizon: DateTime.utc(2026, 12, 31),
      );

      await _pumpHome(tester, repository);

      expect(find.byType(AppEmptyState), findsOneWidget);
      expect(find.textContaining('31 décembre 2026'), findsOneWidget);
    });
  });

  group('Accueil — navigation depuis « À venir »', () {
    testWidgets('tapoter une carte ouvre le détail de SON évènement',
        (tester) async {
      repository.window = EventWindow(items: [
        _event('evt-1', _inHours(3), 'Culte de Gloire'),
        _event('evt-2', _inHours(30), 'Veillée de Prière'),
      ]);

      ChurchEvent? opened;
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const Scaffold(body: HomeScreen()),
          ),
          GoRoute(
            name: AppRoute.eventDetail,
            path: '/event',
            builder: (_, state) {
              opened = state.extra as ChurchEvent?;
              return const Scaffold(body: SizedBox.shrink());
            },
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(InMemoryAuthRepository()),
            branchRepositoryProvider
                .overrideWithValue(const InMemoryBranchRepository()),
            calendarRepositoryProvider.overrideWithValue(repository),
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

      await tester.tap(find.text('Veillée de Prière'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(opened, isNotNull);
      expect(opened!.id, 'evt-2');
    });
  });
}
