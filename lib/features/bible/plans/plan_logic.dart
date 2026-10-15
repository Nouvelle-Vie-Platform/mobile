/// **La logique pure des plans** (M5, #203) : les plans intégrés, la
/// répartition des chapitres sur des jours, la lecture d'un plan publié, la
/// progression (jour du calendrier, série, retard) et les badges. Aucun Flutter,
/// aucune base : tout se teste avec des dates factices.
///
/// Les jours d'un plan sont indexés **à partir de 0** (`completedDays` du
/// contrat §3, et le classement de S3) : le jour 0 tombe le `startedOn`.
library;

import 'dart:convert';

import '../data/canon.dart';

/// Les lectures d'un jour.
typedef PlanDay = List<BibleLink>;

/// Un chapitre du canon.
typedef PlanChapter = ({String book, int chapter});

/// Les codes **stables** des plans intégrés — ils partent sur le fil
/// (`planCode`) : ne jamais les renommer.
abstract final class BuiltinPlanCode {
  static const bible1y = 'bible-1y';
  static const nt90 = 'nt-90';
  static const ps30 = 'ps-30';
  static const gospels40 = 'gospels-40';

  static const all = [bible1y, nt90, ps30, gospels40];
}

const _gospels = ['Matt', 'Mark', 'Luke', 'John'];

/// Les jours d'un plan intégré, ou `null` pour un code inconnu (un appareil
/// plus vieux que le plan qu'un autre a commencé).
List<PlanDay>? builtinPlanDays(String code) =>
    _builtinCache[code] ??= switch (code) {
      BuiltinPlanCode.bible1y => spreadChapters(bibleChapters, 365),
      BuiltinPlanCode.nt90 => spreadBooks([
          for (final b in bibleCanon)
            if (b.testament == Testament.newT) b.osis,
        ], 90),
      BuiltinPlanCode.ps30 => spreadBooks(const ['Ps'], 30),
      BuiltinPlanCode.gospels40 => spreadBooks(_gospels, 40),
      _ => null,
    };

final Map<String, List<PlanDay>?> _builtinCache = {};

/// Les chapitres de [books], **dans l'ordre du canon**, livres inconnus ou
/// répétés écartés.
List<PlanChapter> chaptersOf(Iterable<String> books) {
  final wanted = books.toSet();
  return [
    for (final b in bibleCanon)
      if (wanted.contains(b.osis))
        for (var c = 1; c <= b.chapterCount; c++) (book: b.osis, chapter: c),
  ];
}

/// [books] répartis sur [days] jours.
List<PlanDay> spreadBooks(Iterable<String> books, int days) =>
    spreadChapters(chaptersOf(books), days);

/// **La répartition équilibrée** : les chapitres, dans l'ordre, coupés en
/// [days] jours contigus de charges voisines, mesurées en **versets**. Chaque
/// jour reçoit au moins un chapitre : [days] est ramené au nombre de
/// chapitres s'il le dépasse.
///
/// Glouton : chaque jour vise `versets restants / jours restants` et prend le
/// chapitre suivant tant que cela le rapproche de sa cible. Un jour ne s'écarte
/// donc de la cible que d'un chapitre au plus (Psaume 119 fait sa journée).
List<PlanDay> spreadChapters(List<PlanChapter> chapters, int days) {
  final n = chapters.length;
  if (n == 0 || days < 1) return const [];
  final total = days > n ? n : days;
  final weights = [
    for (final c in chapters) bibleBook(c.book)!.versesIn(c.chapter),
  ];
  var remaining = weights.fold<int>(0, (a, b) => a + b);
  var i = 0;
  final out = <PlanDay>[];
  for (var d = 0; d < total; d++) {
    final daysLeft = total - d;
    final day = <BibleLink>[];
    var load = 0;
    if (daysLeft == 1) {
      for (; i < n; i++) {
        day.add(BibleLink(chapters[i].book, chapters[i].chapter));
        load += weights[i];
      }
    } else {
      final target = remaining / daysLeft;
      do {
        day.add(BibleLink(chapters[i].book, chapters[i].chapter));
        load += weights[i];
        i++;
      } while (n - i > daysLeft - 1 &&
          (load + weights[i] - target).abs() <= (load - target).abs());
    }
    remaining -= load;
    out.add(day);
  }
  return out;
}

/// Les jours d'un plan publié (`bible_plans.days`, `[[référence]]` en JSON).
/// Une référence hors canon est écartée ; un jour vidé ainsi reste un jour
/// (le calendrier du plan ne se décale pas).
List<PlanDay> parsePlanDays(String? json) {
  if (json == null) return const [];
  try {
    final raw = jsonDecode(json);
    if (raw is! List) return const [];
    return [
      for (final day in raw)
        [
          if (day is List)
            for (final r in day)
              if (r is Map) _refOf(r),
        ].nonNulls.toList(),
    ];
  } on FormatException {
    return const [];
  }
}

BibleLink? _refOf(Map<dynamic, dynamic> r) {
  final book = r['book'];
  final chapter = r['chapter'];
  if (book is! String || chapter is! int) return null;
  final from = r['verseFrom'];
  final to = r['verseTo'];
  final link = BibleLink(
    book,
    chapter,
    from: from is int ? from : null,
    to: from is int && to is int ? to : null,
  );
  return isValidBibleRef(link) ? link : null;
}

/// `YYYY-MM-DD` → la date (minuit, heure locale), ou `null`.
DateTime? parseDay(String? day) {
  if (day == null) return null;
  final d = DateTime.tryParse(day);
  return d == null ? null : DateTime(d.year, d.month, d.day);
}

/// La date → `YYYY-MM-DD`.
String formatDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}'
    '-${d.day.toString().padLeft(2, '0')}';

/// Jours de calendrier de [from] à [to] (dates, heure ignorée ; insensible
/// aux changements d'heure).
int daysBetween(DateTime from, DateTime to) => DateTime.utc(
      to.year,
      to.month,
      to.day,
    ).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

/// **La progression d'un plan à une date** — ce que montrent la barre de
/// défi, les objectifs, le rattrapage et la série.
final class PlanProgress {
  PlanProgress({
    required this.totalDays,
    required DateTime startedOn,
    required Set<int> completed,
    required DateTime today,
  })  : completed = {
          for (final d in completed)
            if (d >= 0 && d < totalDays) d,
        },
        todayIndex = daysBetween(startedOn, today);

  final int totalDays;

  /// Les jours faits, bornés au plan.
  final Set<int> completed;

  /// L'indice du jour d'aujourd'hui : négatif avant le début, `≥ totalDays`
  /// après la fin.
  final int todayIndex;

  bool get started => todayIndex >= 0;
  bool get finished => totalDays > 0 && completed.length >= totalDays;

  /// Le dernier jour dû (aujourd'hui, borné au plan), `-1` avant le début.
  int get elapsed => todayIndex < 0
      ? -1
      : todayIndex >= totalDays
          ? totalDays - 1
          : todayIndex;

  /// Aujourd'hui tombe-t-il dans le plan ?
  bool get todayInPlan => todayIndex >= 0 && todayIndex < totalDays;

  /// La lecture du jour est-elle faite ? Vrai quand rien n'est dû aujourd'hui
  /// (plan pas commencé, fini ou dépassé) : le rappel n'a rien à dire.
  bool get todayDone =>
      finished || !todayInPlan || completed.contains(todayIndex);

  /// **Le rattrapage** : les jours passés (avant aujourd'hui) non faits.
  List<int> get behind => [
        for (var d = 0; d < elapsed + (todayInPlan ? 0 : 1); d++)
          if (!completed.contains(d)) d,
      ];

  /// Les jours faits à temps (indice ≤ jour dû) — la règle du classement.
  int get onTime => completed.where((d) => d <= elapsed).length;

  /// **La série** : jours consécutifs faits qui finissent aujourd'hui, ou
  /// hier si la lecture du jour attend encore — la règle du classement (S3).
  int get streak {
    if (elapsed < 0) return 0;
    var n = 0;
    for (var d = completed.contains(elapsed) ? elapsed : elapsed - 1;
        d >= 0 && completed.contains(d);
        d--) {
      n++;
    }
    return n;
  }

  /// La plus longue suite de jours consécutifs faits (badges).
  int get longestRun {
    var best = 0;
    for (final d in completed) {
      if (completed.contains(d - 1)) continue;
      var run = 1;
      while (completed.contains(d + run)) {
        run++;
      }
      if (run > best) best = run;
    }
    return best;
  }

  /// Part faite, `0..1`.
  double get fraction => totalDays == 0 ? 0 : completed.length / totalDays;

  /// Part due à ce jour, `0..1` — le repère de la barre de défi.
  double get expectedFraction => totalDays == 0 ? 0 : (elapsed + 1) / totalDays;

  /// Le prochain jour à lire : le premier en retard, sinon aujourd'hui, sinon
  /// le premier non fait ; `null` si tout est fait.
  int? get nextDay {
    final late = behind;
    if (late.isNotEmpty) return late.first;
    if (todayInPlan && !completed.contains(todayIndex)) return todayIndex;
    for (var d = 0; d < totalDays; d++) {
      if (!completed.contains(d)) return d;
    }
    return null;
  }
}

/// Les jours que les **chapitres lus** suffisent à cocher : tous les
/// chapitres du jour lus, et le jour déjà dû (jamais d'avance sur le
/// calendrier — le classement ne la compterait pas, et un chapitre lu il y a
/// longtemps ne doit pas cocher l'année entière).
Set<int> autoCompletedDays({
  required List<PlanDay> days,
  required PlanProgress progress,
  required bool Function(String book, int chapter) hasRead,
}) =>
    {
      for (var d = 0; d <= progress.elapsed && d < days.length; d++)
        if (days[d].isNotEmpty &&
            days[d].every((r) => hasRead(r.book, r.chapter)))
          d,
    };

/// **Les badges**, calculés sur l'appareil. L'ordre est celui de l'affichage.
enum BibleBadge {
  firstDay,
  week,
  month,
  planDone,
  bookDone,
  hundredChapters,
  challenge,
}

/// Les badges gagnés, d'après la progression de mes plans, mes défis et mes
/// chapitres lus.
Set<BibleBadge> earnedBadges({
  required Iterable<PlanProgress> plans,
  required bool joinedChallenge,
  required Map<String, Set<int>> readChapters,
}) {
  final list = plans.toList();
  final run = list.fold<int>(0, (m, p) => p.longestRun > m ? p.longestRun : m);
  final chaptersRead = readChapters.values.fold<int>(0, (n, s) => n + s.length);
  return {
    if (list.any((p) => p.completed.isNotEmpty)) BibleBadge.firstDay,
    if (run >= 7) BibleBadge.week,
    if (run >= 30) BibleBadge.month,
    if (list.any((p) => p.finished)) BibleBadge.planDone,
    if (readChapters.entries.any(
      (e) =>
          (bibleBook(e.key)?.chapterCount ?? 0) > 0 &&
          e.value.length >= bibleBook(e.key)!.chapterCount,
    ))
      BibleBadge.bookDone,
    if (chaptersRead >= 100) BibleBadge.hundredChapters,
    if (joinedChallenge) BibleBadge.challenge,
  };
}
