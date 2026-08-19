/// **Le décodage du réveil push, tolérant** — le contrat de réveil de
/// `docs/prd/notifications-push.md` §3, réaffirmé identique aux deux transports.
///
/// Le serveur pousse une charge **content-free** : `{ type, groupId, messageId }`.
/// FCM l'envoie en message **data** (une `Map<String, String>`), UnifiedPush la
/// `POST` telle quelle vers l'endpoint. Dans les deux cas l'app la reçoit comme
/// une carte clé/valeur non typée, éventuellement décodée depuis du JSON — donc
/// **jamais de garantie de forme**.
///
/// Ce décodeur est **défensif par construction** : il **ne lève jamais** et rend
/// `null` sur toute charge informe (clé absente, mauvais type, `type` inattendu,
/// identifiant vide). Un réveil qu'on ne comprend pas ne doit ni faire planter le
/// handler background, ni déclencher une sync ou une notification sur des
/// identifiants inventés — il s'ignore, silencieusement.
library;

import 'package:flutter/foundation.dart';

/// **Une charge de réveil `group_message` bien formée** : un fil (`groupId`) et le
/// message qui l'a déclenchée (`messageId`). Rien d'autre ne voyage — pas de
/// contenu (D6). C'est la seule forme que [tryParse] laisse passer.
@immutable
class PushWakePayload {
  const PushWakePayload({required this.groupId, required this.messageId});

  /// `groups.id` du fil concerné (UUID en chaîne).
  final String groupId;

  /// `group_messages.id` du message déclencheur (UUIDv7 en chaîne).
  final String messageId;

  /// Le **seul** `type` reconnu à ce jour. Les pushers `sync`/`notification`
  /// serveur existent mais leur UX mobile est un autre lot (§7 hors périmètre) —
  /// un `type` inconnu se rend en `null`, jamais en erreur.
  static const String groupMessageType = 'group_message';

  /// **Décode une charge de réveil.** Rend `null` — jamais une exception — dès que
  /// la charge n'est pas un `group_message` complet et bien formé.
  ///
  /// Tolérant sur le **transport** : les valeurs arrivent typiquement en chaînes
  /// (FCM data), mais une valeur non nulle d'un autre type scalaire est coercée
  /// via `toString()` plutôt que rejetée. Une chaîne **vide** compte pour absente.
  static PushWakePayload? tryParse(Map<String, Object?>? data) {
    if (data == null) return null;
    if (_string(data['type']) != groupMessageType) return null;
    final groupId = _string(data['groupId']);
    final messageId = _string(data['messageId']);
    if (groupId == null || messageId == null) return null;
    return PushWakePayload(groupId: groupId, messageId: messageId);
  }

  /// Lit [value] comme une chaîne **non vide**, `null` sinon. Un scalaire non
  /// chaîne (nombre…) est coercé ; `null`, la chaîne vide et une carte/liste
  /// rendent `null`.
  static String? _string(Object? value) {
    if (value == null) return null;
    if (value is Map || value is Iterable) return null;
    final text = value is String ? value : value.toString();
    return text.isEmpty ? null : text;
  }

  @override
  bool operator ==(Object other) =>
      other is PushWakePayload &&
      other.groupId == groupId &&
      other.messageId == messageId;

  @override
  int get hashCode => Object.hash(groupId, messageId);

  @override
  String toString() =>
      'PushWakePayload(groupId: $groupId, messageId: $messageId)';
}
