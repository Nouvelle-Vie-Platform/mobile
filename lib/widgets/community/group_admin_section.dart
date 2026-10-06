import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/repositories/group_admin_client.dart';
import '../../l10n/l10n_extension.dart';
import '../../models/echanges_view.dart';
import '../../models/group_management.dart';
import '../../router/app_router.dart';
import '../../state/group_management_providers.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../app_avatar.dart';
import '../app_button.dart';
import '../app_card.dart';
import '../home_tab.dart';

// **Les gestes de la fiche d'un groupe** (#145) : rejoindre, demander,
// quitter, administrer. Écrits ici et non dans `group_info_screen.dart`, que
// d'autres tranches touchent : la fiche ne fait que poser ces widgets.
//
// Tout geste offert est un geste que le serveur accepte : les droits viennent
// de `GroupRights`, miroir des gardes ADR-0009.

/// Dit l'issue d'un geste qui n'a pas abouti. Rien sur un succès : c'est le
/// magasin, en se mettant à jour, qui le montre.
void showGroupActionOutcome(BuildContext context, GroupActionOutcome outcome) {
  if (outcome == GroupActionOutcome.done) return;
  final l = context.l10n;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        outcome == GroupActionOutcome.refused
            ? l.m6ActionRefused
            : l.m6ActionUnreachable,
      ),
    ),
  );
}

/// Les droits de l'acteur sur [group].
GroupRights rightsOf(GroupDetailView group) => GroupRights(
      myRole: group.myRole,
      isDirect: group.isDirect,
      joinPolicy: group.joinPolicy,
      isActive: group.isActive,
    );

/// **Rejoindre, demander, ajouter des membres, quitter** — selon mes droits.
class GroupMembershipActions extends ConsumerStatefulWidget {
  const GroupMembershipActions({
    super.key,
    required this.group,
    this.requestPending = false,
  });

  final GroupDetailView group;

  /// Ma demande d'adhésion est déjà en attente : on le dit au lieu d'offrir le
  /// geste une seconde fois.
  final bool requestPending;

  static const joinKey = ValueKey('group-join');
  static const requestKey = ValueKey('group-request-join');
  static const leaveKey = ValueKey('group-leave');
  static const addMembersKey = ValueKey('add-group-members');

  @override
  ConsumerState<GroupMembershipActions> createState() =>
      _GroupMembershipActionsState();
}

class _GroupMembershipActionsState
    extends ConsumerState<GroupMembershipActions> {
  bool _busy = false;
  bool _requested = false;

  Future<void> _run(
    Future<GroupActionOutcome> Function(GroupActions actions) gesture, {
    VoidCallback? onDone,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    final outcome = await gesture(ref.read(groupActionsProvider));
    if (!mounted) return;
    setState(() => _busy = false);
    if (outcome == GroupActionOutcome.done) {
      onDone?.call();
    } else {
      showGroupActionOutcome(context, outcome);
    }
  }

  Future<void> _leave() async {
    final l = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l.m6Leave),
        content: Text(l.m6LeaveConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(l.m6Cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(l.m6Leave),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(
      (actions) => actions.leave(widget.group.groupId),
      // Le fil et la fiche ne sont plus les miens : retour à la liste.
      onDone: () => context.goNamed(
        AppRoute.home,
        queryParameters: {'tab': HomeTab.community.name},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final rights = rightsOf(widget.group);
    final groupId = widget.group.groupId;
    final pending = widget.requestPending || _requested;

    final buttons = <Widget>[
      if (rights.canJoin)
        AppButton(
          key: GroupMembershipActions.joinKey,
          label: l.m6Join,
          icon: Icons.group_add_outlined,
          loading: _busy,
          onPressed: _busy ? null : () => _run((a) => a.join(groupId)),
        ),
      if (rights.canRequestToJoin && pending)
        Text(
          l.echangesJoinPending,
          textAlign: TextAlign.center,
          style: AppTypography.bodyStrong,
        )
      else if (rights.canRequestToJoin)
        AppButton(
          key: GroupMembershipActions.requestKey,
          label: l.m6RequestJoin,
          icon: Icons.how_to_reg_outlined,
          loading: _busy,
          onPressed: _busy
              ? null
              : () => _run(
                    (a) => a.requestToJoin(groupId),
                    onDone: () => setState(() => _requested = true),
                  ),
        ),
      if (rights.canAddMembers)
        AppButton(
          key: GroupMembershipActions.addMembersKey,
          label: l.m6AddMembers,
          icon: Icons.person_add_alt_1_outlined,
          variant: AppButtonVariant.outline,
          onPressed: () => context.pushNamed(
            AppRoute.addGroupMembers,
            pathParameters: {'id': groupId},
          ),
        ),
      if (rights.canLeave)
        AppButton(
          key: GroupMembershipActions.leaveKey,
          label: l.m6Leave,
          icon: Icons.logout,
          variant: AppButtonVariant.danger,
          onPressed: _busy ? null : _leave,
        ),
    ];
    if (buttons.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final button in buttons) ...[
            button,
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

/// **La file des demandes d'adhésion**, pour un animateur ou un modérateur.
/// Lue au réseau (`GET /groups/:id/join-requests`) — la collection synchronisée
/// ne porte pas le nom du demandeur. Illisible ou vide : la section se tait.
class GroupJoinRequestsSection extends ConsumerWidget {
  const GroupJoinRequestsSection({super.key, required this.group});

  final GroupDetailView group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!rightsOf(group).canDecideRequests) return const SizedBox.shrink();
    final requests =
        ref.watch(groupJoinRequestsProvider(group.groupId)).value ?? const [];
    if (requests.isEmpty) return const SizedBox.shrink();
    final l = context.l10n;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.m6PendingRequests, style: AppTypography.h5),
          const SizedBox(height: AppSpacing.md),
          for (final request in requests) ...[
            _JoinRequestTile(groupId: group.groupId, request: request),
            const SizedBox(height: AppSpacing.sm),
          ],
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

class _JoinRequestTile extends ConsumerStatefulWidget {
  const _JoinRequestTile({required this.groupId, required this.request});

  final String groupId;
  final PendingJoinRequestView request;

  @override
  ConsumerState<_JoinRequestTile> createState() => _JoinRequestTileState();
}

class _JoinRequestTileState extends ConsumerState<_JoinRequestTile> {
  bool _busy = false;

  Future<void> _decide({required bool approve}) async {
    setState(() => _busy = true);
    final outcome = await ref.read(groupActionsProvider).decideJoinRequest(
          widget.groupId,
          widget.request.id,
          approve: approve,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    showGroupActionOutcome(context, outcome);
    // Une décision (la mienne, ou celle d'un autre admin) sort la demande de
    // la file : on la relit dans tous les cas.
    ref.invalidate(groupJoinRequestsProvider(widget.groupId));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final palette = context.palette;
    final name = widget.request.displayName;
    final named = name != null && name.isNotEmpty;

    return AppCard(
      key: ValueKey('join-request-${widget.request.id}'),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          named
              ? AppAvatar(name: name, size: 40)
              : const AppAvatar.neutral(size: 40),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              named ? name : l.m6RequestUnnamed,
              style: named
                  ? AppTypography.bodyStrong
                  : AppTypography.body.copyWith(color: palette.textSecondary),
            ),
          ),
          TextButton(
            onPressed: _busy ? null : () => _decide(approve: false),
            child: Text(l.m6Reject),
          ),
          FilledButton(
            onPressed: _busy ? null : () => _decide(approve: true),
            child: Text(l.m6Approve),
          ),
        ],
      ),
    );
  }
}

/// **Les gestes sur un membre du roster** : lui écrire en privé, et — selon mes
/// droits — le nommer ou le retirer modérateur, le retirer du groupe.
///
/// « Message » n'est jamais offert sur ma propre ligne, ni dans un
/// tête-à-tête (on y est déjà).
class GroupMemberActions extends ConsumerWidget {
  const GroupMemberActions({
    super.key,
    required this.group,
    required this.member,
    required this.me,
  });

  final GroupDetailView group;
  final GroupMemberView member;
  final String? me;

  static ValueKey<String> messageKey(String userId) =>
      ValueKey('member-message-$userId');
  static ValueKey<String> menuKey(String userId) =>
      ValueKey('member-menu-$userId');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final rights = rightsOf(group);
    final isMe = member.userId == me;
    final canRole = rights.canChangeRole(
      targetRole: member.role,
      targetIsMe: isMe,
    );
    final canRemove = rights.canRemove(
      targetRole: member.role,
      targetIsMe: isMe,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isMe && !group.isDirect && me != null)
          IconButton(
            key: messageKey(member.userId),
            tooltip: l.memberMessage,
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () => context.pushNamed(
              AppRoute.directChat,
              pathParameters: {'id': member.userId},
            ),
          ),
        if (canRole || canRemove)
          PopupMenuButton<_MemberGesture>(
            key: menuKey(member.userId),
            tooltip: l.m6MemberOptions,
            onSelected: (gesture) => _apply(context, ref, gesture),
            itemBuilder: (_) => [
              if (canRole && member.role == 'moderator')
                PopupMenuItem(
                  value: _MemberGesture.demote,
                  child: Text(l.m6RemoveModerator),
                )
              else if (canRole)
                PopupMenuItem(
                  value: _MemberGesture.promote,
                  child: Text(l.m6MakeModerator),
                ),
              if (canRemove)
                PopupMenuItem(
                  value: _MemberGesture.remove,
                  child: Text(l.m6RemoveMember),
                ),
            ],
          ),
      ],
    );
  }

  Future<void> _apply(
    BuildContext context,
    WidgetRef ref,
    _MemberGesture gesture,
  ) async {
    final actions = ref.read(groupActionsProvider);
    final groupId = group.groupId;
    final GroupActionOutcome outcome;
    switch (gesture) {
      case _MemberGesture.promote:
        outcome = await actions.setRole(groupId, member.userId, 'moderator');
      case _MemberGesture.demote:
        outcome = await actions.setRole(groupId, member.userId, 'member');
      case _MemberGesture.remove:
        final l = context.l10n;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialog) => AlertDialog(
            title: Text(l.m6RemoveMember),
            content: Text(l.m6RemoveConfirm),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialog).pop(false),
                child: Text(l.m6Cancel),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialog).pop(true),
                child: Text(l.m6RemoveMember),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
        outcome = await actions.removeMember(groupId, member.userId);
    }
    if (context.mounted) {
      showGroupActionOutcome(context, outcome);
    }
  }
}

enum _MemberGesture { promote, demote, remove }
