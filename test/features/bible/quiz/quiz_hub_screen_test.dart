import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/features/bible/quiz/quiz.dart';
import 'package:maison_du_miracle/features/bible/quiz/quiz_hub_screen.dart';
import 'package:maison_du_miracle/features/bible/quiz/quiz_providers.dart';
import 'package:maison_du_miracle/l10n/app_localizations.dart';
import 'package:maison_du_miracle/theme/app_theme.dart';

Future<void> _pump(WidgetTester tester, Size size,
    {QuizAgeBand? current}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        quizAgeProfileProvider.overrideWith((_) => Stream.value(current)),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const QuizHubScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  for (final (name, size) in [
    ('téléphone', const Size(402, 874)),
    ('petit téléphone', const Size(320, 568)),
    ('iPad', const Size(820, 1180)),
    ('paysage', const Size(874, 402)),
  ]) {
    testWidgets('$name : trois tranches, rien ne casse', (tester) async {
      await _pump(tester, size, current: QuizAgeBand.teens);
      expect(tester.takeException(), isNull);
      for (final b in QuizAgeBand.values) {
        expect(find.byKey(QuizHubScreen.bandKey(b)), findsOneWidget);
      }
      expect(find.text('Jeunes'), findsOneWidget);
      expect(find.text('QUIZ'), findsOneWidget);
    });
  }
}
