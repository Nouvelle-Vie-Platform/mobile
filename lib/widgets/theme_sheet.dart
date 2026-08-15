import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../l10n/l10n_extension.dart';
import '../models/theme_preferences.dart';
import '../state/theme_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// **Le réglage d'apparence**, dans une feuille modale ouverte depuis l'icône de
/// l'en-tête du Profil.
///
/// **La feuille ne se ferme pas quand on choisit**, et c'est la décision qui
/// gouverne le reste. Elle vit dans le `MaterialApp` : changer le mode la
/// **repeint elle-même**, donc on voit le résultat sous ses doigts et on peut
/// comparer les quatre positions. Une feuille qui se refermerait obligerait à
/// rouvrir pour comparer, c'est-à-dire pour faire ce qu'on était venu faire.
///
/// **Aucun engrenage interne.** Il en existait un tant que ce réglage vivait
/// dans une ligne de la liste du Profil, où deux heures de plus ne tenaient pas.
/// La feuille lève cette contrainte : les heures s'affichent dès que `Auto` est
/// choisi, et le résumé « Sombre de 19:00 à 06:00 » disparaît avec le repli —
/// deux lignes modifiables le disent mieux qu'une phrase.
///
/// **`Système` et `Auto` se ressemblent et ne font pas la même chose** :
/// `Système` suit le téléphone, `Auto` suit une règle horaire de l'application
/// que le téléphone ignore. Les deux heures affichées sous `Auto` sont ce qui
/// les distingue à l'œil.
Future<void> showThemeSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    // Le contenu grandit de deux lignes quand `Auto` est choisi : sans cela la
    // feuille garderait sa hauteur initiale et rognerait les heures.
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const ThemeSheet(),
  );
}

class ThemeSheet extends ConsumerWidget {
  const ThemeSheet({super.key});

  /// Clés de test : une par position, plus les deux heures.
  static Key segmentKey(ThemeChoice choice) => Key('theme_${choice.key}');
  static const Key darkFromKey = Key('theme_dark_from');
  static const Key lightFromKey = Key('theme_light_from');

  static IconData iconOf(ThemeChoice choice) => switch (choice) {
        ThemeChoice.light => Icons.light_mode_outlined,
        // Un téléphone pour « suit l'appareil », une horloge pour « suit
        // l'heure » : c'est le seul couple d'icônes qui sépare les deux sans
        // légende.
        ThemeChoice.system => Icons.phone_iphone,
        ThemeChoice.auto => Icons.schedule,
        ThemeChoice.dark => Icons.dark_mode_outlined,
      };

  static String labelOf(AppLocalizations l, ThemeChoice choice) =>
      switch (choice) {
        ThemeChoice.light => l.themeLight,
        ThemeChoice.system => l.themeSystem,
        ThemeChoice.auto => l.themeAuto,
        ThemeChoice.dark => l.themeDark,
      };

  Future<void> _pick(
    BuildContext context,
    WidgetRef ref,
    DayTime current, {
    required bool dark,
  }) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: current.toTimeOfDay(),
    );
    if (picked == null) return;
    final dao = ref.read(settingsDaoProvider);
    final time = DayTime.fromTimeOfDay(picked);
    await (dark ? dao.setDarkFrom(time) : dao.setLightFrom(time));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final palette = context.palette;
    final preferences =
        ref.watch(themePreferencesProvider).value ?? const ThemePreferences();
    final isAuto = preferences.choice == ThemeChoice.auto;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.themeSectionTitle,
              style: AppTypography.h5.copyWith(color: palette.textPrimary),
            ),
            const SizedBox(height: AppSpacing.lg),
            _Segments(
              selected: preferences.choice,
              onSelect: (choice) =>
                  ref.read(settingsDaoProvider).setThemeChoice(choice),
            ),
            if (isAuto) ...[
              const SizedBox(height: AppSpacing.lg),
              _HourRow(
                key: darkFromKey,
                label: l.themeDarkFrom,
                time: preferences.darkFrom,
                onTap: () =>
                    _pick(context, ref, preferences.darkFrom, dark: true),
              ),
              _HourRow(
                key: lightFromKey,
                label: l.themeLightFrom,
                time: preferences.lightFrom,
                onTap: () =>
                    _pick(context, ref, preferences.lightFrom, dark: false),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Le contrôle segmenté : quatre pastilles à icône et libellé.
class _Segments extends StatelessWidget {
  const _Segments({required this.selected, required this.onSelect});

  final ThemeChoice selected;
  final ValueChanged<ThemeChoice> onSelect;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final palette = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          for (final choice in ThemeChoice.values)
            Expanded(
              child: _Segment(
                key: ThemeSheet.segmentKey(choice),
                icon: ThemeSheet.iconOf(choice),
                label: ThemeSheet.labelOf(l, choice),
                selected: choice == selected,
                onTap: () => onSelect(choice),
              ),
            ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tint = selected ? Colors.white : palette.textSecondary;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: const EdgeInsets.all(3),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: tint),
            const SizedBox(height: 2),
            // `FittedBox` : « Système » est plus long que les trois autres, et
            // quatre segments sur un écran étroit ne laissent pas de marge.
            FittedBox(
              child: Text(
                label,
                style: AppTypography.caption.copyWith(
                  color: tint,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Une ligne d'heure, qui ouvre le sélecteur du système.
class _HourRow extends StatelessWidget {
  const _HourRow({
    super.key,
    required this.label,
    required this.time,
    required this.onTap,
  });

  final String label;
  final DayTime time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTypography.body.copyWith(color: palette.textPrimary),
              ),
            ),
            Text(
              time.key,
              style:
                  AppTypography.bodyStrong.copyWith(color: AppColors.primary),
            ),
            const SizedBox(width: AppSpacing.xs),
            Icon(Icons.chevron_right, size: 18, color: palette.textSecondary),
          ],
        ),
      ),
    );
  }
}
