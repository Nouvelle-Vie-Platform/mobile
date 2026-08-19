import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/repositories/group_messaging.dart';
import '../l10n/l10n_extension.dart';
import '../models/models.dart';
import '../router/app_router.dart';
import '../state/auth_providers.dart';
import '../state/group_providers.dart';
import '../state/sync_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_avatar.dart';
import '../widgets/app_card.dart';
import '../widgets/community/institution_avatar.dart';
import '../widgets/content_absence.dart';

/// Fiche d'un groupe — **inspiration Telegram**, migrée au réel : en-tête
/// immersif, description, en-tête **propriétaire** (une institution → tap vers sa
/// fiche, décision D23/7), effectif, et — pour un responsable — la file des
/// **demandes d'adhésion** à valider (décision D12).
///
/// Reçoit l'**identifiant** du groupe (jamais une copie figée) et le relit dans
/// la source de vérité : une rétractation le retire de l'écran ouvert.
class GroupInfoScreen extends ConsumerWidget {
  const GroupInfoScreen({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(groupByIdProvider(groupId));
    return Scaffold(
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const ContentAbsenceView(
          absence: ContentAbsence.notSynced,
        ),
        data: (group) {
          if (group == null) {
            return const ContentAbsenceView(
              absence: ContentAbsence.retracted,
            );
          }
          return _Body(group: group, groupId: groupId);
        },
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.group, required this.groupId});

  final Conversation group;
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final description = group.description;
    final isAdmin = group.role?.canModerate ?? false;
    final institution = group.institution;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _Header(group: group),
        const SizedBox(height: AppSpacing.lg),
        if (description != null && description.isNotEmpty) ...[
          _DescriptionCard(text: description),
          const SizedBox(height: AppSpacing.xl),
        ],
        // En-tête propriétaire institutionnel (décision 7) : tap → fiche.
        if (institution != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: _OwnerCard(institution: institution),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
        // Demandes d'adhésion à valider (responsables uniquement).
        if (isAdmin) ...[
          _PendingRequests(groupId: groupId),
          const SizedBox(height: AppSpacing.xl),
        ],
        _SectionTitle(l.groupMembers(group.memberCount ?? 0)),
        const SizedBox(height: AppSpacing.md),
        _MembersList(groupId: groupId),
        const SizedBox(height: AppSpacing.md),
        if (group.role != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: OutlinedButton.icon(
              onPressed: () => _leave(context, ref),
              icon: const Icon(Icons.logout),
              label: Text(l.groupLeave),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }

  Future<void> _leave(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref.read(groupMessagingProvider).leave(groupId);
      await ref.read(pullToRefreshProvider)();
      if (navigator.canPop()) navigator.pop();
    } on GroupWriteException {
      messenger.showSnackBar(SnackBar(content: Text(l.groupActionError)));
    }
  }
}

/// En-tête immersif au dégradé de marque : retour, grand logo, nom, effectif.
class _Header extends StatelessWidget {
  const _Header({required this.group});

  final Conversation group;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final topInset = MediaQuery.paddingOf(context).top;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(gradient: AppColors.gradientPrimary),
      padding: EdgeInsets.only(top: topInset, bottom: AppSpacing.xl),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => context.pop(),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: AppAvatar(name: group.name, size: 96),
          ),
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(
              group.name,
              textAlign: TextAlign.center,
              style: AppTypography.h3.copyWith(color: Colors.white),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l.groupMembers(group.memberCount ?? 0),
            style: AppTypography.body
                .copyWith(color: Colors.white.withValues(alpha: 0.85)),
          ),
        ],
      ),
    );
  }
}

class _DescriptionCard extends StatelessWidget {
  const _DescriptionCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.groupInfoAbout,
              style: AppTypography.caption.copyWith(
                color: palette.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(text, style: AppTypography.body),
          ],
        ),
      ),
    );
  }
}

/// L'identité de l'**institution propriétaire** — tap ouvre sa fiche (D23).
class _OwnerCard extends StatelessWidget {
  const _OwnerCard({required this.institution});

  final InstitutionProfile institution;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final palette = context.palette;
    final subtitle = institution.kind == GroupOwnerKind.officialAccount
        ? l.institutionOfficialAccount
        : l.institutionContributor;
    return AppCard(
      onTap: () => context.pushNamed(
        AppRoute.institutionProfile,
        pathParameters: {
          'kind': institutionKindSlug(institution.kind),
          'id': '${institution.id}',
        },
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          InstitutionAvatar(
            name: institution.name,
            avatarUrl: institution.avatarUrl,
            size: 44,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(institution.name, style: AppTypography.bodyStrong),
                Text(
                  subtitle,
                  style: AppTypography.caption
                      .copyWith(color: palette.textSecondary),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: palette.textSecondary),
        ],
      ),
    );
  }
}

/// La file des demandes d'adhésion — approuver / refuser (D12).
class _PendingRequests extends ConsumerWidget {
  const _PendingRequests({required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final requests =
        ref.watch(groupPendingRequestsProvider(groupId)).asData?.value ??
            const <GroupJoinRequest>[];
    if (requests.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(l.groupJoinRequestsTitle),
        const SizedBox(height: AppSpacing.md),
        for (final r in requests) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  const AppAvatar(name: '', size: 40),
                  const SizedBox(width: AppSpacing.md),
                  // Pas de nom de fidèle (ADR-0029) : identifiant abrégé, à
                  // réconcilier quand un nom voyagera.
                  Expanded(
                    child: Text(
                      _shortId(r.userId),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body,
                    ),
                  ),
                  IconButton(
                    tooltip: l.groupReject,
                    onPressed: () => _decide(context, ref, r, approve: false),
                    icon: const Icon(Icons.close),
                  ),
                  IconButton(
                    tooltip: l.groupApprove,
                    onPressed: () => _decide(context, ref, r, approve: true),
                    icon: const Icon(Icons.check),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }

  String _shortId(String userId) =>
      userId.length <= 8 ? userId : '${userId.substring(0, 8)}…';

  Future<void> _decide(
    BuildContext context,
    WidgetRef ref,
    GroupJoinRequest request, {
    required bool approve,
  }) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final messaging = ref.read(groupMessagingProvider);
    try {
      if (approve) {
        await messaging.approveJoinRequest(groupId, request.id);
      } else {
        await messaging.rejectJoinRequest(groupId, request.id);
      }
      await ref.read(pullToRefreshProvider)();
    } on GroupWriteException {
      messenger.showSnackBar(SnackBar(content: Text(l.groupActionError)));
    }
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Text(label, style: AppTypography.h5),
    );
  }
}

/// **La liste des membres** du groupe (PRD `messagerie-directe.md` D12) — nom via
/// `profiles`, avatar par initiales. Un tap ouvre la fiche membre (d'où part un
/// DM) ; ma propre ligne n'est pas navigable (pas de DM avec soi-même).
class _MembersList extends ConsumerWidget {
  const _MembersList({required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final me = ref.watch(authProvider).user?.id;
    final members =
        ref.watch(groupMembersListProvider(groupId)).asData?.value ??
            const <GroupMemberView>[];
    if (members.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (final m in members) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: AppCard(
              // Ma propre ligne : pas de tap (un DM relie deux personnes).
              onTap: m.userId == me
                  ? null
                  : () => context.pushNamed(
                        AppRoute.memberProfile,
                        extra: m,
                      ),
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  AppAvatar(name: m.name, size: 40),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      // Nom réel ; vide (profil pas encore synchronisé) → repli
                      // sur un identifiant abrégé, jamais un libellé inventé.
                      m.name.isNotEmpty ? m.name : _shortId(m.userId),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body,
                    ),
                  ),
                  if (m.role == GroupRole.leader ||
                      m.role == GroupRole.moderator)
                    Text(
                      m.role == GroupRole.leader
                          ? context.l10n.groupRoleLeader
                          : context.l10n.groupRoleModerator,
                      style: AppTypography.caption
                          .copyWith(color: palette.textSecondary),
                    ),
                  if (m.userId != me)
                    Icon(Icons.chevron_right, color: palette.textSecondary),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }

  String _shortId(String userId) =>
      userId.length <= 8 ? userId : '${userId.substring(0, 8)}…';
}
