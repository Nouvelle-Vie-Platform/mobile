import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../theme/app_typography.dart';

/// Pastille de date (jour + mois) utilisée par les cartes d'événement.
class DateBadge extends StatelessWidget {
  const DateBadge({
    super.key,
    required this.day,
    required this.month,
    this.highlighted = true,
  });

  final String day;
  final String month;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final fg = highlighted ? palette.primary : palette.textSecondary;
    return Container(
      width: 56,
      height: 60,
      decoration: BoxDecoration(
        color: highlighted ? palette.infoBg : palette.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(day, style: AppTypography.h3.copyWith(color: fg)),
          Text(
            month.toUpperCase(),
            style: AppTypography.caption.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
