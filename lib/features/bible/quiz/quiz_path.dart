/// **Le parcours des quiz d'une tranche** : la règle de progression, à part
/// de l'écran (`quiz_path_screen.dart`).
///
/// Les quiz sont rangés du plus facile au plus difficile, puis du plus ancien
/// au plus récent. Seule la première étape est ouverte au départ ; une étape
/// est **réussie** à [passStars] étoiles (sur 3), et ouvre la suivante. Une
/// étape réussie se rejoue.
library;

import 'quiz.dart';
import 'quiz_providers.dart';

/// Les étoiles qu'il faut pour réussir une étape.
const int passStars = 2;

enum QuizStepState { done, current, locked }

final class QuizStep {
  const QuizStep({
    required this.number,
    required this.quiz,
    required this.state,
    required this.stars,
  });

  /// Numéro affiché, à partir de 1 (l'étape du bas de la route).
  final int number;
  final Quiz quiz;
  final QuizStepState state;

  /// Les meilleures étoiles obtenues (0 si jamais jouée).
  final int stars;

  bool get playable => state != QuizStepState.locked;
}

List<QuizStep> quizPath(List<Quiz> quizzes, Map<int, QuizScore> best) {
  final ordered = [...quizzes]..sort((a, b) {
      final d = a.difficulty.compareTo(b.difficulty);
      if (d != 0) return d;
      final pa = a.publishedAt, pb = b.publishedAt;
      if (pa != null && pb != null && pa != pb) return pa.compareTo(pb);
      return a.id.compareTo(b.id);
    });
  final steps = <QuizStep>[];
  var open = true;
  for (final (i, q) in ordered.indexed) {
    final score = best[q.id];
    final stars = score == null ? 0 : quizStars(score.score, score.total);
    final passed = stars >= passStars;
    final state = !open
        ? QuizStepState.locked
        : passed
            ? QuizStepState.done
            : QuizStepState.current;
    steps.add(QuizStep(number: i + 1, quiz: q, state: state, stars: stars));
    if (!passed) open = false;
  }
  return steps;
}
