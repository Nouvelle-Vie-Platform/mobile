import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/features/bible/quiz/quiz.dart';
import 'package:maison_du_miracle/features/bible/quiz/quiz_path_screen.dart';
import 'package:maison_du_miracle/features/bible/quiz/quiz_providers.dart';
import 'package:maison_du_miracle/l10n/app_localizations.dart';
import 'package:maison_du_miracle/theme/app_theme.dart';

Quiz _q(int id, int difficulty) => Quiz(
      id: id,
      title: 'Quiz $id',
      ageBand: QuizAgeBand.teens,
      difficulty: difficulty,
      questions: const [],
      publishedAt: DateTime.utc(2026, 1, id),
    );

Future<void> _pump(WidgetTester tester, Size size, List<Quiz> quizzes,
    {Map<int, QuizScore> best = const {}}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        quizzesProvider.overrideWith((_) => Stream.value(quizzes)),
        quizBestScoresProvider.overrideWithValue(best),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const QuizPathScreen(band: QuizAgeBand.teens),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  final quizzes = [for (var i = 1; i <= 6; i++) _q(i, 1 + i ~/ 3)];

  for (final (name, size) in [
    ('téléphone', const Size(402, 874)),
    ('petit téléphone', const Size(320, 568)),
    ('iPad', const Size(820, 1180)),
  ]) {
    testWidgets('$name : la route se dessine, rien ne déborde', (tester) async {
      await _pump(tester, size, quizzes);
      expect(tester.takeException(), isNull);
      expect(find.byKey(QuizPathScreen.stepKey(1)), findsOneWidget);
    });
  }

  testWidgets('l\'étape 1 est en bas, la 2 au-dessus', (tester) async {
    await _pump(tester, const Size(402, 2000), quizzes);
    final one = tester.getCenter(find.byKey(QuizPathScreen.stepKey(1)));
    final two = tester.getCenter(find.byKey(QuizPathScreen.stepKey(2)));
    expect(one.dy, greaterThan(two.dy));
    expect(one.dx, isNot(closeTo(two.dx, 40)), reason: 'la route serpente');
  });

  testWidgets('une étape verrouillée dit laquelle réussir d\'abord',
      (tester) async {
    await _pump(tester, const Size(402, 2000), quizzes);
    await tester.tap(find.byKey(QuizPathScreen.stepKey(2)));
    await tester.pump();
    expect(find.textContaining("l'étape 1"), findsOneWidget);
  });

  testWidgets('sans quiz : le message vide', (tester) async {
    await _pump(tester, const Size(402, 874), const []);
    expect(find.byKey(QuizPathScreen.stepKey(1)), findsNothing);
    expect(find.textContaining('Aucun quiz'), findsOneWidget);
  });
}
