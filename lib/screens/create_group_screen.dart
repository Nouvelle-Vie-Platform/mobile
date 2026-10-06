import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/repositories/group_admin_client.dart';
import '../l10n/l10n_extension.dart';
import '../models/group_management.dart';
import '../router/app_router.dart';
import '../state/echanges_providers.dart';
import '../state/group_management_providers.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_button.dart';
import '../widgets/app_text_field.dart';
import '../widgets/community/contact_picker.dart';

/// **Créer un groupe** (#145, décision 9) — réservé aux responsables : nom,
/// description facultative, membres choisis parmi les personnes de mes groupes.
/// Le créateur en devient l'animateur (`leader`).
///
/// ## Pas de photo
///
/// Le serveur ne porte **aucune** image de groupe (ni colonne, ni chemin de
/// dépôt : le dépôt présigné des médias est celui des **messages**, et il exige
/// un groupe qui existe déjà). Un champ « photo » qui ne serait envoyé nulle
/// part serait une promesse non tenue ; il viendra avec la colonne.
///
/// ## Un seul groupe, même en touchant deux fois
///
/// L'identifiant est frappé **une fois**, à l'ouverture de l'écran : un second
/// appui après une coupure renvoie la même création, que le serveur reconnaît
/// et rend (200) au lieu d'en faire une seconde (piège 5 du plan).
class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  /// Le bouton d'envoi — pour les tests.
  static const submitKey = ValueKey('create-group-submit');

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final Set<String> _members = {};
  late final String _groupId = mintGroupId();
  bool _sending = false;

  /// Le nom ne se juge qu'après un premier essai d'envoi.
  bool _nameTouched = false;

  /// La borne du serveur (`name.minLength`), nommée une fois.
  static const int minNameLength = 3;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  bool get _nameValid => _name.text.trim().length >= minNameLength;

  Future<void> _submit(GroupCapabilities capabilities) async {
    if (!_nameValid || _sending) {
      setState(() => _nameTouched = true);
      return;
    }
    setState(() => _sending = true);
    final outcome = await ref.read(groupActionsProvider).createGroup(
          id: _groupId,
          name: _name.text,
          description: _description.text,
          branchIds: capabilities.createBranchIds,
          memberIds: _members.toList(growable: false),
        );
    if (!mounted) return;
    setState(() => _sending = false);
    if (outcome == GroupActionOutcome.done) {
      // Le groupe arrive au magasin par le canal ou par le cycle que le geste
      // vient de lancer ; le fil sait attendre une absence passagère.
      context.pushReplacementNamed(
        AppRoute.groupChat,
        pathParameters: {'id': _groupId},
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.m6CreateGroupFailed)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final palette = context.palette;
    final me = ref.watch(echangesActorProvider);
    final capabilities = ref.watch(groupCapabilitiesProvider(me)).value ??
        GroupCapabilities.none;
    final contacts = ref.watch(contactsProvider(me)).value ?? const [];

    return Scaffold(
      appBar: AppBar(title: Text(l.m6CreateGroupTitle)),
      body: ListView(
        padding: AppSpacing.screenPadding.copyWith(
          top: AppSpacing.lg,
          bottom: AppSpacing.xxl,
        ),
        children: [
          AppTextField(
            label: l.m6GroupNameLabel,
            controller: _name,
            errorText:
                _nameTouched && !_nameValid ? l.m6GroupNameTooShort : null,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            label: l.m6GroupDescriptionLabel,
            controller: _description,
            maxLines: 3,
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(l.m6GroupMembersLabel, style: AppTypography.h5),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l.groupMembers(_members.length + 1),
            style: AppTypography.caption.copyWith(color: palette.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          ContactPicker(
            contacts: contacts,
            selected: _members,
            onTap: (contact) => setState(() {
              if (!_members.remove(contact.userId)) {
                _members.add(contact.userId);
              }
            }),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            key: CreateGroupScreen.submitKey,
            label: l.m6CreateGroupSubmit,
            icon: Icons.group_add_outlined,
            loading: _sending,
            // Le bouton ne s'offre qu'à un responsable : sans la capacité, le
            // serveur refuserait, et l'écran n'est atteignable que par elle.
            onPressed: capabilities.canCreateGroup && !_sending
                ? () => _submit(capabilities)
                : null,
          ),
        ],
      ),
    );
  }
}
