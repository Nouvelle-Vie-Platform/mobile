/// **Les plans de lecture** (M5, #203, décision 11) : la liste (mes plans,
/// plans de l'église, plans proposés), le détail d'un plan suivi (barre de
/// défi, objectifs, lecture du jour, rattrapage, badges, tous les jours) et
/// l'éditeur des plans et défis perso. Ouverts à tous : l'invité garde ses
/// plans sur l'appareil, le membre les synchronise.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/app_database.dart' show BiblePlanRow;
import '../../../l10n/l10n_extension.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_palette.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/app_card.dart';
import '../data/bible_providers.dart';
import '../data/canon.dart';
import 'challenges_screen.dart';
import 'plan_logic.dart';
import 'plans_providers.dart';
import 'plans_store.dart';
import 'plans_widgets.dart';

class BiblePlansScreen extends ConsumerWidget {
  const BiblePlansScreen({super.key});

  static const Key createKey = Key('bible_plans_create');
  static Key mineKey(String id) => Key('bible_plans_mine_$id');
  static Key builtinKey(String code) => Key('bible_plans_builtin_$code');
  static Key publishedKey(String id) => Key('bible_plans_published_$id');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final trackers = ref.watch(biblePlanTrackersProvider);
    final published = ref.watch(biblePublishedPlansProvider).value ?? const [];
    final mine = [
      for (final t in trackers ?? const <PlanTracker>[])
        if (t.enrollment.challengeId == null) t,
    ];
    return BiblePlansScaffold(
      title: l.biblePlansTitle,
      floatingActionButton: FloatingActionButton.extended(
        key: createKey,
        icon: const Icon(Icons.add),
        label: Text(l.biblePlansCreate),
        onPressed: () =>
            pushBiblePlansPage<void>(ref, const BibleCustomPlanEditor()),
      ),
      body: trackers == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 96),
              children: [
                PlansSectionTitle(l.biblePlansMine),
                if (mine.isEmpty)
                  Padding(
                    padding: AppSpacing.screenPadding,
                    child: Text(
                      l.biblePlansEmpty,
                      style: AppTypography.body.copyWith(
                        color: context.palette.textSecondary,
                      ),
                    ),
                  ),
                for (final t in mine)
                  _MineTile(
                    key: mineKey(t.enrollment.id),
                    tracker: t,
                    onTap: () => _openDetail(ref, t.enrollment.id),
                  ),
                if (published.isNotEmpty) ...[
                  PlansSectionTitle(l.biblePlansChurch),
                  for (final p in published)
                    _PlanTile(
                      key: publishedKey(p.id),
                      title: p.title,
                      subtitle: p.description,
                      days: parsePlanDays(p.days).length,
                      onTap: () => _start(
                        context,
                        ref,
                        source: PlanSource.published,
                        planId: p.id,
                        title: p.title,
                        description: p.description,
                        days: parsePlanDays(p.days).length,
                      ),
                    ),
                ],
                PlansSectionTitle(l.biblePlansBuiltin),
                for (final code in BuiltinPlanCode.all)
                  _PlanTile(
                    key: builtinKey(code),
                    title: builtinPlanTitle(l, code),
                    days: builtinPlanDays(code)!.length,
                    onTap: () => _start(
                      context,
                      ref,
                      source: PlanSource.builtin,
                      planCode: code,
                      title: builtinPlanTitle(l, code),
                      days: builtinPlanDays(code)!.length,
                    ),
                  ),
              ],
            ),
    );
  }

  /// Ouvre le plan s'il est déjà suivi, sinon propose de le commencer.
  Future<void> _start(
    BuildContext context,
    WidgetRef ref, {
    required PlanSource source,
    String? planCode,
    String? planId,
    required String title,
    String? description,
    required int days,
  }) async {
    final existing = (ref.read(biblePlanTrackersProvider) ?? const [])
        .where(
          (t) =>
              t.enrollment.challengeId == null &&
              t.enrollment.source == source &&
              t.enrollment.planCode == planCode &&
              t.enrollment.planId == planId,
        )
        .firstOrNull;
    if (existing != null) return _openDetail(ref, existing.enrollment.id);
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(title),
        content: Text(
          [
            if (description != null && description.isNotEmpty) description,
            l.biblePlansDays(days),
          ].join('\n\n'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(l.biblePlansCancel),
          ),
          FilledButton(
            key: const Key('bible_plans_start'),
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(l.biblePlansStart),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final e = await ref.read(biblePlansStoreProvider).enroll(
          source: source,
          planCode: planCode,
          planId: planId,
          startedOn: ref.read(bibleTodayProvider),
        );
    await _openDetail(ref, e.id);
  }
}

Future<void> _openDetail(WidgetRef ref, String enrollmentId) =>
    pushBiblePlansPage<void>(
      ref,
      BiblePlanDetailScreen(enrollmentId: enrollmentId),
    );

/// Ouvre le détail d'un plan suivi — pour la carte de l'accueil et les défis.
void openBiblePlanDetail(WidgetRef ref, PlanTracker t) =>
    _openDetail(ref, t.enrollment.id);

class _MineTile extends StatelessWidget {
  const _MineTile({super.key, required this.tracker, required this.onTap});

  final PlanTracker tracker;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = tracker.progress;
    return ListTile(
      leading: Icon(
        p.finished ? Icons.emoji_events : Icons.event_note,
        color: p.finished ? AppColors.warning : context.palette.primary,
      ),
      title: Text(trackerTitle(l, tracker)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.xs),
          LinearProgressIndicator(
            value: p.fraction,
            color: AppColors.accent,
            backgroundColor: context.palette.divider,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            p.finished
                ? l.biblePlansFinished
                : l.biblePlansDayOf(
                    (p.elapsed + 1).clamp(1, p.totalDays),
                    p.totalDays,
                  ),
          ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _PlanTile extends StatelessWidget {
  const _PlanTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.days,
    required this.onTap,
  });

  final String title;
  final String? subtitle;
  final int days;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: const Icon(Icons.menu_book_outlined),
        title: Text(title),
        subtitle: Text(
          [
            if (subtitle != null && subtitle!.isNotEmpty) subtitle!,
            context.l10n.biblePlansDays(days),
          ].join(' · '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      );
}

/// **Le détail d'un plan suivi.**
class BiblePlanDetailScreen extends ConsumerWidget {
  const BiblePlanDetailScreen({super.key, required this.enrollmentId});

  final String enrollmentId;

  static const Key todayKey = Key('bible_plans_today');
  static const Key catchUpKey = Key('bible_plans_catch_up');
  static const Key leaveKey = Key('bible_plans_leave');
  static const Key editKey = Key('bible_plans_edit');
  static Key dayKey(int day) => Key('bible_plans_day_$day');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final t = trackerOf(ref.watch(biblePlanTrackersProvider), enrollmentId);
    if (t == null) {
      return BiblePlansScaffold(
        title: l.biblePlansTitle,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final p = t.progress;
    final e = t.enrollment;
    final palette = context.palette;
    final focus = p.todayInPlan ? p.todayIndex : p.nextDay;
    final header = <Widget>[
      Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ChallengeBar(progress: p),
              const SizedBox(height: AppSpacing.lg),
              Text(l.biblePlansGoals, style: AppTypography.bodyStrong),
              const SizedBox(height: AppSpacing.sm),
              PlanGoals(progress: p),
            ],
          ),
        ),
      ),
      if (!t.available)
        Padding(
          padding: AppSpacing.screenPadding,
          child: Text(l.biblePlansUnavailable),
        ),
      if (t.available && !p.started)
        Padding(
          padding: AppSpacing.screenPadding,
          child: Text(
            l.biblePlansNotStarted(
              MaterialLocalizations.of(context)
                  .formatMediumDate(parseDay(e.startedOn)!),
            ),
            style: AppTypography.bodyStrong,
          ),
        ),
      if (t.available && focus != null)
        _DayCard(
          key: todayKey,
          tracker: t,
          day: focus,
          title: p.todayInPlan && focus == p.todayIndex
              ? l.biblePlansToday
              : l.biblePlansDayOf(focus + 1, p.totalDays),
        ),
      if (t.available && p.behind.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            0,
          ),
          child: AppCard(
            key: catchUpKey,
            color: palette.warningBg,
            child: Row(
              children: [
                const Icon(Icons.history, color: AppColors.warning),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: Text(l.biblePlansCatchUp(p.behind.length))),
                TextButton(
                  onPressed: () => openPlanDay(ref, t.days[p.behind.first]),
                  child: Text(l.biblePlansCatchUpAction),
                ),
              ],
            ),
          ),
        ),
      if (e.challengeId != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            0,
          ),
          child: OutlinedButton.icon(
            icon: const Icon(Icons.leaderboard_outlined),
            label: Text(l.biblePlansLeaderboard),
            onPressed: () => pushBiblePlansPage<void>(
              ref,
              BibleLeaderboardScreen(challengeId: e.challengeId!),
            ),
          ),
        ),
      PlansSectionTitle(l.biblePlansBadges),
      const Padding(padding: AppSpacing.screenPadding, child: BibleBadgeGrid()),
      if (t.available) PlansSectionTitle(l.biblePlansAllDays),
    ];
    return BiblePlansScaffold(
      title: trackerTitle(l, t),
      actions: [
        PopupMenuButton<String>(
          onSelected: (v) => v == 'edit'
              ? pushBiblePlansPage<void>(
                  ref,
                  BibleCustomPlanEditor(enrollment: e),
                )
              : _leave(context, ref, e),
          itemBuilder: (_) => [
            if (e.source == PlanSource.custom)
              PopupMenuItem(
                key: editKey,
                value: 'edit',
                child: Text(l.biblePlansEdit),
              ),
            PopupMenuItem(
              key: leaveKey,
              value: 'leave',
              child: Text(l.biblePlansLeave),
            ),
          ],
        ),
      ],
      body: ListView.builder(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        itemCount: header.length + (t.available ? t.days.length : 0),
        itemBuilder: (context, i) {
          if (i < header.length) return header[i];
          final d = i - header.length;
          final done = p.completed.contains(d);
          return ListTile(
            key: dayKey(d),
            leading: Checkbox(
              value: done,
              onChanged: (_) => _toggle(ref, t, d),
            ),
            title: Text(
              l.biblePlansDayOf(d + 1, p.totalDays),
              style: d == p.todayIndex ? AppTypography.bodyStrong : null,
            ),
            subtitle: Text(t.days[d].map((r) => r.labelFr).join(', ')),
            onTap: () => openPlanDay(ref, t.days[d]),
          );
        },
      ),
    );
  }

  Future<void> _leave(
    BuildContext context,
    WidgetRef ref,
    PlanEnrollment e,
  ) async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        content: Text(l.biblePlansLeaveConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(l.biblePlansCancel),
          ),
          FilledButton(
            key: const Key('bible_plans_leave_confirm'),
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(l.biblePlansLeave),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final store = ref.read(biblePlansStoreProvider);
    final member = ref.read(bibleIsMemberProvider);
    Navigator.of(context).pop();
    await store.remove(e, member: member);
  }
}

/// Coche ou décoche un jour à la main.
Future<void> _toggle(WidgetRef ref, PlanTracker t, int day) {
  final days = {...t.progress.completed};
  if (!days.remove(day)) days.add(day);
  return ref
      .read(biblePlansStoreProvider)
      .save(t.enrollment.copyWith(completedDays: days));
}

/// La carte d'un jour : ses lectures (cochées quand le chapitre est lu),
/// « Lire » et « Marquer comme lu ».
class _DayCard extends ConsumerWidget {
  const _DayCard({
    super.key,
    required this.tracker,
    required this.day,
    required this.title,
  });

  final PlanTracker tracker;
  final int day;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final read = ref.watch(bibleReadingStateProvider).value;
    final done = tracker.progress.completed.contains(day);
    final refs = tracker.days[day];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTypography.h5),
            const SizedBox(height: AppSpacing.sm),
            for (final r in refs)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  children: [
                    Icon(
                      done || (read?.hasRead(r.book, r.chapter) ?? false)
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 20,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(r.labelFr, style: AppTypography.body),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  // Le `Material` transparent : un `ListTile` peint sur le
                  // `Material` le plus proche, que la carte masquerait.
                  child: Material(
                    type: MaterialType.transparency,
                    child: CheckboxListTile(
                      key: const Key('bible_plans_mark_done'),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: done,
                      title: Text(l.biblePlansMarkDone),
                      onChanged: (_) => _toggle(ref, tracker, day),
                    ),
                  ),
                ),
                FilledButton.icon(
                  key: const Key('bible_plans_read'),
                  icon: const Icon(Icons.menu_book_outlined),
                  label: Text(l.biblePlansRead),
                  onPressed: () => openPlanDay(ref, refs),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// **L'éditeur des plans et défis perso** : un titre, des livres, une durée ;
/// les chapitres sont répartis d'eux-mêmes (`spreadBooks`). Sans
/// [enrollment] : un nouveau plan, commencé aujourd'hui.
class BibleCustomPlanEditor extends ConsumerStatefulWidget {
  const BibleCustomPlanEditor({super.key, this.enrollment});

  final PlanEnrollment? enrollment;

  static const Key titleKey = Key('bible_plans_editor_title');
  static const Key daysKey = Key('bible_plans_editor_days');
  static const Key saveKey = Key('bible_plans_editor_save');
  static Key bookKey(String osis) => Key('bible_plans_editor_book_$osis');

  @override
  ConsumerState<BibleCustomPlanEditor> createState() =>
      _BibleCustomPlanEditorState();
}

class _BibleCustomPlanEditorState extends ConsumerState<BibleCustomPlanEditor> {
  late final _title = TextEditingController(
    text: widget.enrollment?.custom?.title ?? '',
  );
  late final _days = TextEditingController(
    text: '${widget.enrollment?.custom?.days ?? 30}',
  );
  late final Set<String> _books = {...?widget.enrollment?.custom?.books};

  @override
  void dispose() {
    _title.dispose();
    _days.dispose();
    super.dispose();
  }

  void _setTestament(Testament? t) => setState(() {
        _books
          ..clear()
          ..addAll([
            for (final b in bibleCanon)
              if (b.testament == t) b.osis,
          ]);
      });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final chapters = chaptersOf(_books).length;
    final asked = int.tryParse(_days.text.trim()) ?? 0;
    final days = asked > chapters ? chapters : asked;
    final valid = _title.text.trim().isNotEmpty && chapters > 0 && days >= 1;
    return BiblePlansScaffold(
      title: l.biblePlansEditorTitle,
      body: ListView(
        padding: AppSpacing.screenPadding.copyWith(
          top: AppSpacing.lg,
          bottom: AppSpacing.xxl,
        ),
        children: [
          TextField(
            key: BibleCustomPlanEditor.titleKey,
            controller: _title,
            maxLength: 120,
            decoration: InputDecoration(labelText: l.biblePlansEditorName),
            onChanged: (_) => setState(() {}),
          ),
          TextField(
            key: BibleCustomPlanEditor.daysKey,
            controller: _days,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: l.biblePlansEditorDuration),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (chapters > 0 && days >= 1)
            Text(
              l.biblePlansEditorSummary(
                chapters,
                (chapters / days).toStringAsFixed(1),
              ),
              style: AppTypography.caption.copyWith(
                color: context.palette.textSecondary,
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          Text(l.biblePlansEditorBooks, style: AppTypography.bodyStrong),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              ActionChip(
                label: Text(l.biblePlansEditorOld),
                onPressed: () => _setTestament(Testament.old),
              ),
              ActionChip(
                label: Text(l.biblePlansEditorNew),
                onPressed: () => _setTestament(Testament.newT),
              ),
              ActionChip(
                label: Text(l.biblePlansEditorClear),
                onPressed: () => _setTestament(null),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final b in bibleCanon)
                FilterChip(
                  key: BibleCustomPlanEditor.bookKey(b.osis),
                  label: Text(b.name),
                  selected: _books.contains(b.osis),
                  onSelected: (on) => setState(
                    () => on ? _books.add(b.osis) : _books.remove(b.osis),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            key: BibleCustomPlanEditor.saveKey,
            onPressed: valid ? () => _save(days) : null,
            child: Text(l.biblePlansEditorSave),
          ),
        ],
      ),
    );
  }

  Future<void> _save(int days) async {
    final spec = CustomPlanSpec(
      title: _title.text.trim(),
      books: [
        for (final b in bibleCanon)
          if (_books.contains(b.osis)) b.osis,
      ],
      days: days,
    );
    final store = ref.read(biblePlansStoreProvider);
    final existing = widget.enrollment;
    final navigator = Navigator.of(context);
    if (existing != null) {
      await store.save(
        existing.copyWith(
          custom: spec,
          completedDays: {
            for (final d in existing.completedDays)
              if (d < spreadBooks(spec.books, spec.days).length) d,
          },
        ),
      );
      navigator.pop();
      return;
    }
    final e = await store.enroll(
      source: PlanSource.custom,
      custom: spec,
      startedOn: ref.read(bibleTodayProvider),
    );
    await navigator.pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => BiblePlanDetailScreen(enrollmentId: e.id),
      ),
    );
  }
}

/// Les plans publiés, par identifiant — pour les défis.
BiblePlanRow? publishedPlan(List<BiblePlanRow>? plans, String? id) {
  for (final p in plans ?? const <BiblePlanRow>[]) {
    if (p.id == id) return p;
  }
  return null;
}
