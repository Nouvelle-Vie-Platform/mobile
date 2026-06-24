import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n_extension.dart';
import '../models/models.dart';
import '../state/repository_providers.dart';
import '../theme/app_spacing.dart';
import '../widgets/chat/chat_app_bar.dart';
import '../widgets/chat/chat_bubble.dart';
import '../widgets/chat/chat_date_pill.dart';
import '../widgets/chat/chat_info_banner.dart';
import '../widgets/chat/message_input_bar.dart';

/// Écran de discussion de groupe (messagerie).
///
/// Composé de briques modulaires : [ChatAppBar], [ChatDatePill],
/// [ChatInfoBanner], [ChatBubble] et [MessageInputBar].
class GroupChatScreen extends ConsumerWidget {
  const GroupChatScreen({super.key, required this.group});

  final CommunityGroup group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final messages = ref.watch(chatProvider(group));

    return Scaffold(
      appBar: ChatAppBar(
        title: group.name,
        subtitle: l.groupMembers(group.members),
        actions: [
          IconButton(icon: const Icon(Icons.call_outlined), onPressed: () {}),
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
                for (final m in messages)
                  if (m.system)
                    ChatInfoBanner(text: m.text)
                  else
                    ChatBubble(message: m),
              ],
            ),
          ),
          MessageInputBar(hintText: l.chatMessageHint),
        ],
      ),
    );
  }
}
