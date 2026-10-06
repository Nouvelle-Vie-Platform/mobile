import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/group_message_sender.dart';
import '../l10n/l10n_extension.dart';
import '../models/echanges_view.dart';
import '../state/echanges_providers.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/chat/chat_app_bar.dart';
import '../widgets/chat/chat_bubble.dart';
import '../widgets/chat/message_input_bar.dart';
import '../widgets/content_absence.dart';
import 'group_chat_screen.dart';

/// **La discussion privée avec une personne** (#145, décision 8) — qu'elle
/// existe déjà ou non.
///
/// Ouverte depuis « Nouvelle discussion », depuis la fiche d'un membre et
/// depuis la liste des membres d'un groupe. Elle reçoit **la personne**, pas un
/// groupe, parce que c'est exactement ce que l'appelant sait :
///
/// - **le tête-à-tête existe** (le magasin a le groupe direct et nos deux
///   appartenances) → c'est le fil ordinaire, [GroupChatScreen], sans détour ;
/// - **il n'existe pas encore** → un fil vide et la barre de saisie. Le premier
///   message part par `POST /groups/direct/:targetUserId/messages`, qui crée la
///   discussion au passage (get-or-create côté serveur). Son écho vit sous la
///   clé [directThreadKey] et paraît ici aussitôt, « en cours » ; quand le
///   groupe direct arrive au magasin (canal `users/{id}` ou synchronisation),
///   cet écran **devient** le fil ordinaire, et la ligne serveur — même
///   `clientMessageId` — remplace l'écho.
///
/// Le serveur ne laisse **démarrer** une discussion qu'avec une personne qui
/// partage un groupe avec moi ; on n'arrive ici que depuis une liste qui le
/// garantit déjà (mes contacts, un roster, une fiche de co-membre). Un refus
/// quand même (le groupe commun vient d'être quitté) laisse l'écho « pas
/// parti », comme tout envoi refusé.
class DirectChatScreen extends ConsumerWidget {
  const DirectChatScreen({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final profile = ref.watch(
      memberProfileProvider(
        (actor: ref.watch(echangesActorProvider), id: userId),
      ),
    );

    return profile.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => Scaffold(
        appBar: AppBar(title: Text(l.communityTitle)),
        body: Center(
          child: Padding(
            padding: AppSpacing.screenPadding,
            child: Text(l.echangesLoadError, textAlign: TextAlign.center),
          ),
        ),
      ),
      data: (member) {
        final direct = member?.directGroupId;
        if (direct != null) {
          // La clé force un état neuf : l'écran d'attente cède la place au fil
          // ordinaire, qui calcule sa fenêtre et sa lecture depuis le début.
          return GroupChatScreen(key: ValueKey(direct), groupId: direct);
        }
        if (member == null) {
          return const Scaffold(
            body: ContentAbsenceView(absence: ContentAbsence.notSynced),
          );
        }
        return _FirstMessage(member: member);
      },
    );
  }
}

/// Le tête-à-tête **pas encore commencé** : l'écho du premier message, et la
/// barre de saisie.
class _FirstMessage extends ConsumerStatefulWidget {
  const _FirstMessage({required this.member});

  final MemberProfileView member;

  @override
  ConsumerState<_FirstMessage> createState() => _FirstMessageState();
}

class _FirstMessageState extends ConsumerState<_FirstMessage> {
  final TextEditingController _controller = TextEditingController();

  String get _threadKey => directThreadKey(widget.member.userId);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send(String text) => ref
      .read(groupMessageComposerProvider)
      .send(groupId: _threadKey, body: text);

  Future<void> _onFailedTap(GroupMessageView message) async {
    final l = context.l10n;
    final choice = await showModalBottomSheet<bool>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.refresh),
              title: Text(l.chatRetry),
              onTap: () => Navigator.of(sheet).pop(true),
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: Theme.of(sheet).colorScheme.error,
              ),
              title: Text(l.chatDiscard),
              onTap: () => Navigator.of(sheet).pop(false),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    final composer = ref.read(groupMessageComposerProvider);
    // Même clé d'idempotence : le serveur reconnaît un premier envoi qui avait
    // abouti, et ne crée ni second fil ni second message.
    if (choice) {
      await composer.retry(message.id);
    } else {
      await composer.discard(message.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final palette = context.palette;
    final echoes = ref.watch(
      groupThreadProvider((
        actor: ref.watch(echangesActorProvider),
        id: _threadKey,
        limit: kThreadWindow,
      )),
    );
    final messages = echoes.value ?? const <GroupMessageView>[];

    return Scaffold(
      appBar: ChatAppBar(title: widget.member.displayName ?? ''),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? Center(
                    child: Padding(
                      padding: AppSpacing.screenPadding,
                      child: Text(
                        l.m6DirectFirstMessage,
                        textAlign: TextAlign.center,
                        style: AppTypography.body
                            .copyWith(color: palette.textSecondary),
                      ),
                    ),
                  )
                : ListView(
                    reverse: true,
                    padding: AppSpacing.screenPadding,
                    children: [
                      for (final m in messages.reversed)
                        ChatBubble(
                          key: ValueKey(m.id),
                          message: m,
                          onFailedTap: () => _onFailedTap(m),
                        ),
                    ],
                  ),
          ),
          MessageInputBar(
            hintText: l.chatMessageHint,
            controller: _controller,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}
