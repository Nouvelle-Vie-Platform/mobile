import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/l10n_extension.dart';
import '../models/echanges_view.dart';
import '../router/app_router.dart';
import '../state/echanges_providers.dart';
import '../state/sync_providers.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_error_state.dart';
import '../widgets/community/community_header.dart';
import '../widgets/community/conversation_tile.dart';
import '../widgets/community/join_group_card.dart';

/// Hub **« Échanges »** : groupes et discussions réunis au même endroit, **peints
/// par le magasin local** (#96).
///
/// L'écran est fait d'un **bandeau diagonal** ([CommunityHeader]), d'une rangée
/// horizontale de **groupes à rejoindre** (découverte, distincte des
/// conversations — D6), puis d'une **liste à plat** de conversations (groupes et
/// tête-à-tête mêlés, triés par récence — D7). Aucun onglet, aucun FAB (le FAB
/// central de la coquille reste inchangé — D9), aucune icône d'appel (D8).
///
/// ## Ce qui change avec le branchement
///
/// Les deux lectures étaient **synchrones** (`SampleData` par
/// `InMemoryChurchRepository`) ; elles sont maintenant des `AsyncValue`. C'est le
/// coût réel de la bascule, et il se paie ici : chargement, vide, erreur.
///
/// - **vide** n'est pas une erreur, et c'est l'état le plus fréquent au premier
///   lancement : le magasin n'a pas encore reçu mes groupes. On le dit, et on
///   offre le **tirer-pour-rafraîchir** — qui est aussi le geste qui ramène les
///   nouveaux messages, puisque le réveil push est de la tranche 2 ;
/// - **erreur** est une panne de magasin, pas de réseau (`AppErrorState`).
///
/// Le nom de fichier/classe reste `groups_screen` / `GroupsScreen` : la coquille
/// et les tests s'y réfèrent, et le renommer n'aurait apporté que du bruit.
class GroupsScreen extends ConsumerWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // **L'acteur est lu par l'écran**, puis passé en clé de famille : voir
    // l'en-tête d'`echanges_providers.dart`. Une chaîne de providers synchrones
    // entre `authProvider` et ces flux fait rougir l'application au retour du
    // parcours de connexion.
    final me = ref.watch(echangesActorProvider);
    final conversations = ref.watch(conversationsProvider(me));
    final toJoin = ref.watch(discoverGroupsProvider(me));

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
          child: RefreshIndicator(
            // Le même geste que la médiathèque, et ici il porte deux choses : les
            // conversations qu'on n'a pas encore reçues, **et** les messages
            // arrivés depuis. Le réveil push est de la tranche 2 ; d'ici là, c'est
            // le seul rattrapage qu'un fidèle puisse déclencher lui-même.
            onRefresh: () => ref.read(pullToRefreshProvider)(),
            child: ListView(
              padding: EdgeInsets.only(top: AppSpacing.lg, bottom: bottomInset),
              children: [
                ..._discoverSection(context, toJoin),
                ..._conversationsSection(ref, context, me, conversations),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// La rangée « groupes à rejoindre ».
  ///
  /// Elle ne porte **ni état de chargement ni état d'erreur** : c'est une rangée
  /// de découverte, pas le contenu de l'écran. Un bandeau d'erreur au-dessus de
  /// mes conversations pour un échec de découverte dirait « Échanges est en
  /// panne » là où seule une suggestion manque.
  List<Widget> _discoverSection(
    BuildContext context,
    AsyncValue<List<DiscoverGroupView>> toJoin,
  ) {
    final groups = toJoin.value ?? const <DiscoverGroupView>[];
    if (groups.isEmpty) return const [];

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
            // Le tap ouvre la **fiche du groupe**, et non plus le profil de
            // l'animateur : on découvre un groupe, on ne découvre pas une
            // personne. La fiche porte la description, l'effectif et l'animateur
            // — tout ce qu'il faut pour décider.
            onTap: () => context.pushNamed(
              AppRoute.groupInfo,
              pathParameters: {'id': groups[i].groupId},
            ),
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.xl),
    ];
  }

  List<Widget> _conversationsSection(
    WidgetRef ref,
    BuildContext context,
    String? actor,
    AsyncValue<List<ConversationView>> conversations,
  ) {
    final l = context.l10n;
    return [
      conversations.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, __) => Padding(
          padding: AppSpacing.screenPadding,
          child: AppErrorState(
            message: l.echangesLoadError,
            // Relire le magasin, et non retenter le réseau : c'est une lecture
            // Drift qui a échoué. Le tirer-pour-rafraîchir reste au-dessus pour
            // l'autre panne.
            onRetry: () => ref.invalidate(conversationsProvider(actor)),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return Padding(
              padding: AppSpacing.screenPadding,
              child: AppEmptyState(
                icon: Icons.forum_outlined,
                title: l.echangesEmptyTitle,
                message: l.echangesEmpty,
              ),
            );
          }
          return Column(
            children: [
              for (final c in items) ...[
                Padding(
                  padding: AppSpacing.screenPadding,
                  child: ConversationTile(
                    conversation: c,
                    // **L'identifiant, jamais l'objet** : un objet en `extra` est
                    // une copie figée hors du magasin, et il ne survit ni à un
                    // réveil push ni à un lien profond.
                    onTap: () => context.pushNamed(
                      AppRoute.groupChat,
                      pathParameters: {'id': c.groupId},
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ],
          );
        },
      ),
    ];
  }
}
