import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/network/api_client.dart';
import '../../models/models.dart';
import 'calendar_repository.dart';

/// Implémentation HTTP de [CalendarRepository].
///
/// ```
/// GET /events?from=<ISO8601>&to=<ISO8601>&branch_id=<int?>&limit=<int?>
/// guards `api` (membre) et `device` (invité) — le Bearer est injecté par ApiClient
/// 200 → { data: { items: [...], horizon: "2027-07-28" } }
/// ```
///
/// Deux choses dont cette classe **n'a pas** à s'occuper, traitées une seule
/// fois dans `ApiClient` : l'enveloppe `data` (déballée par un intercepteur —
/// le corps arrive ici à plat, `{ items, horizon }`) et la conséquence du
/// **401** (purge du token + retour à `/auth`). Le 401 est malgré tout
/// **remonté** ici, sous [CalendarErrorCode.unauthorized] : l'appel en cours a
/// échoué, l'écran doit le savoir pour ne pas afficher un agenda vide.
///
/// En mode maquette, `InMemoryCalendarRepository` remplace cet endpoint.
class HttpCalendarRepository implements CalendarRepository {
  HttpCalendarRepository({ApiClient? client})
      : _client = (client ?? ApiClient.instance).dio;

  final Dio _client;

  @override
  Future<EventWindow> events({
    required DateTime from,
    DateTime? to,
    int? branchId,
    int? limit,
  }) async {
    try {
      final res = await _client.get<Map<String, dynamic>>(
        '/events',
        queryParameters: {
          // Toujours **en UTC** sur le fil : le serveur reçoit un instant, pas
          // l'heure murale du téléphone du lecteur.
          'from': from.toUtc().toIso8601String(),
          if (to != null) 'to': to.toUtc().toIso8601String(),
          if (branchId != null) 'branch_id': branchId,
          if (limit != null) 'limit': limit,
        },
      );
      return _windowFrom(res.data);
    } on DioException catch (e) {
      throw mapCalendarError(e);
    }
  }

  /// Corps déjà déballé (`{ items, horizon }`) → [EventWindow].
  ///
  /// Un `items` d'une autre forme vaut « aucune occurrence » plutôt qu'un
  /// plantage : l'agenda reste navigable. Un **item** malformé, lui, lève —
  /// masquer une occurrence serait pire qu'un échec visible, l'utilisateur
  /// manquerait un rassemblement sans jamais le savoir.
  EventWindow _windowFrom(Map<String, dynamic>? body) {
    final items = body?['items'];
    return EventWindow(
      items: items is! List
          ? const []
          : List<ChurchEvent>.unmodifiable(
              items.whereType<Map>().map(
                    (item) =>
                        ChurchEvent.fromJson(item.cast<String, dynamic>()),
                  ),
            ),
      horizon: parseHorizon(body?['horizon']),
    );
  }
}

/// Lit l'horizon servi par le back : une **date** (`2027-07-28`), pas un
/// instant.
///
/// Rendue en UTC et à minuit : elle sert à comparer des mois, jamais à afficher
/// une heure. La lire en heure locale la décalerait d'un jour selon le fuseau du
/// lecteur — assez pour ouvrir ou fermer un mois de trop en bord d'horizon.
///
/// Une valeur absente ou illisible rend `null` : « le serveur n'a rien annoncé »
/// est un état légitime, qui laisse la navigation ouverte.
@visibleForTesting
DateTime? parseHorizon(Object? raw) {
  if (raw is! String || raw.trim().isEmpty) return null;
  final parsed = DateTime.tryParse(raw.trim());
  if (parsed == null) return null;
  final utc = parsed.isUtc ? parsed : parsed.toUtc();
  return DateTime.utc(utc.year, utc.month, utc.day);
}

/// Traduit une [DioException] en [CalendarException].
///
/// | Situation | [CalendarErrorCode] |
/// | --- | --- |
/// | pas de réponse (timeout, DNS, coupure, TLS) | `network` |
/// | **401** | `unauthorized` |
/// | toute autre réponse HTTP (5xx, 422, 404…) | `server` |
/// | requête annulée, reste | `unknown` |
///
/// Le partage se fait sur **l'existence d'une réponse**, pas sur le statut :
/// « le serveur n'a rien dit » et « le serveur a dit non » sont deux pannes
/// différentes pour le lecteur — l'une se règle en retrouvant du réseau,
/// l'autre pas.
///
/// Fonction de niveau bibliothèque (et non méthode privée) pour rester testable
/// sans réseau — `flutter test` répond 400 à tout accès réel.
@visibleForTesting
CalendarException mapCalendarError(DioException e) {
  if (e.type == DioExceptionType.cancel) {
    return CalendarException(CalendarErrorCode.unknown, e.message);
  }

  final response = e.response;
  if (response == null) {
    return CalendarException(
      CalendarErrorCode.network,
      'Impossible de joindre le serveur (${e.message})',
    );
  }

  final body = response.data;
  final message = body is Map ? body['message'] as String? : null;

  if (response.statusCode == 401) {
    return CalendarException(CalendarErrorCode.unauthorized, message);
  }
  return CalendarException(CalendarErrorCode.server, message ?? e.message);
}
