import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/players/status_player.dart';
import 'package:maison_du_miracle/data/repositories/church_repository.dart';
import 'package:maison_du_miracle/models/models.dart';
import 'package:maison_du_miracle/screens/announcements_screen.dart';
import 'package:maison_du_miracle/state/player_providers.dart';
import 'package:maison_du_miracle/state/repository_providers.dart';
import 'package:maison_du_miracle/widgets/status/status_background.dart';
import 'package:maison_du_miracle/widgets/status/status_waveform.dart';

import '../helpers/pump_screen.dart';

/// Repository de test : la liste de statuts est fournie par le test lui-même.
class _FakeRepository implements ChurchRepository {
  _FakeRepository(this._announcements);

  final List<Announcement> _announcements;

  @override
  List<Announcement> announcements() => _announcements;

  @override
  List<CommunityGroup> groups() => const [];

  @override
  List<PrayerRequest> prayers() => const [];

  @override
  List<SpiritualNote> notes() => const [];

  @override
  List<ChatMessage> chatFor(CommunityGroup group) => const [];
}

/// Monte la visionneuse avec un lecteur **inerte** : sans minuterie, l'écran
/// reste déterministe et aucun timer ne survit au démontage.
Future<void> pumpViewer(
  WidgetTester tester,
  List<Announcement> statuses,
) {
  return pumpScreen(
    tester,
    const Scaffold(body: AnnouncementsScreen()),
    overrides: [
      churchRepositoryProvider.overrideWithValue(_FakeRepository(statuses)),
      statusPlayerProvider.overrideWithValue(InertStatusPlayer()),
    ],
  );
}

Announcement _status({
  required String id,
  String? title,
  String? body,
  StatusAudio? audio,
  String? backgroundImage,
  int? backgroundColor,
  Duration age = const Duration(hours: 2),
}) {
  return Announcement(
    id: id,
    publishedAt: DateTime.now().toUtc().subtract(age),
    title: title,
    body: body,
    author: 'Pasteur Samuel',
    audio: audio,
    backgroundImage: backgroundImage,
    backgroundColor: backgroundColor,
  );
}

void main() {
  group('Visionneuse de statuts', () {
    testWidgets('se monte et affiche le premier statut', (tester) async {
      await pumpViewer(tester, [
        // Le plus récent d'abord : c'est lui qu'on doit voir à l'ouverture.
        _status(
            id: 'b', body: 'Répétition décalée.', age: const Duration(days: 1)),
        _status(id: 'a', title: 'Convention annuelle', body: 'Trois jours.'),
      ]);

      expect(find.byType(AnnouncementsScreen), findsOneWidget);
      expect(find.text('Convention annuelle'), findsOneWidget);
      expect(find.text('Pasteur Samuel'), findsOneWidget);
      // Horodatage relatif localisé, jamais une chaîne venue du back.
      expect(find.textContaining('Il y a 2 heures'), findsOneWidget);
    });

    testWidgets('sans annonce, affiche l’état vide', (tester) async {
      await pumpViewer(tester, const []);

      expect(find.text('Aucune annonce'), findsOneWidget);
      expect(find.byType(StatusWaveform), findsNothing);
    });

    testWidgets(
      'un statut vocal + texte affiche le texte ET la waveform',
      (tester) async {
        await pumpViewer(tester, [
          _status(
            id: 'vocal',
            body: 'Un mot du pasteur.',
            audio: const StatusAudio(
              url: 'https://example.org/vocal.m4a',
              durationMs: 12000,
              waveform: [10, 40, 80, 30, 60],
            ),
          ),
        ]);

        expect(find.text('Un mot du pasteur.'), findsOneWidget);
        expect(find.byType(StatusWaveform), findsOneWidget);
      },
    );

    testWidgets(
      'un statut texte seul n’affiche aucune waveform',
      (tester) async {
        await pumpViewer(tester, [
          _status(id: 'texte', body: 'Collecte de dons solidaires.'),
        ]);

        expect(find.text('Collecte de dons solidaires.'), findsOneWidget);
        expect(find.byType(StatusWaveform), findsNothing);
      },
    );

    testWidgets(
      'sans couleur ni image, le fond retombe sur la palette dérivée de l’id',
      (tester) async {
        await pumpViewer(
            tester, [_status(id: 'sans-habillage', body: 'Paix.')]);

        expect(find.byType(StatusBackground), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'le bouton liste ouvre la feuille et permet de sauter à un statut',
      (tester) async {
        await pumpViewer(tester, [
          _status(id: 'recent', title: 'Convention annuelle'),
          _status(
            id: 'ancien',
            title: 'Collecte solidaire',
            age: const Duration(days: 3),
          ),
        ]);

        await tester.tap(find.byIcon(Icons.format_list_bulleted_rounded));
        await tester.pumpAndSettle();

        // La feuille liste bien tout l'historique, pas seulement le statut vu.
        expect(find.text('Toutes les annonces'), findsOneWidget);
        expect(find.text('Collecte solidaire'), findsOneWidget);

        await tester.tap(find.text('Collecte solidaire'));
        await tester.pumpAndSettle();

        // Retour à la visionneuse, positionnée sur le statut choisi.
        expect(find.text('Toutes les annonces'), findsNothing);
        expect(find.text('Collecte solidaire'), findsOneWidget);
      },
    );

    testWidgets('le bouton muet bascule l’état du son', (tester) async {
      await pumpViewer(tester, [_status(id: 'texte', body: 'Paix sur vous.')]);

      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.volume_up_rounded));
      await tester.pump();

      expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);
      expect(find.byIcon(Icons.volume_up_rounded), findsNothing);
    });

    testWidgets(
      'une image de fond en échec réseau retombe sans lever',
      (tester) async {
        // Sous `flutter test`, toute requête réseau renvoie 400 : c'est donc le
        // chemin `errorBuilder` qui s'exécute, et il doit être couvert.
        await pumpViewer(tester, [
          _status(
            id: 'image',
            body: 'Affiche de la convention.',
            backgroundImage: 'https://example.org/affiche.jpg',
          ),
        ]);
        await tester.pump(const Duration(seconds: 1));

        expect(find.byKey(StatusBackground.imageErrorKey), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
