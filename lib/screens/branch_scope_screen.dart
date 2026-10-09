import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n_extension.dart';
import '../state/branch_scope_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_card.dart';
import '../widgets/brand_app_bar.dart';

/// **Mon assemblée** (`/settings/branch`) — la préférence de branche (#184).
///
/// Elle vivait en tête de « Qualité & données », faute d'une autre page
/// réglée **et atteignable par un invité** ; elle y était déclarée de passage,
/// « autonome, elle ne lit rien de cet écran », et a déménagé telle quelle. La
/// route reste **ouverte** (hors `memberOnlyRoutes`) : le réglage doit servir
/// au porteur d'appareil anonyme.
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
/// 3. **ça a cassé un test qui passait.** Le test d'écran est tombé sur « A
///    Timer is still pending » : sous `flutter test`, `AppEnv.useBackend` vaut
///    vrai, le miroir réel partait sur une socket que le harnais refuse, et Dio
///    laissait derrière lui sa minuterie de délai.
///
/// `hydrateFromAccount()` reste sur `BranchScope`, vérifiée par
/// `test/data/branch_scope_test.dart`, et **attend son appelant** : le démarrage
/// de session (`lib/app.dart` / `lib/state/auth_providers.dart`), qui est sa
/// vraie place — une seule fois par session, là où un appel réseau est déjà
/// attendu. Ce n'est pas un oubli.
///
/// Corollaire du même souci : la sélection et la liste se lisent
/// **ponctuellement** et non en flux Drift, parce qu'un `QueryStream` laisse
/// une minuterie pendante qui tue les tests d'écran. Voir
/// `preferredBranchProvider`. C'est donc [_BranchScopeScreenState._choose] qui
/// invalide après un geste.
class BranchScopeScreen extends ConsumerStatefulWidget {
  const BranchScopeScreen({super.key});

  /// Clé de test d'une option d'assemblée. `null` = « toutes les assemblées ».
  static Key optionKey(int? branchId) =>
      Key('branch_scope_${branchId ?? 'all'}');

  @override
  ConsumerState<BranchScopeScreen> createState() => _BranchScopeScreenState();
}

/// **Un `State` sans `initState`**, et c'est le point : il n'existe que pour le
/// `mounted` de [_BranchScopeScreenState._choose]. Rien ne part au montage.
class _BranchScopeScreenState extends ConsumerState<BranchScopeScreen> {
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final palette = context.palette;
    final selected = ref.watch(preferredBranchProvider).value;
    final branches = ref.watch(branchScopeChoicesProvider).value ?? const [];

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: BrandAppBar(title: l.branchScopeTitle),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: [
          Text(
            context.words.branchScopeLead,
            style: AppTypography.body.copyWith(color: palette.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                // **« Toutes » est toujours là**, même quand la liste n'est pas
                // arrivée : c'est le défaut, et un panneau qui ne proposerait
                // rien du tout donnerait l'impression d'un réglage en panne.
                _ChoiceOption(
                  key: BranchScopeScreen.optionKey(null),
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
                  _ChoiceOption(
                    key: BranchScopeScreen.optionKey(branch.id),
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
      ),
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

/// Une ligne d'assemblée : un rond de sélection, le nom, et la place réservée
/// pour la phrase d'impact.
class _ChoiceOption extends StatelessWidget {
  const _ChoiceOption({
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
