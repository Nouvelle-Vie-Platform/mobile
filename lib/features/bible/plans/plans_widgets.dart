/// **Les pièces d'écran des plans** (M5, #203) : la navigation, l'en-tête,
/// la barre de défi, les objectifs, la grille de badges (réutilisable par M4)
/// et la carte du plan en cours (section de l'accueil du module).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../l10n/l10n_extension.dart';
import '../../../router/app_router.dart';
import '../../../theme/app_colors.dart';
import '../home/home_view.dart';
import '../../../theme/app_palette.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/app_card.dart';
import '../data/bible_providers.dart';
import '../reader/bible_reader_screen.dart';
import '../shell/bible_route.dart';
import 'plan_logic.dart';
import 'plans_providers.dart';
import 'plans_store.dart';

/// Pousse une page du dossier sur le `Navigator` du routeur — jamais par le
/// `BuildContext` : le geste peut venir d'une feuille ou d'un emplacement.
Future<T?> pushBiblePlansPage<T>(WidgetRef ref, Widget page) => ref
    .read(routerProvider)
    .routerDelegate
    .navigatorKey
    .currentState!
    .push<T>(bibleRoute<T>(page));

/// Ouvre le lecteur sur la première lecture de [day] que je n'ai pas lue
/// (la première, si toutes le sont).
void openPlanDay(WidgetRef ref, PlanDay day) {
  if (day.isEmpty) return;
  final read = ref.read(bibleReadingStateProvider).value;
  final first = day.firstWhere(
    (r) => !(read?.hasRead(r.book, r.chapter) ?? false),
    orElse: () => day.first,
  );
  BibleReaderScreen.push(ref.read(routerProvider), first);
}

/// Le titre d'un plan intégré, par son code.
String builtinPlanTitle(AppLocalizations l, String? code) => switch (code) {
      BuiltinPlanCode.bible1y => l.biblePlansBible1y,
      BuiltinPlanCode.nt90 => l.biblePlansNt90,
      BuiltinPlanCode.ps30 => l.biblePlansPs30,
      BuiltinPlanCode.gospels40 => l.biblePlansGospels40,
      _ => l.biblePlansTitle,
    };

String trackerTitle(AppLocalizations l, PlanTracker t) =>
    t.title ?? builtinPlanTitle(l, t.enrollment.planCode);

/// L'en-tête des pages du dossier, celui de la coquille du module.
class BiblePlansScaffold extends StatelessWidget {
  const BiblePlansScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions = const [],
    this.floatingActionButton,
  });

  final String title;
  final Widget body;
  final List<Widget> actions;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        backgroundColor: BibleHomeColors.header,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        title: Text(
          title,
          style: AppTypography.h5.copyWith(color: Colors.white),
        ),
        actions: actions,
      ),
      body: body,
      floatingActionButton: floatingActionButton,
    );
  }
}

/// Un titre de section.
class PlansSectionTitle extends StatelessWidget {
  const PlansSectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.sm,
        ),
        child: Text(text, style: AppTypography.h5),
      );
}

/// **La barre de défi** : la part faite, et un repère à la part due.
class ChallengeBar extends StatelessWidget {
  const ChallengeBar({super.key, required this.progress});

  final PlanProgress progress;

  static const Key barKey = Key('bible_plans_challenge_bar');

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final palette = context.palette;
    final p = progress;
    final day = (p.elapsed + 1).clamp(1, p.totalDays);
    return Column(
      key: barKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l.biblePlansChallengeBar,
                style: AppTypography.bodyStrong,
              ),
            ),
            Text(
              '${(p.fraction * 100).round()} %',
              style: AppTypography.bodyStrong,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        LayoutBuilder(
          builder: (context, box) => Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: LinearProgressIndicator(
                  value: p.fraction,
                  minHeight: 10,
                  color: AppColors.accent,
                  backgroundColor: palette.divider,
                ),
              ),
              if (p.started && !p.finished)
                Positioned(
                  left: (box.maxWidth * p.expectedFraction - 1).clamp(
                    0,
                    box.maxWidth - 2,
                  ),
                  top: -3,
                  child: Container(
                    width: 2,
                    height: 16,
                    color: palette.primary,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          p.finished
              ? l.biblePlansFinished
              : '${l.biblePlansDayOf(day, p.totalDays)} · ${l.biblePlansStreak(p.streak)}',
          style: AppTypography.caption.copyWith(color: palette.textSecondary),
        ),
      ],
    );
  }
}

/// **Les objectifs** du plan : quatre pastilles.
class PlanGoals extends StatelessWidget {
  const PlanGoals({super.key, required this.progress});

  final PlanProgress progress;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = progress;
    final goals = [
      (Icons.today, l.biblePlansGoalToday, p.started && p.todayDone),
      (Icons.local_fire_department, l.biblePlansGoalWeek, p.longestRun >= 7),
      (Icons.flag_outlined, l.biblePlansGoalHalf, p.fraction >= 0.5),
      (Icons.emoji_events_outlined, l.biblePlansGoalDone, p.finished),
    ];
    return Row(
      children: [
        for (final (icon, label, done) in goals)
          Expanded(
            child: BibleMedal(icon: icon, label: label, earned: done),
          ),
      ],
    );
  }
}

/// Une médaille : gagnée en couleur, cadenas sinon (badges de plans, de
/// quiz dans Mon espace, objectifs).
class BibleMedal extends StatelessWidget {
  const BibleMedal({
    super.key,
    required this.icon,
    required this.label,
    required this.earned,
    this.hexagon = false,
  });

  final IconData icon;
  final String label;
  final bool earned;
  final bool hexagon;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final fill = earned ? AppColors.accent : palette.divider;
    final fg = earned ? AppColors.primary : palette.textSecondary;
    return Semantics(
      label: label,
      selected: earned,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: ShapeDecoration(
              color: fill,
              shape: hexagon
                  ? const StarBorder.polygon(sides: 6, pointRounding: 0.3)
                  : const CircleBorder(),
            ),
            child: Icon(
              earned ? icon : Icons.lock_outline,
              color: fg,
              size: 22,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption.copyWith(color: palette.textSecondary),
          ),
        ],
      ),
    );
  }
}

String badgeLabel(AppLocalizations l, BibleBadge b) => switch (b) {
      BibleBadge.firstDay => l.biblePlansBadgeFirstDay,
      BibleBadge.week => l.biblePlansBadgeWeek,
      BibleBadge.month => l.biblePlansBadgeMonth,
      BibleBadge.planDone => l.biblePlansBadgePlanDone,
      BibleBadge.bookDone => l.biblePlansBadgeBookDone,
      BibleBadge.hundredChapters => l.biblePlansBadgeHundred,
      BibleBadge.challenge => l.biblePlansBadgeChallenge,
    };

IconData _badgeIcon(BibleBadge b) => switch (b) {
      BibleBadge.firstDay => Icons.wb_twilight,
      BibleBadge.week => Icons.local_fire_department,
      BibleBadge.month => Icons.whatshot,
      BibleBadge.planDone => Icons.emoji_events,
      BibleBadge.bookDone => Icons.menu_book,
      BibleBadge.hundredChapters => Icons.auto_stories,
      BibleBadge.challenge => Icons.groups,
    };

/// **La grille des badges** — tous, les gagnés en couleur. Lit
/// [bibleBadgesProvider] : M4 peut la poser telle quelle dans « Mon espace ».
class BibleBadgeGrid extends ConsumerWidget {
  const BibleBadgeGrid({super.key});

  static Key badgeKey(BibleBadge b) => Key('bible_badge_${b.name}');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final earned = ref.watch(bibleBadgesProvider);
    final l = context.l10n;
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.md,
      children: [
        for (final b in BibleBadge.values)
          SizedBox(
            width: 76,
            child: BibleMedal(
              key: badgeKey(b),
              icon: _badgeIcon(b),
              label: badgeLabel(l, b),
              earned: earned.contains(b),
              hexagon: true,
            ),
          ),
      ],
    );
  }
}

/// **La carte du plan en cours** — section de l'accueil du module. Rien si
/// aucun plan n'est en cours.
class BiblePlanHomeCard extends ConsumerWidget {
  const BiblePlanHomeCard({super.key, required this.onOpen});

  /// Ouvre le détail du plan.
  final void Function(WidgetRef ref, PlanTracker tracker) onOpen;

  static const Key cardKey = Key('bible_plans_home_card');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(bibleCurrentPlanProvider);
    if (t == null) return const SizedBox.shrink();
    final l = context.l10n;
    final next = t.progress.nextDay;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        0,
      ),
      child: AppCard(
        key: cardKey,
        onTap: () => onOpen(ref, t),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.biblePlansHomeTitle,
              style: AppTypography.caption.copyWith(
                color: context.palette.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(trackerTitle(l, t), style: AppTypography.h5),
            const SizedBox(height: AppSpacing.md),
            ChallengeBar(progress: t.progress),
            if (next != null && !t.progress.todayDone) ...[
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  icon: const Icon(Icons.menu_book_outlined),
                  label: Text(l.biblePlansRead),
                  onPressed: () => openPlanDay(ref, t.days[next]),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Une ligne d'inscription vers son plan, pour les listes.
PlanTracker? trackerOf(List<PlanTracker>? trackers, String enrollmentId) {
  for (final t in trackers ?? const <PlanTracker>[]) {
    if (t.enrollment.id == enrollmentId) return t;
  }
  return null;
}

/// L'inscription liée à un défi, s'il y en a une.
PlanEnrollment? enrollmentForChallenge(
  List<PlanEnrollment>? enrollments,
  String challengeId,
) {
  for (final e in enrollments ?? const <PlanEnrollment>[]) {
    if (e.challengeId == challengeId) return e;
  }
  return null;
}
