import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/messaging/group_arranger.dart';
import '../../l10n/l10n_extension.dart';
import '../../models/chat_organization.dart';
import '../../models/echanges_view.dart';
import '../../state/chat_organization_providers.dart';
import '../../state/echanges_providers.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import 'conversation_tile.dart';

/// Ce qu'on peut faire d'une discussion depuis la liste (#146, tranche M8).
enum ConversationAction { archive, unarchive, pin, unpin, markRead }

/// **Une tuile de conversation qu'on peut ranger** : appui long → le menu
/// (Archiver, Épingler, Marquer comme lu), glissement vers la gauche →
/// archiver (ou désarchiver, dans la liste des archives).
///
/// ## Le glissement ne prend que ce qui commence sur la tuile
///
/// La page Échanges se balaie d'un onglet à l'autre (#148, `TabBarView`). Le
/// [Dismissible] pose son propre reconnaisseur **sur la tuile** : un glissement
/// qui commence sur elle est à lui (l'arène des gestes donne la main au plus
/// profond), un glissement qui commence ailleurs — le bandeau, la rangée de
/// découverte, l'espace entre les tuiles, une liste vide — reste au balayage
/// d'onglet. Il n'écoute que la gauche (`endToStart`) : un glissement vers la
/// droite n'a rien à faire sur une tuile.
///
/// Le [Dismissible] ne retire pas la tuile lui-même (`confirmDismiss` rend
/// `false`) : c'est le magasin qui la retire de la liste, une fois le rangement
/// posé. Rendre `true` exigerait que la tuile quitte l'arbre dans la même image,
/// ce qu'un flux asynchrone ne garantit pas.
class OrganizableConversationTile extends ConsumerWidget {
  const OrganizableConversationTile({
    super.key,
    required this.conversation,
    required this.onTap,
    this.typingLabel,
  });

  final ConversationView conversation;
  final VoidCallback onTap;

  /// #142 (M3) : « Ama écrit… », passé à la tuile à la place de l'aperçu.
  final String? typingLabel;

  /// La clé du [Dismissible] d'une conversation — ce qu'un test fait glisser.
  static Key dismissKeyOf(String groupId) => ValueKey('dismiss-$groupId');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final palette = context.palette;
    final swipeArchives = !conversation.archived;

    return Dismissible(
      key: dismissKeyOf(conversation.groupId),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        await runConversationAction(
          context,
          ref,
          conversation,
          swipeArchives
              ? ConversationAction.archive
              : ConversationAction.unarchive,
        );
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        decoration: BoxDecoration(
          color: palette.primary,
          borderRadius: AppRadius.card,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              swipeArchives ? Icons.archive_outlined : Icons.unarchive_outlined,
              color: Colors.white,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              swipeArchives ? l.chatArchive : l.chatUnarchive,
              style: AppTypography.bodyStrong.copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
      child: GestureDetector(
        onLongPress: () async {
          final action = await showConversationActions(context, conversation);
          if (action == null || !context.mounted) return;
          await runConversationAction(context, ref, conversation, action);
        },
        child: ConversationTile(
          conversation: conversation,
          onTap: onTap,
          typingLabel: typingLabel,
        ),
      ),
    );
  }
}

/// **Le menu d'une discussion** (appui long). Rend l'action choisie, ou `null`.
Future<ConversationAction?> showConversationActions(
  BuildContext context,
  ConversationView conversation,
) {
  final l = context.l10n;
  return showModalBottomSheet<ConversationAction>(
    context: context,
    builder: (sheet) {
      Widget item(ConversationAction action, IconData icon, String label) =>
          ListTile(
            key: ValueKey('conversation_action_${action.name}'),
            leading: Icon(icon),
            title: Text(label),
            onTap: () => Navigator.of(sheet).pop(action),
          );
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                conversation.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodyStrong,
              ),
            ),
            if (conversation.archived)
              item(
                ConversationAction.unarchive,
                Icons.unarchive_outlined,
                l.chatUnarchive,
              )
            else
              item(
                ConversationAction.archive,
                Icons.archive_outlined,
                l.chatArchive,
              ),
            if (conversation.pinned)
              item(ConversationAction.unpin, Icons.push_pin_outlined,
                  l.chatUnpin)
            else
              item(ConversationAction.pin, Icons.push_pin, l.chatPin),
            if (conversation.unreadCount > 0)
              item(
                ConversationAction.markRead,
                Icons.mark_chat_read_outlined,
                l.chatMarkRead,
              ),
          ],
        ),
      );
    },
  );
}

/// **Exécute une action** sur une discussion, et dit ce qui doit l'être (la
/// borne des trois épingles, un refus).
Future<void> runConversationAction(
  BuildContext context,
  WidgetRef ref,
  ConversationView conversation,
  ConversationAction action,
) async {
  final l = context.l10n;
  final messenger = ScaffoldMessenger.maybeOf(context);
  final actor = ref.read(echangesActorProvider);
  final groupId = conversation.groupId;

  if (action == ConversationAction.markRead) {
    final newest =
        await ref.read(chatOrganizationDaoProvider).newestMessageOf(groupId);
    if (newest == null) return;
    await ref.read(groupReadAdvancerProvider).advance(
          groupId: groupId,
          messageId: newest.id,
          messageCreatedAt: newest.createdAt,
        );
    return;
  }

  final arranger = ref.read(groupArrangerProvider(actor));
  if (arranger == null) return;
  final result = switch (action) {
    ConversationAction.archive => await arranger.archive(groupId, value: true),
    ConversationAction.unarchive =>
      await arranger.archive(groupId, value: false),
    ConversationAction.pin => await arranger.pin(groupId, value: true),
    ConversationAction.unpin => await arranger.pin(groupId, value: false),
    ConversationAction.markRead => ArrangeResult.unchanged,
  };

  final message = switch (result) {
    ArrangeResult.pinLimit => l.chatPinLimit(kMaxPinnedChats),
    ArrangeResult.rejected => l.chatArrangeFailed,
    ArrangeResult.done when action == ConversationAction.archive =>
      l.chatArchivedNotice,
    _ => null,
  };
  if (message == null || messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        action:
            result == ArrangeResult.done && action == ConversationAction.archive
                ? SnackBarAction(
                    label: l.chatUndo,
                    onPressed: () => arranger.archive(groupId, value: false),
                  )
                : null,
      ),
    );
}
