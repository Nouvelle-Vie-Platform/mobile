import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../app_card.dart';

/// Carte de note spirituelle (titre + aperçu).
class NoteCard extends StatelessWidget {
  const NoteCard({super.key, required this.note, this.onTap});

  final SpiritualNote note;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(note.title, style: AppTypography.h5),
          const SizedBox(height: AppSpacing.sm),
          Text(note.preview,
              style: AppTypography.body
                  .copyWith(color: context.palette.textSecondary)),
        ],
      ),
    );
  }
}
