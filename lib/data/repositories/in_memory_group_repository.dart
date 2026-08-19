import '../../models/models.dart';
import '../sample_data.dart';
import 'group_repository.dart';

/// Double **en mémoire** de [GroupRepository], servi quand `AppEnv.useBackend`
/// est faux (mode maquette) et dans les tests d'écran.
///
/// Il rejoue les mêmes fixtures que l'ancienne messagerie fictive
/// (`SampleData`), en flux : le hub « Échanges » garde exactement son allure hors
/// backend, et aucun écran ne change de forme selon l'environnement.
class InMemoryGroupRepository implements GroupRepository {
  const InMemoryGroupRepository();

  @override
  Stream<List<Conversation>> conversations() =>
      Stream.value(SampleData.conversations);

  @override
  Stream<List<DiscoverGroup>> groupsToJoin() =>
      Stream.value(SampleData.groupsToJoin);

  @override
  Stream<Conversation?> group(String groupId) => Stream.value(
        SampleData.conversations
            .where((c) => c.id == groupId)
            .cast<Conversation?>()
            .firstOrNull,
      );

  @override
  Stream<List<ChatMessage>> messages(String groupId) =>
      Stream.value(SampleData.chat);

  @override
  Stream<List<GroupMemberView>> members(String groupId) =>
      Stream.value(const []);

  @override
  Stream<Conversation?> directConversationWith(String otherUserId) =>
      Stream.value(null);

  @override
  Stream<List<GroupJoinRequest>> pendingRequests(String groupId) =>
      const Stream.empty();

  @override
  Stream<InstitutionProfile?> institution(GroupOwnerKind kind, int id) =>
      Stream.value(null);

  @override
  Stream<List<Conversation>> institutionGroups(GroupOwnerKind kind, int id) =>
      Stream.value(const []);
}
