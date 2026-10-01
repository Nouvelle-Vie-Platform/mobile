import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../l10n/l10n_extension.dart';
import '../models/media_preferences.dart';
import '../state/branch_scope_providers.dart';
import '../state/media_settings_providers.dart';
import '../state/theme_provider.dart';
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
///
/// ## **Mon assemblée** — une section qui n'est pas de la qualité
///
/// La **préférence de branche** vit ici, en tête du panneau, et il faut savoir
/// que ce n'est pas sa place définitive : elle ne parle ni de débit ni de
/// forfait, et le titre de l'écran (« Qualité & données ») ne la couvre pas.
/// Elle y est parce que c'est le seul écran de réglages **déjà routé** et
/// **atteignable par un invité** — l'onglet Profil suppose un compte, et le
/// réglage doit servir au porteur d'appareil anonyme. Le jour où une route
/// `/settings` générique existera (`lib/router/app_router.dart`), la section
/// déménage telle quelle : elle est autonome, elle ne lit rien de cet écran.
///
/// Elle est **en tête** et non en pied parce que c'est le réglage qui change ce
/// qu'on voit, là où les trois autres changent seulement ce qu'on consomme.
class MediaSettingsScreen extends ConsumerWidget {
  const MediaSettingsScreen({super.key});

  /// Clés de test : une par usage, pour cibler le bon groupe d'options.
  static Key optionKey(MediaUsage usage, MediaQuality quality) =>
      Key('media_${usage.key}_${quality.key}');

  /// Le toggle « Télécharger en données mobiles » (F8).
  static const Key downloadOnCellularKey = Key('media_download_on_cellular');

  /// Clé de test d'une option d'assemblée. `null` = « toutes les assemblées ».
  static Key branchOptionKey(int? branchId) =>
      Key('branch_scope_${branchId ?? 'all'}');

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
          const _BranchScopeSection(),
          const SizedBox(height: AppSpacing.xl),
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
          // **Le réseau autorisé pour les téléchargements** (F8), distinct des
          // qualités : un booléen, pas un palier. Rangé juste sous la section
          // « Téléchargement », qui est la dernière du panneau.
          _DownloadOnCellularToggle(
            value: preferences.downloadOnCellular,
            onChanged: (allowed) =>
                ref.read(settingsDaoProvider).setDownloadOnCellular(allowed),
          ),
        ],
      ),
    );
  }
}

/// **Mon assemblée** — la préférence de branche.
///
/// **Elle ne lit que le magasin local**, et c'est une décision, pas un
/// raccourci. Une première version appelait `BranchScope.hydrateFromAccount()`
/// dans un `initState`, pour adopter au passage ce que le compte porte. Elle est
/// retirée, pour trois raisons qui vont toutes dans le même sens :
///
/// 1. **l'écran n'en a pas besoin.** La préférence est persistée localement : le
///    panneau est exact sans réseau, et c'est précisément ce qui la rend
///    utilisable par un invité dans un taxi ;
/// 2. **le réseau ne peint jamais** (ADR-0026). Faire partir un `GET /auth/me`
///    au montage d'un panneau de réglages, pour ne rien afficher de nouveau,
///    contredit la règle qui gouverne tout le reste de ce dépôt ;
/// 3. **ça a cassé un test qui passait.** `media_settings_screen_test.dart` est
///    tombé sur « A Timer is still pending » : sous `flutter test`,
///    `AppEnv.useBackend` vaut vrai, le miroir réel partait sur une socket que
///    le harnais refuse, et Dio laissait derrière lui sa minuterie de délai. Le
///    fichier porte déjà en en-tête la trace d'un blocage du même genre. Un test
///    existant n'a pas à changer pour accommoder une section nouvelle.
///
/// `hydrateFromAccount()` reste sur `BranchScope`, vérifiée par
/// `test/data/branch_scope_test.dart`, et **attend son appelant** : le démarrage
/// de session (`lib/app.dart` / `lib/state/auth_providers.dart`), qui est sa
/// vraie place — une seule fois par session, là où un appel réseau est déjà
/// attendu. Ce n'est pas un oubli.
///
/// Corollaire du même souci : la sélection et la liste se lisent **ponctuellement**
/// et non en flux Drift, parce qu'un `QueryStream` laisse une minuterie pendante
/// qui tue les tests de cet écran. Voir `preferredBranchProvider`. C'est donc
/// [_BranchScopeSectionState._choose] qui invalide après un geste.
class _BranchScopeSection extends ConsumerStatefulWidget {
  const _BranchScopeSection();

  @override
  ConsumerState<_BranchScopeSection> createState() =>
      _BranchScopeSectionState();
}

/// **Un `State` sans `initState`**, et c'est le point : il n'existe que pour le
/// `mounted` de [_BranchScopeSectionState._choose]. Rien ne part au montage.
class _BranchScopeSectionState extends ConsumerState<_BranchScopeSection> {
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final palette = context.palette;
    final selected = ref.watch(preferredBranchProvider).value;
    final branches = ref.watch(branchScopeChoicesProvider).value ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.branchScopeTitle,
          style: AppTypography.bodyStrong.copyWith(color: palette.textPrimary),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          context.words.branchScopeLead,
          style: AppTypography.caption.copyWith(color: palette.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              // **« Toutes » est toujours là**, même quand la liste n'est pas
              // arrivée : c'est le défaut, et un panneau qui ne proposerait
              // rien du tout donnerait l'impression d'un réglage en panne.
              _BranchOption(
                key: MediaSettingsScreen.branchOptionKey(null),
                label: l.branchScopeAll,
                impact: l.branchScopeAllSubtitle,
                selected: selected == null,
                last: branches.isEmpty,
                onTap: () => _choose(null),
              ),
              if (branches.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.md,
                  ),
                  child: Text(
                    l.branchScopeEmpty,
                    style: AppTypography.caption
                        .copyWith(color: palette.textSecondary),
                  ),
                ),
              for (final branch in branches)
                _BranchOption(
                  key: MediaSettingsScreen.branchOptionKey(branch.id),
                  label: branch.name,
                  impact: null,
                  selected: selected == branch.id,
                  last: branch.id == branches.last.id,
                  onTap: () => _choose(branch.id),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// **Le seul geste de cet écran qui touche la synchronisation.**
  ///
  /// `BranchScope.choose` pose la préférence, marque les quatre collections
  /// concernées « à remplacer » et relance un cycle. Rien n'est attendu ici :
  /// l'écran se repeint dès que le magasin change, et le cycle peut durer.
  void _choose(int? branchId) {
    unawaited(
      ref.read(branchScopeProvider).choose(branchId).then((_) {
        // Le cycle de synchronisation peut durer plus longtemps que l'écran.
        if (!mounted) return;
        // **C'est l'écran qui invalide**, parce que c'est l'écran qui a changé
        // la valeur. La préférence se lit ponctuellement et non en flux (un
        // `QueryStream` Drift laisse une minuterie pendante qui tue les tests
        // d'écran — voir `preferredBranchProvider`), donc la coche ne se
        // déplacerait pas d'elle-même. Une ligne explicite vaut mieux qu'un flux
        // qui coûte un piège.
        ref.invalidate(preferredBranchProvider);
      }).catchError((Object error) {
        // Muet, comme le reste : le réglage local, lui, est déjà posé.
        debugPrint('[branche] choix non propagé : $error');
      }),
    );
  }
}

/// Une ligne d'assemblée, sur le patron exact de [_Option] — même rond de
/// sélection, même séparateur, même place réservée pour la phrase d'impact.
///
/// Un type distinct et non [_Option] paramétré : celui-ci porte un
/// [MediaQuality] et en dérive son libellé et son coût horaire. Les fondre
/// obligerait à passer des chaînes toutes faites à l'un et un enum à l'autre,
/// et ferait entrer un réglage d'affichage dans le type du réglage de débit.
class _BranchOption extends StatelessWidget {
  const _BranchOption({
    super.key,
    required this.label,
    required this.impact,
    required this.selected,
    required this.last,
    required this.onTap,
  });

  final String label;

  /// La phrase qui dit ce que l'option fait voir, `null` quand il n'y a rien à
  /// ajouter — un nom d'assemblée se passe de commentaire.
  final String? impact;
  final bool selected;
  final bool last;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final line = impact;

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
                    label,
                    style: AppTypography.body.copyWith(
                      color: palette.textPrimary,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  if (line != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      line,
                      style: AppTypography.caption
                          .copyWith(color: palette.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// L'interrupteur « Télécharger en données mobiles » (F8).
///
/// Défaut **désactivé** (wifi seulement) : le sous-titre dit le pourquoi, comme
/// les phrases d'impact des paliers de qualité — un réglage réseau se choisit en
/// connaissant ce qu'il coûte.
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

    return AppCard(
      padding: EdgeInsets.zero,
      // La carte peint son propre fond ; un `ListTile` peint le sien sur le
      // Material le plus proche. Sans ce Material transparent intermédiaire,
      // Flutter avertit que l'encre du switch serait masquée.
      child: Material(
        type: MaterialType.transparency,
        child: SwitchListTile(
          key: MediaSettingsScreen.downloadOnCellularKey,
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppColors.primary,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xs,
          ),
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
              style:
                  AppTypography.caption.copyWith(color: palette.textSecondary),
            ),
          ),
        ),
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

  String _title(BuildContext context, AppLocalizations l) => switch (usage) {
        // La seule des trois que le catalogue du portail déclare surchargeable
        // (`surface: 'mobile'`) — d'où `context.words` ici et `l` à côté.
        MediaUsage.streaming => context.words.mediaSettingsStreaming,
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
          _title(context, l),
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
