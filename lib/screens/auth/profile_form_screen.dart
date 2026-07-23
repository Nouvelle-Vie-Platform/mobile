// TODO(#5): écran complet — profil (Frère/Sœur, nom, branche / « Je suis
// nouveau »), skippable, réutilisé pour l'édition.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n_extension.dart';
import '../../models/models.dart';
import '../../router/app_router.dart';
import '../../state/auth_providers.dart';
import '../../theme/app_spacing.dart';

/// `/profile/edit` : complétion (après inscription) et édition du profil.
///
/// Placeholder minimaliste : enregistre un profil factice ou saute l'étape,
/// puis retourne à l'accueil. Accessible en authenticated (garde du routeur).
class ProfileFormScreen extends ConsumerWidget {
  const ProfileFormScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final branches = ref.watch(branchesProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: AppSpacing.screenPadding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l.profileFormTitle),
                const SizedBox(height: AppSpacing.xl),
                FilledButton(
                  onPressed: () => _save(context, ref, branches),
                  child: Text(l.actionSave),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: () => context.goNamed(AppRoute.home),
                  child: Text(l.actionLater),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save(
    BuildContext context,
    WidgetRef ref,
    List<Branch> branches,
  ) async {
    await ref.read(authProvider.notifier).updateProfile(
          title: UserTitle.frere,
          fullName: 'Jean Kossi',
          branchId: branches.isEmpty ? null : branches.first.id,
          status: branches.isEmpty ? UserStatus.nouveau : UserStatus.membre,
        );
    if (!context.mounted) return;
    context.goNamed(AppRoute.home);
  }
}
