import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Styles de chip/badge issus de la section « Chips / Badges ».
enum AppChipTone { urgent, event, neu, info, culte, live, neutral }

/// Petit badge coloré (statut, catégorie).
class AppChip extends StatelessWidget {
  const AppChip(
    this.label, {
    super.key,
    this.tone = AppChipTone.info,
    this.showDot = false,
    this.outlined = false,
  });

  final String label;
  final AppChipTone tone;
  final bool showDot;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final palette = _palette(context, tone);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : palette.background,
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.pill)),
        border: outlined
            ? Border.all(color: palette.foreground.withValues(alpha: 0.5))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: palette.foreground,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: palette.foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  _ChipPalette _palette(BuildContext context, AppChipTone tone) {
    final p = context.palette;
    switch (tone) {
      case AppChipTone.urgent:
      case AppChipTone.live:
        return _ChipPalette(p.chipUrgentBg, AppColors.danger);
      case AppChipTone.event:
        return _ChipPalette(p.chipEventBg, AppColors.chipEvent);
      case AppChipTone.neu:
      case AppChipTone.culte:
        return _ChipPalette(p.chipNewBg, AppColors.success);
      case AppChipTone.info:
        return _ChipPalette(p.infoBg, p.primary);
      case AppChipTone.neutral:
        return _ChipPalette(p.surfaceAlt, p.textSecondary);
    }
  }
}

class _ChipPalette {
  const _ChipPalette(this.background, this.foreground);
  final Color background;
  final Color foreground;
}

/// Badge « LIVE » avec pastille pour les flux en direct.
class LiveBadge extends StatelessWidget {
  const LiveBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: const BoxDecoration(
        color: AppColors.danger,
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.sm)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'LIVE',
            style: AppTypography.caption.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Chip de filtre sélectionnable (médiathèque). Sans état interne : la
/// sélection est pilotée par le parent.
class FilterChipButton extends StatelessWidget {
  const FilterChipButton({
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : palette.surface,
          borderRadius: const BorderRadius.all(Radius.circular(AppRadius.pill)),
          border: Border.all(
            color: selected ? AppColors.primary : palette.border,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            color: selected ? Colors.white : palette.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
