import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_env.dart';
import '../data/repositories/calendar_repository.dart';
import '../data/repositories/http_calendar_repository.dart';

/// Mois affiché par l'agenda — **clé de famille** de [monthEventsProvider].
///
/// Une classe plutôt qu'un `DateTime` : une clé de `family` est mise en cache
/// telle quelle, et un `DateTime` porte l'heure, les minutes, les microsecondes.
/// Deux lectures du même mois à deux instants différents créeraient deux entrées
/// de cache et deux appels réseau pour la même page d'agenda.
@immutable
class EventMonth {
  const EventMonth(this.year, this.month);

  /// Mois auquel appartient [date] (dans le fuseau porté par [date]).
  factory EventMonth.of(DateTime date) => EventMonth(date.year, date.month);

  /// Mois courant, dans le fuseau de l'appareil — c'est le mois que le lecteur
  /// a sous les yeux quand il ouvre l'agenda.
  factory EventMonth.current() => EventMonth.of(DateTime.now());

  final int year;

  /// 1 = janvier … 12 = décembre.
  final int month;

  /// Premier instant du mois, **en UTC**.
  ///
  /// Les bornes sont posées en UTC et non dans le fuseau de la branche : les
  /// branches sont au Togo (`Africa/Lome`, UTC+0 toute l'année), la fenêtre est
  /// donc exacte. Une future branche décalée (Lagos, UTC+1) verrait ses
  /// évènements de bord de mois d'une heure du mauvais côté de la borne — à
  /// traiter le jour où une telle branche existe, et côté serveur, qui est le
  /// seul à connaître le fuseau de chaque évènement.
  DateTime get from => DateTime.utc(year, month);

  /// Premier instant du mois **suivant** (borne haute, exclue).
  ///
  /// `DateTime.utc(2026, 13)` vaut janvier 2027 : le passage d'année est déjà
  /// géré par la bibliothèque, inutile de le recalculer.
  DateTime get to => DateTime.utc(year, month + 1);

  EventMonth get next => EventMonth.of(to);

  EventMonth get previous => EventMonth.of(DateTime.utc(year, month - 1));

  @override
  bool operator ==(Object other) =>
      other is EventMonth && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);

  @override
  String toString() => '$year-${month.toString().padLeft(2, '0')}';
}

/// Nombre d'évènements de la section « À venir » de l'accueil.
///
/// L'accueil est une vitrine, pas l'agenda : trois lignes suffisent, et le
/// plafond part sur le fil (`limit`) plutôt que de tronquer côté client une
/// liste entière qu'on aurait fait voyager pour rien.
const int kUpcomingEventsLimit = 3;

/// Politique de réessai des providers d'agenda : **aucun réessai automatique**.
///
/// Riverpod 3 réessaie tout seul un provider en échec — jusqu'à 10 fois, avec
/// une attente qui double à chaque tour (jusqu'à 6,4 s). Appliqué ici, l'agenda
/// resterait en chargement près d'une minute avant d'oser dire qu'il a échoué,
/// et un **401** serait retenté dix fois alors que le token vient d'être purgé :
/// dix échecs certains, pour retarder d'autant l'affichage de l'erreur.
///
/// Le réessai est donc **une action de l'utilisateur**, pas une temporisation
/// invisible : `AppErrorState` impose un bouton « Réessayer » (`onRetry` n'est
/// pas nullable), et l'écran y branche `ref.invalidate`. Échouer vite et le
/// dire vaut mieux que faire tourner un squelette sans rien annoncer.
Duration? _noAutomaticRetry(int retryCount, Object error) => null;

/// Fournit l'implémentation courante de [CalendarRepository] — mêmes règles que
/// `authRepositoryProvider` : HTTP avec backend, double en mémoire sinon.
///
/// `GET /events` n'est pas encore déployé (issue serveur #80) : basculer
/// `AppEnv.useBackend` à faux fait tourner l'agenda sur le double, sans toucher
/// une ligne d'écran.
final calendarRepositoryProvider = Provider<CalendarRepository>(
  (ref) => AppEnv.useBackend
      ? HttpCalendarRepository()
      : InMemoryCalendarRepository(),
);

/// Section « À venir » de l'accueil : les [kUpcomingEventsLimit] prochaines
/// occurrences à partir de **maintenant**, sans borne haute.
///
/// Pas de `to` : « les trois prochains » n'a pas de fin. Borner arbitrairement
/// à un mois ferait disparaître la section pendant les périodes creuses, alors
/// que l'agenda, lui, a bien quelque chose à annoncer.
final upcomingEventsProvider = FutureProvider<EventWindow>(
  (ref) => ref.watch(calendarRepositoryProvider).events(
        from: DateTime.now().toUtc(),
        limit: kUpcomingEventsLimit,
      ),
  retry: _noAutomaticRetry,
);

/// Occurrences du mois consulté par l'agenda.
///
/// L'[EventWindow] rendue porte aussi l'**horizon** : c'est ce qui permet à
/// l'écran de distinguer « ce mois-ci est vide » (→ `AppEmptyState.nothing`)
/// de « le serveur ne s'engage pas jusque-là » (→ navigation vers le mois
/// suivant désactivée, `AppEmptyStateVariant.endOfRange`). Sans lui, un mois
/// au-delà de l'horizon se lirait comme une absence d'évènements, ce qui serait
/// faux.
final monthEventsProvider = FutureProvider.family<EventWindow, EventMonth>(
  (ref, month) => ref.watch(calendarRepositoryProvider).events(
        from: month.from,
        to: month.to,
      ),
  retry: _noAutomaticRetry,
);

/// Horizon annoncé par le serveur pour le mois [month], ou `null` tant qu'il
/// n'est pas chargé (ou s'il n'a pas été annoncé).
///
/// Raccourci de lecture : l'horizon vit dans l'[EventWindow], il n'y a pas de
/// second appel — l'écran qui n'a besoin que de la borne n'a pas à déballer
/// l'`AsyncValue` lui-même.
final eventsHorizonProvider = Provider.family<DateTime?, EventMonth>(
  (ref, month) => ref.watch(monthEventsProvider(month)).value?.horizon,
);
