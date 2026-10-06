import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/messaging/group_mute_setter.dart';
import 'package:maison_du_miracle/models/echanges_view.dart';
import 'package:maison_du_miracle/widgets/chat/chat_mute_menu.dart';
import 'package:maison_du_miracle/widgets/community/conversation_tile.dart';
import 'package:maison_du_miracle/widgets/community/muted_indicator.dart';
import 'package:maison_du_miracle/widgets/notification_preview_tile.dart';

import '../helpers/pump_screen.dart';

/// **La sourdine et l'aperçu, à l'écran** (M5) : l'icône de la tuile, le menu
/// « ⋮ » du fil, l'interrupteur du profil.
void main() {
  ConversationView conversation({bool muted = false}) => ConversationView(
        groupId: 'grp-1',
        title: 'Chorale Harmonie',
        isDirect: false,
        memberCount: 3,
        canWrite: true,
        unreadCount: 2,
        isMuted: muted,
      );

  group('La tuile de la liste', () {
    testWidgets('une discussion en sourdine porte le haut-parleur barré',
        (tester) async {
      await pumpScreen(
        tester,
        Scaffold(
            body: ConversationTile(conversation: conversation(muted: true))),
      );

      expect(find.byKey(MutedIndicator.iconKey), findsOneWidget);
      expect(find.byIcon(Icons.volume_off), findsOneWidget);
      // La pastille des non-lus reste : une sourdine tait, elle ne cache pas.
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('une discussion ordinaire n\'en porte pas', (tester) async {
      await pumpScreen(
        tester,
        Scaffold(body: ConversationTile(conversation: conversation())),
      );

      expect(find.byKey(MutedIndicator.iconKey), findsNothing);
    });
  });

  group('Le menu du fil', () {
    Widget bar() => Scaffold(
          appBar: AppBar(actions: const [ChatMuteMenu(groupId: 'grp-1')]),
        );

    testWidgets('mettre en sourdine : trois durées, et la choisie part',
        (tester) async {
      final sender = _RecordingMuteSender();
      await pumpScreen(tester, bar(), muteSender: sender);

      await tester.tap(find.byKey(ChatMuteMenu.buttonKey));
      await tester.pumpAndSettle();
      expect(find.byKey(ChatMuteMenu.unmuteKey), findsNothing);
      await tester.tap(find.byKey(ChatMuteMenu.muteKey));
      await tester.pumpAndSettle();

      for (final duration in MuteDuration.values) {
        expect(find.byKey(ChatMuteMenu.durationKey(duration)), findsOneWidget);
      }
      expect(find.text('8 heures'), findsOneWidget);
      expect(find.text('1 semaine'), findsOneWidget);
      expect(find.text('Toujours'), findsOneWidget);

      await tester
          .tap(find.byKey(ChatMuteMenu.durationKey(MuteDuration.oneWeek)));
      await tester.pumpAndSettle();

      expect(
          sender.calls, [(groupId: 'grp-1', duration: MuteDuration.oneWeek)]);
      await drainSnackBar(tester);
    });

    testWidgets('en sourdine : « Réactiver les notifications »',
        (tester) async {
      final sender = _RecordingMuteSender();
      await pumpScreen(
        tester,
        bar(),
        muteSender: sender,
        mutes: const {'grp-1': (mutedUntil: null, mutedForever: true)},
      );

      await tester.tap(find.byKey(ChatMuteMenu.buttonKey));
      await tester.pumpAndSettle();
      expect(find.byKey(ChatMuteMenu.muteKey), findsNothing);
      await tester.tap(find.byKey(ChatMuteMenu.unmuteKey));
      await tester.pumpAndSettle();

      expect(sender.calls, [(groupId: 'grp-1', duration: null)]);
      await drainSnackBar(tester);
    });

    testWidgets('une sourdine échue propose de nouveau la sourdine',
        (tester) async {
      await pumpScreen(
        tester,
        bar(),
        mutes: {
          'grp-1': (
            mutedUntil: DateTime.now().subtract(const Duration(hours: 1)),
            mutedForever: false,
          ),
        },
      );

      await tester.tap(find.byKey(ChatMuteMenu.buttonKey));
      await tester.pumpAndSettle();

      expect(find.byKey(ChatMuteMenu.muteKey), findsOneWidget);
    });

    testWidgets('un refus se dit tout de suite', (tester) async {
      // Le double inerte du harnais ne confirme rien : c'est le cas « hors
      // ligne ».
      await pumpScreen(tester, bar());

      await tester.tap(find.byKey(ChatMuteMenu.buttonKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ChatMuteMenu.muteKey));
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(ChatMuteMenu.durationKey(MuteDuration.forever)));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'La sourdine n\'a pas pu être réglée. Vérifiez votre connexion.',
        ),
        findsOneWidget,
      );
      await drainSnackBar(tester);
    });
  });

  group('Le réglage du profil', () {
    testWidgets('« Afficher le contenu » est activé par défaut',
        (tester) async {
      await pumpScreen(
        tester,
        const Scaffold(body: NotificationPreviewTile()),
      );

      final toggle =
          tester.widget<Switch>(find.byKey(NotificationPreviewTile.switchKey));
      expect(toggle.value, isTrue);
      expect(find.text('Afficher le contenu des messages'), findsOneWidget);
    });

    testWidgets('désactivé, il le montre', (tester) async {
      await pumpScreen(
        tester,
        const Scaffold(body: NotificationPreviewTile()),
        notificationPreview: false,
      );

      final toggle =
          tester.widget<Switch>(find.byKey(NotificationPreviewTile.switchKey));
      expect(toggle.value, isFalse);
    });
  });
}

/// Le double du harnais ne confirme rien : chaque geste se termine sur le
/// message bref du refus, dont la minuterie d'affichage doit expirer avant la
/// fin du test (sans quoi le harnais signale une minuterie pendante).
Future<void> drainSnackBar(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

class _RecordingMuteSender implements GroupMuteSender {
  final List<({String groupId, MuteDuration? duration})> calls = [];

  @override
  Future<Map<String, Object?>?> send({
    required String groupId,
    required MuteDuration? duration,
  }) async {
    calls.add((groupId: groupId, duration: duration));
    // Aucune ligne rendue : rien n'est rangé dans le magasin (un flux Drift
    // sous l'horloge factice figerait le test). Ces tests jugent ce qui part ;
    // le rangement de la réponse est vérifié dans `group_mute_test.dart`.
    return null;
  }
}
