import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n_extension.dart';
import '../models/models.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Ligne d'état affichée **sous** la liste des branches : chargement en cours,
/// référentiel vide, ou échec du chargement.
///
/// Ne rend **rien** dès qu'il y a au moins une branche à choisir.
///
/// Le point important est ce qu'elle ne fait pas : jamais d'écran d'erreur
/// plein cadre, jamais de bloc qui empêche de continuer. Les branches viennent
/// du réseau (`GET /sync/branches`) et leur absence est un contretemps, pas une
/// impasse — « Je suis nouveau », lui, ne dépend d'aucun référentiel, et le
/// profil est de toute façon skippable.
class BranchListStatus extends StatelessWidget {
  const BranchListStatus(this.branches, {super.key});

  final AsyncValue<List<Branch>> branches;

  @override
  Widget build(BuildContext context) {
    final loaded = branches.value;
    if (loaded != null && loaded.isNotEmpty) return const SizedBox.shrink();

    final palette = context.palette;
    final style = AppTypography.caption.copyWith(color: palette.textSecondary);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: switch (branches) {
        // Chargement : un simple indicateur, sans libellé — la ligne est
        // fugace et un texte de plus n'apprendrait rien.
        AsyncValue(isLoading: true) => Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(palette.textSecondary),
              ),
            ),
          ),
        AsyncValue(hasError: true) =>
          Text(context.l10n.branchesUnavailable, style: style),
        _ => Text(context.l10n.branchesEmpty, style: style),
      },
    );
  }
}
