import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/settings_dao.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n_extension.dart';
import '../models/media_preferences.dart';
import '../models/message_media.dart' show formatByteSize;
import '../state/chat_media_providers.dart';
import '../state/media_settings_providers.dart';
import '../state/theme_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_card.dart';
import '../widgets/brand_app_bar.dart';
import '../widgets/quality_arc.dart';

/// **Qualité** (`/settings/media`) — quatre onglets, un cadran chacun (#184,
/// puis T3 #225).
///
/// RADIO · ÉCOUTE · TÉLÉCHARGEMENT · MESSAGERIE. Chaque onglet pose une question en grand,
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
///   alimente `DownloadManager.mobileDataAllowed` ;
/// - **la messagerie** (T3, #225) ne règle pas une qualité mais un **moment** :
///   quand les médias reçus descendent sur l'appareil. Elle alimente
///   `MessageMediaQueue`. Son réglage est **à elle** et ne réutilise pas
///   l'interrupteur du téléchargement : autoriser le forfait pour un
///   enseignement d'une heure qu'on a demandé n'est pas autoriser toutes les
///   vidéos qu'un groupe publiera demain. Et son cadran n'a que trois crans,
///   parce qu'il n'y a que trois moments.
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
/// de `MediaQuality` et `RadioQuality`, jamais d'une traduction — et le poids
/// de l'onglet MESSAGERIE est la **somme réelle** des `media_size` que le
/// serveur a mesurés, lue au magasin (`GroupDao.watchMediaToDescend`).
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

  /// Clé de test d'une pastille de l'onglet MESSAGERIE (T3, #225).
  static Key chatMediaOptionKey(ChatMediaDescent descent) =>
      Key('media_chat_${descent.key}');

  /// Clé de test du curseur en arc de l'onglet MESSAGERIE.
  static const Key chatMediaSliderKey = Key('media_chat_slider');

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
      length: 4,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: BrandAppBar(title: l.mediaSettingsTitle),
        body: Column(
          children: [
            TabBar(
              labelColor: palette.textPrimary,
              unselectedLabelColor: palette.textSecondary,
              // Quatre mots en capitales espacées sur la largeur d'un
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
                _tab(l.mediaSettingsMessaging),
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
                    factsOf: (q) => _radioFacts(l, q),
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
                  _chatMediaPage(
                    l,
                    preferences.chatMedia,
                    ref.watch(chatMediaWaitingProvider).value,
                    dao,
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
        factsOf: (q) =>
            _mediaFacts(l, q, download: usage == MediaUsage.download),
        onSelected: (q) => dao.setMediaQuality(usage, q),
        footer: footer,
      );

  /// **L'onglet MESSAGERIE** (T3, #225) : le même cadran, trois crans, et une
  /// carte dont le gros chiffre est **mesuré**.
  ///
  /// [waiting] est `null` tant que le magasin n'a pas répondu — la carte dit
  /// alors « tout est déjà sur l'appareil » plutôt qu'un chiffre deviné.
  Widget _chatMediaPage(
    AppLocalizations l,
    ChatMediaDescent selected,
    ({int count, int bytes})? waiting,
    SettingsDao dao,
  ) =>
      _QualityPage<ChatMediaDescent>(
        question: l.qualityQuestionMessaging,
        lead: l.qualityLeadMessaging,
        values: ChatMediaDescent.values,
        selected: selected,
        labelOf: (d) => _chatMediaLabel(l, d),
        iconOf: _chatMediaIcon,
        keyOf: chatMediaOptionKey,
        sliderKey: chatMediaSliderKey,
        factsOf: (d) => _chatMediaFacts(l, d, waiting),
        onSelected: dao.setChatMediaDescent,
      );

  /// **Le poids qui attend**, et rien d'inventé : la somme des `media_size`
  /// que le serveur a mesurés, pour les médias reçus qui ne sont pas encore
  /// sur l'appareil. Zéro média s'affiche comme une absence, jamais « 0 Mo ».
  ///
  /// Pas de ligne « son » ici : ce réglage ne touche à aucun débit.
  static _Facts _chatMediaFacts(
    AppLocalizations l,
    ChatMediaDescent descent,
    ({int count, int bytes})? waiting,
  ) {
    final count = waiting?.count ?? 0;
    return _Facts(
      headline: count == 0
          ? l.chatMediaNothingWaiting
          : l.chatMediaWaiting(formatByteSize(waiting!.bytes, l.localeName)),
      plan: count == 0 ? null : l.chatMediaWaitingCount(count),
      network: switch (descent) {
        ChatMediaDescent.never => l.chatMediaDescentNeverFact,
        ChatMediaDescent.wifi => l.chatMediaDescentWifiFact,
        ChatMediaDescent.always => l.chatMediaDescentAlwaysFact,
      },
      sound: null,
    );
  }

  static String _chatMediaLabel(AppLocalizations l, ChatMediaDescent d) =>
      switch (d) {
        ChatMediaDescent.never => l.chatMediaDescentNever,
        ChatMediaDescent.wifi => l.chatMediaDescentWifi,
        ChatMediaDescent.always => l.chatMediaDescentAlways,
      };

  /// Pas de barres de signal ici : les trois crans ne disent pas une
  /// *quantité* mais un *réseau*, et le pictogramme doit le dire aussi.
  static Widget _chatMediaIcon(ChatMediaDescent d, double size) => Icon(
        switch (d) {
          ChatMediaDescent.never => Icons.block,
          ChatMediaDescent.wifi => Icons.wifi,
          ChatMediaDescent.always => Icons.signal_cellular_alt,
        },
        color: Colors.white,
        size: size,
      );

  /// **Ce que coûte et ce que donne un choix**, dans les mots de l'auditeur :
  /// le forfait en heures, le réseau qui suffit, le rendu. Les heures se
  /// tirent du débit, jamais d'une traduction.
  static _Facts _radioFacts(AppLocalizations l, RadioQuality q) {
    final hours = _hoursPerGigabyte(q.megabytesPerHour);
    return switch (q) {
      RadioQuality.minimum => _Facts(
          headline: l.qualityPerHour(q.megabytesPerHour),
          plan: l.qualityHoursPerGigabyte(hours),
          network: l.qualityNetworkEdge,
          sound: l.qualitySoundVoice,
        ),
      RadioQuality.economy => _Facts(
          headline: l.qualityPerHour(q.megabytesPerHour),
          plan: l.qualityHoursPerGigabyte(hours),
          network: l.qualityNetworkWeak,
          sound: l.qualitySoundVoiceMusic,
        ),
      RadioQuality.auto => _Facts(
          headline: l.qualityAdaptive,
          plan: l.qualityHoursPerGigabyteAtLeast(hours),
          network: l.qualityNetworkAdaptive,
          sound: l.qualitySoundAdaptive,
        ),
      RadioQuality.high => _Facts(
          headline: l.qualityPerHour(q.megabytesPerHour),
          plan: l.qualityHoursPerGigabyte(hours),
          network: l.qualityNetworkStrong,
          sound: l.qualitySoundFull,
        ),
    };
  }

  /// Le même, pour l'écoute et le téléchargement. Un téléchargement ne
  /// demande aucun réseau en particulier — il prend son temps — : pas de
  /// ligne « réseau » dans cet onglet.
  static _Facts _mediaFacts(
    AppLocalizations l,
    MediaQuality q, {
    required bool download,
  }) {
    final mb = q == MediaQuality.auto
        ? MediaQuality.high.megabytesPerHour
        : q.megabytesPerHour;
    final hours = _hoursPerGigabyte(mb);
    final network = switch (q) {
      MediaQuality.low => l.qualityNetwork3g,
      MediaQuality.mid => l.qualityNetworkGood,
      MediaQuality.auto => l.qualityNetworkListeningAuto,
      MediaQuality.high => l.qualityNetworkStrong,
    };
    return _Facts(
      headline: q == MediaQuality.auto
          ? l.qualityAdaptive
          : l.qualityPerHour(q.megabytesPerHour),
      plan: q == MediaQuality.auto
          ? l.qualityHoursPerGigabyteAtLeast(hours)
          : l.qualityHoursPerGigabyte(hours),
      network: download ? null : network,
      sound: switch (q) {
        MediaQuality.low => l.qualitySoundVoiceMusic,
        MediaQuality.mid => l.qualitySoundClear,
        MediaQuality.auto => l.qualitySoundAdaptive,
        MediaQuality.high => l.qualitySoundFull,
      },
    );
  }

  /// Heures d'écoute que tient 1 Go (1000 Mo) à ce coût horaire.
  static int _hoursPerGigabyte(int megabytesPerHour) =>
      megabytesPerHour <= 0 ? 0 : (1000 / megabytesPerHour).floor();

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

  /// **Des barres de signal pour les paliers fixes, un « A » pour Auto.**
  /// Une, deux, trois barres disent la quantité d'un coup d'œil, et dans le
  /// même ordre que l'arc. Pas d'étincelles pour Auto : c'est devenu le
  /// signe de « l'IA », et ce n'est pas ce que ce choix promet.
  static Widget _radioIcon(RadioQuality q, double size) => switch (q) {
        RadioQuality.minimum => SignalLevelGlyph(level: 1, size: size),
        RadioQuality.economy => SignalLevelGlyph(level: 2, size: size),
        RadioQuality.auto => _autoGlyph(size),
        RadioQuality.high => SignalLevelGlyph(level: 3, size: size),
      };

  static Widget _mediaIcon(MediaQuality q, double size) => switch (q) {
        MediaQuality.low => SignalLevelGlyph(level: 1, size: size),
        MediaQuality.mid => SignalLevelGlyph(level: 2, size: size),
        MediaQuality.auto => _autoGlyph(size),
        MediaQuality.high => SignalLevelGlyph(level: 3, size: size),
      };

  static Widget _autoGlyph(double size) =>
      Icon(Icons.hdr_auto, color: Colors.white, size: size * 1.15);
}

/// Un onglet : la question, l'explication, le cadran, la consommation, et le
/// halo qui monte du bas de l'écran.
/// Ce qu'une carte dit d'un choix. [network] est nul quand le réseau n'a pas
/// d'importance (le téléchargement), [sound] quand le choix ne touche pas au
/// son — l'onglet MESSAGERIE règle un moment, pas un débit.
class _Facts {
  const _Facts({
    required this.headline,
    required this.plan,
    required this.network,
    required this.sound,
  });

  final String headline;

  /// La ligne « forfait ». Nulle quand il n'y a rien à compter (l'onglet
  /// MESSAGERIE quand tout est déjà sur l'appareil).
  final String? plan;
  final String? network;
  final String? sound;
}

class _QualityPage<T> extends ConsumerWidget {
  const _QualityPage({
    required this.question,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.iconOf,
    required this.keyOf,
    required this.sliderKey,
    required this.factsOf,
    required this.onSelected,
    this.lead,
    this.footer,
  });

  final String question;
  final List<T> values;
  final T selected;
  final String Function(T value) labelOf;
  final Widget Function(T value, double size) iconOf;
  final Key Function(T value) keyOf;
  final Key sliderKey;
  final _Facts Function(T value) factsOf;
  final ValueChanged<T> onSelected;

  /// L'explication sous la question. Nulle = celle des trois onglets de
  /// qualité ([AppLocalizations.qualityLead]) ; l'onglet MESSAGERIE ne règle
  /// pas un débit et a donc la sienne.
  final String? lead;
  final Widget? footer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final palette = context.palette;
    final extra = footer;
    // Le réseau de l'instant : `null` tant que l'OS n'a pas répondu, et alors
    // la ligne ne s'affiche pas — jamais un réseau deviné.
    final cellular = ref.watch(onCellularProvider).value;

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
                  colors: [Color(0x598FB0F5), Color(0x008FB0F5)],
                ),
              ),
            ),
          ),
        ),
        // **Le contenu se répartit sur la hauteur** : question en haut,
        // cadran au milieu, carte en bas — sur un grand écran l'air se
        // partage au lieu de s'entasser sous la carte. Sur un petit écran,
        // une hauteur plancher et le défilement prennent le relais.
        LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: SizedBox(
              height: math.max(constraints.maxHeight, 640),
              child: Padding(
                padding: const EdgeInsets.only(
                  top: AppSpacing.xl,
                  bottom: AppSpacing.xl,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
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
                            lead ?? l.qualityLead,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.body
                                .copyWith(color: palette.textSecondary),
                          ),
                        ),
                      ],
                    ),
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
                    Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg),
                          child: _FactsCard(
                            facts: factsOf(selected),
                            now: cellular == null
                                ? null
                                : (cellular
                                    ? l.qualityNowCellular
                                    : l.qualityNowWifi),
                            cellular: cellular ?? false,
                          ),
                        ),
                        if (extra != null) ...[
                          const SizedBox(height: AppSpacing.lg),
                          extra,
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
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

/// **La carte de ce qu'un choix coûte et donne** : un gros chiffre (le coût
/// à l'heure, ou « s'adapte »), puis le forfait en heures, le réseau qui
/// suffit et le rendu, chacun derrière un pictogramme. En pied, le réseau de
/// l'instant, pour que l'auditeur relie le choix à sa situation.
class _FactsCard extends StatelessWidget {
  const _FactsCard({
    required this.facts,
    required this.now,
    required this.cellular,
  });

  final _Facts facts;
  final String? now;
  final bool cellular;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final network = facts.network;
    final plan = facts.plan;
    final sound = facts.sound;
    final current = now;

    Widget row(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  text,
                  style: AppTypography.body.copyWith(
                    color: palette.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        );

    return AppCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            facts.headline,
            style: AppTypography.h3.copyWith(
              color: palette.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (plan != null) row(Icons.data_usage, plan),
          if (network != null) row(Icons.cell_tower, network),
          if (sound != null) row(Icons.graphic_eq, sound),
          if (current != null) ...[
            const SizedBox(height: AppSpacing.md),
            Divider(height: 1, color: palette.border),
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Row(
                children: [
                  Icon(
                    cellular ? Icons.signal_cellular_alt : Icons.wifi,
                    size: 16,
                    color: palette.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    current,
                    style: AppTypography.caption.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
