import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/group_dao.dart';
import 'package:maison_du_miracle/data/push/notification_reconciler.dart';

import 'notification_doubles.dart';

/// **Application ouverte, la notification d'une conversation lue s'efface**
/// (M5) — lue ici, ou ailleurs (`read.advanced` range la lecture, la liste se
/// recalcule). Le réconciliateur écoute la liste, il n'affiche jamais rien.
void main() {
  final now = DateTime.utc(2026, 10, 6, 12);

  ConversationRecord record(String id, int unread, {bool forever = false}) =>
      ConversationRecord(
        groupId: id,
        groupName: id,
        isDirect: false,
        memberCount: 2,
        postPolicy: 'all',
        isWriteLocked: false,
        isActive: true,
        myRole: 'member',
        unreadCount: unread,
        mutedForever: forever,
      );

  late RecordingNotifier notifier;
  late NotificationReconciler reconciler;

  setUp(() {
    notifier = RecordingNotifier();
    reconciler = NotificationReconciler(notifier: notifier, now: () => now);
  });

  test('une conversation qui devient lue voit sa notification effacée',
      () async {
    await reconciler.onConversations([record('a', 3), record('b', 1)]);
    notifier.cancelled.clear();

    // Lue sur un autre appareil : `read.advanced` est arrivé, la liste a émis.
    await reconciler.onConversations([record('a', 0), record('b', 1)]);

    expect(notifier.cancelled, ['a']);
    // Il reste une conversation à coiffer : le résumé reste.
    expect(notifier.summaryCancelled, 0);
    // Le premier plan ne dresse jamais rien.
    expect(notifier.shown, isEmpty);
    expect(notifier.summaries, isEmpty);
  });

  test('plus rien de non lu : le résumé part aussi', () async {
    await reconciler.onConversations([record('a', 3)]);
    await reconciler.onConversations([record('a', 0)]);

    expect(notifier.cancelled, ['a']);
    expect(notifier.summaryCancelled, 1);
  });

  test('à l\'ouverture, ce qui est déjà lu est effacé une fois', () async {
    // Une notification d'avant l'ouverture peut traîner pour une conversation
    // lue entre-temps sur un autre appareil.
    await reconciler.onConversations([record('a', 0), record('b', 2)]);

    expect(notifier.cancelled, ['a']);

    // Et pas à chaque émission : rien n'a changé pour « a ».
    await reconciler.onConversations([record('a', 0), record('b', 2)]);
    expect(notifier.cancelled, ['a']);
  });

  test('une conversation mise en sourdine voit sa notification effacée',
      () async {
    await reconciler.onConversations([record('a', 3)]);
    await reconciler.onConversations([record('a', 3, forever: true)]);

    expect(notifier.cancelled, ['a']);
  });
}
