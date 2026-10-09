/// **Les routes de la page live** (#135) — lectures de resynchronisation et
/// écritures de l'audience.
///
/// Séparé de `RadioRepository` (l'adresse d'antenne), et pour les trois raisons
/// qui ont déjà séparé l'écriture des annonces de leur lecture : autre garde
/// (`['api', 'device']`, `api` seul pour la modération), autre forme, autre
/// régime d'échec. L'antenne doit répondre pour qu'on **écoute** ; le fil peut
/// tomber sans que le son s'arrête.
library;

import 'package:dio/dio.dart';

import 'radio_live.dart';

/// **Pourquoi le serveur a refusé** — lu sur le `code` de la réponse, jamais
/// sur le statut seul (deux 403 et quatre 409 disent des choses différentes).
enum RadioLiveRefusal {
  /// 403 `E_RADIO_PSEUDONYM_REQUIRED` : un invité doit choisir un pseudo avant
  /// d'écrire ou de signaler.
  pseudonymRequired,

  /// 403 `E_RADIO_AUTHOR_SILENCED` : réduit au silence jusqu'à la fin du direct.
  silenced,

  /// 409 `E_RADIO_COMMENTS_CLOSED` : pas de direct, donc pas de fil.
  closed,

  /// 429 — commentaire (1 / 5 s), réaction (20 / 10 s), pseudo (5 / h).
  throttled,

  /// 422 `E_RADIO_COMMENT_INVALID` / `E_VALIDATION_ERROR` : vide ou trop long.
  invalid,

  /// 422 `E_RADIO_PSEUDONYM_INVALID` : 2 à 24 caractères.
  pseudonymInvalid,

  /// 409 `E_RADIO_COMMENT_ALREADY_REPORTED`.
  alreadyReported,

  /// 404 `E_RADIO_COMMENT_NOT_FOUND` : déjà masqué, ou d'un autre direct.
  notFound,

  /// 409 `E_RADIO_COMMENT_AUTHOR_NOT_GUEST` : on ne réinitialise que le pseudo
  /// d'un invité.
  notGuest,

  /// 403 `E_OUTSIDE_SCOPE` (ou tout autre 403) : pas modérateur.
  forbidden,

  /// Aucune réponse : réseau coupé, délai dépassé.
  transport,

  /// Une réponse qu'on ne sait pas ranger.
  unknown,
}

/// L'échec d'une route du live, déjà rangé.
class RadioLiveException implements Exception {
  const RadioLiveException(this.refusal, {this.status});

  final RadioLiveRefusal refusal;
  final int? status;

  @override
  String toString() => 'RadioLiveException($refusal, ${status ?? '—'})';
}

/// **Range une erreur de route en refus** — un seul endroit, pour que l'écran
/// ne lise jamais une `DioException`.
RadioLiveException classifyRadioLiveError(Object error) {
  if (error is RadioLiveException) return error;
  if (error is! DioException) {
    return const RadioLiveException(RadioLiveRefusal.unknown);
  }
  final response = error.response;
  if (response == null) {
    return const RadioLiveException(RadioLiveRefusal.transport);
  }
  final status = response.statusCode;
  final data = response.data;
  final code = data is Map ? data['code'] : null;
  final refusal = switch (code) {
    'E_RADIO_PSEUDONYM_REQUIRED' => RadioLiveRefusal.pseudonymRequired,
    'E_RADIO_AUTHOR_SILENCED' => RadioLiveRefusal.silenced,
    'E_RADIO_COMMENTS_CLOSED' => RadioLiveRefusal.closed,
    'E_RADIO_COMMENT_THROTTLED' ||
    'E_RADIO_REACTION_THROTTLED' =>
      RadioLiveRefusal.throttled,
    'E_RADIO_COMMENT_INVALID' ||
    'E_VALIDATION_ERROR' =>
      RadioLiveRefusal.invalid,
    'E_RADIO_PSEUDONYM_INVALID' => RadioLiveRefusal.pseudonymInvalid,
    'E_RADIO_COMMENT_ALREADY_REPORTED' => RadioLiveRefusal.alreadyReported,
    'E_RADIO_COMMENT_NOT_FOUND' => RadioLiveRefusal.notFound,
    'E_RADIO_COMMENT_AUTHOR_NOT_GUEST' => RadioLiveRefusal.notGuest,
    'E_OUTSIDE_SCOPE' => RadioLiveRefusal.forbidden,
    _ => switch (status) {
        429 => RadioLiveRefusal.throttled,
        403 => RadioLiveRefusal.forbidden,
        404 => RadioLiveRefusal.notFound,
        422 => RadioLiveRefusal.invalid,
        _ => RadioLiveRefusal.unknown,
      },
  };
  return RadioLiveException(refusal, status: status);
}

/// Le contrat. **Chaque écriture lève une [RadioLiveException]** quand le
/// serveur refuse ou ne répond pas — jamais une `DioException`.
abstract interface class RadioLiveRepository {
  /// `GET /radio/comments` — le fil, le direct et ce que ce porteur peut faire.
  Future<RadioThread> thread();

  /// `POST /radio/reactions`. [heardAt] : l'heure d'antenne entendue au
  /// geste (mobile#187), absente quand on ne la sait pas — le serveur prend
  /// alors l'heure de réception.
  Future<void> react(RadioReaction reaction, {DateTime? heardAt});

  /// `POST /radio/comments` → le commentaire tel que le canal le diffusera.
  /// [heardAt] : comme pour [react].
  Future<RadioComment> postComment(String body, {DateTime? heardAt});

  /// `PUT /radio/pseudonym` (invité seulement) → le pseudo retenu.
  Future<String> savePseudonym(String pseudonym);

  /// `POST /radio/comments/:id/reports`.
  Future<void> report(String commentId);

  /// `GET /radio/moderation/comments` — modérateurs seulement.
  Future<RadioModerationQueue> moderationQueue();

  /// `POST /radio/moderation/comments/:id/hide`.
  Future<void> hide(String commentId);

  /// `POST /radio/moderation/comments/:id/keep`.
  Future<void> keep(String commentId);

  /// `POST /radio/moderation/comments/:id/silence`.
  Future<void> silence(String commentId);

  /// `POST /radio/moderation/comments/:id/reset-pseudonym`.
  Future<void> resetPseudonym(String commentId);
}

/// **Le double inerte** : hors direct, aucun fil, aucune socket.
///
/// Le défaut sans backend et dans tous les tests d'écran (`pumpScreen` le
/// pose) : une page live montée sans parler du live voit une radio hors direct,
/// ses réactions partent dans le vide sans erreur, et un commentaire est refusé
/// comme le ferait le serveur hors direct.
class InertRadioLiveRepository implements RadioLiveRepository {
  const InertRadioLiveRepository();

  @override
  Future<RadioThread> thread() async => RadioThread.closed;

  @override
  Future<void> react(RadioReaction reaction, {DateTime? heardAt}) async {}

  @override
  Future<RadioComment> postComment(String body, {DateTime? heardAt}) async =>
      throw const RadioLiveException(RadioLiveRefusal.closed, status: 409);

  @override
  Future<String> savePseudonym(String pseudonym) async => pseudonym;

  @override
  Future<void> report(String commentId) async {}

  @override
  Future<RadioModerationQueue> moderationQueue() async =>
      RadioModerationQueue.empty;

  @override
  Future<void> hide(String commentId) async {}

  @override
  Future<void> keep(String commentId) async {}

  @override
  Future<void> silence(String commentId) async {}

  @override
  Future<void> resetPseudonym(String commentId) async {}
}
