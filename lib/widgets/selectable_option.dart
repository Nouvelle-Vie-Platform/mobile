import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Ligne à choix unique (radio) — section « Composants d'interface ».
class RadioOptionTile extends StatelessWidget {
  const RadioOptionTile({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.card,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          children: [
            Expanded(child: Text(label, style: AppTypography.bodyLarge)),
            _RadioDot(selected: selected),
          ],
        ),
      ),
    );
  }
}

class _RadioDot extends StatelessWidget {
  const _RadioDot({required this.selected});
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? palette.primary : palette.border,
          width: 2,
        ),
      ),
      child: selected
          ? Center(
              child: Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  color: palette.primary,
                  shape: BoxShape.circle,
                ),
              ),
            )
          : null,
    );
  }
}

/// Option de montant de don (grille 2 colonnes).
class AmountOption extends StatelessWidget {
  const AmountOption({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
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

/// Option de méthode de paiement (icône + libellé + indicateur de choix).
class PaymentOption extends StatelessWidget {
  const PaymentOption({
    super.key,
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.selected,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final Color iconColor;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: AppRadius.field,
          border: Border.all(
            color: selected ? palette.primary : palette.border,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(label, style: AppTypography.bodyLarge)),
            _RadioDot(selected: selected),
          ],
        ),
      ),
    );
  }
}
