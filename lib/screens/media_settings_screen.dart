import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../l10n/l10n_extension.dart';
import '../models/media_preferences.dart';
import '../state/media_settings_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_card.dart';
import '../widgets/brand_app_bar.dart';

/// **Qualité & données** (`/settings/media`).
///
/// Trois usages, quatre paliers chacun. Ce que le panneau promet réellement,
/// aujourd'hui, est plus étroit que ce qu'il montre — et il faut le savoir
/// avant d'y toucher :
///
/// - **l'écoute** agit sur **iOS** (`AVPlayer.preferredPeakBitRate`) et sur le
///   **web** (`hls.js`, `autoLevelCapping`), par `BitrateCapController`, câblé
///   dans `main.dart` — et sur **Android** par l'URL du rendu, `just_audio` y
///   ignorant le plafond. Seul le mode `auto` reste sans effet sur Android ;
/// - **le direct** n'a pas de lecteur — `LiveScreen` affiche une vignette
///   décorative et un compteur de spectateurs en dur ;
/// - **le téléchargement** n'existe pas, et `docs/mediatheque-en-ligne.md` §2
///   en fait un refus **documenté**, pas un reste-à-faire.
///
/// Les trois sont néanmoins réglables et enregistrés, à la demande explicite du
/// produit. Le jour où l'un des deux derniers existera, la préférence sera déjà
/// là et il n'y aura rien à changer ici.
///
/// **Les chiffres ne s'inventent pas.** Les Mo par heure viennent des débits de
/// `MediaQuality`, eux-mêmes recopiés de l'échelle du transcodeur. Écrire une
/// valeur en dur dans une traduction la ferait mentir à la première fois qu'on
/// touche à l'échelle.
class MediaSettingsScreen extends ConsumerWidget {
  const MediaSettingsScreen({super.key});

  /// Clés de test : une par usage, pour cibler le bon groupe d'options.
  static Key optionKey(MediaUsage usage, MediaQuality quality) =>
      Key('media_${usage.key}_${quality.key}');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final palette = context.palette;
    final preferences =
        ref.watch(mediaPreferencesProvider).value ?? const MediaPreferences();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: BrandAppBar(title: l.mediaSettingsTitle),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: [
          Text(
            l.mediaSettingsLead,
            style: AppTypography.body.copyWith(color: palette.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xl),
          for (final usage in MediaUsage.values) ...[
            _UsageSection(
              usage: usage,
              selected: preferences.of(usage),
              onSelect: (quality) =>
                  ref.read(settingsDaoProvider).setMediaQuality(usage, quality),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ],
      ),
    );
  }
}

/// Un usage et ses quatre paliers.
class _UsageSection extends StatelessWidget {
  const _UsageSection({
    required this.usage,
    required this.selected,
    required this.onSelect,
  });

  final MediaUsage usage;
  final MediaQuality selected;
  final ValueChanged<MediaQuality> onSelect;

  String _title(AppLocalizations l) => switch (usage) {
        MediaUsage.streaming => l.mediaSettingsStreaming,
        MediaUsage.live => l.mediaSettingsLive,
        MediaUsage.download => l.mediaSettingsDownload,
      };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _title(l),
          style: AppTypography.bodyStrong.copyWith(color: palette.textPrimary),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final quality in MediaQuality.values)
                _Option(
                  key: MediaSettingsScreen.optionKey(usage, quality),
                  quality: quality,
                  selected: quality == selected,
                  last: quality == MediaQuality.values.last,
                  onTap: () => onSelect(quality),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// **Le sélecteur maison** : un titre, et juste en dessous la phrase qui dit ce
/// que ce palier coûte et ce qu'il fait perdre.
///
/// Une liste de lignes plutôt qu'un `DropdownButton` : le menu déroulant
/// masquerait justement la phrase d'impact tant qu'on ne l'ouvre pas, alors que
/// c'est elle qui fait choisir. Ici les quatre arbitrages sont lisibles d'un
/// seul regard, sans geste préalable.
class _Option extends StatelessWidget {
  const _Option({
    super.key,
    required this.quality,
    required this.selected,
    required this.last,
    required this.onTap,
  });

  final MediaQuality quality;
  final bool selected;
  final bool last;
  final VoidCallback onTap;

  String _label(AppLocalizations l) => switch (quality) {
        MediaQuality.auto => l.mediaQualityAuto,
        MediaQuality.low => l.mediaQualityLow,
        MediaQuality.mid => l.mediaQualityMid,
        MediaQuality.high => l.mediaQualityHigh,
      };

  /// Le chiffre vient de l'échelle, jamais d'une chaîne écrite à la main.
  String _impact(AppLocalizations l) {
    final mb = quality.megabytesPerHour;
    return switch (quality) {
      MediaQuality.auto => l.mediaQualityImpactAuto(mb),
      MediaQuality.low => l.mediaQualityImpactLow(mb),
      MediaQuality.mid => l.mediaQualityImpactMid(mb),
      MediaQuality.high => l.mediaQualityImpactHigh(mb),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final palette = context.palette;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          border: last
              ? null
              : Border(bottom: BorderSide(color: palette.border, width: 0.6)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Le rond de sélection occupe sa place même quand il est vide :
            // sans cela les libellés se décaleraient d'une ligne à l'autre.
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 20,
                color: selected ? AppColors.primary : palette.textSecondary,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _label(l),
                    style: AppTypography.body.copyWith(
                      color: palette.textPrimary,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _impact(l),
                    style: AppTypography.caption
                        .copyWith(color: palette.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
