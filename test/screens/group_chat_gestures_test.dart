/// **Les gestes sur un message** (M2, #141 ; décisions 5 et 11 du plan) — ce
/// que le fil offre et ce qu'il fait : glisser pour répondre, la citation qui
/// mène au message d'origine, le menu d'appui long selon mes droits, les
/// réactions, « Modifié » et « Ce message a été supprimé ».
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/messaging/message_gestures.dart';
import 'package:maison_du_miracle/data/repositories/echanges_repository.dart';
import 'package:maison_du_miracle/l10n/app_localizations_fr.dart';
import 'package:maison_du_miracle/models/echanges_view.dart';
import 'package:maison_du_miracle/screens/group_chat_screen.dart';
import 'package:maison_du_miracle/state/echanges_providers.dart';
import 'package:maison_du_miracle/widgets/chat/chat_bubble.dart';

import '../helpers/pump_screen.dart';
import '../helpers/signed_in_auth.dart';

const String _groupId = 'g-1';

/// L'identifiant de `SignedInAuthRepository`.
const String _me = 'u_1';
final _fr = AppLocalizationsFr();

GroupDetailView _group({String myRole = 'member', bool canWrite = true}) =>
    GroupDetailView(
      groupId: _groupId,
      title: 'Chorale Harmonie',
      isDirect: false,
      memberCount: 3,
      canWrite: canWrite,
      members: [
        GroupMemberView(userId: _me, role: myRole),
        const GroupMemberView(userId: 'u-peer', role: 'member'),
      ],
    );

GroupMessageView _message(
  String id, {
  String? body = 'Bonjour',
  bool mine = false,
  DateTime? createdAt,
  bool deleted = false,
  bool edited = false,
  bool forwarded = false,
  MessageQuoteView? quote,
  List<MessageReactionView> reactions = const [],
  String? myReaction,
}) =>
    GroupMessageView(
      id: id,
      groupId: _groupId,
      body: deleted ? null : body,
      origin: messageOriginOf(
        authorId: mine ? _me : 'u-peer',
        isSystem: false,
      ),
      mine: mine,
      delivery: MessageDelivery.sent,
      authorId: mine ? _me : 'u-peer',
      authorName: mine ? null : 'Estelle Adjo',
      createdAt: createdAt ?? DateTime.now(),
      deleted: deleted,
      edited: edited,
      forwarded: forwarded,
      quote: quote,
      reactions: reactions,
      myReaction: myReaction,
    );

/// Enregistre les gestes envoyés — sans réseau.
class _RecordingSender implements MessageGestureSender {
  final List<String> calls = [];

  static const GestureReply _done =
      (outcome: GestureOutcome.done, rows: <Map<String, Object?>>[]);

  @override
  Future<GestureReply> react(String g, String m, String e) async {
    calls.add('react $m $e');
    return _done;
  }

  @override
  Future<GestureReply> unreact(String g, String m) async {
    calls.add('unreact $m');
    return _done;
  }

  @override
  Future<GestureReply> edit(String g, String m, String b) async {
    calls.add('edit $m $b');
    return _done;
  }

  @override
  Future<GestureReply> deleteForEveryone(String g, String m) async {
    calls.add('delete $m');
    return _done;
  }

  @override
  Future<GestureReply> hideForMe(String g, String m) async {
    calls.add('hide $m');
    return _done;
  }

  @override
  Future<GestureReply> forward(
    String g,
    String m,
    List<ForwardTarget> t,
  ) async {
    calls.add('forward $m ${t.map((x) => x.groupId).join(',')}');
    return _done;
  }
}

Future<_RecordingSender> _pump(
  WidgetTester tester,
  List<GroupMessageView> messages, {
  GroupDetailView? group,
}) async {
  final sender = _RecordingSender();
  await pumpScreen(
    tester,
    const GroupChatScreen(groupId: _groupId),
    auth: SignedInAuthRepository(),
    echanges: InMemoryEchangesRepository(
      groups: {_groupId: group ?? _group()},
      threads: {_groupId: messages},
    ),
    overrides: [
      messageGesturesProvider.overrideWithValue(
        MessageGestures(sender: sender, store: (_, __) async {}),
      ),
    ],
  );
  await tester.pumpAndSettle();
  return sender;
}

Future<void> _longPress(WidgetTester tester, String text) async {
  await tester.longPress(
    find.descendant(of: find.byType(ChatBubble), matching: find.text(text)),
  );
  await tester.pumpAndSettle();
}

Finder _action(String name) => find.byKey(Key('message_action_$name'));

void main() {
  group('Répondre en glissant', () {
    testWidgets(
        'glisser une bulle vers la droite pose la citation au-dessus du champ',
        (tester) async {
      await _pump(tester, [_message('m-1', body: 'Répétition samedi')]);
      EditableText field() =>
          tester.widget<EditableText>(find.byType(EditableText));
      expect(field().focusNode.hasFocus, isFalse);

      await tester.drag(find.text('Répétition samedi'), const Offset(120, 0));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('composer_reply_bar')), findsOneWidget);
      expect(find.text(_fr.chatReplyingTo('Estelle Adjo')), findsOneWidget);
      // Comme WhatsApp : le champ prend le focus, le clavier s'ouvre.
      expect(field().focusNode.hasFocus, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);

      // La croix l'annule.
      await tester.tap(find.byKey(const Key('composer_context_cancel')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('composer_reply_bar')), findsNothing);
    });

    testWidgets('un glissement trop court, ou vers la gauche, ne répond pas',
        (tester) async {
      await _pump(tester, [_message('m-1', body: 'Répétition samedi')]);

      await tester.drag(find.text('Répétition samedi'), const Offset(30, 0));
      await tester.pumpAndSettle();
      await tester.drag(find.text('Répétition samedi'), const Offset(-150, 0));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('composer_reply_bar')), findsNothing);
    });

    testWidgets('un message supprimé ne se glisse pas', (tester) async {
      await _pump(tester, [_message('m-1', deleted: true)]);

      await tester.drag(
          find.text(_fr.chatMessageDeleted), const Offset(120, 0));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('composer_reply_bar')), findsNothing);
    });
  });

  group('La citation', () {
    testWidgets('elle se peint dans la bulle, « Message supprimé » compris',
        (tester) async {
      await _pump(tester, [
        _message(
          'm-2',
          body: 'Oui !',
          quote: const MessageQuoteView(
            messageId: 'm-1',
            authorName: 'Kofi',
            excerpt: 'On répète samedi ?',
          ),
        ),
        _message(
          'm-3',
          body: 'Trop tard',
          quote: const MessageQuoteView(messageId: 'm-0', deleted: true),
        ),
      ]);

      expect(find.text('On répète samedi ?'), findsOneWidget);
      expect(find.text('Kofi'), findsOneWidget);
      expect(find.text(_fr.chatQuoteDeleted), findsOneWidget);
    });

    testWidgets(
        'la toucher défile jusqu\'au message d\'origine, hors fenêtre, et le '
        'met en évidence', (tester) async {
      final base = DateTime.now().subtract(const Duration(hours: 2));
      await _pump(tester, [
        _message('m-0', body: 'Le tout premier', createdAt: base),
        for (var i = 1; i < 60; i++)
          _message(
            'm-$i',
            body: 'Message $i',
            createdAt: base.add(Duration(minutes: i)),
          ),
        _message(
          'm-60',
          body: 'Je réponds au premier',
          createdAt: base.add(const Duration(minutes: 61)),
          quote: const MessageQuoteView(
            messageId: 'm-0',
            excerpt: 'Le tout premier (cité)',
          ),
        ),
      ]);
      // Le premier message n'est pas construit : il est à des écrans du bas.
      expect(find.byKey(const ValueKey('m-0')), findsNothing);

      await tester.tap(find.byKey(const Key('message_quote')));
      await tester.pumpAndSettle();

      final origin = find.byKey(const ValueKey('m-0'));
      expect(origin, findsOneWidget);
      final viewport = tester.getRect(find.byType(ListView));
      expect(viewport.contains(tester.getCenter(origin)), isTrue);

      // Mis en évidence…
      // La ligne du message (pas le conteneur du glissement, qui n'a pas de
      // décor).
      final row = find.ancestor(
        of: origin,
        matching: find.byWidgetPredicate(
          (w) => w is AnimatedContainer && w.decoration is BoxDecoration,
        ),
      );
      final highlight = tester.widget<AnimatedContainer>(row.first);
      final color = (highlight.decoration! as BoxDecoration).color!;
      expect(color.a, greaterThan(0));

      // … puis plus.
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      final after = tester.widget<AnimatedContainer>(row.first);
      expect((after.decoration! as BoxDecoration).color!.a, 0);
    });
  });

  group('Le menu d\'appui long, selon mes droits', () {
    testWidgets(
        'mon message récent : répondre, copier, transférer, modifier, '
        'supprimer pour moi et pour tous', (tester) async {
      await _pump(tester, [_message('m-1', body: 'À moi', mine: true)]);

      await _longPress(tester, 'À moi');

      for (final name in const [
        'reply',
        'copy',
        'forward',
        'edit',
        'deleteForMe',
        'deleteForEveryone',
      ]) {
        expect(_action(name), findsOneWidget, reason: name);
      }
      expect(find.byKey(const Key('quick_reaction_👍')), findsOneWidget);
    });

    testWidgets(
        'mon message de plus de 15 min : plus de « Modifier » ; de plus de '
        '2 jours : plus de « Supprimer pour tous »', (tester) async {
      await _pump(tester, [
        _message(
          'm-1',
          body: 'Vieux de 20 min',
          mine: true,
          createdAt: DateTime.now().subtract(const Duration(minutes: 20)),
        ),
        _message(
          'm-2',
          body: 'Vieux de 3 jours',
          mine: true,
          createdAt: DateTime.now().subtract(const Duration(days: 3)),
        ),
      ]);

      await _longPress(tester, 'Vieux de 20 min');
      expect(_action('edit'), findsNothing);
      expect(_action('deleteForEveryone'), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      await _longPress(tester, 'Vieux de 3 jours');
      expect(_action('edit'), findsNothing);
      expect(_action('deleteForEveryone'), findsNothing);
      expect(_action('deleteForMe'), findsOneWidget);
    });

    testWidgets(
        'le message d\'un autre, simple membre : ni modifier, ni supprimer '
        'pour tous', (tester) async {
      await _pump(tester, [_message('m-1', body: 'De Estelle')]);

      await _longPress(tester, 'De Estelle');

      expect(_action('reply'), findsOneWidget);
      expect(_action('deleteForMe'), findsOneWidget);
      expect(_action('edit'), findsNothing);
      expect(_action('deleteForEveryone'), findsNothing);
    });

    testWidgets(
        'administrateur du groupe : supprimer pour tous le message d\'un '
        'autre, même ancien', (tester) async {
      final sender = await _pump(
        tester,
        [
          _message(
            'm-1',
            body: 'Ancien',
            createdAt: DateTime.now().subtract(const Duration(days: 30)),
          ),
        ],
        group: _group(myRole: 'moderator'),
      );

      await _longPress(tester, 'Ancien');
      await tester.tap(_action('deleteForEveryone'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm_delete_for_everyone')));
      await tester.pumpAndSettle();

      expect(sender.calls, ['delete m-1']);
    });

    testWidgets('lecture seule : ni répondre, ni modifier', (tester) async {
      await _pump(
        tester,
        [_message('m-1', body: 'À moi', mine: true)],
        group: _group(canWrite: false),
      );

      await _longPress(tester, 'À moi');

      expect(_action('reply'), findsNothing);
      expect(_action('edit'), findsNothing);
      expect(_action('deleteForEveryone'), findsOneWidget);
    });

    testWidgets('un message supprimé : seulement « supprimer pour moi »',
        (tester) async {
      final sender = await _pump(tester, [_message('m-1', deleted: true)]);

      await tester.longPress(find.text(_fr.chatMessageDeleted));
      await tester.pumpAndSettle();

      expect(_action('deleteForMe'), findsOneWidget);
      expect(_action('reply'), findsNothing);
      expect(find.byKey(const Key('quick_reaction_👍')), findsNothing);

      await tester.tap(_action('deleteForMe'));
      await tester.pumpAndSettle();
      expect(sender.calls, ['hide m-1']);
    });

    testWidgets('« Modifier » met le texte dans le champ, et l\'envoi modifie',
        (tester) async {
      final sender =
          await _pump(tester, [_message('m-1', body: 'Coquile', mine: true)]);

      await _longPress(tester, 'Coquile');
      await tester.tap(_action('edit'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('composer_edit_bar')), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Coquille');
      // Le champ est multiligne : Entrée passe à la ligne, le bouton envoie.
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      expect(sender.calls, ['edit m-1 Coquille']);
      expect(find.byKey(const Key('composer_edit_bar')), findsNothing);
    });
  });

  group('Les réactions', () {
    testWidgets('l\'agrégat se peint sous la bulle', (tester) async {
      await _pump(tester, [
        _message(
          'm-1',
          reactions: const [
            MessageReactionView(emoji: '🙏', count: 3),
            MessageReactionView(emoji: '👍', count: 1, mine: true),
          ],
          myReaction: '👍',
        ),
      ]);

      expect(find.byKey(const Key('message_reactions')), findsOneWidget);
      expect(find.text('🙏 3'), findsOneWidget);
      expect(find.text('👍'), findsOneWidget);
    });

    testWidgets('un emoji du jeu rapide réagit ; retoucher le mien le retire',
        (tester) async {
      final sender = await _pump(tester, [
        _message('m-1', body: 'Sans réaction'),
        _message('m-2', body: 'Déjà 👍', myReaction: '👍'),
      ]);

      await _longPress(tester, 'Sans réaction');
      await tester.tap(find.byKey(const Key('quick_reaction_🙏')));
      await tester.pumpAndSettle();

      await _longPress(tester, 'Déjà 👍');
      await tester.tap(find.byKey(const Key('quick_reaction_👍')));
      await tester.pumpAndSettle();

      expect(sender.calls, ['react m-1 🙏', 'unreact m-2']);
    });
  });

  group('Ce que la bulle dit', () {
    testWidgets('« Modifié », « Transféré », et « Ce message a été supprimé »',
        (tester) async {
      await _pump(tester, [
        _message('m-1', body: 'Corrigé', edited: true),
        _message('m-2', body: 'Venu d\'ailleurs', forwarded: true),
        _message('m-3', deleted: true),
      ]);

      expect(find.text(_fr.chatMessageEdited), findsOneWidget);
      expect(find.text(_fr.chatMessageForwarded), findsOneWidget);
      expect(find.text(_fr.chatMessageDeleted), findsOneWidget);
    });
  });
}
