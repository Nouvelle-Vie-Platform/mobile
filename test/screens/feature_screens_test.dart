import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/repositories/calendar_repository.dart';
import 'package:maison_du_miracle/data/sample_data.dart';
import 'package:maison_du_miracle/models/models.dart';
import 'package:maison_du_miracle/screens/agenda_screen.dart';
import 'package:maison_du_miracle/screens/donations_screen.dart';
import 'package:maison_du_miracle/screens/group_chat_screen.dart';
import 'package:maison_du_miracle/screens/live_screen.dart';
import 'package:maison_du_miracle/screens/new_request_screen.dart';
import 'package:maison_du_miracle/screens/notes_screen.dart';
import 'package:maison_du_miracle/screens/prayer_requests_screen.dart';
import 'package:maison_du_miracle/screens/teaching_detail_screen.dart';
import 'package:maison_du_miracle/state/calendar_providers.dart';

import '../helpers/pump_screen.dart';

void main() {
  group('Écrans secondaires (smoke)', () {
    testWidgets('AgendaScreen se monte', (tester) async {
      // L'agenda lit `calendarRepositoryProvider`, qui part sur HTTP quand
      // `AppEnv.useBackend` est vrai : sans ce repli en mémoire, un simple
      // montage ouvrirait une socket (400 en test).
      await pumpScreen(
        tester,
        const AgendaScreen(),
        overrides: [
          calendarRepositoryProvider
              .overrideWithValue(InMemoryCalendarRepository()),
        ],
      );
      expect(find.byType(AgendaScreen), findsOneWidget);
    });

    testWidgets('LiveScreen se monte', (tester) async {
      await pumpScreen(tester, const LiveScreen());
      expect(find.byType(LiveScreen), findsOneWidget);
    });

    testWidgets('PrayerRequestsScreen se monte', (tester) async {
      await pumpScreen(tester, const PrayerRequestsScreen());
      expect(find.byType(PrayerRequestsScreen), findsOneWidget);
      expect(find.text('Espace de prière'), findsOneWidget);
    });

    testWidgets('NewRequestScreen se monte', (tester) async {
      await pumpScreen(tester, const NewRequestScreen());
      expect(find.byType(NewRequestScreen), findsOneWidget);
    });

    testWidgets('NotesScreen se monte', (tester) async {
      await pumpScreen(tester, const NotesScreen());
      expect(find.byType(NotesScreen), findsOneWidget);
    });

    testWidgets('DonationsScreen se monte', (tester) async {
      await pumpScreen(tester, const DonationsScreen());
      expect(find.byType(DonationsScreen), findsOneWidget);
    });

    testWidgets('TeachingDetailScreen affiche l\'enseignement reçu',
        (tester) async {
      // Enseignement sans image : évite tout chargement réseau en test — c'est
      // le repli coloré qui s'affiche, exactement comme hors ligne.
      // `final` et non `const` : les dates ne sont pas constructibles en
      // constante.
      final teaching = Teaching(
        title: 'Enseignement de test',
        author: 'Pasteur Test',
        duration: '10:00',
        color: 0xFF223B8C,
        rubric: TeachingRubric.dimanche,
        recordedAt: DateTime.utc(2026, 4, 12),
        publishedAt: DateTime.utc(2026, 4, 12, 8),
      );
      await pumpScreen(tester, TeachingDetailScreen(teaching: teaching));
      expect(find.byType(TeachingDetailScreen), findsOneWidget);
      expect(find.text(teaching.title), findsOneWidget);
    });

    testWidgets('GroupChatScreen affiche le groupe reçu', (tester) async {
      final group = SampleData.groups.first;
      await pumpScreen(tester, GroupChatScreen(group: group));
      expect(find.byType(GroupChatScreen), findsOneWidget);
      expect(find.text(group.name), findsOneWidget);
    });
  });
}
