/// **Les quiz bibliques** (M6, mobile#204) : le modèle lu depuis le miroir
/// `bible_quizzes` (S4) et la partie, en pur Dart.
///
/// La forme d'une question est celle de `server-portal/app/bible_quiz/support/
/// quiz_questions.ts` : `{ kind: choice|truefalse, prompt, choices, answer
/// (index base 0), explanation?, reference? }`. Une question illisible est
/// **écartée**, jamais une erreur ; un quiz sans question lisible ne se montre
/// pas.
library;

import 'dart:convert';

import '../../../data/local/app_database.dart';
import '../data/canon.dart';

/// La tranche d'âge d'un quiz — et le profil du joueur.
enum QuizAgeBand {
  kids,
  teens,
  adults;

  static QuizAgeBand? parse(String? raw) {
    for (final b in values) {
      if (b.name == raw) return b;
    }
    return null;
  }
}

final class QuizQuestion {
  const QuizQuestion({
    required this.isTrueFalse,
    required this.prompt,
    required this.choices,
    required this.answer,
    this.explanation,
    this.reference,
  });

  final bool isTrueFalse;
  final String prompt;
  final List<String> choices;

  /// Index de la bonne réponse dans [choices].
  final int answer;
  final String? explanation;
  final BibleLink? reference;

  /// `null` si la question n'est pas jouable.
  static QuizQuestion? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final kind = raw['kind'];
    final prompt = raw['prompt'];
    final choices = raw['choices'];
    final answer = raw['answer'];
    if (kind != 'choice' && kind != 'truefalse') return null;
    if (prompt is! String || prompt.trim().isEmpty) return null;
    if (choices is! List || choices.length < 2) return null;
    if (choices.any((c) => c is! String)) return null;
    if (answer is! int || answer < 0 || answer >= choices.length) return null;
    final explanation = raw['explanation'];
    return QuizQuestion(
      isTrueFalse: kind == 'truefalse',
      prompt: prompt,
      choices: choices.cast<String>(),
      answer: answer,
      explanation:
          explanation is String && explanation.isNotEmpty ? explanation : null,
      reference: _reference(raw['reference']),
    );
  }

  static BibleLink? _reference(Object? raw) {
    if (raw is! Map) return null;
    final book = raw['book'];
    final chapter = raw['chapter'];
    final from = raw['verseFrom'];
    final to = raw['verseTo'];
    if (book is! String || chapter is! int) return null;
    final link = BibleLink(
      book,
      chapter,
      from: from is int ? from : null,
      to: from is int && to is int ? to : null,
    );
    return isValidBibleRef(link) ? link : null;
  }
}

final class Quiz {
  const Quiz({
    required this.id,
    required this.title,
    required this.ageBand,
    required this.difficulty,
    required this.questions,
    this.featuredFrom,
    this.featuredUntil,
    this.imageUrl,
    this.publishedAt,
  });

  final int id;
  final String title;
  final QuizAgeBand ageBand;

  /// 1 (facile) à 3 (difficile).
  final int difficulty;
  final List<QuizQuestion> questions;

  /// `YYYY-MM-DD`.
  final String? featuredFrom;
  final String? featuredUntil;
  final String? imageUrl;
  final DateTime? publishedAt;

  /// `null` si le quiz n'est pas jouable (tranche inconnue, aucune question).
  static Quiz? fromRow(BibleQuizRow row) {
    final band = QuizAgeBand.parse(row.ageBand);
    if (band == null) return null;
    Object? raw;
    try {
      raw = jsonDecode(row.questions ?? '[]');
    } on FormatException {
      return null;
    }
    if (raw is! List) return null;
    final questions =
        raw.map(QuizQuestion.tryParse).whereType<QuizQuestion>().toList();
    if (questions.isEmpty) return null;
    return Quiz(
      id: row.id,
      title: row.title,
      ageBand: band,
      difficulty: (row.difficulty ?? 1).clamp(1, 3),
      questions: questions,
      featuredFrom: row.featuredFrom,
      featuredUntil: row.featuredUntil,
      imageUrl: row.imageUrl,
      publishedAt: row.publishedAt,
    );
  }

  /// La fenêtre de mise en avant contient-elle [day] (`YYYY-MM-DD`) ? Une
  /// borne absente est ouverte ; sans aucune borne, le quiz n'est pas en avant.
  bool featuredOn(String day) {
    final from = featuredFrom;
    final until = featuredUntil;
    if (from == null && until == null) return false;
    return (from == null || from.compareTo(day) <= 0) &&
        (until == null || until.compareTo(day) >= 0);
  }
}

/// `YYYY-MM-DD` du jour local.
String quizDay(DateTime now) => now.toIso8601String().substring(0, 10);

/// **Étoiles** d'un score : 3 sans faute, 2 dès 60 %, 1 dès une bonne réponse.
int quizStars(int score, int total) {
  if (total <= 0 || score <= 0) return 0;
  if (score >= total) return 3;
  return score / total >= 0.6 ? 2 : 1;
}

/// **Une partie** : une question à la fois, une réponse par question.
class QuizGame {
  QuizGame(this.quiz);

  final Quiz quiz;
  int _index = 0;
  int _score = 0;

  /// La réponse donnée à la question courante (`-1` : temps écoulé), `null`
  /// tant qu'on n'a pas répondu.
  int? _picked;

  int get index => _index;
  int get score => _score;
  int get total => quiz.questions.length;
  int? get picked => _picked;
  bool get answered => _picked != null;
  bool get isLast => _index == total - 1;
  QuizQuestion get question => quiz.questions[_index];

  /// Répond [choice] (`-1` : temps écoulé) ; rend `true` si c'est juste. Une
  /// seconde réponse à la même question est ignorée.
  bool answer(int choice) {
    if (answered) return choice == question.answer;
    _picked = choice;
    final right = choice == question.answer;
    if (right) _score++;
    return right;
  }

  /// Passe à la question suivante ; rend `false` à la fin.
  bool next() {
    if (!answered || isLast) return false;
    _index++;
    _picked = null;
    return true;
  }
}
