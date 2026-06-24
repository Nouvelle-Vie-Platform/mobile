import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/l10n_extension.dart';
import '../models/models.dart';
import '../router/app_router.dart';
import '../state/repository_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_avatar.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/cards/group_tile.dart';
import '../widgets/cards/prayer_request_card.dart';

/// Onglet « Communauté » : hub à trois sections — Groupes, Inbox, Requêtes.
///
/// L'onglet courant est un état local (préservé entre reconstructions).
class GroupsScreen extends ConsumerStatefulWidget {
  const GroupsScreen({super.key});

  @override
  ConsumerState<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends ConsumerState<GroupsScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Text(l.communityTitle, style: AppTypography.h2),
          ),
          Padding(
            padding: AppSpacing.screenPadding,
            child: _PillTabs(
              labels: [
                l.navGroups,
                l.communityTabInbox,
                l.communityTabRequests,
              ],
              selected: _tab,
              onSelect: (i) => setState(() => _tab = i),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(child: _content(_tab)),
        ],
      ),
    );
  }

  Widget _content(int tab) {
    switch (tab) {
      case 1:
        return const _InboxTab();
      case 2:
        return const _RequestsTab();
      default:
        return const _GroupsTab();
    }
  }
}

/// Onglets en « pilules » : teal de marque quand actif, contour léger sinon.
class _PillTabs extends StatelessWidget {
  const _PillTabs({
    required this.labels,
    required this.selected,
    required this.onSelect,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.sm),
          Expanded(child: _pill(palette, labels[i], i)),
        ],
      ],
    );
  }

  Widget _pill(AppPalette palette, String label, int index) {
    final selectedTab = index == selected;
    return GestureDetector(
      onTap: () => onSelect(index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: selectedTab ? AppColors.secondary : palette.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: selectedTab ? null : Border.all(color: palette.border),
          boxShadow: selectedTab
              ? [
                  BoxShadow(
                    color: AppColors.secondary.withValues(alpha: 0.30),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: AppTypography.bodyStrong.copyWith(
              color: selectedTab ? Colors.white : palette.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Section « Groupes » : liste des groupes communautaires.
class _GroupsTab extends ConsumerWidget {
  const _GroupsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(groupsProvider);
    return ListView(
      padding: _tabListPadding(context),
      children: [
        for (final g in groups) ...[
          GroupTile(
            group: g,
            onTap: () => context.pushNamed(AppRoute.groupChat, extra: g),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        const SizedBox(height: AppSpacing.sm),
        AppButton(label: context.l10n.groupsDiscoverMore, onPressed: () {}),
      ],
    );
  }
}

/// Marge des listes d'onglets, avec dégagement bas pour la barre givrée.
EdgeInsets _tabListPadding(BuildContext context) => EdgeInsets.fromLTRB(
      AppSpacing.lg,
      0,
      AppSpacing.lg,
      MediaQuery.paddingOf(context).bottom + AppSpacing.xl,
    );

/// Section « Inbox » : conversations (groupes) avec aperçu du dernier message.
class _InboxTab extends ConsumerWidget {
  const _InboxTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(groupsProvider);
    return ListView(
      padding: _tabListPadding(context),
      children: [
        for (final g in groups) ...[
          _ConversationTile(
            group: g,
            onTap: () => context.pushNamed(AppRoute.groupChat, extra: g),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

class _ConversationTile extends ConsumerWidget {
  const _ConversationTile({required this.group, this.onTap});

  final CommunityGroup group;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final messages = ref.watch(chatProvider(group));
    final last = messages.isNotEmpty ? messages.last : null;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          AppAvatar(name: group.name, size: 48),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyStrong,
                ),
                const SizedBox(height: 2),
                Text(
                  last?.text ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption
                      .copyWith(color: palette.textSecondary),
                ),
              ],
            ),
          ),
          if (last != null) ...[
            const SizedBox(width: AppSpacing.sm),
            Text(
              last.time,
              style:
                  AppTypography.caption.copyWith(color: palette.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

/// Section « Requêtes » : requêtes de prière + nouvelle requête.
class _RequestsTab extends ConsumerWidget {
  const _RequestsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prayers = ref.watch(prayersProvider);
    return ListView(
      padding: _tabListPadding(context),
      children: [
        for (final p in prayers) ...[
          PrayerRequestCard(request: p),
          const SizedBox(height: AppSpacing.md),
        ],
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: context.l10n.prayersNewRequest,
          icon: Icons.add,
          onPressed: () => context.pushNamed(AppRoute.newRequest),
        ),
      ],
    );
  }
}
