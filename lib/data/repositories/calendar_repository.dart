import 'package:flutter/foundation.dart';

import '../../models/models.dart';
import '../sample_data.dart';

/// Nature d'un échec de chargement de l'agenda.
///
/// Ces codes existent pour une seule raison : **un écran vide parce que le
/// réseau a coupé ne se dit pas comme un serveur en panne, ni comme une
/// session expirée**. `AppErrorState` distingue déjà `stateErrorMessage`
/// (réseau) de `stateErrorServerMessage` (serveur) ; c'est l'écran qui choisit
/// le texte, mais il ne peut choisir que si la couche données lui dit **quoi**
/// a échoué. D'où un code, jamais un `DioException` remonté brut ni un message
/// déjà rédigé ici.
enum CalendarErrorCode {
  /// Le serveur n'a **pas répondu** : coupure, DNS, timeout, TLS.
  network,

  /// **401** — le token n'est plus valide (révoqué, ou 90 jours d'inactivité).
  ///
  /// Distinct de [server] : la purge du token et le retour à `/auth` ont déjà
  /// été déclenchés globalement par `UnauthorizedInterceptor`. L'écran n'a donc
  /// pas à proposer « Réessayer » comme si ça pouvait marcher.
  unauthorized,

  /// Le serveur a répondu, mais en erreur (5xx, 422, 404…). Il est joignable :
  /// ce n'est pas la connexion du lecteur qui est en cause.
  server,

  /// Ni l'un ni l'autre (requête annulée, cas non prévu).
  unknown,
}

/// Échec de chargement de l'agenda, tel que le voit l'appelant.
class CalendarException implements Exception {
  CalendarException(this.code, [this.message]);

  final CalendarErrorCode code;

  /// Message **déjà localisé par le serveur** quand il en a fourni un.
  ///
  /// À réserver au diagnostic : les écrans affichent les clés `stateError*`,
  /// écrites pour un non-technicien. Un message serveur n'est pas un texte
  /// d'interface.
  final String? message;

  @override
  String toString() => 'CalendarException(${code.name}'
      '${message == null ? '' : ': $message'})';
}

/// Réponse de `GET /events` : les occurrences demandées **et** jusqu'où le
/// serveur s'engage.
///
/// Les deux voyagent ensemble à dessein. [horizon] est la borne de
/// matérialisation : au-delà, le serveur **n'affirme rien** — ce n'est pas
/// « aucun évènement ». Un mois postérieur à l'horizon doit donc désactiver la
/// navigation, pas s'afficher vide. Séparer les deux obligerait l'agenda à un
/// second appel pour savoir si son mois vide est vrai.
@immutable
class EventWindow {
  const EventWindow({required this.items, this.horizon});

  /// Fenêtre sans aucun évènement **et sans horizon connu**.
  static const EventWindow empty = EventWindow(items: []);

  /// Occurrences, dans l'ordre servi par le serveur (chronologique).
  final List<ChurchEvent> items;

  /// Borne de matérialisation du serveur, **en UTC**, ou `null` s'il ne l'a pas
  /// annoncée. Une date sans heure (`2027-07-28`) : elle borne des mois, pas
  /// des rendez-vous.
  final DateTime? horizon;

  bool get isEmpty => items.isEmpty;

  /// Le serveur s'engage-t-il jusqu'à [instant] ?
  ///
  /// `true` quand l'horizon est inconnu : sans information, on ne bride pas la
  /// navigation. `false` veut dire « au-delà de ce que le serveur a matérialisé »
  /// — l'agenda désactive alors le mois suivant au lieu de le montrer vide.
  bool covers(DateTime instant) =>
      horizon == null || !instant.toUtc().isAfter(horizon!);
}

/// Agenda de l'église — **repository dédié et asynchrone**.
///
/// Hors de [ChurchRepository] à dessein : ce contrat-là est **synchrone** et ne
/// couvre plus que des domaines fictifs (annonces, enseignements, groupes,
/// prières, notes). Le passer en `Future` pour brancher l'agenda casserait les
/// cinq autres d'un coup. Le motif du dépôt est l'inverse : un domaine servi par
/// le back **sort** vers sa propre abstraction, comme `AuthRepository` et
/// `BranchRepository` avant lui.
abstract interface class CalendarRepository {
  /// Occurrences comprises dans la fenêtre demandée.
  ///
  /// [from] est **obligatoire** : l'agenda ne charge jamais « tout », il charge
  /// une fenêtre. [to] est facultatif — la section « À venir » de l'accueil
  /// demande « les N prochains à partir de maintenant », sans borne haute, là où
  /// l'agenda mensuel borne des deux côtés.
  ///
  /// [branchId] `null` = toutes portées confondues. [limit] plafonne le nombre
  /// d'occurrences rendues.
  ///
  /// Lève une [CalendarException] : réseau, 401 et erreur serveur se
  /// distinguent par [CalendarException.code].
  Future<EventWindow> events({
    required DateTime from,
    DateTime? to,
    int? branchId,
    int? limit,
  });
}

/// Implémentation **en mémoire** : aucun réseau, aucun plugin.
///
/// Deux usages, un seul code : le mode maquette (`AppEnv.useBackend` faux) et
/// les tests. `GET /events` n'est pas encore déployé (issue serveur #80) —
/// c'est ce double qui fait tourner l'agenda en attendant.
///
/// Le filtrage imite le serveur **sans prétendre l'égaler** : sélection sur
/// `startsAt` seul (une occurrence commencée avant [from] mais encore en cours
/// n'est pas rendue), tri chronologique, puis plafond. Le serveur reste la
/// source de vérité le jour où il répond.
class InMemoryCalendarRepository implements CalendarRepository {
  InMemoryCalendarRepository({
    List<ChurchEvent>? events,
    DateTime? horizon,
  })  : _events = events ?? SampleData.events,
        _horizon = horizon;

  final List<ChurchEvent> _events;

  /// Horizon annoncé par le double. `null` par défaut : un mock ne doit pas
  /// inventer une borne que le serveur seul connaît — la navigation reste
  /// ouverte en mode maquette.
  final DateTime? _horizon;

  @override
  Future<EventWindow> events({
    required DateTime from,
    DateTime? to,
    int? branchId,
    int? limit,
  }) async {
    final start = from.toUtc();
    final end = to?.toUtc();

    final matching = _events.where((event) {
      final at = event.startsAt.toUtc();
      if (at.isBefore(start)) return false;
      if (end != null && !at.isBefore(end)) return false;
      // Une occurrence de portée nationale (`branchId` null) concerne toutes
      // les branches : la filtrer ferait disparaître les évènements du pays
      // dès qu'on regarde une branche.
      if (branchId != null &&
          event.branchId != null &&
          event.branchId != branchId) {
        return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

    final items = limit == null || limit >= matching.length
        ? matching
        : matching.sublist(0, limit < 0 ? 0 : limit);

    return EventWindow(
      items: List<ChurchEvent>.unmodifiable(items),
      horizon: _horizon,
    );
  }
}
