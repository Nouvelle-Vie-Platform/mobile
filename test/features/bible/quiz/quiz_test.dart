/// **Les quiz, en pur Dart** (M6, mobile#204) : lecture des questions servies
/// par S4, partie, étoiles, fenêtre de mise en avant.
library;

import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/features/bible/quiz/quiz.dart';

BibleQuizRow _row({
  String? ageBand = 'adults',
  Object? questions,
  String? featuredFrom,
  String? featuredUntil,
}) =>
    BibleQuizRow(
      id: 4,
      title: const {'fr': 'Les patriarches'},
      ageBand: ageBand,
      difficulty: 2,
      featuredFrom: featuredFrom,
      featuredUntil: featuredUntil,
      questions: jsonEncode(questions ?? [_choice, _trueFalse]),
      publishedAt: DateTime.utc(2026, 10, 1),
      syncStamp: 0,
    );

/// Le repli se fait à la lecture : ces tests-là lisent en français, sauf ceux
/// qui mesurent justement le repli.
Quiz? _fromRow(BibleQuizRow row, [String locale = 'fr']) =>
    Quiz.fromRow(row, locale);

const _choice = {
  'kind': 'choice',
  'prompt': 'Qui est le père d\'Isaac ?',
  'choices': ['Abraham', 'Jacob', 'Moïse'],
  'answer': 0,
  'explanation': 'Isaac est le fils de la promesse.',
  'reference': {'book': 'Gen', 'chapter': 21, 'verseFrom': 1, 'verseTo': 3},
};

const _trueFalse = {
  'kind': 'truefalse',
  'prompt': 'Jacob a douze fils.',
  'choices': ['Vrai', 'Faux'],
  'answer': 0,
};

void main() {
  group('Lecture des questions', () {
    test('la forme exacte de S4, référence comprise', () {
      final quiz = _fromRow(_row())!;
      expect(quiz.ageBand, QuizAgeBand.adults);
      expect(quiz.difficulty, 2);
      expect(quiz.questions, hasLength(2));
      final q = quiz.questions.first;
      expect(q.isTrueFalse, isFalse);
      expect(q.choices, ['Abraham', 'Jacob', 'Moïse']);
      expect(q.answer, 0);
      expect(q.explanation, 'Isaac est le fils de la promesse.');
      expect(q.reference!.toUrl(), 'nv://bible/Gen/21/1-3');
      expect(quiz.questions.last.isTrueFalse, isTrue);
      expect(quiz.questions.last.reference, isNull);
    });

    test('une question illisible est écartée, jamais une erreur', () {
      final quiz = _fromRow(_row(questions: [
        _trueFalse,
        {..._choice, 'answer': 5}, // hors des choix
        {
          ..._choice,
          'choices': ['Seul']
        }, // un seul choix
        {..._choice, 'kind': 'open'}, // genre inconnu
        'pas un objet',
        {
          ..._choice,
          'reference': {'book': 'Xyz', 'chapter': 1}
        },
      ]))!;
      expect(quiz.questions, hasLength(2));
      // La référence inconnue tombe ; la question reste.
      expect(quiz.questions.last.reference, isNull);
    });

    test(
        'un quiz sans question jouable ou de tranche inconnue ne se montre pas',
        () {
      expect(_fromRow(_row(questions: [])), isNull);
      expect(_fromRow(_row(ageBand: 'seniors')), isNull);
      expect(
        _fromRow(_row().copyWith(questions: const Value('{oups'))),
        isNull,
      );
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Les cartes de traduction (#263)
  // ───────────────────────────────────────────────────────────────────────────
  group('Le repli des textes', () {
    const card = {
      'kind': 'choice',
      'prompt': {'fr': 'Qui est le père d\'Isaac ?', 'ee': 'Ame kae nye ?'},
      'choices': [
        {'fr': 'Abraham', 'ee': 'Abraham'},
        {'fr': 'Jacob', 'ee': 'Yakob'},
      ],
      'answer': 0,
      'explanation': {'fr': 'Le fils de la promesse.'},
    };

    test('la carte se replie dans la langue demandée', () {
      final q = _fromRow(_row(questions: [card]), 'ee')!.questions.single;
      expect(q.prompt, 'Ame kae nye ?');
      expect(q.choices, ['Abraham', 'Yakob']);
      // `answer` est un **index** : la place ne bouge pas d'une langue à
      // l'autre, et c'est pourquoi les choix sont des cartes plutôt qu'un jeu
      // de questions par langue.
      expect(q.answer, 0);
      expect(q.explanation, 'Le fils de la promesse.',
          reason: 'repli sur le français, faute d\'éwé');
    });

    test('une chaîne reçue se lit comme du français, sans lever', () {
      // L'ancienne forme : c'est ce que sert un serveur sous son plancher de
      // compatibilité, et ce que portent les lignes d'avant le palier v33.
      final quiz = _fromRow(_row(questions: [_choice]), 'ee')!;
      expect(quiz.title, 'Les patriarches');
      expect(quiz.questions.single.prompt, 'Qui est le père d\'Isaac ?');
      expect(quiz.questions.single.choices, ['Abraham', 'Jacob', 'Moïse']);
      expect(quiz.questions.single.explanation,
          'Isaac est le fils de la promesse.');
    });

    test('un énoncé vide dans toutes les langues écarte la question', () {
      expect(
        _fromRow(_row(questions: [
          {
            ...card,
            'prompt': const {'fr': '  '}
          },
          {
            ...card,
            'choices': const [
              {'fr': 'Abraham'},
              {'fr': ''},
            ],
          },
        ])),
        isNull,
      );
    });
  });

  group('La partie', () {
    test('bonne réponse, mauvaise réponse, fin et score', () {
      final game = QuizGame(_fromRow(_row())!);
      expect(game.next(), isFalse, reason: 'pas avant d\'avoir répondu');
      expect(game.answer(0), isTrue);
      game.answer(1); // une seule réponse comptée
      expect(game.score, 1);
      expect(game.next(), isTrue);
      expect(game.isLast, isTrue);
      expect(game.answer(1), isFalse);
      expect(game.score, 1);
      expect(game.next(), isFalse, reason: 'fin');
      expect(quizStars(game.score, game.total), 1);
    });

    test('le temps écoulé compte faux', () {
      final game = QuizGame(_fromRow(_row())!);
      expect(game.answer(-1), isFalse);
      expect(game.picked, -1);
      expect(game.score, 0);
    });

    test('étoiles', () {
      expect(quizStars(0, 5), 0);
      expect(quizStars(1, 5), 1);
      expect(quizStars(3, 5), 2);
      expect(quizStars(5, 5), 3);
    });
  });

  test('la fenêtre de mise en avant, bornes comprises et ouvertes', () {
    Quiz q(String? from, String? until) =>
        _fromRow(_row(featuredFrom: from, featuredUntil: until))!;
    expect(q(null, null).featuredOn('2026-10-13'), isFalse);
    expect(q('2026-10-12', '2026-10-18').featuredOn('2026-10-13'), isTrue);
    expect(q('2026-10-13', '2026-10-13').featuredOn('2026-10-13'), isTrue);
    expect(q('2026-10-14', null).featuredOn('2026-10-13'), isFalse);
    expect(q(null, '2026-10-12').featuredOn('2026-10-13'), isFalse);
    expect(q('2026-10-01', null).featuredOn('2026-10-13'), isTrue);
  });
}
