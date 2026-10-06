import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/echanges_view.dart';
import '../../state/group_management_providers.dart';
import 'group_admin_section.dart';

/// **Rejoindre ou demander à rejoindre depuis la carte** (#145), selon la
/// politique du groupe : `open` → `POST /groups/:id/join` ; `request` →
/// `POST /groups/:id/join-requests`.
///
/// Rien n'est peint par la réponse : le groupe rejoint arrive par le canal
/// (`membership.changed`, puis `group.updated`) ou par le cycle que le geste
/// lance — il quitte alors la rangée « à rejoindre » et entre dans la liste. Une
/// demande, elle, revient par `group_join_requests` et la carte dit « Demande
/// envoyée ». Un second appui est sans effet : le serveur répond « déjà fait »,
/// que le client lit comme tel.
Future<void> joinFromCard(
  BuildContext context,
  WidgetRef ref,
  DiscoverGroupView group,
) async {
  final actions = ref.read(groupActionsProvider);
  final outcome = group.joinPolicy == 'open'
      ? await actions.join(group.groupId)
      : await actions.requestToJoin(group.groupId);
  if (context.mounted) showGroupActionOutcome(context, outcome);
}
