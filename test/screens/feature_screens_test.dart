import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/repositories/calendar_repository.dart';
import 'package:maison_du_miracle/data/repositories/echanges_repository.dart';
import 'package:maison_du_miracle/data/repositories/mediatheque_repository.dart';
import 'package:maison_du_miracle/models/echanges_view.dart';
import 'package:maison_du_miracle/models/models.dart';
import 'package:maison_du_miracle/screens/agenda_screen.dart';
import 'package:maison_du_miracle/screens/donations_screen.dart';
import 'package:maison_du_miracle/screens/group_chat_screen.dart';
import 'package:maison_du_miracle/screens/radio_screen.dart';
import 'package:maison_du_miracle/screens/new_request_screen.dart';
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

    testWidgets('RadioScreen se monte', (tester) async {
      // Le double par défaut de `pumpScreen` ne connaît **aucune** adresse
      // d'antenne : l'écran doit donc se monter sur l'absence, et c'est le cas
      // qu'un smoke test doit exercer — l'application s'ouvre avant que la route
      // publique ait répondu.
      await pumpScreen(tester, const RadioScreen());
      expect(find.byType(RadioScreen), findsOneWidget);
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

    testWidgets('DonationsScreen se monte', (tester) async {
      await pumpScreen(tester, const DonationsScreen());
      expect(find.byType(DonationsScreen), findsOneWidget);
    });

    testWidgets('TeachingDetailScreen affiche l\'enseignement résolu',
        (tester) async {
      // Enseignement sans image : évite tout chargement réseau en test — c'est
      // le repli coloré qui s'affiche, exactement comme hors ligne.
      // `final` et non `const` : les dates ne sont pas constructibles en
      // constante.
      //
      // **Avec `playlistUrl`** : sans elle, l'écran bascule sur la branche
      // « média absent » (#41) et n'affiche plus de titre. Ce qu'on veut ici
      // est le lecteur rempli, pas l'absence — elle a ses propres tests.
      final teaching = Teaching(
        id: '01940000-0000-7000-8000-00000000cafe',
        title: 'Enseignement de test',
        author: 'Pasteur Test',
        color: 0xFF223B8C,
        teachingTypeId: 1,
        recordedAt: DateTime.utc(2026, 4, 12),
        publishedAt: DateTime.utc(2026, 4, 12, 8),
        playlistUrl: 'https://exemple.test/enseignement-de-test/master.m3u8',
      );
      // L'écran ne reçoit qu'un identifiant : la donnée vient du provider.
      await pumpScreen(
        tester,
        TeachingDetailScreen(teachingId: teaching.id),
        mediatheque: InMemoryMediathequeRepository(teachings: [teaching]),
      );
      expect(find.byType(TeachingDetailScreen), findsOneWidget);
      expect(find.text(teaching.title), findsOneWidget);
    });

    testWidgets('GroupChatScreen résout son groupe depuis le magasin',
        (tester) async {
      // ⚠️ **L'écran ne reçoit plus qu'un identifiant** (#96) : `SampleData` ne
      // porte plus de conversation, et l'ancienne convention « l'objet en
      // `extra`, repli sur le premier » est tombée avec le fictif. Le groupe vient
      // du repository, comme un enseignement vient du sien.
      const group = GroupDetailView(
        groupId: 'g-1',
        title: 'Chorale Harmonie',
        isDirect: false,
        memberCount: 12,
        canWrite: true,
      );
      await pumpScreen(
        tester,
        const GroupChatScreen(groupId: 'g-1'),
        echanges: InMemoryEchangesRepository(groups: {'g-1': group}),
      );
      expect(find.byType(GroupChatScreen), findsOneWidget);
      expect(find.text(group.title), findsOneWidget);
    });
  });
}
