import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/l10n_extension.dart';
import '../models/chat_organization.dart';
import '../router/app_router.dart';
import '../state/echanges_providers.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_error_state.dart';
import '../widgets/brand_app_bar.dart';
import '../widgets/community/organizable_conversation_tile.dart';

/// **Mes discussions archivées** (#146, tranche M8) — ouvertes depuis la rangée
/// « Archivées (N) » de l'onglet Messages.
///
/// La même lecture que la liste principale (`conversationsProvider`), rangée par
/// `organizeConversations` : il n'y a pas de seconde requête, donc pas de
/// seconde vérité. Une discussion archivée **reste ici** quand un message y
/// arrive ; on la désarchive en la faisant glisser vers la gauche, ou par
/// l'appui long.
class ArchivedChatsScreen extends ConsumerWidget {
  const ArchivedChatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final me = ref.watch(echangesActorProvider);
    final conversations = ref.watch(conversationsProvider(me));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: BrandAppBar(title: l.chatArchivedTitle),
      body: SafeArea(
        child: conversations.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Padding(
            padding: AppSpacing.screenPadding,
            child: AppErrorState(
              message: l.echangesLoadError,
              onRetry: () => ref.invalidate(conversationsProvider(me)),
            ),
          ),
          data: (items) {
            final archived = organizeConversations(items).archived;
            if (archived.isEmpty) {
              return Padding(
                padding: AppSpacing.screenPadding,
                child: AppEmptyState(
                  icon: Icons.archive_outlined,
                  title: l.chatArchivedEmptyTitle,
                  message: l.chatArchivedEmpty,
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              itemCount: archived.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, i) => Padding(
                padding: AppSpacing.screenPadding,
                child: OrganizableConversationTile(
                  conversation: archived[i],
                  // #142 (M3) : « Ama écrit… » aussi aux archives.
                  showTyping: true,
                  actor: me,
                  onTap: () => context.pushNamed(
                    AppRoute.groupChat,
                    pathParameters: {'id': archived[i].groupId},
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
