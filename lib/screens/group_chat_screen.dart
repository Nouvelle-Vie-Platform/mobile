import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/l10n_extension.dart';
import '../models/models.dart';
import '../router/app_router.dart';
import '../state/repository_providers.dart';
import '../theme/app_spacing.dart';
import '../widgets/chat/chat_app_bar.dart';
import '../widgets/chat/chat_bubble.dart';
import '../widgets/chat/chat_date_pill.dart';
import '../widgets/chat/chat_info_banner.dart';
import '../widgets/chat/message_input_bar.dart';

/// Écran de discussion (messagerie) d'une [Conversation] — groupe ou message
/// privé.
///
/// Composé de briques modulaires : [ChatAppBar], [ChatDatePill],
/// [ChatInfoBanner], [ChatBubble] et [MessageInputBar].
///
/// **Aucune action d'appel** (décision D8) : la barre ne porte que le menu.
class GroupChatScreen extends ConsumerWidget {
  const GroupChatScreen({super.key, required this.conversation});

  final Conversation conversation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final messages = ref.watch(chatProvider(conversation));
    final isGroup = conversation.kind == ConversationKind.group;

    return Scaffold(
      appBar: ChatAppBar(
        title: conversation.name,
        // Le titre est **toujours** cliquable → une page détail :
        //  - groupe : fiche du groupe (effectif en sous-titre) ;
        //  - privé : fiche du membre (un utilisateur simple y a droit aussi).
        subtitle: isGroup ? l.groupMembers(conversation.members.length) : null,
        onTitleTap: () => isGroup
            ? context.pushNamed(AppRoute.groupInfo, extra: conversation)
            : context.pushNamed(AppRoute.memberProfile,
                extra: conversation.name),
        actions: [
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              children: [
                ChatDatePill(label: l.chatToday),
                const SizedBox(height: AppSpacing.md),
                // Le choix bannière / bulle est le **seul** point où l'origine
                // d'un message se décide. Au branchement il se lira sur le
                // couple `(authorId, isSystem)` et non sur un auteur absent :
                // `(null, false)` = auteur retiré, et c'est une **bulle**
                // (docs/messagerie-groupe.md §1 et §3).
                for (final m in messages)
                  if (m.system)
                    ChatInfoBanner(text: m.text)
                  else
                    ChatBubble(
                      message: m,
                      // Répondre en privé à un membre qui intervient : tap sur
                      // son nom/avatar → profil (uniquement dans un groupe, pour
                      // les messages reçus).
                      onAuthorTap: isGroup && !m.mine
                          ? () => context.pushNamed(
                                AppRoute.memberProfile,
                                extra: m.author,
                              )
                          : null,
                    ),
              ],
            ),
          ),
          MessageInputBar(hintText: l.chatMessageHint),
        ],
      ),
    );
  }
}
