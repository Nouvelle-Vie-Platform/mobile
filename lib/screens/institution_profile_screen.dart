import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/l10n_extension.dart';
import '../models/models.dart';
import '../router/app_router.dart';
import '../state/group_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_card.dart';
import '../widgets/community/institution_avatar.dart';
import '../widgets/content_absence.dart';

/// **La fiche d'une institution** (compte officiel / intervenant) — décision D23,
/// un écran **nouveau et dédié**, distinct de la fiche membre.
///
/// Alimenté par les collections **déjà répliquées** `official_accounts` /
/// `contributors` (identité) et par les groupes qu'elle possède. Atteint depuis
/// l'en-tête propriétaire d'un groupe institutionnel (décision 7).
///
/// **Partiel, à compléter** : la section « ses annonces / contenus » du cadrage
/// D23 n'est pas encore câblée (annonces via `announcements.accountId`, contenus
/// via `teachings.contributorId`) — signalé comme reste-à-faire.
class InstitutionProfileScreen extends ConsumerWidget {
  const InstitutionProfileScreen({
    super.key,
    required this.kind,
    required this.id,
  });

  final GroupOwnerKind kind;
  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ref_ = (kind: kind, id: id);
    final profile = ref.watch(institutionProfileProvider(ref_));
    return Scaffold(
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const ContentAbsenceView(
          absence: ContentAbsence.notSynced,
        ),
        data: (institution) {
          if (institution == null) {
            return const ContentAbsenceView(
              absence: ContentAbsence.notSynced,
            );
          }
          return _Body(institution: institution);
        },
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.institution});

  final InstitutionProfile institution;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final description = institution.description;
    final groups = ref
            .watch(
              institutionGroupsProvider(
                (kind: institution.kind, id: institution.id),
              ),
            )
            .asData
            ?.value ??
        const <Conversation>[];

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _Header(institution: institution),
        const SizedBox(height: AppSpacing.lg),
        if (description != null && description.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(description, style: AppTypography.body),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
        if (groups.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(l.institutionGroupsTitle, style: AppTypography.h5),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final g in groups) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: _GroupTile(group: g),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.institution});

  final InstitutionProfile institution;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final topInset = MediaQuery.paddingOf(context).top;
    final subtitle = institution.kind == GroupOwnerKind.officialAccount
        ? l.institutionOfficialAccount
        : l.institutionContributor;
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
            child: InstitutionAvatar(
              name: institution.name,
              avatarUrl: institution.avatarUrl,
              size: 96,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(
              institution.name,
              textAlign: TextAlign.center,
              style: AppTypography.h3.copyWith(color: Colors.white),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle,
            style: AppTypography.body
                .copyWith(color: Colors.white.withValues(alpha: 0.85)),
          ),
        ],
      ),
    );
  }
}

class _GroupTile extends StatelessWidget {
  const _GroupTile({required this.group});

  final Conversation group;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AppCard(
      onTap: () => context.pushNamed(AppRoute.groupInfo, extra: group.id),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Icon(Icons.groups_outlined, color: palette.textSecondary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              group.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodyStrong,
            ),
          ),
          Icon(Icons.chevron_right, color: palette.textSecondary),
        ],
      ),
    );
  }
}
