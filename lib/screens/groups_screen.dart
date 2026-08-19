import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/repositories/group_messaging.dart';
import '../l10n/l10n_extension.dart';
import '../models/models.dart';
import '../router/app_router.dart';
import '../state/group_providers.dart';
import '../state/sync_providers.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_error_state.dart';
import '../widgets/app_list_skeleton.dart';
import '../widgets/community/community_header.dart';
import '../widgets/community/conversation_tile.dart';
import '../widgets/community/join_group_card.dart';

/// Hub **« Échanges »** : groupes et discussions réunis au même endroit.
///
/// **Migré du fictif au réel** (groupes officiels) : les conversations et les
/// groupes à rejoindre viennent désormais du **magasin** (`StreamProvider`,
/// `AsyncValue`), remplis par la synchronisation. L'UI construite lors de la
/// refonte est conservée — [CommunityHeader], [ConversationTile], [JoinGroupCard]
/// —, seule la source change, et la rangée de découverte est **câblée aux vrais
/// groupes publics** (décision D13).
///
/// Le nom de fichier/classe reste `groups_screen` / `GroupsScreen` : la coquille
/// et les tests s'y réfèrent.
class GroupsScreen extends ConsumerWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final conversations = ref.watch(conversationsProvider);
    final toJoin = ref.watch(groupsToJoinProvider);

    // Dégagement pour la barre de nav givrée (et son encoche).
    final bottomInset =
        MediaQuery.paddingOf(context).bottom + AppSpacing.xxxl + AppSpacing.xl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CommunityHeader(
          onRequests: () => context.pushNamed(AppRoute.requests),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: ref.read(pullToRefreshProvider),
            child: conversations.when(
              loading: () => const AppListSkeleton(),
              error: (_, __) => ListView(
                children: [
                  AppErrorState(
                    message: l.echangesError,
                    onRetry: () => ref.invalidate(conversationsProvider),
                  ),
                ],
              ),
              data: (list) => ListView(
                padding:
                    EdgeInsets.only(top: AppSpacing.lg, bottom: bottomInset),
                children: [
                  // Rangée « groupes à rejoindre » — distincte des conversations.
                  ...toJoin.maybeWhen(
                    orElse: () => const <Widget>[],
                    data: (groups) => groups.isEmpty
                        ? const []
                        : _discoverRow(context, ref, groups),
                  ),
                  // Liste à plat des conversations.
                  if (list.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xxl),
                      child: AppEmptyState(title: l.echangesEmpty),
                    )
                  else
                    for (final c in list) ...[
                      Padding(
                        padding: AppSpacing.screenPadding,
                        child: ConversationTile(
                          conversation: c,
                          onTap: () => context.pushNamed(
                            AppRoute.groupChat,
                            extra: c,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _discoverRow(
    BuildContext context,
    WidgetRef ref,
    List<DiscoverGroup> groups,
  ) {
    return [
      Padding(
        padding: AppSpacing.screenPadding,
        child: Text(context.l10n.echangesDiscover, style: AppTypography.h5),
      ),
      const SizedBox(height: AppSpacing.md),
      SizedBox(
        height: JoinGroupCard.rowHeight,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: AppSpacing.screenPadding,
          itemCount: groups.length,
          separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
          itemBuilder: (context, i) => JoinGroupCard(
            group: groups[i],
            // Le tap ouvre la fiche du groupe (consultable avant de rejoindre).
            onTap: () =>
                context.pushNamed(AppRoute.groupInfo, extra: groups[i].id),
            onJoin: () => _act(context, ref, groups[i], request: false),
            onRequest: () => _act(context, ref, groups[i], request: true),
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.xl),
    ];
  }

  /// Rejoindre / demander, puis déclencher un cycle de synchronisation pour que
  /// le magasin ramène l'appartenance ou la demande — le réseau ne peint jamais.
  Future<void> _act(
    BuildContext context,
    WidgetRef ref,
    DiscoverGroup group, {
    required bool request,
  }) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final messaging = ref.read(groupMessagingProvider);
    try {
      if (request) {
        await messaging.requestToJoin(group.id);
      } else {
        await messaging.join(group.id);
      }
      await ref.read(pullToRefreshProvider)();
      messenger.showSnackBar(
        SnackBar(content: Text(request ? l.groupRequestSent : l.groupJoined)),
      );
    } on GroupWriteException {
      messenger.showSnackBar(SnackBar(content: Text(l.groupActionError)));
    }
  }
}
