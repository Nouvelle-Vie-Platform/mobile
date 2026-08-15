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

/// **Le réglage d'apparence**, dans la liste du Profil.
///
/// Un bloc et non une ligne : quatre positions, un engrenage et deux heures ne
/// tiennent pas dans un `MenuTile` à interrupteur. Il reste **sur place**
/// plutôt que d'ouvrir un écran — on juge des couleurs sur l'écran qu'on
/// regarde, et basculer en sombre est le geste le plus fréquent des trois.
///
/// **Quatre positions, dont deux qui se ressemblent.** « Système » suit le
/// réglage du téléphone ; « Auto » suit une règle horaire de l'application, que
/// le téléphone ignore. Elles peuvent donc se contredire, et c'est pour cela que
/// le résumé « Sombre de 19:00 à 06:00 » s'affiche sous le sélecteur en mode
/// Auto : sans lui, rien ne distinguerait les deux à l'œil.
///
/// **L'engrenage n'apparaît qu'en Auto**, et ne fait que déplier les deux
/// heures. Un engrenage visible en permanence promettrait des réglages qui
/// n'existent pas pour les trois autres positions.
class ThemeChoiceTile extends ConsumerStatefulWidget {
  const ThemeChoiceTile({super.key});

  /// Clés de test : une par position, plus l'engrenage et les deux heures.
  static Key segmentKey(ThemeChoice choice) => Key('theme_${choice.key}');
  static const Key gearKey = Key('theme_gear');
  static const Key darkFromKey = Key('theme_dark_from');
  static const Key lightFromKey = Key('theme_light_from');

  @override
  ConsumerState<ThemeChoiceTile> createState() => _ThemeChoiceTileState();
}

class _ThemeChoiceTileState extends ConsumerState<ThemeChoiceTile> {
  bool _hoursOpen = false;

  IconData _icon(ThemeChoice choice) => switch (choice) {
        ThemeChoice.light => Icons.light_mode_outlined,
        // Un téléphone pour « suit l'appareil », une horloge pour « suit
        // l'heure » : c'est le seul couple d'icônes qui sépare les deux sans
        // légende.
        ThemeChoice.system => Icons.phone_iphone,
        ThemeChoice.auto => Icons.schedule,
        ThemeChoice.dark => Icons.dark_mode_outlined,
      };

  String _label(AppLocalizations l, ThemeChoice choice) => switch (choice) {
        ThemeChoice.light => l.themeLight,
        ThemeChoice.system => l.themeSystem,
        ThemeChoice.auto => l.themeAuto,
        ThemeChoice.dark => l.themeDark,
      };

  Future<void> _pick(DayTime current, {required bool dark}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: current.toTimeOfDay(),
    );
    if (picked == null || !mounted) return;
    final dao = ref.read(settingsDaoProvider);
    final time = DayTime.fromTimeOfDay(picked);
    await (dark ? dao.setDarkFrom(time) : dao.setLightFrom(time));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final palette = context.palette;
    final preferences =
        ref.watch(themePreferencesProvider).value ?? const ThemePreferences();
    final isAuto = preferences.choice == ThemeChoice.auto;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.dark_mode_outlined,
                  size: 22, color: palette.textSecondary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  l.themeSectionTitle,
                  style:
                      AppTypography.body.copyWith(color: palette.textPrimary),
                ),
              ),
              // L'engrenage n'existe qu'en Auto — voir l'en-tête.
              if (isAuto)
                IconButton(
                  key: ThemeChoiceTile.gearKey,
                  icon: const Icon(Icons.tune, size: 20),
                  color: _hoursOpen ? AppColors.primary : palette.textSecondary,
                  tooltip: l.themeAutoHoursTitle,
                  onPressed: () => setState(() => _hoursOpen = !_hoursOpen),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _Segments(
            selected: preferences.choice,
            icon: _icon,
            label: (choice) => _label(l, choice),
            onSelect: (choice) =>
                ref.read(settingsDaoProvider).setThemeChoice(choice),
          ),
          if (isAuto) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              l.themeAutoHint(
                  preferences.darkFrom.key, preferences.lightFrom.key),
              style:
                  AppTypography.caption.copyWith(color: palette.textSecondary),
            ),
          ],
          if (isAuto && _hoursOpen) ...[
            const SizedBox(height: AppSpacing.sm),
            _HourRow(
              key: ThemeChoiceTile.darkFromKey,
              label: l.themeDarkFrom,
              time: preferences.darkFrom,
              onTap: () => _pick(preferences.darkFrom, dark: true),
            ),
            _HourRow(
              key: ThemeChoiceTile.lightFromKey,
              label: l.themeLightFrom,
              time: preferences.lightFrom,
              onTap: () => _pick(preferences.lightFrom, dark: false),
            ),
          ],
        ],
      ),
    );
  }
}

/// Le contrôle segmenté : quatre pastilles à icône et libellé.
class _Segments extends StatelessWidget {
  const _Segments({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onSelect,
  });

  final ThemeChoice selected;
  final IconData Function(ThemeChoice) icon;
  final String Function(ThemeChoice) label;
  final ValueChanged<ThemeChoice> onSelect;

  @override
  Widget build(BuildContext context) {
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
                key: ThemeChoiceTile.segmentKey(choice),
                icon: icon(choice),
                label: label(choice),
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
            Icon(icon, size: 18, color: tint),
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
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style:
                    AppTypography.body.copyWith(color: palette.textSecondary),
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
