import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/l10n_extension.dart';
import '../router/app_router.dart';
import '../state/repository_providers.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/community/community_header.dart';
import '../widgets/community/conversation_tile.dart';
import '../widgets/community/join_group_card.dart';

/// Hub **« Échanges »** : groupes et discussions réunis au même endroit.
///
/// La séparation par onglets pilules a disparu (décision D3). L'écran est fait
/// d'un **bandeau diagonal** ([CommunityHeader]), d'une rangée horizontale de
/// **groupes à rejoindre** (découverte, distincte des conversations — D6), puis
/// d'une **liste à plat** de conversations (groupes + messages privés mêlés,
/// triés par récence — D7). Aucun onglet, aucun FAB (le FAB central de la
/// coquille reste inchangé — D9), aucune icône d'appel (D8).
///
/// Le nom de fichier/classe reste `groups_screen` / `GroupsScreen` : la coquille
/// et les tests s'y réfèrent, et le renommer n'aurait apporté que du bruit.
class GroupsScreen extends ConsumerWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final conversations = ref.watch(conversationsProvider);
    final toJoin = ref.watch(groupsToJoinProvider);

    // Dégagement pour la barre de nav givrée (et son encoche) : la dernière
    // tuile doit pouvoir remonter au-dessus d'elle.
    final bottomInset =
        MediaQuery.paddingOf(context).bottom + AppSpacing.xxxl + AppSpacing.xl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CommunityHeader(
          onRequests: () => context.pushNamed(AppRoute.requests),
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.only(top: AppSpacing.lg, bottom: bottomInset),
            children: [
              // Rangée « groupes à rejoindre » — distincte des conversations.
              if (toJoin.isNotEmpty) ...[
                Padding(
                  padding: AppSpacing.screenPadding,
                  child: Text(l.echangesDiscover, style: AppTypography.h5),
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  height: JoinGroupCard.rowHeight,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: AppSpacing.screenPadding,
                    itemCount: toJoin.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: AppSpacing.md),
                    itemBuilder: (context, i) => JoinGroupCard(
                      group: toJoin[i],
                      // Le tap ouvre le profil de l'animateur (porte vers une
                      // conversation directe, D10).
                      onTap: () => context.pushNamed(
                        AppRoute.memberProfile,
                        extra: toJoin[i].host,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
              // Liste à plat des conversations.
              for (final c in conversations) ...[
                Padding(
                  padding: AppSpacing.screenPadding,
                  child: ConversationTile(
                    conversation: c,
                    onTap: () =>
                        context.pushNamed(AppRoute.groupChat, extra: c),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
