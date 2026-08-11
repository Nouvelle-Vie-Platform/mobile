import 'package:flutter/material.dart';

import '../../l10n/l10n_extension.dart';
import '../../models/announcement_view.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../cards/announcement_card.dart';

/// Feuille modale listant **tous** les statuts, d'où l'on saute à n'importe
/// lequel.
///
/// Elle glisse par-dessus la visionneuse plutôt que de la remplacer par une
/// route : le statut courant reste en place derrière, simplement mis en pause,
/// et on reprend exactement où on en était en refermant.
///
/// Renvoie l'index choisi, ou `null` si la feuille est refermée sans choix.
Future<int?> showStatusListSheet(
  BuildContext context, {
  required List<AnnouncementView> statuses,
  required int currentIndex,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _StatusListSheet(
      statuses: statuses,
      currentIndex: currentIndex,
    ),
  );
}

class _StatusListSheet extends StatelessWidget {
  const _StatusListSheet({required this.statuses, required this.currentIndex});

  final List<AnnouncementView> statuses;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.xl),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.sm),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: palette.textSecondary.withValues(alpha: 0.4),
                  borderRadius: const BorderRadius.all(
                    Radius.circular(AppRadius.pill),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    context.l10n.statusListTitle,
                    style: AppTypography.h4,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: EdgeInsets.only(
                    bottom:
                        MediaQuery.paddingOf(context).bottom + AppSpacing.lg,
                  ),
                  itemCount: statuses.length,
                  itemBuilder: (context, index) {
                    final selected = index == currentIndex;
                    return ColoredBox(
                      color: selected
                          ? palette.textPrimary.withValues(alpha: 0.06)
                          : Colors.transparent,
                      child: AnnouncementCard(
                        announcement: statuses[index],
                        compact: true,
                        onTap: () => Navigator.of(context).pop(index),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
