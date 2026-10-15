/// **La logique des plans** (M5, #203) : répartition des plans intégrés et
/// perso, lecture d'un plan publié, progression, série, rattrapage, cochage
/// par les chapitres lus et badges — sur des dates factices.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/features/bible/data/canon.dart';
import 'package:maison_du_miracle/features/bible/plans/plan_logic.dart';

int _verses(PlanDay day) =>
    day.fold(0, (n, r) => n + bibleBook(r.book)!.versesIn(r.chapter));

/// Les jours couvrent [chapters] une fois chacun, dans l'ordre, sans jour
/// vide, et aucun jour ne dépasse la moyenne de plus d'un chapitre.
void _expectBalanced(List<PlanDay> days, List<PlanChapter> chapters, int n) {
  expect(days, hasLength(n));
  expect(days.every((d) => d.isNotEmpty), isTrue);
  final flat = [for (final d in days) ...d];
  expect([for (final r in flat) (book: r.book, chapter: r.chapter)], chapters);
  final total = days.fold<int>(0, (s, d) => s + _verses(d));
  final heaviest = chapters.fold<int>(
      0, (m, c) => bibleBook(c.book)!.versesIn(c.chapter).clamp(m, 1 << 30));
  for (final d in days) {
    expect(_verses(d), lessThanOrEqualTo(total / n + heaviest),
        reason: d.map((r) => r.labelFr).join(', '));
  }
}

void main() {
  group('Les plans intégrés', () {
    test('la Bible en 1 an : 365 jours, les 1 189 chapitres', () {
      _expectBalanced(
          builtinPlanDays(BuiltinPlanCode.bible1y)!, bibleChapters, 365);
    });

    test('le Nouveau Testament en 90 jours, de Matthieu à l\'Apocalypse', () {
      final days = builtinPlanDays(BuiltinPlanCode.nt90)!;
      _expectBalanced(
        days,
        chaptersOf([
          for (final b in bibleCanon)
            if (b.testament == Testament.newT) b.osis,
        ]),
        90,
      );
      expect(days.first.first.labelFr, 'Matthieu 1');
      expect(days.last.last.labelFr, 'Apocalypse 22');
    });

    test('les Psaumes en 30 jours ; le Psaume 119 fait sa journée', () {
      final days = builtinPlanDays(BuiltinPlanCode.ps30)!;
      _expectBalanced(days, chaptersOf(['Ps']), 30);
      expect(days.where((d) => d.any((r) => r.chapter == 119)).single,
          hasLength(1));
    });

    test('les Évangiles en 40 jours', () {
      _expectBalanced(builtinPlanDays(BuiltinPlanCode.gospels40)!,
          chaptersOf(['Matt', 'Mark', 'Luke', 'John']), 40);
    });

    test('un code inconnu ne casse rien', () {
      expect(builtinPlanDays('nope'), isNull);
    });
  });

  group('Les plans perso', () {
    test('livres remis dans l\'ordre du canon, doublons écartés', () {
      final days = spreadBooks(['John', 'Ruth', 'John', 'Xyz'], 5);
      _expectBalanced(days, chaptersOf(['Ruth', 'John']), 5);
      expect(days.first.first.labelFr, 'Ruth 1');
    });

    test('plus de jours que de chapitres : un chapitre par jour', () {
      final days = spreadBooks(['Ruth'], 10);
      expect(days, hasLength(4));
      expect(days.every((d) => d.length == 1), isTrue);
    });

    test('un seul jour prend tout ; rien ne donne rien', () {
      expect(spreadBooks(['Jude', 'Phlm'], 1).single, hasLength(2));
      expect(spreadBooks(const [], 10), isEmpty);
      expect(spreadBooks(['John'], 0), isEmpty);
    });
  });

  test('un plan publié se lit ; une référence hors canon est écartée', () {
    final days = parsePlanDays(
      '[[{"book":"John","chapter":3,"verseFrom":16,"verseTo":18},'
      '{"book":"Nope","chapter":1}],[{"book":"Ps","chapter":23}],'
      '[{"book":"Gen","chapter":99}]]',
    );
    expect(days, hasLength(3));
    expect(days[0].single.labelFr, 'Jean 3:16-18');
    expect(days[1].single.labelFr, 'Psaumes 23');
    expect(days[2], isEmpty);
    expect(parsePlanDays('pas du json'), isEmpty);
    expect(parsePlanDays(null), isEmpty);
  });

  group('La progression', () {
    final start = DateTime(2026, 10, 1);
    PlanProgress at(int dayOffset, Set<int> done, {int total = 10}) =>
        PlanProgress(
          totalDays: total,
          startedOn: start,
          completed: done,
          today: start.add(Duration(days: dayOffset, hours: 15)),
        );

    test('le jour du calendrier, la série, le retard, la lecture du jour', () {
      final p = at(4, {0, 1, 3});
      expect(p.todayIndex, 4);
      expect(p.todayDone, isFalse);
      // Série : hier (3) fait, avant-hier (2) non → 1.
      expect(p.streak, 1);
      expect(p.behind, [2]);
      expect(p.nextDay, 2);
      expect(p.onTime, 3);
      expect(p.fraction, 0.3);
      expect(p.expectedFraction, 0.5);

      final today = at(4, {0, 1, 2, 3, 4});
      expect(today.todayDone, isTrue);
      expect(today.streak, 5);
      expect(today.behind, isEmpty);
    });

    test('l\'avance ne compte pas à temps ; les jours hors plan sont ignorés',
        () {
      final p = at(1, {0, 1, 5, 42, -1});
      expect(p.completed, {0, 1, 5});
      expect(p.onTime, 2);
      expect(p.longestRun, 2);
    });

    test('avant le début et après la fin, rien n\'est dû aujourd\'hui', () {
      final before = at(-3, {});
      expect(before.started, isFalse);
      expect(before.todayDone, isTrue);
      expect(before.behind, isEmpty);
      expect(before.streak, 0);

      final after = at(20, {0, 1});
      expect(after.todayDone, isTrue);
      expect(after.behind, [2, 3, 4, 5, 6, 7, 8, 9]);
      expect(at(20, {for (var d = 0; d < 10; d++) d}).finished, isTrue);
    });

    test('les chapitres lus cochent les jours dus, jamais l\'avance', () {
      final days = spreadBooks(['Ruth'], 4); // un chapitre par jour
      final read = {1, 2, 4};
      final auto = autoCompletedDays(
        days: days,
        progress: at(2, {}, total: 4),
        hasRead: (b, c) => b == 'Ruth' && read.contains(c),
      );
      // Ruth 4 est lu, mais le jour 3 n'est pas encore dû.
      expect(auto, {0, 1});
    });
  });

  group('Les badges', () {
    final start = DateTime(2026, 1, 1);
    PlanProgress plan(Set<int> done, {int total = 40}) => PlanProgress(
          totalDays: total,
          startedOn: start,
          completed: done,
          today: DateTime(2026, 3, 1),
        );

    test('aucun badge au départ', () {
      expect(
        earnedBadges(
            plans: [plan({})], joinedChallenge: false, readChapters: {}),
        isEmpty,
      );
    });

    test('premier jour, 7 jours d\'affilée, défi rejoint', () {
      expect(
        earnedBadges(
          plans: [
            plan({for (var d = 3; d < 10; d++) d})
          ],
          joinedChallenge: true,
          readChapters: {},
        ),
        {BibleBadge.firstDay, BibleBadge.week, BibleBadge.challenge},
      );
    });

    test('30 jours d\'affilée, plan terminé, livre terminé, 100 chapitres', () {
      final badges = earnedBadges(
        plans: [
          plan({for (var d = 0; d < 30; d++) d}, total: 30)
        ],
        joinedChallenge: false,
        readChapters: {
          'Ruth': {1, 2, 3, 4},
          'Ps': {for (var c = 1; c <= 96; c++) c},
        },
      );
      expect(badges, {
        BibleBadge.firstDay,
        BibleBadge.week,
        BibleBadge.month,
        BibleBadge.planDone,
        BibleBadge.bookDone,
        BibleBadge.hundredChapters,
      });
    });

    test('six jours ne font pas une semaine ; un livre entamé n\'est pas fini',
        () {
      final badges = earnedBadges(
        plans: [
          plan({0, 1, 2, 3, 4, 5, 7})
        ],
        joinedChallenge: false,
        readChapters: {
          'Ruth': {1, 2, 3},
        },
      );
      expect(badges, {BibleBadge.firstDay});
    });
  });

  test('les jours voyagent en YYYY-MM-DD', () {
    expect(formatDay(DateTime(2026, 3, 7)), '2026-03-07');
    expect(parseDay('2026-03-07'), DateTime(2026, 3, 7));
    expect(parseDay('n\'importe quoi'), isNull);
    // Passage à l'heure d'été : toujours un jour de calendrier.
    expect(daysBetween(DateTime(2026, 3, 28), DateTime(2026, 3, 30, 1)), 2);
  });
}
