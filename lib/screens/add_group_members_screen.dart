import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/repositories/group_admin_client.dart';
import '../l10n/l10n_extension.dart';
import '../models/group_management.dart';
import '../state/echanges_providers.dart';
import '../state/group_management_providers.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_button.dart';
import '../widgets/community/contact_picker.dart';

/// **Ajouter des membres à un groupe** (#145) — réservé à ses animateurs et
/// modérateurs (ADR-0009 ; la fiche n'offre le bouton qu'à eux, et le serveur
/// revérifie). On choisit parmi **mes contacts de groupe** qui n'en sont pas
/// déjà membres.
class AddGroupMembersScreen extends ConsumerStatefulWidget {
  const AddGroupMembersScreen({super.key, required this.groupId});

  final String groupId;

  /// Le bouton d'envoi — pour les tests.
  static const submitKey = ValueKey('add-members-submit');

  @override
  ConsumerState<AddGroupMembersScreen> createState() =>
      _AddGroupMembersScreenState();
}

class _AddGroupMembersScreenState extends ConsumerState<AddGroupMembersScreen> {
  final Set<String> _chosen = {};
  bool _sending = false;

  Future<void> _submit() async {
    if (_chosen.isEmpty || _sending) return;
    setState(() => _sending = true);
    final outcome = await ref
        .read(groupActionsProvider)
        .addMembers(widget.groupId, _chosen.toList(growable: false));
    if (!mounted) return;
    setState(() => _sending = false);
    if (outcome == GroupActionOutcome.done) {
      context.pop();
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          outcome == GroupActionOutcome.refused
              ? context.l10n.m6ActionRefused
              : context.l10n.m6ActionUnreachable,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final me = ref.watch(echangesActorProvider);
    final detail =
        ref.watch(groupDetailProvider((actor: me, id: widget.groupId))).value;
    final contacts = ref.watch(contactsProvider(me)).value ?? const [];
    final already = {for (final m in detail?.members ?? const []) m.userId};
    final candidates = <ContactView>[
      for (final contact in contacts)
        if (!already.contains(contact.userId)) contact,
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l.m6AddMembers)),
      body: ListView(
        padding: AppSpacing.screenPadding.copyWith(
          top: AppSpacing.lg,
          bottom: AppSpacing.xxl,
        ),
        children: [
          ContactPicker(
            contacts: candidates,
            selected: _chosen,
            emptyText: l.m6NoOneToAdd,
            onTap: (contact) => setState(() {
              if (!_chosen.remove(contact.userId)) _chosen.add(contact.userId);
            }),
          ),
          const SizedBox(height: AppSpacing.xl),
          if (candidates.isNotEmpty)
            AppButton(
              key: AddGroupMembersScreen.submitKey,
              label: l.m6AddMembersSubmit,
              icon: Icons.person_add_alt_1_outlined,
              loading: _sending,
              onPressed: _chosen.isEmpty || _sending ? null : _submit,
            ),
        ],
      ),
    );
  }
}
