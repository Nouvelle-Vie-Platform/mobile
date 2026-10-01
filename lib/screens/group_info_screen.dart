import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/l10n_extension.dart';
import '../models/echanges_view.dart';
import '../router/app_router.dart';
import '../state/echanges_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_avatar.dart';
import '../widgets/app_card.dart';
import '../widgets/content_absence.dart';

/// Fiche d'un groupe — **inspiration Telegram** (D15) : en-tête immersif (logo,
/// nom, effectif), puis description, puis la liste des membres.
///
/// Taper un membre ouvre sa **fiche**, d'où l'on démarre une conversation privée
/// (D10).
///
/// ## Elle reçoit un identifiant et résout depuis le magasin (#96)
///
/// L'ancienne version recevait un `Conversation` en `extra` et lisait ses champs
/// fictifs. L'effectif, la description et les membres viennent désormais des
/// collections répliquées : `groups` (nom, description, effectif compté par le
/// serveur), `group_members` (le roster) et `profiles` (les noms).
///
/// ## La section « Médias partagés » **a disparu de la tranche 1**
///
/// C'étaient des `picsum.photos` tirées du nom du groupe. Le serveur ne sert aucune
/// pièce jointe aujourd'hui — elles n'existent **nulle part**, des deux côtés, et
/// le PRD d'ADR-0006 les exclut nommément de la V1. La section reviendra en tranche
/// 3, remplie des **images du fil** ; garder la place en l'habillant d'images
/// inventées aurait promis une fonctionnalité qui n'existe pas.
class GroupInfoScreen extends ConsumerWidget {
  const GroupInfoScreen({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    // L'acteur est lu ici et passé en clé : voir l'en-tête
    // d'`echanges_providers.dart`.
    final detail = ref.watch(
      groupDetailProvider(
          (actor: ref.watch(echangesActorProvider), id: groupId)),
    );

    return detail.when(
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
      data: (group) {
        // Le magasin ne connaît pas cet identifiant : une **absence**, pas une
        // erreur. On n'éjecte pas le fidèle de l'écran qu'il a ouvert.
        if (group == null) {
          return const Scaffold(
            body: ContentAbsenceView(absence: ContentAbsence.notSynced),
          );
        }
        return Scaffold(body: _Body(group: group));
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.group});

  final GroupDetailView group;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final description = group.description;
    final host = group.hostName;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _Header(group: group),
        const SizedBox(height: AppSpacing.lg),
        if (host != null && host.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(
              l.echangesHostedBy(host),
              style: AppTypography.body
                  .copyWith(color: context.palette.textSecondary),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (description != null && description.isNotEmpty) ...[
          _DescriptionCard(text: description),
          const SizedBox(height: AppSpacing.xl),
        ],
        // « Pas de contenu, pas de section » : un roster que la synchronisation
        // n'a pas encore ramené ne laisse pas un titre suivi du vide.
        if (group.members.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(
              l.groupMembers(group.members.length),
              style: AppTypography.h5,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final member in group.members) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: _MemberTile(member: member),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }
}

/// En-tête immersif au dégradé de marque : retour, grand logo, nom, effectif.
class _Header extends StatelessWidget {
  const _Header({required this.group});

  final GroupDetailView group;

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
            child: AppAvatar(name: group.title, size: 96),
          ),
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(
              group.title,
              textAlign: TextAlign.center,
              style: AppTypography.h3.copyWith(color: Colors.white),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          // L'effectif vient du **serveur** (`memberCount`, membres actifs) et non
          // de la longueur du roster : ce roster-là n'arrive que pour les groupes
          // dont je suis membre, et un groupe à rejoindre afficherait « 0 membre ».
          Text(
            l.groupMembers(group.memberCount),
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

/// Une ligne du roster.
///
/// **Un membre dont `profiles` n'a pas encore livré le nom se rend quand même**,
/// avec un avatar neutre : la jointure est tolérante, et l'absence s'affiche comme
/// une absence. Sa fiche reste atteignable — c'est un identifiant valide.
class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.member});

  final GroupMemberView member;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final name = member.displayName;
    return AppCard(
      onTap: () => context.pushNamed(
        AppRoute.memberProfile,
        pathParameters: {'id': member.userId},
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          if (name == null || name.isEmpty)
            const AppAvatar.neutral(size: 44)
          else
            AppAvatar(name: name, size: 44),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              // Jamais d'« Utilisateur inconnu » : le nom manquant laisse la ligne
              // au libellé du rôle, qui est un fait.
              name == null || name.isEmpty ? _roleLabel(context, member) : name,
              style: AppTypography.bodyStrong,
            ),
          ),
          if (name != null && name.isNotEmpty && member.role != 'member')
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: Text(
                _roleLabel(context, member),
                style: AppTypography.caption
                    .copyWith(color: palette.textSecondary),
              ),
            ),
          Icon(Icons.chevron_right, color: palette.textSecondary),
        ],
      ),
    );
  }

  /// Le rôle, traduit. Un rôle **inconnu** rend le libellé générique : le serveur
  /// peut en ajouter un, et une chaîne brute à l'écran se lirait comme une donnée
  /// perdue.
  static String _roleLabel(BuildContext context, GroupMemberView member) {
    final l = context.l10n;
    return switch (member.role) {
      'leader' => l.groupRoleLeader,
      'moderator' => l.groupRoleModerator,
      _ => l.groupRoleMember,
    };
  }
}
