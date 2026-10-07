import 'package:flutter/material.dart';

import '../../l10n/l10n_extension.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

/// **La rangée « Archivées (N) »**, en haut de la liste (#146). Elle n'existe
/// que s'il y a au moins une discussion archivée.
class ArchivedChatsRow extends StatelessWidget {
  const ArchivedChatsRow({super.key, required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  static const Key rowKey = Key('archived_chats_row');

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      key: rowKey,
      borderRadius: AppRadius.card,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Icon(Icons.archive_outlined, color: palette.textSecondary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                context.l10n.chatArchivedRow(count),
                style: AppTypography.bodyStrong,
              ),
            ),
            Icon(Icons.chevron_right, color: palette.textSecondary),
          ],
        ),
      ),
    );
  }
}
