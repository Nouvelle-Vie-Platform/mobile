import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/repositories/calendar_repository.dart';
import 'package:maison_du_miracle/models/models.dart';
import 'package:maison_du_miracle/state/calendar_providers.dart';

/// Fenêtre demandée par un provider, telle que le repository l'a reçue.
class _Query {
  _Query(this.from, this.to, this.branchId, this.limit);

  final DateTime from;
  final DateTime? to;
  final int? branchId;
  final int? limit;
}

/// Repository espion : note ce qu'on lui demande et rend ce que le test veut.
///
/// Aucun réseau — `flutter test` répond 400 à tout accès réel, et de toute
/// façon `GET /events` n'est pas encore déployé (issue serveur #80).
class _SpyCalendarRepository implements CalendarRepository {
  /// Réponse rendue à l'appel suivant.
  EventWindow window = EventWindow.empty;

  /// Échec à lever à la place, quand le test veut une erreur.
  CalendarException? failure;

  final List<_Query> queries = [];

  @override
  Future<EventWindow> events({
    required DateTime from,
    DateTime? to,
    int? branchId,
    int? limit,
  }) async {
    queries.add(_Query(from, to, branchId, limit));
    final error = failure;
    if (error != null) throw error;
    return window;
  }
}

ChurchEvent _event(String id, DateTime startsAt) => ChurchEvent(
      id: id,
      startsAt: startsAt,
      timezone: 'Africa/Lome',
      title: const {'fr': 'Culte'},
    );

void main() {
  late _SpyCalendarRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = _SpyCalendarRepository();
    container = ProviderContainer(
      overrides: [calendarRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
  });

  group('upcomingEventsProvider', () {
    test('demande les 3 prochains à partir de maintenant, sans borne haute',
        () async {
      final before = DateTime.now().toUtc();

      await container.read(upcomingEventsProvider.future);

      final query = repository.queries.single;
      expect(query.limit, 3);
      expect(query.limit, kUpcomingEventsLimit);
      expect(query.to, isNull);
      expect(query.from.isUtc, isTrue);
      expect(query.from.isBefore(before), isFalse);
      expect(
        query.from.isAfter(DateTime.now().toUtc()),
        isFalse,
      );
    });

    test('porte l\'horizon jusqu\'à l\'écran', () async {
      repository.window = EventWindow(
        items: [_event('a', DateTime.utc(2026, 8, 3, 17, 30))],
        horizon: DateTime.utc(2027, 7, 28),
      );

      final window = await container.read(upcomingEventsProvider.future);

      expect(window.items.single.id, 'a');
      expect(window.horizon, DateTime.utc(2027, 7, 28));
    });

    test('une erreur réseau remonte telle quelle dans l\'AsyncValue', () async {
      repository.failure = CalendarException(CalendarErrorCode.network);

      await expectLater(
        container.read(upcomingEventsProvider.future),
        throwsA(
          isA<CalendarException>()
              .having((e) => e.code, 'code', CalendarErrorCode.network),
        ),
      );
      // Un seul appel : pas de réessai automatique en sourdine — l'échec est
      // annoncé tout de suite, et c'est le bouton « Réessayer » d'AppErrorState
      // qui relance.
      expect(repository.queries, hasLength(1));
    });

    test('un 401 reste distinct d\'une coupure réseau', () async {
      repository.failure = CalendarException(CalendarErrorCode.unauthorized);

      await expectLater(
        container.read(upcomingEventsProvider.future),
        throwsA(
          // L'écran choisit son texte à partir du code (`stateErrorMessage` vs
          // `stateErrorServerMessage`) : le mappage n'a rien à faire dans le
          // widget.
          isA<CalendarException>()
              .having((e) => e.code, 'code', CalendarErrorCode.unauthorized),
        ),
      );
      // Le token vient d'être purgé : réessayer ne peut que rater à nouveau.
      expect(repository.queries, hasLength(1));
    });
  });

  group('monthEventsProvider', () {
    test('borne la requête au mois demandé', () async {
      await container
          .read(monthEventsProvider(const EventMonth(2026, 8)).future);

      final query = repository.queries.single;
      expect(query.from, DateTime.utc(2026, 8));
      expect(query.to, DateTime.utc(2026, 9));
      expect(query.limit, isNull);
    });

    test('décembre borne sur janvier de l\'année suivante', () async {
      await container
          .read(monthEventsProvider(const EventMonth(2026, 12)).future);

      expect(repository.queries.single.to, DateTime.utc(2027));
    });

    test('deux lectures du même mois ne font qu\'une requête', () async {
      const month = EventMonth(2026, 8);

      await container.read(monthEventsProvider(month).future);
      await container
          .read(monthEventsProvider(const EventMonth(2026, 8)).future);

      // La clé de famille est une **valeur** : sans `==`, deux instances du
      // même mois créeraient deux entrées de cache et deux appels réseau.
      expect(repository.queries, hasLength(1));
    });

    test('l\'horizon est lisible depuis les providers, sans second appel',
        () async {
      repository.window = EventWindow(
        items: const [],
        horizon: DateTime.utc(2027, 7, 28),
      );
      const month = EventMonth(2026, 8);

      final window = await container.read(monthEventsProvider(month).future);

      expect(window.horizon, DateTime.utc(2027, 7, 28));
      expect(container.read(eventsHorizonProvider(month)),
          DateTime.utc(2027, 7, 28));
      expect(repository.queries, hasLength(1));

      // Ce que l'agenda en fait : août 2027 est au-delà de ce que le serveur a
      // matérialisé — mois suivant désactivé, et surtout pas « rien de prévu ».
      expect(window.covers(const EventMonth(2027, 8).from), isFalse);
      expect(window.covers(const EventMonth(2026, 9).from), isTrue);
    });

    test('horizon inconnu tant que le mois n\'est pas chargé', () {
      expect(
        container.read(eventsHorizonProvider(const EventMonth(2026, 8))),
        isNull,
      );
    });
  });

  group('EventMonth', () {
    test('bornes en UTC : premier instant du mois, mois suivant exclu', () {
      const month = EventMonth(2026, 2);

      expect(month.from, DateTime.utc(2026, 2));
      expect(month.to, DateTime.utc(2026, 3));
      expect(month.from.isUtc, isTrue);
    });

    test('navigation d\'un mois à l\'autre, changement d\'année compris', () {
      expect(const EventMonth(2026, 12).next, const EventMonth(2027, 1));
      expect(const EventMonth(2026, 1).previous, const EventMonth(2025, 12));
    });

    test('égalité de valeur — indispensable comme clé de famille', () {
      expect(const EventMonth(2026, 8), const EventMonth(2026, 8));
      expect(
        const EventMonth(2026, 8).hashCode,
        const EventMonth(2026, 8).hashCode,
      );
      expect(const EventMonth(2026, 8), isNot(const EventMonth(2026, 9)));
    });

    test('se construit depuis une date, dans le fuseau de celle-ci', () {
      expect(
        EventMonth.of(DateTime.utc(2026, 8, 31, 23, 59)),
        const EventMonth(2026, 8),
      );
    });

    test('toString lisible : année-mois', () {
      expect(const EventMonth(2026, 8).toString(), '2026-08');
    });
  });
}
