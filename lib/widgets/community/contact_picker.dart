import 'package:flutter/material.dart';

import '../../l10n/l10n_extension.dart';
import '../../models/group_management.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../app_avatar.dart';

/// **Le sélecteur des personnes de mes groupes** (#145) — un champ de
/// recherche par nom, puis la liste.
///
/// Deux usages, un seul widget :
///
/// - **un choix** (`selected == null`) : « Nouvelle discussion » — toucher une
///   personne ouvre la discussion avec elle ;
/// - **plusieurs** (`selected != null`) : les membres d'un groupe qu'on crée,
///   ou qu'on ajoute — chaque ligne porte une case.
///
/// Il ne fait **pas** défiler : il se pose dans la `ListView` de son écran, à
/// la suite des autres champs. La liste qu'il reçoit est **déjà bornée** à mes
/// contacts de groupe (`GroupDao.contactsOf`, la règle du serveur) : il ne
/// propose jamais quelqu'un que le serveur refuserait.
class ContactPicker extends StatefulWidget {
  const ContactPicker({
    super.key,
    required this.contacts,
    required this.onTap,
    this.selected,
    this.emptyText,
  });

  final List<ContactView> contacts;

  /// Toucher une ligne : ouvrir (un choix) ou cocher/décocher (plusieurs).
  final ValueChanged<ContactView> onTap;

  /// Les identifiants cochés ; `null` = sélecteur à un choix, sans cases.
  final Set<String>? selected;

  /// La phrase quand il n'y a **personne** (avant toute recherche).
  final String? emptyText;

  /// Le champ de recherche — pour les tests.
  static const searchFieldKey = ValueKey('contact-picker-search');

  @override
  State<ContactPicker> createState() => _ContactPickerState();
}

class _ContactPickerState extends State<ContactPicker> {
  final TextEditingController _query = TextEditingController();

  @override
  void initState() {
    super.initState();
    _query.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final palette = context.palette;

    if (widget.contacts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Text(
          widget.emptyText ?? l.m6NoContacts,
          textAlign: TextAlign.center,
          style: AppTypography.body.copyWith(color: palette.textSecondary),
        ),
      );
    }

    final shown = searchContacts(widget.contacts, _query.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: ContactPicker.searchFieldKey,
          controller: _query,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: l.m6SearchContacts,
            prefixIcon: Icon(Icons.search, color: palette.textSecondary),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Text(
              l.m6NoContactMatch,
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(color: palette.textSecondary),
            ),
          ),
        for (final contact in shown)
          _ContactTile(
            contact: contact,
            checked: widget.selected?.contains(contact.userId),
            onTap: () => widget.onTap(contact),
          ),
      ],
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.contact,
    required this.checked,
    required this.onTap,
  });

  final ContactView contact;

  /// `null` = sélecteur à un choix (pas de case).
  final bool? checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = contact.displayName;
    final named = name != null && name.isNotEmpty;
    return ListTile(
      key: ValueKey('contact-${contact.userId}'),
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: named
          ? AppAvatar(name: name, size: 40)
          : const AppAvatar.neutral(size: 40),
      // Sans nom, la ligne reste : un compte qui n'a jamais rempli son profil
      // est une personne quand même. Pas d'« Utilisateur inconnu ».
      title: Text(named ? name : '—', style: AppTypography.bodyStrong),
      trailing: checked == null
          ? null
          : Checkbox(value: checked, onChanged: (_) => onTap()),
    );
  }
}
