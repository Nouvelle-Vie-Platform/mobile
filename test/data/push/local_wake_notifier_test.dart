import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/push/conversation_notification.dart';
import 'package:maison_du_miracle/data/push/wake_notifier.dart';

import 'notification_doubles.dart';

/// **Le dessin d'une notification de conversation** (M5) — ce que
/// [LocalWakeNotifier] confie au greffon, vérifié sur un **double du greffon**
/// qui note chaque appel : le style « messagerie », le groupe Android, le
/// compteur, les deux actions, et le résumé.
void main() {
  late _FakePlugin plugin;
  late LocalWakeNotifier notifier;

  final at = DateTime.utc(2026, 9, 3, 10, 30);

  ConversationNotification conversation({bool alert = true}) =>
      ConversationNotification(
        id: conversationNotificationId('grp-1'),
        groupId: 'grp-1',
        title: 'Chorale Harmonie',
        isGroup: true,
        lines: [
          NotificationLine(
            text: 'Répétition samedi',
            at: at,
            authorKey: 'u-ama',
            authorName: 'Ama',
          ),
          NotificationLine(
            text: 'Paix',
            at: at.add(const Duration(minutes: 2)),
            authorKey: 'removed',
          ),
        ],
        unreadCount: 7,
        texts: kTestNotificationTexts,
        alert: alert,
      );

  setUp(() {
    plugin = _FakePlugin();
    notifier = LocalWakeNotifier(plugin: plugin);
  });

  test('une conversation : MessagingStyle, auteurs, groupe et compteur',
      () async {
    await notifier.show(conversation());

    final call = plugin.shown.single;
    expect(call.id, conversationNotificationId('grp-1'));
    expect(call.title, 'Chorale Harmonie');
    expect(call.body, 'Paix');
    // Le tap ouvre **cette** conversation, et les actions la désignent.
    expect(call.payload, 'grp-1');

    final android = call.details!.android!;
    expect(android.channelId, kWakeChannelId);
    expect(android.groupKey, kMessagesGroupKey);
    expect(android.setAsGroupSummary, isFalse);
    expect(android.number, 7);
    expect(android.category, AndroidNotificationCategory.message);
    expect(android.silent, isFalse);

    final style = android.styleInformation! as MessagingStyleInformation;
    expect(style.person.name, 'Vous');
    expect(style.conversationTitle, 'Chorale Harmonie');
    expect(style.groupConversation, isTrue);
    expect(style.messages!.map((m) => (m.person?.name, m.text)), [
      ('Ama', 'Répétition samedi'),
      // L'auteur retiré, dit comme dans le fil.
      ('Membre retiré', 'Paix'),
    ]);
  });

  test('deux actions, traitées sans ouvrir l\'application', () async {
    await notifier.show(conversation());

    final actions = plugin.shown.single.details!.android!.actions!;
    expect(actions.map((a) => a.id), [kReplyActionId, kMarkReadActionId]);

    final reply = actions.first;
    expect(reply.title, 'Répondre');
    expect(reply.inputs.single.label, 'Votre message');
    expect(reply.semanticAction, SemanticAction.reply);
    expect(reply.showsUserInterface, isFalse);
    expect(reply.cancelNotification, isTrue);

    final markRead = actions.last;
    expect(markRead.title, 'Marquer comme lu');
    expect(markRead.inputs, isEmpty);
    expect(markRead.semanticAction, SemanticAction.markAsRead);
    expect(markRead.showsUserInterface, isFalse);
  });

  test('une mise à jour silencieuse ne sonne pas', () async {
    await notifier.show(conversation(alert: false));

    final android = plugin.shown.single.details!.android!;
    expect(android.silent, isTrue);
    expect(android.onlyAlertOnce, isTrue);
  });

  test('un tête-à-tête n\'a pas de titre de conversation', () async {
    await notifier.show(
      ConversationNotification(
        id: 1,
        groupId: 'dm',
        title: 'Estelle',
        isGroup: false,
        lines: [
          NotificationLine(
            text: 'Bonsoir',
            at: at,
            authorKey: 'u-estelle',
            authorName: 'Estelle',
          ),
        ],
        unreadCount: 1,
        texts: kTestNotificationTexts,
      ),
    );

    final style = plugin.shown.single.details!.android!.styleInformation!
        as MessagingStyleInformation;
    expect(style.conversationTitle, isNull);
    expect(style.groupConversation, isFalse);
    expect(style.messages!.single.person?.name, 'Estelle');
  });

  test('le résumé coiffe le groupe, et ne sonne jamais', () async {
    await notifier.showSummary(
      const NotificationSummary(
        title: '9 nouveaux messages',
        text: 'dans 2 discussions',
        totalUnread: 9,
        conversations: 2,
        lines: ['Chorale Harmonie', 'Estelle'],
      ),
    );

    final call = plugin.shown.single;
    expect(call.id, kMessagesSummaryId);
    expect(call.payload, isNull);
    final android = call.details!.android!;
    expect(android.setAsGroupSummary, isTrue);
    expect(android.groupKey, kMessagesGroupKey);
    expect(android.number, 9);
    expect(android.groupAlertBehavior, GroupAlertBehavior.children);
    final style = android.styleInformation! as InboxStyleInformation;
    expect(style.lines, ['Chorale Harmonie', 'Estelle']);
  });

  test('effacer : la conversation par son identifiant, le résumé par le sien',
      () async {
    await notifier.cancel('grp-1');
    await notifier.cancelSummary();

    expect(plugin.cancelled, [
      conversationNotificationId('grp-1'),
      kMessagesSummaryId,
    ]);
  });

  test('un greffon qui lève ne remonte jamais', () async {
    plugin.fails = true;

    await expectLater(notifier.show(conversation()), completes);
    await expectLater(notifier.cancel('grp-1'), completes);
  });
}

class _Shown {
  _Shown(this.id, this.title, this.body, this.details, this.payload);

  final int id;
  final String? title;
  final String? body;
  final NotificationDetails? details;
  final String? payload;
}

/// **Le double du greffon** : il note `show` et `cancel`, et rien d'autre n'est
/// appelé par ces tests — tout le reste lèverait (`noSuchMethod`).
class _FakePlugin implements FlutterLocalNotificationsPlugin {
  final List<_Shown> shown = [];
  final List<int> cancelled = [];
  bool fails = false;

  @override
  Future<void> show({
    required int id,
    String? title,
    String? body,
    NotificationDetails? notificationDetails,
    String? payload,
  }) async {
    if (fails) throw StateError('greffon indisponible');
    shown.add(_Shown(id, title, body, notificationDetails, payload));
  }

  @override
  Future<void> cancel({required int id, String? tag}) async {
    if (fails) throw StateError('greffon indisponible');
    cancelled.add(id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
