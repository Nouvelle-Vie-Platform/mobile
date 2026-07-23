import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n_extension.dart';
import '../../models/models.dart';
import '../../router/app_router.dart';
import '../../state/auth_providers.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/brand_app_bar.dart';
import '../../widgets/selectable_option.dart';

/// `/profile/edit` : écran unique servant **deux cas** —
///
/// 1. **complétion** juste après la première connexion (`isNewUser`) ;
/// 2. **édition** depuis l'onglet Profil (profil déjà complet → préremplissage).
///
/// Le mode est déduit de `user.profileComplete`. L'écran est **skippable**
/// (« Plus tard » n'enregistre rien). Civilité **requise dès qu'un nom est
/// saisi** ; branche choisie → `membre`, « Je suis nouveau » → `nouveau`.
class ProfileFormScreen extends ConsumerStatefulWidget {
  const ProfileFormScreen({super.key});

  @override
  ConsumerState<ProfileFormScreen> createState() => _ProfileFormScreenState();
}

class _ProfileFormScreenState extends ConsumerState<ProfileFormScreen> {
  final _nameController = TextEditingController();

  UserTitle? _title;

  /// Branche sélectionnée (`null` si aucune ou si « Je suis nouveau »).
  String? _branchId;

  /// « Je suis nouveau » choisi (mutuellement exclusif avec [_branchId]).
  bool _isNewSelected = false;

  /// Vrai si le profil était déjà complété à l'ouverture (mode édition).
  bool _editMode = false;

  bool _titleMissing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Préremplissage en mode édition (profil déjà complété).
    final user = ref.read(authProvider).user;
    _editMode = user?.profileComplete ?? false;
    if (_editMode && user != null) {
      _title = user.title;
      _nameController.text = user.fullName ?? '';
      if (user.branchId != null) {
        _branchId = user.branchId;
      } else {
        _isNewSelected = true;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Retour après save ou skip :
  /// - complétion → accueil ;
  /// - édition → retour arrière si possible, sinon accueil.
  void _navigateAfter() {
    if (_editMode && context.canPop()) {
      context.pop();
    } else {
      context.goNamed(AppRoute.home);
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    // Civilité obligatoire dès qu'un nom est renseigné.
    if (name.isNotEmpty && _title == null) {
      setState(() => _titleMissing = true);
      return;
    }

    final branchChosen = _branchId != null;
    setState(() => _saving = true);
    await ref.read(authProvider.notifier).updateProfile(
          title: _title,
          fullName: name.isEmpty ? null : name,
          branchId: branchChosen ? _branchId : null,
          status: branchChosen ? UserStatus.membre : UserStatus.nouveau,
        );
    if (!mounted) return;
    _navigateAfter();
  }

  void _selectTitle(UserTitle title) {
    setState(() {
      _title = title;
      _titleMissing = false;
    });
  }

  void _selectBranch(String id) {
    setState(() {
      _branchId = id;
      _isNewSelected = false;
    });
  }

  void _selectNew() {
    setState(() {
      _branchId = null;
      _isNewSelected = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final palette = context.palette;
    final branches = ref.watch(branchesProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: BrandAppBar(title: l.profileFormTitle),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.profileFormTitle, style: AppTypography.h3),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l.profileFormSubtitle,
                style:
                    AppTypography.body.copyWith(color: palette.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Civilité ──────────────────────────────────────────
                    Text(
                      l.profileTitleLabel,
                      style: AppTypography.bodyStrong,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: _TitleChoice(
                            label: l.titleBrother,
                            selected: _title == UserTitle.frere,
                            onTap: () => _selectTitle(UserTitle.frere),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _TitleChoice(
                            label: l.titleSister,
                            selected: _title == UserTitle.soeur,
                            onTap: () => _selectTitle(UserTitle.soeur),
                          ),
                        ),
                      ],
                    ),
                    if (_titleMissing) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        l.profileTitleRequired,
                        style: AppTypography.caption.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),

                    // ── Nom ───────────────────────────────────────────────
                    AppTextField(
                      label: l.fieldYourName,
                      controller: _nameController,
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // ── Branche ───────────────────────────────────────────
                    Text(l.fieldYourBranch, style: AppTypography.bodyStrong),
                    for (final branch in branches)
                      RadioOptionTile(
                        label: branch.city == null
                            ? branch.name
                            : '${branch.name} · ${branch.city}',
                        selected: !_isNewSelected && _branchId == branch.id,
                        onTap: () => _selectBranch(branch.id),
                      ),
                    Divider(color: palette.divider, height: 1),
                    RadioOptionTile(
                      label: l.branchImNew,
                      selected: _isNewSelected,
                      onTap: _selectNew,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: l.actionSave,
                loading: _saving,
                onPressed: _saving ? null : _save,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: l.actionLater,
                variant: AppButtonVariant.ghost,
                onPressed: _saving ? null : _navigateAfter,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Choix de civilité (pilule sélectionnable) — style aligné sur les options
/// de montant/paiement du design.
class _TitleChoice extends StatelessWidget {
  const _TitleChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? palette.infoBg : palette.surface,
          borderRadius: AppRadius.field,
          border: Border.all(
            color: selected ? palette.primary : palette.border,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.bodyStrong.copyWith(
            color: selected ? palette.primary : palette.textPrimary,
          ),
        ),
      ),
    );
  }
}
