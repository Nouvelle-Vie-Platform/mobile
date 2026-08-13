import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/network/api_client.dart';
import 'legal_acceptance_recorder.dart';

/// Implémentation HTTP de [LegalAcceptanceRecorder].
///
/// ```
/// POST /legal/accept   guard `api`
/// { "accepts": [ { "kind": "cgu", "version": 3 }, … ] }
/// → 200 { "acceptedLegal": { "cgu": 3, "privacy": 2 } }   (enveloppe `data` déballée)
/// ```
///
/// Corps en **`camelCase`**, comme tous les corps REST de ce serveur — son
/// `snake_case` ne concerne que les query strings et l'enveloppe `/sync`. Le
/// Bearer est injecté par `ApiClient`, qui déballe aussi l'enveloppe `data` et
/// traite globalement le **401** (purge du token, retour à `/auth`). Le 401 est
/// malgré tout **remonté** ici : l'accord en cours a échoué, et l'écran ne peut
/// pas se contenter de rester muet — c'est celui dont on ne sort pas.
///
/// **Un tableau, et un seul appel**, même quand deux documents sont cochés : le
/// serveur écrit dans une transaction, et un corps dont une entrée est refusée
/// n'écrit rien du tout. Deux appels laisseraient une barrière à moitié levée
/// sans que personne sache laquelle des deux cases est passée.
///
/// **La réponse, elle, est lue** — contrairement au composeur d'annonces. Elle
/// porte le résumé à jour, ce qui évite un `GET /auth/me` de plus entre le
/// bouton « Continuer » et l'application (ADR-0036) : la garde de route est
/// synchrone, chaque aller-retour de plus y serait un écran d'attente.
///
/// **Aucune écriture dans le magasin**, et il n'y a rien à y écrire : une ligne
/// d'acceptation n'entre dans aucune collection synchronisée (ADR-0036,
/// décision 3). Elle n'a rien à peindre.
class HttpLegalAcceptanceRecorder implements LegalAcceptanceRecorder {
  HttpLegalAcceptanceRecorder({ApiClient? client})
      : _client = (client ?? ApiClient.instance).dio;

  final Dio _client;

  /// Le seul endroit où ce chemin est écrit.
  static const String _path = '/legal/accept';

  @override
  Future<Map<String, int>> accept(List<LegalAcceptance> accepts) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        _path,
        data: {
          'accepts': [for (final accept in accepts) accept.toJson()]
        },
      );
      return acceptedLegalFrom(response.data);
    } on DioException catch (e) {
      throw mapLegalAcceptanceError(e);
    }
  }
}

/// Le résumé porté par la réponse, `{ 'cgu': 3, 'privacy': 2 }`.
///
/// **Une réponse illisible n'est pas un échec.** L'écriture a eu lieu — le
/// serveur a répondu 200 —, et faire lever ici rejouerait un enregistrement
/// déjà fait pour un champ mal formé. La carte revient alors **vide**, et la
/// barrière se relèvera au prochain `GET /auth/me` si le serveur la contredit :
/// c'est bruyant, ce n'est pas faux.
///
/// Un genre absent le **reste** : on ne garnit aucun trou à zéro (ADR-0036).
@visibleForTesting
Map<String, int> acceptedLegalFrom(Map<String, dynamic>? body) {
  final summary = body?['acceptedLegal'];
  if (summary is! Map) return const {};
  return {
    for (final entry in summary.entries)
      if (entry.key is String && entry.value is num)
        entry.key as String: (entry.value as num).toInt(),
  };
}

/// Traduit une [DioException] en [LegalAcceptanceException].
///
/// | Situation | code |
/// | --- | --- |
/// | pas de réponse (timeout, DNS, coupure, TLS) | `network` |
/// | **401** | `unauthorized` |
/// | **422** | `outdated` — le texte affiché est en retard sur le serveur |
/// | autre réponse HTTP (5xx…) | `server` |
/// | requête annulée | `network` |
///
/// Le partage se fait d'abord sur **l'existence d'une réponse**, pas sur le
/// statut : « le serveur n'a rien dit » et « le serveur a dit non » sont deux
/// choses différentes pour le fidèle — l'une se règle en retrouvant du réseau,
/// l'autre jamais.
///
/// Une annulation retombe sur `network` et non sur un cinquième code : elle
/// n'arrive que si l'écran est démonté pendant l'appel, il n'y a alors plus
/// personne pour lire la phrase, et **quatre cas, quatre phrases** vaut mieux
/// qu'un cinquième qui ne s'afficherait jamais.
///
/// Fonction de niveau bibliothèque (et non méthode privée) pour rester testable
/// sans réseau — `flutter test` répond 400 à tout accès réel.
@visibleForTesting
LegalAcceptanceException mapLegalAcceptanceError(DioException e) {
  final response = e.response;
  if (response == null) {
    return LegalAcceptanceException(
      LegalAcceptanceErrorCode.network,
      'Impossible de joindre le serveur (${e.message})',
    );
  }

  final body = response.data;
  final message = body is Map ? body['message'] as String? : null;

  return switch (response.statusCode) {
    401 =>
      LegalAcceptanceException(LegalAcceptanceErrorCode.unauthorized, message),
    422 => LegalAcceptanceException(LegalAcceptanceErrorCode.outdated, message),
    _ => LegalAcceptanceException(
        LegalAcceptanceErrorCode.server, message ?? e.message),
  };
}
