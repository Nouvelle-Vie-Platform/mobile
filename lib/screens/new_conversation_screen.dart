import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/l10n_extension.dart';
import '../models/group_management.dart';
import '../router/app_router.dart';
import '../state/echanges_providers.dart';
import '../state/group_management_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/community/contact_picker.dart';

/// **« Nouvelle discussion »** (#145, décisions 8 et 9) — le sélecteur des
/// personnes de mes groupes, et pour un responsable, « Nouveau groupe ».
///
/// ## Borné, et c'est la décision 8
///
/// La liste est celle de mes **contacts de groupe** (`contactsProvider`) : les
/// personnes avec qui je partage un groupe qui n'est pas un tête-à-tête. C'est
/// exactement la règle que le serveur applique pour **démarrer** une discussion
/// — jamais un annuaire de l'église.
///
/// ## « Nouveau groupe » n'existe que pour un responsable (décision 9)
///
/// Lu sur `GET /groups/capabilities`, la policy même qui garde `POST /groups`.
/// Pour les autres, la ligne n'existe pas — ni grisée, ni expliquée : un geste
/// qu'on ne peut pas faire n'a pas à être montré (#83).
class NewConversationScreen extends ConsumerWidget {
  const NewConversationScreen({super.key});

  /// La ligne « Nouveau groupe » — pour les tests.
  static const newGroupKey = ValueKey('new-conversation-new-group');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final me = ref.watch(echangesActorProvider);
    final contacts = ref.watch(contactsProvider(me));
    final capabilities = ref.watch(groupCapabilitiesProvider(me)).value ??
        GroupCapabilities.none;

    return Scaffold(
      appBar: AppBar(title: Text(l.m6NewConversation)),
      body: ListView(
        padding: AppSpacing.screenPadding.copyWith(
          top: AppSpacing.lg,
          bottom: AppSpacing.xxl,
        ),
        children: [
          if (capabilities.canCreateGroup) ...[
            ListTile(
              key: newGroupKey,
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                backgroundColor: AppColors.primary,
                child: Icon(Icons.group_add_outlined, color: Colors.white),
              ),
              title: Text(l.m6NewGroup, style: AppTypography.bodyStrong),
              onTap: () => context.pushReplacementNamed(AppRoute.createGroup),
            ),
            const Divider(height: AppSpacing.xl),
          ],
          contacts.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => Text(
              l.echangesLoadError,
              textAlign: TextAlign.center,
            ),
            data: (people) => ContactPicker(
              contacts: people,
              // **Remplacer**, pas empiler : le retour depuis la discussion
              // ramène à la liste des Échanges, pas au sélecteur.
              onTap: (contact) => context.pushReplacementNamed(
                AppRoute.directChat,
                pathParameters: {'id': contact.userId},
              ),
            ),
          ),
        ],
      ),
    );
  }
}
