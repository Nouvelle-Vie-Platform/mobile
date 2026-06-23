import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../app_card.dart';
import '../app_chip.dart';
import '../date_badge.dart';
import '../icon_text.dart';

/// Carte d'événement « À venir » : pastille de date, titre et méta-infos.
class EventCard extends StatelessWidget {
  const EventCard({super.key, required this.event, this.onTap});

  final ChurchEvent event;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          DateBadge(day: event.day, month: event.month),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (event.tag != null) ...[
                  AppChip(event.tag!, tone: AppChipTone.culte),
                  const SizedBox(height: 6),
                ],
                Text(event.title, style: AppTypography.h5),
                const SizedBox(height: 6),
                Row(
                  children: [
                    IconText(icon: Icons.schedule, label: event.time),
                    const SizedBox(width: AppSpacing.md),
                    Flexible(
                      child: IconText(
                          icon: Icons.place_outlined, label: event.place),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: context.palette.textSecondary),
        ],
      ),
    );
  }
}
