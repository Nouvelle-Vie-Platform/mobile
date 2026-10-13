/// **Les providers des plans et des défis** (M5, #203).
///
/// Ce que les autres tranches lisent :
///
/// - [bibleBadgesProvider] — les badges gagnés (M4, « Mon espace ») ; tous les
///   badges, dans l'ordre d'affichage : `BibleBadge.values`. Le widget
///   `BibleBadgeGrid` (`plans_widgets.dart`) les peint.
/// - [biblePlanReadingDoneTodayProvider] — « la lecture du jour est-elle
///   faite ? » (M4 : rappel « Lecture du plan »).
/// - [bibleCurrentPlanProvider] — le plan en cours, pour une carte.
library;

import 'package:drift/drift.dart' hide Column;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../data/local/app_database.dart';
import '../../../state/sync_providers.dart';
import '../data/bible_providers.dart';
import 'plan_logic.dart';
import 'plans_api.dart';
import 'plans_store.dart';

Duration? _noRetry(int _, Object __) => null;

/// Aujourd'hui (date locale) — surchargé par les tests.
final bibleTodayProvider = Provider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

final biblePlansStoreProvider = Provider<BiblePlansStore>(
  (ref) => BiblePlansStore(ref.watch(appDatabaseProvider)),
);

/// Le seul provider de ce dossier qui parle au réseau ; les tests le
/// surchargent.
final biblePlansApiProvider = Provider<BiblePlansApi>(
  (ref) => BiblePlansApi(ApiClient.instance.dio),
);

/// Mes inscriptions (invité : brouillons ; membre : miroir + file).
final biblePlanEnrollmentsProvider = StreamProvider<List<PlanEnrollment>>(
  (ref) => ref
      .watch(biblePlansStoreProvider)
      .watchEnrollments(member: ref.watch(bibleIsMemberProvider)),
  retry: _noRetry,
);

/// Les plans **publiés** par l'église : `publishedAt == null` masqué, les
/// retirés ont déjà quitté le miroir (tombstone).
final biblePublishedPlansProvider = StreamProvider<List<BiblePlanRow>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.biblePlans)
        ..where((t) => t.publishedAt.isNotNull())
        ..orderBy([(t) => OrderingTerm.asc(t.title)]))
      .watch();
}, retry: _noRetry);

/// Les défis publiés **pas encore finis** (en cours ou à venir), par date de
/// début.
final bibleChallengesProvider = StreamProvider<List<BibleChallengeRow>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final today = formatDay(ref.watch(bibleTodayProvider));
  return (db.select(db.bibleChallenges)
        ..where(
          (t) =>
              t.publishedAt.isNotNull() &
              t.startsOn.isNotNull() &
              t.endsOn.isNotNull() &
              t.endsOn.isBiggerOrEqualValue(today),
        )
        ..orderBy([(t) => OrderingTerm.asc(t.startsOn)]))
      .watch();
}, retry: _noRetry);

/// **Un plan suivi, résolu** : ses jours, sa progression à aujourd'hui
/// (jours cochés + jours que les chapitres lus suffisent à cocher).
final class PlanTracker {
  const PlanTracker({
    required this.enrollment,
    required this.days,
    required this.progress,
    this.title,
  });

  final PlanEnrollment enrollment;

  /// Vide si le plan n'est plus disponible (publié puis retiré).
  final List<PlanDay> days;
  final PlanProgress progress;

  /// Le titre d'un plan publié ou perso ; `null` pour un intégré (l10n).
  final String? title;

  bool get available => days.isNotEmpty;
}

/// Les jours d'une inscription, et le titre qui va avec.
(List<PlanDay>, String?) resolvePlan(
  PlanEnrollment e,
  List<BiblePlanRow> published,
) {
  switch (e.source) {
    case PlanSource.builtin:
      return (builtinPlanDays(e.planCode ?? '') ?? const [], null);
    case PlanSource.custom:
      final c = e.custom;
      return c == null
          ? (const [], null)
          : (spreadBooks(c.books, c.days), c.title);
    case PlanSource.published:
      for (final p in published) {
        if (p.id == e.planId) return (parsePlanDays(p.days), p.title);
      }
      return (const [], null);
  }
}

/// Mes plans, résolus et mesurés. `null` pendant le premier chargement.
final biblePlanTrackersProvider = Provider<List<PlanTracker>?>((ref) {
  final enrollments = ref.watch(biblePlanEnrollmentsProvider).value;
  final published = ref.watch(biblePublishedPlansProvider).value ?? const [];
  if (enrollments == null) return null;
  final today = ref.watch(bibleTodayProvider);
  final read = ref.watch(bibleReadingStateProvider).value;
  bool hasRead(String b, int c) => read?.hasRead(b, c) ?? false;
  return [for (final e in enrollments) _track(e, published, today, hasRead)];
});

PlanTracker _track(
  PlanEnrollment e,
  List<BiblePlanRow> published,
  DateTime today,
  bool Function(String, int) hasRead,
) {
  final (days, title) = resolvePlan(e, published);
  final start = parseDay(e.startedOn) ?? today;
  final stored = PlanProgress(
    totalDays: days.length,
    startedOn: start,
    completed: e.completedDays,
    today: today,
  );
  final auto = autoCompletedDays(
    days: days,
    progress: stored,
    hasRead: hasRead,
  );
  return PlanTracker(
    enrollment: e,
    days: days,
    title: title,
    progress: auto.difference(e.completedDays).isEmpty
        ? stored
        : PlanProgress(
            totalDays: days.length,
            startedOn: start,
            completed: {...e.completedDays, ...auto},
            today: today,
          ),
  );
}

/// **Le plan en cours** : le premier commencé et pas fini.
final bibleCurrentPlanProvider = Provider<PlanTracker?>((ref) {
  final trackers = ref.watch(biblePlanTrackersProvider) ?? const [];
  for (final t in trackers) {
    if (t.available && t.progress.started && !t.progress.finished) return t;
  }
  return null;
});

/// **« La lecture du plan est-elle faite aujourd'hui ? »** — pour le rappel
/// « Lecture du plan » (M4). Vrai quand aucun plan n'attend de lecture
/// aujourd'hui ; `null` pendant le premier chargement.
final biblePlanReadingDoneTodayProvider = Provider<bool?>((ref) {
  final trackers = ref.watch(biblePlanTrackersProvider);
  if (trackers == null) return null;
  return trackers.every((t) => !t.available || t.progress.todayDone);
});

/// **Les badges gagnés**, calculés sur l'appareil (M4 les montre dans « Mon
/// espace »).
final bibleBadgesProvider = Provider<Set<BibleBadge>>((ref) {
  final trackers = ref.watch(biblePlanTrackersProvider) ?? const [];
  return earnedBadges(
    plans: [for (final t in trackers) t.progress],
    joinedChallenge: trackers.any((t) => t.enrollment.challengeId != null),
    readChapters:
        ref.watch(bibleReadingStateProvider).value?.readChapters ?? const {},
  );
});

/// **La file d'envoi**, que `app.dart` appelle après chaque cycle réussi :
/// les jours que les chapitres lus ont cochés sont d'abord écrits (le
/// classement du serveur les lit dans `completedDays`), puis tout ce qui
/// attend part. Rien pour un invité : M2 verse ses brouillons à la connexion.
final biblePlansOutboxProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    if (!ref.read(bibleIsMemberProvider)) return;
    final store = ref.read(biblePlansStoreProvider);
    final db = ref.read(appDatabaseProvider);
    final today = ref.read(bibleTodayProvider);
    final published = await (db.select(
      db.biblePlans,
    )..where((t) => t.publishedAt.isNotNull()))
        .get();
    final read =
        await ref.read(bibleDaoProvider).watchReadingState(member: true).first;
    bool hasRead(String b, int c) => read?.hasRead(b, c) ?? false;
    for (final e in await store.enrollments(member: true)) {
      final t = _track(e, published, today, hasRead);
      if (!e.completedDays.containsAll(t.progress.completed)) {
        await store.save(e.copyWith(completedDays: t.progress.completed));
      }
    }
    await store.resendDirty(ref.read(biblePlansApiProvider));
  };
});
