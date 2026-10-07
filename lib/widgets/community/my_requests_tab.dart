import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_extension.dart';
import '../../models/my_request_view.dart';
import '../../router/app_router.dart';
import '../../state/echanges_providers.dart';
import '../../state/requests_providers.dart';
import '../../state/sync_providers.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/event_time.dart';
import '../app_button.dart';
import '../app_card.dart';
import '../app_chip.dart';
import '../app_empty_state.dart';
import '../app_error_state.dart';

/// Onglet **« Requêtes »** de la page Échanges (#148) : **mes** demandes de
/// prière, suggestions et réclamations, avec leur état de traitement et leur
/// date, plus le bouton qui en crée une.
///
/// **Peint par le magasin local** — la collection privée `my_interactions`, que
/// la synchronisation remplit à l'ouverture, au retour au premier plan, au
/// tirer-pour-rafraîchir et après chaque envoi. Jamais de requête réseau ici :
/// le mobile ne sonde pas.
class MyRequestsTab extends ConsumerWidget {
  const MyRequestsTab({super.key, this.showAddButton = true});

  /// Le bouton « Nouvelle requête » dans la liste. Faux dans la page Échanges,
  /// où le « + » du bandeau le remplace ; vrai sur la page autonome `/requests`,
  /// qui n'a pas ce bandeau.
  final bool showAddButton;

  /// Le bouton « Nouvelle requête » — exposé pour les tests.
  static const addButtonKey = ValueKey('my-requests-add');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // L'acteur est lu par l'écran, puis passé en clé de famille : voir
    // l'en-tête d'`echanges_providers.dart`.
    final me = ref.watch(echangesActorProvider);
    final requests = ref.watch(myRequestsProvider(me));
    final l = context.l10n;

    // Dégagement pour la barre de nav givrée, comme l'onglet Messages.
    final bottomInset =
        MediaQuery.paddingOf(context).bottom + AppSpacing.xxxl + AppSpacing.xl;

    final addButton = AppButton(
      key: addButtonKey,
      label: l.requestsAdd,
      icon: Icons.add,
      onPressed: () => context.pushNamed(AppRoute.newRequest),
    );

    return RefreshIndicator(
      onRefresh: () => ref.read(pullToRefreshProvider)(),
      child: ListView(
        padding: EdgeInsets.only(
          top: AppSpacing.lg,
          bottom: bottomInset,
          left: AppSpacing.screenPadding.left,
          right: AppSpacing.screenPadding.right,
        ),
        children: requests.when(
          loading: () => const [
            Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
          error: (_, __) => [
            AppErrorState(
              message: l.requestsLoadError,
              // Relire le magasin : c'est une lecture Drift qui a échoué.
              onRetry: () => ref.invalidate(myRequestsProvider(me)),
            ),
          ],
          data: (items) => items.isEmpty
              ? [
                  const SizedBox(height: AppSpacing.xl),
                  AppEmptyState(
                    icon: Icons.assignment_outlined,
                    title: l.requestsEmptyTitle,
                    message: l.requestsEmpty,
                  ),
                  if (showAddButton) ...[
                    const SizedBox(height: AppSpacing.xl),
                    addButton,
                  ],
                ]
              : [
                  if (showAddButton) ...[
                    addButton,
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  for (final request in items) ...[
                    MyRequestTile(request: request),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ],
        ),
      ),
    );
  }
}

/// Une requête envoyée : genre et état en tête, objet, extrait, date.
class MyRequestTile extends StatelessWidget {
  const MyRequestTile({super.key, required this.request});

  final MyRequestView request;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final palette = context.palette;
    final kind = requestKindLabel(request.kind, l);
    final sentAt = request.sentAt;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (kind != null)
                Expanded(
                  child: Text(
                    kind,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption
                        .copyWith(color: palette.textSecondary),
                  ),
                )
              else
                const Spacer(),
              _StatusChip(status: request.status),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            request.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.h5,
          ),
          const SizedBox(height: 4),
          Text(
            request.content,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.body.copyWith(color: palette.textSecondary),
          ),
          if (sentAt != null || request.isAnonymous) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              [
                if (sentAt != null)
                  l.requestSentOn(formatRequestDate(sentAt, l.localeName)),
                if (request.isAnonymous) l.anonymousLabel,
              ].join(' · '),
              style:
                  AppTypography.caption.copyWith(color: palette.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final RequestStatus status;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final (label, tone) = switch (status) {
      RequestStatus.received => (l.requestStatusNew, AppChipTone.info),
      RequestStatus.inProgress => (
          l.requestStatusInProgress,
          AppChipTone.event
        ),
      RequestStatus.resolved => (l.requestStatusResolved, AppChipTone.culte),
      RequestStatus.archived => (l.requestStatusArchived, AppChipTone.neutral),
      // Un état qu'un serveur plus récent connaîtrait et pas nous : aucune
      // étiquette plutôt qu'une fausse.
      RequestStatus.unknown => (null, AppChipTone.neutral),
    };
    if (label == null) return const SizedBox.shrink();
    return AppChip(label, tone: tone, showDot: true);
  }
}

/// Le libellé d'un genre de requête — le même dans le formulaire et la liste.
/// `null` pour un genre inconnu de cette version.
String? requestKindLabel(RequestKind kind, AppLocalizations l) =>
    switch (kind) {
      RequestKind.prayer => l.requestTypePrayer,
      RequestKind.suggestion => l.requestTypeSuggestion,
      RequestKind.complaint => l.requestTypeComplaint,
      RequestKind.unknown => null,
    };
