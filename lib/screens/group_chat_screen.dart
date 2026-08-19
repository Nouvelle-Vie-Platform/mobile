import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../data/repositories/group_messaging.dart';
import '../l10n/l10n_extension.dart';
import '../models/models.dart';
import '../router/app_router.dart';
import '../state/group_providers.dart';
import '../state/sync_providers.dart';
import '../theme/app_spacing.dart';
import '../widgets/chat/chat_app_bar.dart';
import '../widgets/chat/chat_bubble.dart';
import '../widgets/chat/chat_date_pill.dart';
import '../widgets/chat/chat_info_banner.dart';
import '../widgets/chat/message_input_bar.dart';

/// Écran de discussion d'une [Conversation] — groupe (réel) ou message privé
/// (encore fictif).
///
/// **Migré au réel** pour les groupes : les messages viennent du magasin
/// (`groupMessagesProvider`), le composeur est **gardé** par la politique du
/// groupe ([Conversation.canPost]) et l'envoi passe par le **client d'écriture**
/// ([GroupMessaging]) puis un cycle de synchronisation — le réseau ne peint
/// jamais. La [Conversation] reçue par `extra` sert d'amorce ; l'écran **relit**
/// le groupe par identifiant ([groupByIdProvider]) pour tenir ses politiques et
/// mon rôle à jour (diffusion, verrou, désactivation, rétractation).
class GroupChatScreen extends ConsumerStatefulWidget {
  const GroupChatScreen({super.key, required this.conversation});

  final Conversation conversation;

  @override
  ConsumerState<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends ConsumerState<GroupChatScreen> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final seed = widget.conversation;
    final isGroup = seed.kind == ConversationKind.group;

    // **DM** : le fil est adressé par l'`userId` du pair. On le résout dans le
    // magasin (`directConversationProvider`) — `null` tant que rien n'est écrit
    // (création paresseuse). Après le premier envoi + sync, il apparaît et
    // l'écran se rebranche sur son `id` réel, sans que rien ne bouge à l'écran.
    final directUserId = isGroup ? null : seed.peerUserId;
    final resolvedDirect = directUserId == null
        ? null
        : ref.watch(directConversationProvider(directUserId)).asData?.value;

    // Relire le groupe dans la source de vérité (politiques, rôle, existence).
    // Pour un DM, la source est le fil direct résolu ; repli sur l'amorce.
    final live = isGroup
        ? ref.watch(groupByIdProvider(seed.id)).asData?.value ?? seed
        : (resolvedDirect ?? seed);

    // L'identifiant du fil dont on lit les messages : le groupe pour un groupe,
    // le fil direct résolu pour un DM. `null` tant qu'un DM naissant n'existe pas
    // → aucun message (état vide), et surtout aucun `GET /groups//messages`.
    final chatId = isGroup
        ? seed.id
        : (resolvedDirect?.id ?? (seed.id.isNotEmpty ? seed.id : null));

    final messages = chatId == null
        ? const AsyncValue<List<ChatMessage>>.data(<ChatMessage>[])
        : ref.watch(groupMessagesProvider(chatId));

    return Scaffold(
      appBar: ChatAppBar(
        title: live.name,
        subtitle: isGroup
            ? l.groupMembers(live.memberCount ?? live.members.length)
            : null,
        onTitleTap: () => isGroup
            ? context.pushNamed(AppRoute.groupInfo, extra: live.id)
            : (directUserId == null
                ? null
                : context.pushNamed(
                    AppRoute.memberProfile,
                    extra: GroupMemberView(
                      userId: directUserId,
                      name: live.name,
                    ),
                  )),
        actions: [
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => Center(child: Text(l.echangesError)),
              data: (list) => ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                children: [
                  ChatDatePill(label: l.chatToday),
                  const SizedBox(height: AppSpacing.md),
                  // Le choix bannière / bulle se lit sur le couple
                  // `(authorId, isSystem)` (ADR-0032) : un message système est une
                  // bannière ; un auteur retiré reste une **bulle**, sans nom.
                  for (final m in list)
                    if (m.system)
                      ChatInfoBanner(text: m.text)
                    else
                      // La bulle ne porte pas de nom d'auteur (le nom se lit dans
                      // la liste des membres, pas sur chaque message) : pas de tap
                      // vers une fiche depuis une bulle de groupe.
                      ChatBubble(message: m),
                ],
              ),
            ),
          ),
          _Composer(
            conversation: live,
            controller: _controller,
            onSend: _send,
            sending: _sending,
          ),
        ],
      ),
    );
  }

  /// Envoie un message : client d'écriture (idempotent, ADR-0018) puis cycle de
  /// synchronisation qui ramène le message. Le champ se vide à l'appel ; un échec
  /// le laisse dans le flux à retenter au prochain déclencheur (message perdu =
  /// désagrément, pas panne à afficher pendant une discussion).
  Future<void> _send(String body) async {
    if (_sending) return;
    setState(() => _sending = true);
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final messaging = ref.read(groupMessagingProvider);
    final seed = widget.conversation;
    try {
      if (seed.kind == ConversationKind.direct) {
        // DM : **toujours** adressé par l'`userId` du pair (`sendDirect` est
        // idempotent et get-or-create) — inutile de connaître l'`id` du fil, y
        // compris pour le tout premier message qui le crée.
        await messaging.sendDirect(
          seed.peerUserId!,
          body: body,
          clientMessageId: const Uuid().v4(),
          clientCreatedAt: DateTime.now().toUtc(),
        );
      } else {
        await messaging.sendMessage(
          seed.id,
          body: body,
          clientMessageId: const Uuid().v4(),
          clientCreatedAt: DateTime.now().toUtc(),
        );
      }
      await ref.read(pullToRefreshProvider)();
    } on GroupWriteException {
      messenger.showSnackBar(SnackBar(content: Text(l.groupActionError)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}

/// Le bas de l'écran : **composeur si je peux écrire**, sinon un bandeau lecture
/// seule qui dit pourquoi (diffusion / verrou / archive). En diffusion, un
/// non-admin ne voit **pas** de champ (décision D14) — le bandeau le remplace.
class _Composer extends StatelessWidget {
  const _Composer({
    required this.conversation,
    required this.controller,
    required this.onSend,
    required this.sending,
  });

  final Conversation conversation;
  final TextEditingController controller;
  final ValueChanged<String> onSend;
  final bool sending;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final reason = conversation.readOnlyReason;
    if (reason == null) {
      return MessageInputBar(
        hintText: l.chatMessageHint,
        controller: controller,
        onSend: sending ? null : onSend,
      );
    }
    final text = switch (reason) {
      GroupReadOnlyReason.broadcast => l.groupBroadcastBanner,
      GroupReadOnlyReason.writeLocked => l.groupWriteLockedBanner,
      GroupReadOnlyReason.deactivated => l.groupDeactivatedBanner,
      GroupReadOnlyReason.notMember => null,
    };
    if (text == null) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: _ReadOnlyBanner(text: text),
      ),
    );
  }
}

class _ReadOnlyBanner extends StatelessWidget {
  const _ReadOnlyBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline, size: 18, color: theme.hintColor),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(text, style: theme.textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
