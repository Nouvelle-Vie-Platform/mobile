import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n_extension.dart';
import '../models/models.dart';
import '../state/auth_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/branch_label.dart';
import 'app_button.dart';
import 'branch_list_status.dart';

/// Demande d'ouverture de la feuille de mise en route du profil.
///
/// Positionné juste avant d'atterrir sur l'accueil quand la connexion concerne
/// un nouvel utilisateur ; l'accueil la consomme (puis remet à `false`).
class ProfileSetupPending extends Notifier<bool> {
  @override
  bool build() => false;

  void request() => state = true;

  void clear() => state = false;
}

final profileSetupPendingProvider =
    NotifierProvider<ProfileSetupPending, bool>(ProfileSetupPending.new);

/// Ouvre la feuille de mise en route du profil par-dessus l'écran courant.
///
/// L'écran en dessous reste visible au travers du voile : un appui dans le
/// vide referme la feuille et le rend de nouveau pleinement lisible.
Future<void> showProfileSetupSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.42),
    builder: (_) => const _ProfileSetupSheet(),
  );
}

/// Feuille en deux temps : d'abord civilité + nom, puis choix de la branche.
class _ProfileSetupSheet extends ConsumerStatefulWidget {
  const _ProfileSetupSheet();

  @override
  ConsumerState<_ProfileSetupSheet> createState() => _ProfileSetupSheetState();
}

class _ProfileSetupSheetState extends ConsumerState<_ProfileSetupSheet> {
  final _nameController = TextEditingController();

  int _step = 0;
  UserTitle? _title;
  int? _branchId;
  bool _isNewMember = false;
  bool _titleMissing = false;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Étape 1 → 2. Le nom saisi est enregistré immédiatement : si l'utilisateur
  /// referme la feuille à l'étape 2, sa saisie n'est pas perdue.
  Future<void> _next() async {
    final name = _nameController.text.trim();
    if (name.isNotEmpty && _title == null) {
      setState(() => _titleMissing = true);
      return;
    }
    setState(() {
      _titleMissing = false;
      _saving = true;
    });
    if (name.isNotEmpty) {
      await ref.read(authProvider.notifier).updateProfile(
            title: _title,
            firstName: name,
          );
    }
    if (!mounted) return;
    setState(() {
      _saving = false;
      _step = 1;
    });
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    await ref.read(authProvider.notifier).updateProfile(
          branchId: _isNewMember ? null : _branchId,
          status: _isNewMember || _branchId == null
              ? UserStatus.newcomer
              : UserStatus.affiliated,
        );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      // Remonte la feuille au-dessus du clavier.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.sm,
          bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.lg,
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Poignée de glissement.
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: palette.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: _step == 0
                      ? _buildIdentityStep(context, palette)
                      : _buildBranchStep(context, palette),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Étape 1 : civilité + nom.
  Widget _buildIdentityStep(BuildContext context, AppPalette palette) {
    final l = context.l10n;
    return Column(
      key: const ValueKey('identity'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l.profileFormTitle, style: AppTypography.h3),
        const SizedBox(height: AppSpacing.xs),
        Text(
          l.profileFormSubtitle,
          style: AppTypography.body.copyWith(color: palette.textSecondary),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          l.profileTitleLabel,
          style: AppTypography.bodyStrong.copyWith(color: palette.textPrimary),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _ChoiceChip(
                label: l.titleBrother,
                selected: _title == UserTitle.brother,
                onTap: () => setState(() {
                  _title = UserTitle.brother;
                  _titleMissing = false;
                }),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _ChoiceChip(
                label: l.titleSister,
                selected: _title == UserTitle.sister,
                onTap: () => setState(() {
                  _title = UserTitle.sister;
                  _titleMissing = false;
                }),
              ),
            ),
          ],
        ),
        if (_titleMissing) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            l.profileTitleRequired,
            style: AppTypography.caption.copyWith(color: AppColors.danger),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _nameController,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: l.fieldYourName),
        ),
        const SizedBox(height: AppSpacing.xl),
        AppButton(
          label: l.actionNext,
          loading: _saving,
          onPressed: _saving ? null : _next,
        ),
      ],
    );
  }

  /// Étape 2 : branche, ou « Je suis nouveau ».
  Widget _buildBranchStep(BuildContext context, AppPalette palette) {
    final l = context.l10n;
    // Référentiel serveur : chargement, liste vide ou échec réseau laissent
    // l'étape utilisable — « Je suis nouveau » ne dépend d'aucune branche.
    final branchesAsync = ref.watch(branchesProvider);
    // L'ordre vient de l'utilitaire, pas du serveur : `/sync/branches` est un
    // flux delta, son ordre répond à « qu'est-ce qui a changé ».
    final branches =
        branchesForSelection(branchesAsync.value ?? const <Branch>[], l);
    return Column(
      key: const ValueKey('branch'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l.fieldYourBranch, style: AppTypography.h3),
        const SizedBox(height: AppSpacing.xs),
        Text(
          l.profileFormSubtitle,
          style: AppTypography.body.copyWith(color: palette.textSecondary),
        ),
        const SizedBox(height: AppSpacing.lg),
        for (final branch in branches) ...[
          _BranchTile(
            // La ville seule — même règle que `ProfileFormScreen`, écrite une
            // seule fois (voir utils/branch_label.dart).
            label: branchSelectionLabel(branch, l),
            selected: !_isNewMember && _branchId == branch.id,
            onTap: () => setState(() {
              _branchId = branch.id;
              _isNewMember = false;
            }),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        BranchListStatus(branchesAsync),
        _BranchTile(
          label: l.branchImNew,
          selected: _isNewMember,
          onTap: () => setState(() {
            _isNewMember = true;
            _branchId = null;
          }),
        ),
        const SizedBox(height: AppSpacing.xl),
        AppButton(
          label: l.actionSave,
          loading: _saving,
          onPressed: _saving ? null : _finish,
        ),
      ],
    );
  }
}

/// Pilule de choix (civilité).
class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
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
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? palette.primary.withValues(alpha: 0.10)
              : palette.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadius.pill),
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

/// Ligne de choix d'une branche.
class _BranchTile extends StatelessWidget {
  const _BranchTile({
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
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: selected
              ? palette.primary.withValues(alpha: 0.08)
              : palette.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: selected ? palette.primary : palette.border,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 20,
              color: selected ? palette.primary : palette.textSecondary,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                label,
                style: AppTypography.body.copyWith(color: palette.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
