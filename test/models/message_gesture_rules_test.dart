/// **Quels gestes offrir sur un message** (M2, #141) — les règles, seules.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/models/echanges_view.dart';
import 'package:maison_du_miracle/models/message_gesture_rules.dart';

final DateTime _now = DateTime.utc(2026, 10, 6, 12);

GroupMessageView _message({
  bool mine = false,
  Duration age = Duration.zero,
  String? body = 'Amen',
  bool deleted = false,
  MessageDelivery delivery = MessageDelivery.sent,
}) =>
    GroupMessageView(
      id: 'm-1',
      groupId: 'g-1',
      body: body,
      origin: MessageOrigin.member,
      mine: mine,
      delivery: delivery,
      authorId: mine ? 'me' : 'peer',
      createdAt: _now.subtract(age),
      deleted: deleted,
    );

Set<MessageAction> _actions(
  GroupMessageView message, {
  bool isAdmin = false,
  bool canWrite = true,
}) =>
    availableMessageActions(
      message,
      isAdmin: isAdmin,
      canWrite: canWrite,
      now: _now,
    );

void main() {
  test('mon message, dans les 15 minutes : tout', () {
    expect(_actions(_message(mine: true, age: kMessageEditWindow)), {
      MessageAction.reply,
      MessageAction.copy,
      MessageAction.forward,
      MessageAction.edit,
      // « Infos du message » (M3, #142) : sur mes messages.
      MessageAction.info,
      MessageAction.deleteForMe,
      MessageAction.deleteForEveryone,
    });
  });

  test('modifier : pas au-delà de 15 minutes, jamais un média', () {
    final late =
        _message(mine: true, age: const Duration(minutes: 15, seconds: 1));
    expect(_actions(late), isNot(contains(MessageAction.edit)));
    expect(_actions(_message(mine: true, body: null)),
        isNot(contains(MessageAction.edit)));
  });

  test('supprimer pour tous : l\'auteur 2 jours, l\'administrateur toujours',
      () {
    final old = _message(mine: true, age: const Duration(days: 2, minutes: 1));
    expect(_actions(old), isNot(contains(MessageAction.deleteForEveryone)));
    expect(
      _actions(_message(mine: true, age: kDeleteForEveryoneWindow)),
      contains(MessageAction.deleteForEveryone),
    );

    final othersOld = _message(age: const Duration(days: 400));
    expect(
        _actions(othersOld), isNot(contains(MessageAction.deleteForEveryone)));
    expect(
      _actions(othersOld, isAdmin: true),
      contains(MessageAction.deleteForEveryone),
    );
  });

  test('le message d\'un autre : ni modifier, même administrateur', () {
    expect(_actions(_message(), isAdmin: true),
        isNot(contains(MessageAction.edit)));
  });

  test('supprimé : seulement pour moi ; ni réaction ni glissement', () {
    final deleted = _message(mine: true, deleted: true, body: null);
    expect(_actions(deleted, isAdmin: true), {MessageAction.deleteForMe});
    expect(canReactTo(deleted), isFalse);
    expect(canSwipeToReply(deleted, canWrite: true), isFalse);
  });

  test('lecture seule : ni répondre, ni modifier, ni glisser', () {
    final mine = _message(mine: true);
    expect(
        _actions(mine, canWrite: false), isNot(contains(MessageAction.reply)));
    expect(
        _actions(mine, canWrite: false), isNot(contains(MessageAction.edit)));
    expect(canSwipeToReply(mine, canWrite: false), isFalse);
  });

  test('un écho pas encore parti : copier, et rien d\'autre', () {
    final echo = _message(mine: true, delivery: MessageDelivery.sending);
    expect(_actions(echo, isAdmin: true), {MessageAction.copy});
    expect(canReactTo(echo), isFalse);
  });

  test('le jeu rapide est celui de WhatsApp, dans son ordre', () {
    expect(kQuickReactions, ['👍', '❤️', '😂', '😮', '😢', '🙏']);
  });
}
