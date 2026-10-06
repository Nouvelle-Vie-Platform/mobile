import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/l10n_extension.dart';
import '../models/echanges_view.dart';
import '../router/app_router.dart';
import '../state/echanges_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_avatar.dart';
import '../widgets/app_button.dart';
import '../widgets/content_absence.dart';

/// Fiche détail d'un **membre** — le pendant, pour une personne, de la fiche de
/// groupe (D15/D16) : en-tête immersif (avatar, nom), puis l'action **Message**.
///
/// Accessible depuis un roster de groupe, depuis l'auteur d'un message reçu, et
/// depuis l'en-tête d'un tête-à-tête : un utilisateur simple a droit à la même
/// page détail.
///
/// ## Elle reçoit un identifiant, et le nom vient de `profiles` (#96)
///
/// L'ancienne version recevait un **nom** en `extra` — tout ce que la maquette
/// avait. Le nom vient désormais de la collection `profiles`, et il peut
/// **manquer** : profil pas encore arrivé, ou compte qui n'a jamais rempli son
/// nom. Dans les deux cas l'écran se rend, avec un avatar neutre et sans ligne de
/// nom. Jamais d'« Utilisateur inconnu », qui ressemblerait à une donnée.
///
/// ## La galerie de médias **a disparu** (#96, décision 10)
///
/// Elle était engendrée par **hachage du nom** : quatre `picsum.photos` qui
/// n'avaient aucun rapport avec la personne, et que deux homonymes auraient
/// partagées. Les pièces jointes n'existent nulle part, des deux côtés, et le PRD
/// d'ADR-0006 les exclut de la V1.
///
/// ## Le bouton « Message » (#145, décision 8)
///
/// Il ouvre le tête-à-tête **qu'il existe ou non** : `directGroupId` connu → le
/// fil ordinaire ; inconnu → l'écran du premier message (`DirectChatScreen`),
/// dont l'envoi crée la discussion (`POST /groups/direct/:targetUserId/messages`).
/// La fiche d'une personne n'est atteignable que si `profiles` l'a livrée,
/// c'est-à-dire pour une co-membre — exactement ce que le serveur exige pour
/// démarrer. Jamais sur **ma** fiche : on ne s'écrit pas à soi-même.
class MemberProfileScreen extends ConsumerWidget {
  const MemberProfileScreen({super.key, required this.memberId});

  final String memberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    // L'acteur est lu ici et passé en clé : voir l'en-tête
    // d'`echanges_providers.dart`.
    final profile = ref.watch(
      memberProfileProvider(
        (actor: ref.watch(echangesActorProvider), id: memberId),
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
        // `profiles` n'a pas encore livré cette personne — ou ne la livrera plus,
        // n'étant plus ma co-membre. Une **absence**, pas une erreur.
        if (member == null) {
          return const Scaffold(
            body: ContentAbsenceView(absence: ContentAbsence.notSynced),
          );
        }
        return Scaffold(
          body: _Body(member: member, me: ref.watch(echangesActorProvider)),
        );
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.member, required this.me});

  final MemberProfileView member;
  final String? me;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final directGroupId = member.directGroupId;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _Header(member: member),
        const SizedBox(height: AppSpacing.lg),
        if (directGroupId != null || (me != null && member.userId != me))
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: AppButton(
              label: l.memberMessage,
              icon: Icons.chat_bubble_outline,
              // **L'identifiant du groupe, jamais un objet** : c'est une vraie
              // conversation du magasin, pas une coquille fabriquée pour l'écran.
              onPressed: () => directGroupId != null
                  ? context.pushNamed(
                      AppRoute.groupChat,
                      pathParameters: {'id': directGroupId},
                    )
                  : context.pushNamed(
                      AppRoute.directChat,
                      pathParameters: {'id': member.userId},
                    ),
            ),
          ),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }
}

/// En-tête immersif au dégradé de marque : retour, grand avatar, nom.
class _Header extends StatelessWidget {
  const _Header({required this.member});

  final MemberProfileView member;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final name = member.displayName;
    final named = name != null && name.isNotEmpty;

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
            // Sans nom, l'avatar est **neutre** : les initiales d'un identifiant
            // seraient deux caractères d'UUID, c'est-à-dire un marqueur
            // d'identité inventé.
            child: named
                ? AppAvatar(name: name, size: 96)
                : const AppAvatar.neutral(size: 96),
          ),
          if (named) ...[
            const SizedBox(height: AppSpacing.md),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Text(
                name,
                textAlign: TextAlign.center,
                style: AppTypography.h3.copyWith(color: Colors.white),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          Text(
            context.l10n.memberProfileSubtitle,
            style: AppTypography.body
                .copyWith(color: Colors.white.withValues(alpha: 0.85)),
          ),
        ],
      ),
    );
  }
}
