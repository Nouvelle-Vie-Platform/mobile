import 'package:flutter/material.dart';

import '../l10n/l10n_extension.dart';
import '../models/models.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/event_time.dart';
import '../utils/i18n_text.dart';
import '../widgets/app_card.dart';
import '../widgets/app_chip.dart';
import '../widgets/brand_app_bar.dart';
import '../widgets/cards/event_card.dart' show eventChipTone;
import '../widgets/icon_text.dart';

/// Écran de détail d'un [ChurchEvent] : intitulé, catégorie, quand, où et
/// description.
///
/// **Volontairement minimal.** Pas d'inscription, pas de partage, pas d'ajout
/// au calendrier du téléphone : trois fonctionnalités distinctes, chacune avec
/// ses propres questions. L'écran existe pour les accueillir plus tard.
///
/// L'évènement arrive par `extra` (cf. `app_router.dart`), comme les autres
/// écrans de détail du dépôt.
class EventDetailScreen extends StatelessWidget {
  const EventDetailScreen({super.key, required this.event});

  final ChurchEvent event;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final locale = l.intlLocale;
    final palette = context.palette;

    final category = event.category;
    final place = event.place?.trim() ?? '';
    // `body` est nullable **et** peut n'être qu'une traduction vide : `pick`
    // ramène les deux cas à la chaîne vide, un seul test suffit donc ensuite.
    final description =
        event.body == null ? '' : pick(event.body!, locale).trim();

    return Scaffold(
      appBar: BrandAppBar(title: l.eventDetailTitle),
      body: ListView(
        padding: AppSpacing.screenPadding,
        children: [
          const SizedBox(height: AppSpacing.lg),
          // Catégorie facultative : sans elle, le titre remonte simplement.
          if (category != null) ...[
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: AppChip(
                pick(category.label, locale),
                tone: eventChipTone(category),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          Text(pick(event.title, locale), style: AppTypography.h2),
          const SizedBox(height: AppSpacing.lg),
          _WhenAndWhere(event: event, place: place),
          // Section description entière (titre compris) uniquement s'il y a
          // quelque chose à dire : pas de titre orphelin ni de bloc vide.
          if (description.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            Text(l.eventDetailAbout, style: AppTypography.h5),
            const SizedBox(height: AppSpacing.sm),
            Text(
              description,
              style: AppTypography.bodyLarge
                  .copyWith(color: palette.textSecondary, height: 1.4),
            ),
          ],
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

/// Carte « quand / où » : date complète, heure, et lieu s'il est connu.
class _WhenAndWhere extends StatelessWidget {
  const _WhenAndWhere({required this.event, required this.place});

  final ChurchEvent event;

  /// Lieu déjà normalisé par l'écran ; vide = non annoncé, ligne omise.
  final String place;

  @override
  Widget build(BuildContext context) {
    final locale = context.l10n.intlLocale;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoLine(
            icon: Icons.event_outlined,
            label: formatEventFullDate(event, locale),
          ),
          const SizedBox(height: AppSpacing.md),
          // Heure de la **branche**, suffixée de son décalage seulement si le
          // lecteur n'est pas dans le même fuseau : l'évènement est un
          // rassemblement physique, l'heure annoncée est vraie sur place.
          _InfoLine(
            icon: Icons.schedule,
            label: formatEventTime(event, locale),
          ),
          if (place.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _InfoLine(icon: Icons.place_outlined, label: place),
          ],
        ],
      ),
    );
  }
}

/// Ligne d'information de la carte : icône colorée, texte lisible.
class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return IconText(
      icon: icon,
      label: label,
      color: palette.primary,
      style: AppTypography.body.copyWith(color: palette.textPrimary),
    );
  }
}
