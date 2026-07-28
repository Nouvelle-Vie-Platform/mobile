import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:maison_du_miracle/data/repositories/calendar_repository.dart';
import 'package:maison_du_miracle/l10n/l10n_setup.dart';
import 'package:maison_du_miracle/models/models.dart';
import 'package:maison_du_miracle/screens/agenda_screen.dart';
import 'package:maison_du_miracle/state/calendar_providers.dart';
import 'package:maison_du_miracle/theme/app_theme.dart';
import 'package:maison_du_miracle/widgets/app_empty_state.dart';
import 'package:maison_du_miracle/widgets/app_error_state.dart';
import 'package:maison_du_miracle/widgets/app_list_skeleton.dart';
import 'package:maison_du_miracle/widgets/cards/event_card.dart';

import '../helpers/pump_screen.dart';

/// Double d'agenda : rend ce que le test lui donne, sans réseau.
///
/// Le filtrage reproduit celui du serveur (fenêtre `[from, to[` sur `startsAt`)
/// pour que la navigation entre mois demande bien un mois à la fois.
class _FakeCalendarRepository implements CalendarRepository {
  _FakeCalendarRepository({
    this.items = const [],
    this.horizon,
    this.pending = false,
  });

  final List<ChurchEvent> items;
  final DateTime? horizon;

  /// Ne répond jamais : fige l'écran sur son état de chargement.
  final bool pending;

  /// Échec levé à la place d'une réponse. Modifiable en cours de test pour
  /// vérifier que « Réessayer » recharge vraiment.
  CalendarException? failure;

  int calls = 0;

  @override
  Future<EventWindow> events({
    required DateTime from,
    DateTime? to,
    int? branchId,
    int? limit,
  }) {
    calls++;
    if (pending) return Completer<EventWindow>().future;

    final error = failure;
    if (error != null) return Future.error(error);

    final start = from.toUtc();
    final end = to?.toUtc();
    final matching = items.where((event) {
      final at = event.startsAt.toUtc();
      if (at.isBefore(start)) return false;
      if (end != null && !at.isBefore(end)) return false;
      return true;
    }).toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

    return Future.value(EventWindow(items: matching, horizon: horizon));
  }
}

ChurchEvent _event(String id, DateTime startsAt, {String title = 'Culte'}) =>
    ChurchEvent(
      id: id,
      startsAt: startsAt,
      timezone: 'Africa/Lome',
      title: {'fr': title},
    );

Future<void> _pumpAgenda(
  WidgetTester tester,
  _FakeCalendarRepository repository, {
  EventMonth? month,
}) {
  // Surface d'un téléphone (390 × 844) plutôt que la fenêtre de test par
  // défaut (800 × 600) : dans un cadre carré, la grille du mois occupe à elle
  // seule plus d'un écran et les jours de fin de mois tombent hors champ, donc
  // hors de portée d'un `tap`.
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  return pumpScreen(
    tester,
    AgendaScreen(initialMonth: month),
    overrides: [calendarRepositoryProvider.overrideWithValue(repository)],
  );
}

/// Titre attendu pour [month], tel que l'écran le compose (`intl` + majuscule
/// initiale). À n'appeler qu'après un `pump` : les symboles de date de la
/// locale sont chargés par les délégués de localisation.
String _title(int year, int month) {
  final text = DateFormat.yMMMM('fr').format(DateTime(year, month));
  return text[0].toUpperCase() + text.substring(1);
}

void main() {
  group('AgendaScreen — grille du mois', () {
    testWidgets('affiche le mois courant au premier rendu', (tester) async {
      await _pumpAgenda(tester, _FakeCalendarRepository());

      final now = DateTime.now();
      expect(find.text(_title(now.year, now.month)), findsOneWidget);
    });

    testWidgets('février bissextile : 29 jours, décalage au jeudi',
        (tester) async {
      // 1er février 2024 = jeudi → 3 cases vides avant le 1er.
      expect(DateTime(2024, 2).weekday, DateTime.thursday);

      await _pumpAgenda(tester, _FakeCalendarRepository(),
          month: const EventMonth(2024, 2));

      expect(find.byKey(AgendaScreen.dayKey(29)), findsOneWidget);
      expect(find.byKey(AgendaScreen.dayKey(30)), findsNothing);
      expect(find.byKey(AgendaScreen.leadingBlankKey(2)), findsOneWidget);
      expect(find.byKey(AgendaScreen.leadingBlankKey(3)), findsNothing);

      // Le 1er et le 8 tombent le même jour de semaine : même colonne. Le 5
      // (lundi) ouvre la ligne suivante : plus à gauche, et plus bas.
      final first = tester.getCenter(find.byKey(AgendaScreen.dayKey(1)));
      final eighth = tester.getCenter(find.byKey(AgendaScreen.dayKey(8)));
      final fifth = tester.getCenter(find.byKey(AgendaScreen.dayKey(5)));
      expect(first.dx, eighth.dx);
      expect(fifth.dx, lessThan(first.dx));
      expect(fifth.dy, greaterThan(first.dy));
    });

    testWidgets('février non bissextile : 28 jours, décalage au mercredi',
        (tester) async {
      expect(DateTime(2023, 2).weekday, DateTime.wednesday);

      await _pumpAgenda(tester, _FakeCalendarRepository(),
          month: const EventMonth(2023, 2));

      expect(find.byKey(AgendaScreen.dayKey(28)), findsOneWidget);
      expect(find.byKey(AgendaScreen.dayKey(29)), findsNothing);
      expect(find.byKey(AgendaScreen.leadingBlankKey(1)), findsOneWidget);
      expect(find.byKey(AgendaScreen.leadingBlankKey(2)), findsNothing);
    });

    testWidgets('mois de 31 jours : janvier 2027, décalage au vendredi',
        (tester) async {
      expect(DateTime(2027).weekday, DateTime.friday);

      await _pumpAgenda(tester, _FakeCalendarRepository(),
          month: const EventMonth(2027, 1));

      expect(find.byKey(AgendaScreen.dayKey(31)), findsOneWidget);
      expect(find.byKey(AgendaScreen.dayKey(32)), findsNothing);
      expect(find.byKey(AgendaScreen.leadingBlankKey(3)), findsOneWidget);
      expect(find.byKey(AgendaScreen.leadingBlankKey(4)), findsNothing);
    });
  });

  group('AgendaScreen — pastilles', () {
    testWidgets(
        'deux évènements le même jour : la pastille le dit et les '
        'deux cartes sont là', (tester) async {
      final semantics = tester.ensureSemantics();
      final repository = _FakeCalendarRepository(items: [
        _event('a', DateTime.utc(2026, 3, 12, 8), title: 'Culte du matin'),
        _event('b', DateTime.utc(2026, 3, 12, 17), title: 'Prière du soir'),
        _event('c', DateTime.utc(2026, 3, 20, 17), title: 'Veillée'),
      ]);

      await _pumpAgenda(tester, repository, month: const EventMonth(2026, 3));

      expect(find.bySemanticsLabel('12 — 2 événements'), findsOneWidget);
      expect(find.bySemanticsLabel('20 — 1 événement'), findsOneWidget);
      expect(find.bySemanticsLabel('13 — aucun événement'), findsOneWidget);

      expect(find.text('Culte du matin'), findsOneWidget);
      expect(find.text('Prière du soir'), findsOneWidget);
      expect(find.byType(EventCard), findsNWidgets(3));

      semantics.dispose();
    });
  });

  testWidgets('AgendaScreen se monte en thème sombre', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          calendarRepositoryProvider.overrideWithValue(
            _FakeCalendarRepository(items: [
              _event('a', DateTime.utc(2026, 3, 5, 17), title: 'Culte'),
            ]),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          locale: const Locale('fr'),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: appSupportedLocales,
          home: const AgendaScreen(initialMonth: EventMonth(2026, 3)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Culte'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('AgendaScreen — tapoter un jour', () {
    /// Un mois bien rempli : de quoi rendre la liste défilable.
    List<ChurchEvent> busyMarch() => [
          for (var day = 2; day <= 30; day += 3)
            _event('e$day', DateTime.utc(2026, 3, day, 17),
                title: 'Rencontre du $day'),
        ];

    testWidgets('fait défiler la liste sans jamais la vider', (tester) async {
      final events = busyMarch();
      await _pumpAgenda(tester, _FakeCalendarRepository(items: events),
          month: const EventMonth(2026, 3));

      expect(find.byType(EventCard), findsNWidgets(events.length));
      expect(_scrollPosition(tester).pixels, 0);

      await tester.tap(find.byKey(AgendaScreen.dayKey(29)));
      await tester.pump(); // setState : le jour passe en avant
      await tester.pump(); // post-frame : l'ancre est posée, on vise
      await tester.pump(const Duration(milliseconds: 400)); // fin du défilement

      expect(_scrollPosition(tester).pixels, greaterThan(0));
      // La liste n'a pas été filtrée : toutes les cartes du mois sont là.
      expect(find.byType(EventCard), findsNWidgets(events.length));
    });

    testWidgets('un jour sans évènement ne vide pas la liste non plus',
        (tester) async {
      final events = busyMarch();
      await _pumpAgenda(tester, _FakeCalendarRepository(items: events),
          month: const EventMonth(2026, 3));

      // Le 3 mars ne porte rien (les rencontres tombent les 2, 5, 8, …).
      await tester.tap(find.byKey(AgendaScreen.dayKey(3)));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(EventCard), findsNWidgets(events.length));
      expect(find.byType(AppEmptyState), findsNothing);
    });
  });

  group('AgendaScreen — navigation entre mois', () {
    testWidgets('le titre suit le mois navigué', (tester) async {
      await _pumpAgenda(tester, _FakeCalendarRepository(),
          month: const EventMonth(2026, 3));

      expect(find.text(_title(2026, 3)), findsOneWidget);

      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text(_title(2026, 4)), findsOneWidget);

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text(_title(2026, 2)), findsOneWidget);
    });

    testWidgets('à la borne d\'horizon, « mois suivant » est désactivé',
        (tester) async {
      // Le serveur s'engage jusqu'au 30 avril : mai n'est pas « vide », il est
      // inconnu — la flèche se grise plutôt que d'afficher un mois en creux.
      final repository = _FakeCalendarRepository(
        items: [_event('a', DateTime.utc(2026, 4, 5, 17))],
        horizon: DateTime.utc(2026, 4, 30),
      );

      await _pumpAgenda(tester, repository, month: const EventMonth(2026, 4));

      expect(_arrow(tester, Icons.chevron_right).onPressed, isNull);
      expect(_arrow(tester, Icons.chevron_left).onPressed, isNotNull);
      // Fin de parcours annoncée en pied de liste, pas un état « rien ici ».
      expect(find.text('Fin du calendrier'), findsOneWidget);
      expect(find.byType(EventCard), findsOneWidget);
    });

    testWidgets('en deçà de l\'horizon, « mois suivant » reste actif',
        (tester) async {
      final repository = _FakeCalendarRepository(
        items: [_event('a', DateTime.utc(2026, 3, 5, 17))],
        horizon: DateTime.utc(2027, 3, 31),
      );

      await _pumpAgenda(tester, repository, month: const EventMonth(2026, 3));

      expect(_arrow(tester, Icons.chevron_right).onPressed, isNotNull);
      expect(find.text('Fin du calendrier'), findsNothing);
    });
  });

  group('AgendaScreen — états asynchrones', () {
    testWidgets('chargement : squelette de liste', (tester) async {
      await _pumpAgenda(tester, _FakeCalendarRepository(pending: true),
          month: const EventMonth(2026, 3));

      expect(find.byType(AppListSkeleton), findsOneWidget);
      expect(find.byType(AppEmptyState), findsNothing);
      expect(find.byType(AppErrorState), findsNothing);
    });

    testWidgets('mois vide : état vide, jamais l\'état d\'erreur',
        (tester) async {
      await _pumpAgenda(tester, _FakeCalendarRepository(),
          month: const EventMonth(2026, 3));

      expect(find.text('Aucun événement ce mois-ci'), findsOneWidget);
      expect(find.byType(AppErrorState), findsNothing);
      expect(find.byType(EventCard), findsNothing);
    });

    testWidgets('échec réseau : état d\'erreur, distinct de l\'état vide',
        (tester) async {
      final repository = _FakeCalendarRepository(
        items: [_event('a', DateTime.utc(2026, 3, 5, 17))],
      )..failure = CalendarException(CalendarErrorCode.network);

      await _pumpAgenda(tester, repository, month: const EventMonth(2026, 3));

      expect(find.byType(AppErrorState), findsOneWidget);
      expect(find.byType(AppEmptyState), findsNothing);
      expect(find.text('Aucun événement ce mois-ci'), findsNothing);
    });

    testWidgets(
        'échec serveur : message serveur, pas « vérifiez votre '
        'connexion »', (tester) async {
      final repository = _FakeCalendarRepository()
        ..failure = CalendarException(CalendarErrorCode.server);

      await _pumpAgenda(tester, repository, month: const EventMonth(2026, 3));

      expect(
        find.text('Le serveur ne répond pas pour l\'instant. '
            'Réessayez dans un instant.'),
        findsOneWidget,
      );
    });

    testWidgets('« Réessayer » relance le chargement du mois affiché',
        (tester) async {
      final repository = _FakeCalendarRepository(
        items: [_event('a', DateTime.utc(2026, 3, 5, 17), title: 'Culte')],
      )..failure = CalendarException(CalendarErrorCode.network);

      await _pumpAgenda(tester, repository, month: const EventMonth(2026, 3));
      expect(find.byType(AppErrorState), findsOneWidget);
      final callsBefore = repository.calls;

      repository.failure = null;
      await tester.tap(find.byKey(AppErrorState.retryKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(repository.calls, greaterThan(callsBefore));
      expect(find.byType(AppErrorState), findsNothing);
      expect(find.text('Culte'), findsOneWidget);
    });
  });
}

/// Position du défilement de la liste (le `Scrollable` extérieur : la grille du
/// mois en imbrique un second, non défilable).
ScrollPosition _scrollPosition(WidgetTester tester) =>
    tester.state<ScrollableState>(find.byType(Scrollable).first).position;

IconButton _arrow(WidgetTester tester, IconData icon) =>
    tester.widget<IconButton>(
      find.ancestor(of: find.byIcon(icon), matching: find.byType(IconButton)),
    );
