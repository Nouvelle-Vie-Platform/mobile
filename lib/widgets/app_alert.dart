import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Types d'alerte issus de la section « Alertes ».
enum AppAlertType { success, info, warning, danger }

/// Bandeau d'alerte avec icône, titre et message.
class AppAlert extends StatelessWidget {
  const AppAlert({
    super.key,
    required this.type,
    required this.title,
    required this.message,
  });

  final AppAlertType type;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = _palette(context, type);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: AppRadius.card,
        border: Border.all(color: palette.foreground.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(palette.icon, color: palette.foreground, size: 22),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTypography.bodyStrong
                        .copyWith(color: palette.foreground)),
                const SizedBox(height: 2),
                Text(message,
                    style: AppTypography.body
                        .copyWith(color: context.palette.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  _AlertPalette _palette(BuildContext context, AppAlertType type) {
    final p = context.palette;
    switch (type) {
      case AppAlertType.success:
        return _AlertPalette(p.successBg, AppColors.success, Icons.check_circle);
      case AppAlertType.info:
        return _AlertPalette(p.infoBg, p.primary, Icons.info);
      case AppAlertType.warning:
        return _AlertPalette(
            p.warningBg, AppColors.warning, Icons.warning_amber_rounded);
      case AppAlertType.danger:
        return _AlertPalette(p.dangerBg, AppColors.danger, Icons.error);
    }
  }
}

class _AlertPalette {
  const _AlertPalette(this.background, this.foreground, this.icon);
  final Color background;
  final Color foreground;
  final IconData icon;
}
