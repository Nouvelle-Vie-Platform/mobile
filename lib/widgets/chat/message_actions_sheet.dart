import 'package:flutter/material.dart';

import '../../l10n/l10n_extension.dart';
import '../../models/message_gesture_rules.dart';
import 'message_reactions.dart';

/// Ce qu'a choisi la personne dans le menu d'appui long.
sealed class MessageMenuChoice {
  const MessageMenuChoice();
}

/// Un emoji — du jeu rapide, ou de « + ».
final class ReactionChoice extends MessageMenuChoice {
  const ReactionChoice(this.emoji);
  final String emoji;
}

/// Un geste du menu.
final class ActionChoice extends MessageMenuChoice {
  const ActionChoice(this.action);
  final MessageAction action;
}

/// **Le menu d'appui long sur une bulle** (M2, #141) : le jeu rapide de
/// réactions en tête (si [canReact]), puis les gestes que ce message admet —
/// [actions], calculés par `availableMessageActions` selon mes droits. Un geste
/// qui n'est pas permis **n'apparaît pas** : l'absence, pas le grisage.
Future<MessageMenuChoice?> showMessageActionsSheet(
  BuildContext context, {
  required Set<MessageAction> actions,
  required bool canReact,
  required String? myReaction,
}) {
  return showModalBottomSheet<MessageMenuChoice>(
    context: context,
    builder: (sheet) {
      final l = sheet.l10n;
      final error = Theme.of(sheet).colorScheme.error;

      Widget tile(MessageAction action, IconData icon, String label,
              {bool destructive = false}) =>
          ListTile(
            key: Key('message_action_${action.name}'),
            leading: Icon(icon, color: destructive ? error : null),
            title: Text(
              label,
              style: destructive ? TextStyle(color: error) : null,
            ),
            onTap: () => Navigator.of(sheet).pop(ActionChoice(action)),
          );

      return SafeArea(
        child: SingleChildScrollView(
          child: Column(
            key: const Key('message_actions_sheet'),
            mainAxisSize: MainAxisSize.min,
            children: [
              if (canReact) ...[
                QuickReactionsBar(
                  current: myReaction,
                  onPick: (emoji) =>
                      Navigator.of(sheet).pop(ReactionChoice(emoji)),
                  onMore: () async {
                    final emoji = await showMoreReactionsSheet(sheet);
                    if (emoji != null && sheet.mounted) {
                      Navigator.of(sheet).pop(ReactionChoice(emoji));
                    }
                  },
                ),
                const Divider(height: 1),
              ],
              for (final action in MessageAction.values)
                if (actions.contains(action))
                  switch (action) {
                    MessageAction.reply =>
                      tile(action, Icons.reply, l.chatActionReply),
                    MessageAction.copy =>
                      tile(action, Icons.copy_outlined, l.chatActionCopy),
                    MessageAction.forward =>
                      tile(action, Icons.forward_outlined, l.chatActionForward),
                    MessageAction.edit =>
                      tile(action, Icons.edit_outlined, l.chatActionEdit),
                    MessageAction.info =>
                      tile(action, Icons.info_outline, l.messageInfoAction),
                    MessageAction.deleteForMe => tile(
                        action,
                        Icons.delete_outline,
                        l.chatActionDeleteForMe,
                        destructive: true,
                      ),
                    MessageAction.deleteForEveryone => tile(
                        action,
                        Icons.delete_forever_outlined,
                        l.chatActionDeleteForEveryone,
                        destructive: true,
                      ),
                  },
            ],
          ),
        ),
      );
    },
  );
}
