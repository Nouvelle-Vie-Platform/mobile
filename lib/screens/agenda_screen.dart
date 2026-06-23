import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n_extension.dart';
import '../state/repository_providers.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_button.dart';
import '../widgets/cards/event_card.dart';

/// Écran « Agenda » : calendrier mensuel et liste d'événements.
class AgendaScreen extends ConsumerWidget {
  const AgendaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(eventsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mai 2024')),
      body: ListView(
        padding: AppSpacing.screenPadding,
        children: [
          const SizedBox(height: AppSpacing.md),
          const _MonthCalendar(daysInMonth: 31, leadingBlanks: 2, selected: 24),
          const SizedBox(height: AppSpacing.xl),
          for (final e in events) ...[
            EventCard(event: e),
            const SizedBox(height: AppSpacing.md),
          ],
          const SizedBox(height: AppSpacing.sm),
          AppButton(label: context.l10n.agendaSeeAll, onPressed: () {}),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

/// Grille calendaire d'un mois (en-têtes Lun→Dim, jour sélectionné mis en avant).
class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({
    required this.daysInMonth,
    required this.leadingBlanks,
    required this.selected,
  });

  final int daysInMonth;
  final int leadingBlanks;
  final int selected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = context.l10n;
    final weekdays = [
      l10n.weekdayMon,
      l10n.weekdayTue,
      l10n.weekdayWed,
      l10n.weekdayThu,
      l10n.weekdayFri,
      l10n.weekdaySat,
      l10n.weekdaySun,
    ];
    final cells = <Widget>[
      for (final d in weekdays)
        Center(
          child: Text(d,
              style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w700, color: palette.textSecondary)),
        ),
      for (var i = 0; i < leadingBlanks; i++) const SizedBox.shrink(),
      for (var day = 1; day <= daysInMonth; day++)
        _DayCell(day: day, selected: day == selected),
    ];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: AppRadius.card,
        border: Border.all(color: palette.divider),
      ),
      child: GridView.count(
        crossAxisCount: 7,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 4,
        children: cells,
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, required this.selected});
  final int day;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? context.palette.primary : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Text(
          '$day',
          style: AppTypography.caption.copyWith(
            color: selected ? Colors.white : context.palette.textPrimary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
