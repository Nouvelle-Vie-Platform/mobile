import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../app_card.dart';
import '../app_chip.dart';

/// Carte d'une annonce de l'église (catégorie, date, titre, contenu).
class AnnouncementCard extends StatelessWidget {
  const AnnouncementCard({super.key, required this.announcement, this.onTap});

  final Announcement announcement;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (announcement.tag != null)
                AppChip(announcement.tag!, tone: AppChipTone.info),
              const Spacer(),
              Text(
                announcement.date,
                style: AppTypography.caption
                    .copyWith(color: palette.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(announcement.title, style: AppTypography.h5),
          const SizedBox(height: 4),
          Text(
            announcement.body,
            style: AppTypography.body.copyWith(color: palette.textSecondary),
          ),
        ],
      ),
    );
  }
}
