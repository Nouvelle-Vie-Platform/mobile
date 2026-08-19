import 'group_messaging.dart';

/// Double **inerte** de [GroupMessaging] — le défaut hors backend et en test.
///
/// Aucune écriture ne part sur le réseau : chaque méthode réussit sans effet.
/// C'est le pendant, pour l'écriture, de [InMemoryGroupRepository] côté lecture —
/// en mode maquette il n'y a rien à envoyer, et un test qui veut observer un
/// envoi surcharge le provider par un faux.
class InertGroupMessaging implements GroupMessaging {
  const InertGroupMessaging();

  @override
  Future<void> sendMessage(
    String groupId, {
    required String body,
    String? clientMessageId,
    DateTime? clientCreatedAt,
  }) async {}

  @override
  Future<void> sendDirect(
    String targetUserId, {
    required String body,
    String? clientMessageId,
    DateTime? clientCreatedAt,
  }) async {}

  @override
  Future<void> join(String groupId) async {}

  @override
  Future<void> requestToJoin(String groupId) async {}

  @override
  Future<void> leave(String groupId) async {}

  @override
  Future<void> approveJoinRequest(String groupId, int requestId) async {}

  @override
  Future<void> rejectJoinRequest(String groupId, int requestId) async {}
}
