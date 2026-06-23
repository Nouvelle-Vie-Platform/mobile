import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../app_card.dart';
import '../app_chip.dart';
import '../icon_text.dart';

/// Carte d'une requête de prière (titre, contenu, statut, compteur).
class PrayerRequestCard extends StatelessWidget {
  const PrayerRequestCard({super.key, required this.request});

  final PrayerRequest request;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(request.title, style: AppTypography.h5)),
              Icon(Icons.more_vert, color: palette.textSecondary, size: 20),
            ],
          ),
          const SizedBox(height: 6),
          Text(request.body,
              style: AppTypography.body.copyWith(color: palette.textSecondary)),
          const SizedBox(height: AppSpacing.md),
          AppChip(
            request.status,
            tone: request.confidential ? AppChipTone.info : AppChipTone.culte,
            showDot: true,
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconText(
                icon: Icons.volunteer_activism_outlined,
                label: '${request.prayingCount} membres en prière',
                color: AppColors.secondary,
              ),
              Text(request.age,
                  style: AppTypography.caption
                      .copyWith(color: palette.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}
