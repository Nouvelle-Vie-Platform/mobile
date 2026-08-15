import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/repositories/calendar_repository.dart';
import 'package:maison_du_miracle/screens/groups_screen.dart';
import 'package:maison_du_miracle/screens/home_screen.dart';
import 'package:maison_du_miracle/screens/media_library_screen.dart';
import 'package:maison_du_miracle/screens/profile_screen.dart';
import 'package:maison_du_miracle/widgets/theme_choice_tile.dart';
import 'package:maison_du_miracle/state/calendar_providers.dart';

import '../helpers/pump_screen.dart';

void main() {
  group('Onglets principaux (smoke)', () {
    testWidgets('HomeScreen se monte avec les données', (tester) async {
      // Agenda forcé sur le double en mémoire : sans cet override, la section
      // « À venir » partirait sur `HttpCalendarRepository` et ouvrirait une
      // socket, à laquelle `flutter test` répond 400.
      await pumpScreen(
        tester,
        const Scaffold(body: HomeScreen()),
        overrides: [
          calendarRepositoryProvider
              .overrideWithValue(InMemoryCalendarRepository()),
        ],
      );
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.textContaining('Bonjour'), findsOneWidget);
    });

    testWidgets('MediaLibraryScreen se monte', (tester) async {
      await pumpScreen(tester, const Scaffold(body: MediaLibraryScreen()));
      expect(find.byType(MediaLibraryScreen), findsOneWidget);
      expect(find.text('Médiathèque'), findsOneWidget);
    });

    testWidgets('GroupsScreen (Communauté) se monte avec ses onglets',
        (tester) async {
      await pumpScreen(tester, const Scaffold(body: GroupsScreen()));
      expect(find.byType(GroupsScreen), findsOneWidget);
      expect(find.text('Communauté'), findsOneWidget);
      expect(find.text('Inbox'), findsOneWidget);
    });

    testWidgets('ProfileScreen se monte', (tester) async {
      await pumpScreen(tester, const Scaffold(body: ProfileScreen()));
      expect(find.byType(ProfileScreen), findsOneWidget);
      // Le réglage d'apparence a remplacé l'interrupteur « Mode sombre » par un
      // bloc à quatre positions ; on vérifie sa présence, pas son ancien
      // libellé.
      expect(find.byType(ThemeChoiceTile), findsOneWidget);
    });
  });
}
