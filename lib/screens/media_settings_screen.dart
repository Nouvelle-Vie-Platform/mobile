import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/settings_dao.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n_extension.dart';
import '../models/media_preferences.dart';
import '../state/media_settings_providers.dart';
import '../state/theme_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/brand_app_bar.dart';
import '../widgets/quality_arc.dart';

/// **Qualité** (`/settings/media`) — trois onglets, un cadran chacun (#184).
///
/// RADIO · ÉCOUTE · TÉLÉCHARGEMENT. Chaque onglet pose une question en grand,
/// une ligne d'explication, puis le cadran ([QualityArc]) et la consommation
/// du choix. Le choix s'enregistre au toucher, sans bouton « valider ».
///
/// Ce que chaque réglage fait réellement — et ce qu'il ne fait pas — est écrit
/// dans `CLAUDE.md`, « Les réglages média » :
///
/// - **la radio** agit partout, par l'URL que `RadioListening` ouvre
///   (`RadioAntenna.streamUrlFor`) ; changer pendant l'écoute relance
///   l'antenne, et c'est `RadioListening` qui écoute le réglage, pas cet écran ;
/// - **l'écoute** agit sur iOS et le web par le plafond
///   (`BitrateCapController`), sur Android par l'URL du rendu ;
/// - **le téléchargement** se range sans piloter de débit
///   (`docs/mediatheque-en-ligne.md` §2) ; son interrupteur de réseau, lui,
///   alimente `DownloadManager.mobileDataAllowed`.
///
/// **Le direct n'est plus réglable** : aucun lecteur ne lisait son palier.
/// **Mon assemblée** a quitté cette page pour la sienne (`BranchScopeScreen`).
///
/// **En-tête : `BrandAppBar`**, comme toutes les pages poussées depuis le
/// Profil (confidentialité, téléchargements, suppression) — même retour, même
/// bandeau. L'air de la maquette commence dessous, sur `AppBackground`, dont
/// le dégradé clair est déjà presque blanc-lavande.
///
/// **Les onglets ne glissent pas** : le curseur en arc se tire à
/// l'horizontale, et un `TabBarView` glissant lui disputerait le geste.
///
/// **Les chiffres ne s'inventent pas.** Les Mo par heure viennent des débits
/// de `MediaQuality` et `RadioQuality`, jamais d'une traduction.
class MediaSettingsScreen extends ConsumerWidget {
  const MediaSettingsScreen({super.key});

  /// Clé de test d'une pastille, par usage et par palier.
  static Key optionKey(MediaUsage usage, MediaQuality quality) =>
      Key('media_${usage.key}_${quality.key}');

  /// Clé de test d'une pastille de la radio.
  static Key radioOptionKey(RadioQuality quality) =>
      Key('media_${MediaUsage.radio.key}_${quality.key}');

  /// Clé de test du curseur en arc d'un usage.
  static Key sliderKey(MediaUsage usage) => Key('media_${usage.key}_slider');

  /// Le toggle « Télécharger en données mobiles » (F8).
  static const Key downloadOnCellularKey = Key('media_download_on_cellular');

  /// L'ordre de l'arc pour l'écoute et le téléchargement, du plus économe au
  /// plus riche — Automatique avant Haute, comme pour la radio. L'ordre de
  /// l'enum, lui, ne bouge pas.
  static const List<MediaQuality> arcOrder = [
    MediaQuality.low,
    MediaQuality.mid,
    MediaQuality.auto,
    MediaQuality.high,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final palette = context.palette;
    final preferences =
        ref.watch(mediaPreferencesProvider).value ?? const MediaPreferences();
    final dao = ref.read(settingsDaoProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: BrandAppBar(title: l.mediaSettingsTitle),
        body: Column(
          children: [
            TabBar(
              labelColor: palette.textPrimary,
              unselectedLabelColor: palette.textSecondary,
              // Trois mots en capitales espacées sur la largeur d'un
              // téléphone étroit : marges serrées, et chaque libellé se
              // réduit plutôt que de se couper.
              labelPadding: const EdgeInsets.symmetric(horizontal: 4),
              labelStyle: AppTypography.caption.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
              unselectedLabelStyle: AppTypography.caption.copyWith(
                letterSpacing: 1.1,
              ),
              indicatorSize: TabBarIndicatorSize.label,
              indicator: UnderlineTabIndicator(
                borderSide: BorderSide(color: palette.textPrimary, width: 1.5),
              ),
              dividerColor: Colors.transparent,
              tabs: [
                _tab(l.mediaSettingsRadio),
                _tab(l.mediaSettingsListening),
                _tab(l.mediaSettingsDownload),
              ],
            ),
            Expanded(
              child: TabBarView(
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _QualityPage<RadioQuality>(
                    question: l.qualityQuestionRadio,
                    values: RadioQuality.values,
                    selected: preferences.radio,
                    labelOf: (q) => _radioLabel(l, q),
                    iconOf: _radioIcon,
                    keyOf: radioOptionKey,
                    sliderKey: sliderKey(MediaUsage.radio),
                    consumptionOf: (q) => q == RadioQuality.auto
                        ? l.qualityAdaptive
                        : l.qualityPerHour(q.megabytesPerHour),
                    onSelected: dao.setRadioQuality,
                  ),
                  _usagePage(l, MediaUsage.streaming, preferences, dao),
                  _usagePage(
                    l,
                    MediaUsage.download,
                    preferences,
                    dao,
                    footer: _DownloadOnCellularToggle(
                      value: preferences.downloadOnCellular,
                      onChanged: dao.setDownloadOnCellular,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _tab(String label) => Tab(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label.toUpperCase(), maxLines: 1),
        ),
      );

  Widget _usagePage(
    AppLocalizations l,
    MediaUsage usage,
    MediaPreferences preferences,
    SettingsDao dao, {
    Widget? footer,
  }) =>
      _QualityPage<MediaQuality>(
        question: usage == MediaUsage.download
            ? l.qualityQuestionDownload
            : l.qualityQuestionListening,
        values: arcOrder,
        selected: preferences.of(usage),
        labelOf: (q) => _mediaLabel(l, q),
        iconOf: _mediaIcon,
        keyOf: (q) => optionKey(usage, q),
        sliderKey: sliderKey(usage),
        consumptionOf: (q) => q == MediaQuality.auto
            ? l.qualityAdaptive
            : l.qualityPerHour(q.megabytesPerHour),
        onSelected: (q) => dao.setMediaQuality(usage, q),
        footer: footer,
      );

  static String _radioLabel(AppLocalizations l, RadioQuality q) => switch (q) {
        RadioQuality.minimum => l.radioQualityMinimum,
        RadioQuality.economy => l.mediaQualityLow,
        RadioQuality.auto => l.mediaQualityAuto,
        RadioQuality.high => l.mediaQualityHigh,
      };

  static String _mediaLabel(AppLocalizations l, MediaQuality q) => switch (q) {
        MediaQuality.low => l.mediaQualityLow,
        MediaQuality.mid => l.mediaQualityMid,
        MediaQuality.auto => l.mediaQualityAuto,
        MediaQuality.high => l.mediaQualityHigh,
      };

  /// **Un pictogramme par niveau, le même d'un onglet à l'autre** : les barres
  /// de signal disent la quantité (une, deux, trois), la feuille dit
  /// l'économie, l'étincelle dit « l'appli décide ».
  static IconData _radioIcon(RadioQuality q) => switch (q) {
        RadioQuality.minimum => Icons.signal_cellular_alt_1_bar,
        RadioQuality.economy => Icons.eco,
        RadioQuality.auto => Icons.auto_awesome,
        RadioQuality.high => Icons.signal_cellular_alt,
      };

  static IconData _mediaIcon(MediaQuality q) => switch (q) {
        MediaQuality.low => Icons.eco,
        MediaQuality.mid => Icons.signal_cellular_alt_2_bar,
        MediaQuality.auto => Icons.auto_awesome,
        MediaQuality.high => Icons.signal_cellular_alt,
      };
}

/// Un onglet : la question, l'explication, le cadran, la consommation, et le
/// halo qui monte du bas de l'écran.
class _QualityPage<T> extends StatelessWidget {
  const _QualityPage({
    required this.question,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.iconOf,
    required this.keyOf,
    required this.sliderKey,
    required this.consumptionOf,
    required this.onSelected,
    this.footer,
  });

  final String question;
  final List<T> values;
  final T selected;
  final String Function(T value) labelOf;
  final IconData Function(T value) iconOf;
  final Key Function(T value) keyOf;
  final Key sliderKey;
  final String Function(T value) consumptionOf;
  final ValueChanged<T> onSelected;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final palette = context.palette;
    final extra = footer;

    return Stack(
      children: [
        // Le halo : un dégradé radial bleu clair, très diffus, qui monte du
        // bas. Décoratif — il ne prend aucun toucher.
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 380,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.bottomCenter,
                  // Le rayon se compte sur la hauteur de la boîte : à 0,9 le
                  // dégradé s'éteint avant son bord haut, qui sinon se lirait
                  // comme une ligne en travers de l'écran.
                  radius: 0.9,
                  colors: [Color(0x998FB0F5), Color(0x008FB0F5)],
                ),
              ),
            ),
          ),
        ),
        SingleChildScrollView(
          padding: const EdgeInsets.only(
            top: AppSpacing.xxl,
            bottom: AppSpacing.xxl,
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  question,
                  textAlign: TextAlign.center,
                  style: AppTypography.h1.copyWith(
                    fontSize: 34,
                    height: 1.15,
                    fontWeight: FontWeight.w400,
                    color: palette.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  l.qualityLead,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style:
                      AppTypography.body.copyWith(color: palette.textSecondary),
                ),
              ),
              const SizedBox(height: 48),
              QualityArc<T>(
                values: values,
                selected: selected,
                labelOf: labelOf,
                iconOf: iconOf,
                keyOf: keyOf,
                sliderKey: sliderKey,
                semanticsLabel: l.mediaSettings,
                onSelected: onSelected,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                consumptionOf(selected),
                textAlign: TextAlign.center,
                style: AppTypography.bodyLarge.copyWith(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (extra != null) ...[
                const SizedBox(height: AppSpacing.lg),
                extra,
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// L'interrupteur « Télécharger en données mobiles » (F8), sobre, sous la
/// consommation de l'onglet Téléchargement.
///
/// Défaut **désactivé** (wifi seulement) : le sous-titre dit le pourquoi — un
/// réglage réseau se choisit en connaissant ce qu'il coûte.
class _DownloadOnCellularToggle extends StatelessWidget {
  const _DownloadOnCellularToggle({
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final palette = context.palette;

    // Un `SwitchListTile` peint son encre sur le Material le plus proche : sans
    // ce Material transparent, Flutter avertit qu'elle serait masquée.
    return Material(
      type: MaterialType.transparency,
      child: SwitchListTile(
        key: MediaSettingsScreen.downloadOnCellularKey,
        value: value,
        onChanged: onChanged,
        activeThumbColor: AppColors.primary,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        title: Text(
          l.mediaSettingsDownloadOnCellular,
          style: AppTypography.body.copyWith(
            color: palette.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            l.mediaSettingsDownloadOnCellularSubtitle,
            style: AppTypography.caption.copyWith(color: palette.textSecondary),
          ),
        ),
      ),
    );
  }
}
