import 'package:flutter/material.dart';

import '../../l10n/l10n_extension.dart';
import '../../models/models.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/relative_time.dart';
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
    final title = announcement.title;
    final body = announcement.body;
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
                relativeTime(context.l10n, announcement.publishedAt),
                style: AppTypography.caption
                    .copyWith(color: palette.textSecondary),
              ),
            ],
          ),
          if (title != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(title, style: AppTypography.h5),
          ],
          if (body != null) ...[
            SizedBox(height: title == null ? AppSpacing.sm : 4),
            Text(
              body,
              style: AppTypography.body.copyWith(color: palette.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}
