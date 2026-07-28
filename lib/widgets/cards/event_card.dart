import 'package:flutter/material.dart';

import '../../l10n/l10n_extension.dart';
import '../../models/models.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/event_time.dart';
import '../../utils/i18n_text.dart';
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
    // Le modèle ne porte plus que des données : date, heure et intitulé sont
    // formatés ici, dans la locale courante.
    final locale = context.l10n.localeName;
    final category = event.category;

    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          DateBadge(
            day: formatEventDay(event, locale),
            month: formatEventMonth(event, locale),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (category != null) ...[
                  AppChip(
                    pick(category.label, locale),
                    tone: eventChipTone(category),
                  ),
                  const SizedBox(height: 6),
                ],
                Text(pick(event.title, locale), style: AppTypography.h5),
                const SizedBox(height: 6),
                Row(
                  children: [
                    IconText(
                      icon: Icons.schedule,
                      label: formatEventTime(event, locale),
                    ),
                    if (event.place != null) ...[
                      const SizedBox(width: AppSpacing.md),
                      Flexible(
                        child: IconText(
                            icon: Icons.place_outlined, label: event.place!),
                      ),
                    ],
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

/// Habillage d'une catégorie d'évènement.
///
/// [EventCategory.tone] est une **clé servie par le back**, pas une couleur :
/// une clé inconnue (catégorie ajoutée côté serveur avant l'app) retombe sur
/// le ton neutre plutôt que de faire planter la carte.
AppChipTone eventChipTone(EventCategory category) =>
    AppChipTone.values.firstWhere((t) => t.name == category.tone,
        orElse: () => AppChipTone.neutral);
