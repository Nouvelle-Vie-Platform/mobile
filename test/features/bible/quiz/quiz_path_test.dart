import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/features/bible/quiz/quiz.dart';
import 'package:maison_du_miracle/features/bible/quiz/quiz_path.dart';
import 'package:maison_du_miracle/features/bible/quiz/quiz_providers.dart';

Quiz _q(int id, int difficulty, int month) => Quiz(
      id: id,
      title: 'Quiz $id',
      ageBand: QuizAgeBand.teens,
      difficulty: difficulty,
      questions: const [],
      publishedAt: DateTime.utc(2026, month),
    );

QuizScore _s(int quizId, int score, int total) =>
    (id: 's$quizId', quizId: quizId, score: score, total: total);

void main() {
  final quizzes = [_q(1, 2, 1), _q(2, 1, 5), _q(3, 1, 2), _q(4, 3, 1)];

  test('rangés du plus facile au plus difficile, puis du plus ancien', () {
    final path = quizPath(quizzes, const {});
    expect([for (final s in path) s.quiz.id], [3, 2, 1, 4]);
    expect([for (final s in path) s.number], [1, 2, 3, 4]);
  });

  test('au départ : la première étape ouverte, les autres verrouillées', () {
    final path = quizPath(quizzes, const {});
    expect([
      for (final s in path) s.state
    ], [
      QuizStepState.current,
      QuizStepState.locked,
      QuizStepState.locked,
      QuizStepState.locked,
    ]);
  });

  test('réussir (2 étoiles) ouvre la suivante ; échouer ne l\'ouvre pas', () {
    final best = {
      3: _s(3, 10, 10), // 3 étoiles : réussie
      2: _s(2, 1, 10), // 0 étoile : en cours, la suite reste fermée
    };
    final path = quizPath(quizzes, best);
    expect([
      for (final s in path) s.state
    ], [
      QuizStepState.done,
      QuizStepState.current,
      QuizStepState.locked,
      QuizStepState.locked,
    ]);
    expect(path.first.stars, 3);
    expect(path[1].playable, isTrue);
    expect(path[2].playable, isFalse);
  });

  test('tout réussi : toutes les étapes rejouables, aucune en cours', () {
    final best = {for (final q in quizzes) q.id: _s(q.id, 9, 10)};
    final path = quizPath(quizzes, best);
    expect(path.every((s) => s.state == QuizStepState.done), isTrue);
  });

  test('aucun quiz : un parcours vide', () {
    expect(quizPath(const [], const {}), isEmpty);
  });
}
