import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/repositories/church_repository.dart';
import 'package:maison_du_miracle/models/models.dart';
import 'package:maison_du_miracle/screens/groups_screen.dart';
import 'package:maison_du_miracle/state/repository_providers.dart';

import '../helpers/pump_screen.dart';

/// Faux repository renvoyant des données contrôlées par le test.
class _FakeRepository implements ChurchRepository {
  @override
  List<Announcement> announcements() => const [];

  @override
  List<Teaching> teachings() => const [];

  @override
  List<CommunityGroup> groups() => const [
        CommunityGroup(name: 'Groupe de Test', members: 3),
      ];

  @override
  List<PrayerRequest> prayers() => const [];

  @override
  List<SpiritualNote> notes() => const [];

  @override
  List<ChatMessage> chatFor(CommunityGroup group) => const [];
}

void main() {
  testWidgets(
    'GroupsScreen affiche les données du repository injecté',
    (tester) async {
      await pumpScreen(
        tester,
        const Scaffold(body: GroupsScreen()),
        overrides: [
          churchRepositoryProvider.overrideWithValue(_FakeRepository()),
        ],
      );

      // La donnée provient du faux repository, pas des SampleData.
      expect(find.text('Groupe de Test'), findsOneWidget);
      expect(find.textContaining('Jeunesse Nouvelle Vie'), findsNothing);
    },
  );
}
