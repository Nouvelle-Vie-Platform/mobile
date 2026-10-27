/// **Les écrans des quiz** (M6, mobile#204) : de l'onglet « Plus » au score à
/// travers le vrai routeur (profil, bonne et mauvaise réponse, référence vers
/// le lecteur, fin, score retenu, rejouer), puis le profil enfant et le
/// chronomètre sous l'horloge factice.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/core/network/api_client.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/radio/radio_antenna.dart';
import 'package:maison_du_miracle/data/radio/radio_repository.dart';
import 'package:maison_du_miracle/data/sync/sync_rows.dart';
import 'package:maison_du_miracle/features/bible/quiz/quiz.dart';
import 'package:maison_du_miracle/features/bible/quiz/quiz_hub_screen.dart';
import 'package:maison_du_miracle/features/bible/quiz/quiz_path_screen.dart';
import 'package:maison_du_miracle/features/bible/quiz/quiz_providers.dart';
import 'package:maison_du_miracle/features/bible/quiz/quiz_screens.dart';
import 'package:maison_du_miracle/features/bible/reader/bible_reader_screen.dart';
import 'package:maison_du_miracle/l10n/app_localizations_fr.dart';
import 'package:maison_du_miracle/l10n/l10n_setup.dart';
import 'package:maison_du_miracle/state/radio_providers.dart';
import 'package:maison_du_miracle/state/sync_providers.dart';

import '../../../helpers/fake_api.dart';
import '../../../helpers/guest_app.dart';

final _fr = AppLocalizationsFr();

final Override _radioOff = radioRepositoryProvider.overrideWithValue(
  const FixedRadioRepository(RadioAntenna.unknown),
);

final Map<String, Object?> _served = {
  'id': 4,
  'title': 'Les patriarches',
  'ageBand': 'adults',
  'difficulty': 2,
  'featuredFrom': null,
  'featuredUntil': null,
  'imageUrl': null,
  'questions': [
    {
      'kind': 'choice',
      'prompt': 'Qui est le père d\'Isaac ?',
      'choices': ['Abraham', 'Jacob', 'Moïse'],
      'answer': 0,
      'explanation': 'Isaac est le fils de la promesse.',
      'reference': {'book': 'Gen', 'chapter': 21, 'verseFrom': 1},
    },
    {
      'kind': 'truefalse',
      'prompt': 'Jacob a douze fils.',
      'choices': ['Vrai', 'Faux'],
      'answer': 0,
    },
  ],
  // Publié hier : « nouveau » tant qu'il n'a pas été joué.
  'publishedAt': DateTime.now()
      .toUtc()
      .subtract(const Duration(days: 1))
      .toIso8601String(),
};

Quiz get _quiz => Quiz.fromRow(
      BibleQuizRow(
        id: 4,
        title: const {'fr': 'Les patriarches'},
        ageBand: 'kids',
        difficulty: 1,
        questions: '[{"kind":"truefalse","prompt":"Noé a bâti une arche.",'
            '"choices":["Vrai","Faux"],"answer":0}]',
        syncStamp: 0,
      ),
      'fr',
    )!;

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 30));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }
}

class _Speaker implements QuizSpeaker {
  final said = <String>[];
  var stopped = false;

  @override
  Future<void> speak(String text) async => said.add(text);

  @override
  Future<void> stop() async => stopped = true;
}

Future<_Speaker> _pumpPlay(WidgetTester tester, {required bool kids}) async {
  final speaker = _Speaker();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [quizSpeakerProvider.overrideWithValue(speaker)],
      child: MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: appSupportedLocales,
        home: QuizPlayScreen(quiz: _quiz, kids: kids),
      ),
    ),
  );
  await tester.pump();
  return speaker;
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    ApiClient.instance.dio.httpClientAdapter = FakeAdapter(
      (o) => throw StateError('requête HTTP interdite : ${o.method} ${o.path}'),
    );
  });

  testWidgets('de « Plus » au score : profil, réponses, référence, rejouer',
      (tester) async {
    await tester.runAsync(() async {
      final container = guestContainer(extra: [_radioOff]);
      final db = container.read(appDatabaseProvider);
      await db.syncDao.applyLiveRows(
        db.syncDao.bibleQuizzesCollection,
        upserts: [bibleQuizRowOf(_served)],
      );
      final router = await pumpGuestApp(tester, container);
      router.push('/bible?tab=more');
      await _settle(tester);

      await tester.tap(find.byKey(const Key('bible_more_quiz')));
      await _settle(tester);

      // L'écran de choix du joueur, à chaque ouverture : Adultes.
      expect(find.byType(QuizHubScreen), findsOneWidget);
      expect(find.text(_fr.bibleQuizBandTeens), findsOneWidget);
      await tester.tap(find.byKey(QuizHubScreen.bandKey(QuizAgeBand.adults)));
      await _settle(tester);
      expect(await db.select(db.appSettings).get(), isNotEmpty);
      // Le parcours de la tranche : l'étape 1, ouverte, lance la partie.
      expect(find.byType(QuizPathScreen), findsOneWidget);
      expect(find.text(_fr.bibleQuizPathProgress(0, 1)), findsOneWidget);
      await tester.tap(find.byKey(QuizPathScreen.stepKey(1)));
      await _settle(tester);
      expect(find.text(_fr.bibleQuizProgress(1, 2)), findsOneWidget);

      // Bonne réponse : retour immédiat, explication, référence.
      await tester.tap(find.byKey(QuizPlayScreen.choiceKey(0)));
      await _settle(tester);
      expect(find.text(_fr.bibleQuizRight), findsOneWidget);
      expect(find.text('Isaac est le fils de la promesse.'), findsOneWidget);
      await tester.tap(find.byKey(QuizPlayScreen.referenceKey));
      await _settle(tester);
      final reader =
          tester.widget<BibleReaderScreen>(find.byType(BibleReaderScreen));
      expect((reader.book, reader.chapter, reader.from), ('Gen', 21, 1));
      router.pop();
      await _settle(tester);
      expect(find.byType(BibleReaderScreen), findsNothing);

      // Mauvaise réponse.
      await tester.tap(find.byKey(QuizPlayScreen.nextKey));
      await _settle(tester);
      await tester.tap(find.byKey(QuizPlayScreen.choiceKey(1)));
      await _settle(tester);
      expect(find.text(_fr.bibleQuizWrong), findsOneWidget);
      expect(find.text(_fr.bibleQuizAnswerWas('Vrai')), findsOneWidget);

      // Fin : score, étoiles, score retenu.
      await tester.tap(find.byKey(QuizPlayScreen.nextKey));
      await _settle(tester);
      expect(find.text(_fr.bibleQuizScore(1, 2)), findsOneWidget);
      final saved = await db.select(db.localBibleQuizResults).get();
      expect(
        saved.map((r) => (r.quizId, r.score, r.total, r.dirty)),
        [(4, 1, 2, true)],
      );

      // Rejouer repart de la première question.
      await tester.tap(find.byKey(QuizPlayScreen.replayKey));
      await _settle(tester);
      expect(find.text(_fr.bibleQuizProgress(1, 2)), findsOneWidget);

      // Retour au parcours : 1/2, une étoile — pas assez pour réussir
      // l'étape (2 étoiles), qui reste à jouer.
      router.routerDelegate.navigatorKey.currentState!.pop();
      await _settle(tester);
      expect(find.byType(QuizPathScreen), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
      expect(find.text(_fr.bibleQuizPathProgress(0, 1)), findsOneWidget);
    });
  });

  testWidgets(
      'profil enfant : voix, grands boutons, texte agrandi, '
      'chronomètre sans pénalité', (tester) async {
    final speaker = await _pumpPlay(tester, kids: true);
    expect(speaker.said, ['Noé a bâti une arche.. Vrai. Faux']);
    expect(
      tester.getSize(find.byKey(QuizPlayScreen.choiceKey(0))).height,
      greaterThanOrEqualTo(72),
    );
    final prompt = tester.element(find.text('Noé a bâti une arche.'));
    expect(MediaQuery.textScalerOf(prompt).scale(10), greaterThanOrEqualTo(13));

    await tester.tap(find.byKey(QuizPlayScreen.listenKey));
    expect(speaker.said, hasLength(2));

    await tester.pump(QuizPlayScreen.questionTime + const Duration(seconds: 2));
    expect(find.text(_fr.bibleQuizTimeUp), findsNothing);
    await tester.tap(find.byKey(QuizPlayScreen.choiceKey(0)));
    await tester.pump();
    expect(find.text(_fr.bibleQuizRight), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    expect(speaker.stopped, isTrue);
  });

  testWidgets('profil adulte : muet, et le temps écoulé compte faux',
      (tester) async {
    final speaker = await _pumpPlay(tester, kids: false);
    expect(speaker.said, isEmpty);
    expect(find.byKey(QuizPlayScreen.listenKey), findsNothing);
    expect(
      tester.getSize(find.byKey(QuizPlayScreen.choiceKey(0))).height,
      lessThan(72),
    );

    await tester.pump(QuizPlayScreen.questionTime + const Duration(seconds: 1));
    expect(find.text(_fr.bibleQuizTimeUp), findsOneWidget);
    expect(find.text(_fr.bibleQuizAnswerWas('Vrai')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
