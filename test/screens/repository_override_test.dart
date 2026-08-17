import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/repositories/group_repository.dart';
import 'package:maison_du_miracle/models/models.dart';
import 'package:maison_du_miracle/screens/groups_screen.dart';

import '../helpers/pump_screen.dart';

/// Faux [GroupRepository] renvoyant des données contrôlées par le test — la
/// messagerie a migré du fictif synchrone au magasin (`StreamProvider`), le
/// double se surcharge donc désormais ici et non sur `ChurchRepository`.
class _FakeGroupRepository implements GroupRepository {
  @override
  Stream<List<Conversation>> conversations() => Stream.value(const [
        Conversation(
          id: 'conv-test',
          kind: ConversationKind.group,
          name: 'Groupe de Test',
          lastMessagePreview: 'Bonjour',
          time: '10:00',
        ),
      ]);

  @override
  Stream<List<DiscoverGroup>> groupsToJoin() => Stream.value(const []);

  @override
  Stream<Conversation?> group(String groupId) => Stream.value(null);

  @override
  Stream<List<ChatMessage>> messages(String groupId) => Stream.value(const []);

  @override
  Stream<List<GroupJoinRequest>> pendingRequests(String groupId) =>
      Stream.value(const []);

  @override
  Stream<InstitutionProfile?> institution(GroupOwnerKind kind, int id) =>
      Stream.value(null);

  @override
  Stream<List<Conversation>> institutionGroups(GroupOwnerKind kind, int id) =>
      Stream.value(const []);
}

void main() {
  testWidgets(
    'GroupsScreen affiche les données du repository injecté',
    (tester) async {
      await pumpScreen(
        tester,
        const Scaffold(body: GroupsScreen()),
        // Paramètre nommé et non `Override` de plus : `pumpScreen` pose déjà un
        // double de groupe (Riverpod 3 refuse une seconde surcharge).
        groupRepository: _FakeGroupRepository(),
      );
      // Le flux nu (`Stream.value`) émet dès la première frame : `pump(1s)` de
      // `pumpScreen` a suffi à le livrer.
      await tester.pump();

      // La donnée provient du faux repository, pas des SampleData.
      expect(find.text('Groupe de Test'), findsOneWidget);
      expect(find.textContaining('Jeunesse Nouvelle Vie'), findsNothing);
    },
  );
}
