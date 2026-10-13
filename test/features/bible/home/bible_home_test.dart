/// **L'accueil du module Bible** (M7, #205) : verset du jour (portail puis
/// repli), gestes dédoublonnés, favori, Continuer la lecture, passage du
/// dimanche, raccourcis disposés, carte du quiz, deux colonnes sur iPad.
///
/// Tout ce qui touche Drift vit dans **un** `runAsync` par test.
library;

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:maison_du_miracle/core/network/api_client.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/features/bible/data/bible_providers.dart';
import 'package:maison_du_miracle/features/bible/data/canon.dart';
import 'package:maison_du_miracle/features/bible/home/data/fallback_verses.dart';
import 'package:maison_du_miracle/features/bible/home/data/home_data.dart';
import 'package:maison_du_miracle/features/bible/home/home_slots.dart';
import 'package:maison_du_miracle/features/bible/home/home_view.dart';
import 'package:maison_du_miracle/features/bible/quiz/quiz_screens.dart';
import 'package:maison_du_miracle/features/bible/shell/bible_slots.dart';
import 'package:maison_du_miracle/l10n/app_localizations_fr.dart';
import 'package:maison_du_miracle/l10n/l10n_setup.dart';
import 'package:maison_du_miracle/router/app_router.dart';
import 'package:maison_du_miracle/state/sync_providers.dart';
import 'package:maison_du_miracle/state/theme_provider.dart';
import 'package:maison_du_miracle/theme/app_theme.dart';

import '../../../data/local/local_database_fixtures.dart';
import '../../../helpers/fake_api.dart';

final _fr = AppLocalizationsFr();
final _today = DateTime(2026, 10, 13, 9);
const _day = '2026-10-13';

late FakeAdapter _wire;

List<RequestOptions> _events() => [
      for (final r in _wire.requests)
        if (r.path.endsWith('/bible/verse-of-day/events')) r,
    ];

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 30));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }
}

/// Le corps du test en temps réel, puis le démontage **dans** ce temps réel :
/// les flux Drift se referment sans laisser de minuterie factice.
Future<void> _run(WidgetTester tester, Future<void> Function() body) =>
    tester.runAsync(() async {
      await body();
      await tester.pumpWidget(const SizedBox());
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });

final List<String> _shared = [];
final List<String> _tapped = [];

BibleHomeShortcut _shortcut(String id, int order) => BibleHomeShortcut(
      id: id,
      order: order,
      icon: Icons.circle,
      label: (_) => 'raccourci $id',
      onTap: (_, __) => _tapped.add(id),
    );

/// L'accueil seul, sous un routeur minimal : `/` puis les destinations.
Future<(AppDatabase, GoRouter)> _pump(
  WidgetTester tester, {
  List<BibleHomeShortcut> shortcuts = const [],
  Future<void> Function(AppDatabase db)? seed,
}) async {
  final db = openTestDatabase();
  addTearDown(db.close);
  await seed?.call(db);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => Scaffold(
          body: Consumer(
            builder: (context, ref, _) => ListView(
              children: [
                for (final s in ref.watch(bibleSlotsProvider).homeSections)
                  s.builder(context),
              ],
            ),
          ),
        ),
      ),
      GoRoute(
        name: AppRoute.bibleReader,
        path: '/bible/read/:book/:chapter',
        builder: (_, s) => Text(
          'lecteur ${s.pathParameters['book']} ${s.pathParameters['chapter']}'
          ' ${s.uri.queryParameters['v'] ?? ''}',
        ),
      ),
      GoRoute(
        name: AppRoute.teachingDetail,
        path: '/teaching/:id',
        builder: (_, s) => Text('enseignement ${s.pathParameters['id']}'),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        nowProvider.overrideWithValue(() => _today),
        bibleIsMemberProvider.overrideWithValue(false),
        routerProvider.overrideWithValue(router),
        bibleVerseSharerProvider
            .overrideWithValue((_, link) => _shared.add(link.labelFr)),
        bibleSlotsProvider.overrideWithValue(
          BibleSlots.merge([BibleSlots(homeShortcuts: shortcuts), homeSlots]),
        ),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.light,
        locale: const Locale('fr'),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: appSupportedLocales,
      ),
    ),
  );
  await _settle(tester);
  return (db, router);
}

Future<void> _seedVerse(AppDatabase db, {int? backgroundId}) async {
  await db.into(db.bibleVerseOfDays).insert(
        BibleVerseOfDaysCompanion.insert(
          id: const Value(1),
          day: _day,
          book: 'Rom',
          chapter: 8,
          verseFrom: const Value(28),
          comment: const Value('Tout concourt au bien.'),
          backgroundId: Value(backgroundId),
        ),
      );
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    _shared.clear();
    _tapped.clear();
    _wire = FakeAdapter((o) => jsonReply(200, {'counted': true}));
    ApiClient.instance.dio.httpClientAdapter = _wire;
  });

  group('Le verset du jour', () {
    testWidgets('celui du portail, avec son commentaire et son fond',
        (tester) async {
      _phone(tester);
      await _run(tester, () async {
        await _pump(
          tester,
          seed: (db) async {
            await db.into(db.statusBackgrounds).insert(
                  StatusBackgroundsCompanion.insert(
                    id: const Value(4),
                    label: const {'fr': 'Aube'},
                    baseColor: '#223B8C',
                    topColor: '#2E4BA8',
                    bottomColor: '#162A66',
                    ink: 'light',
                  ),
                );
            await _seedVerse(db, backgroundId: 4);
          },
        );
        expect(find.text(_fr.bibleHomeHeroTitle), findsOneWidget);
        expect(find.text('Romains 8:28'), findsOneWidget);
        expect(find.text('Tout concourt au bien.'), findsOneWidget);
        final text = tester.widget<Text>(find.byKey(BibleHomeKeys.verseText));
        expect(text.data, startsWith('« '));
        expect(find.byType(Image), findsNothing, reason: 'fond servi');

        await tester.tap(find.byKey(BibleHomeKeys.read));
        await _settle(tester);
        expect(find.text('lecteur Rom 8 28'), findsOneWidget);
      });
    });

    testWidgets('sans verset publié : la liste intégrée et l\'image',
        (tester) async {
      _phone(tester);
      await _run(tester, () async {
        await _pump(tester);
        expect(find.text(fallbackVerseFor(_today).labelFr), findsOneWidget);
        expect(find.byType(Image), findsOneWidget);
      });
    });
  });

  group('Les gestes', () {
    testWidgets('ouvert, partagé, favori : une fois par jour et par type',
        (tester) async {
      _phone(tester);
      await _run(tester, () async {
        final (db, _) = await _pump(tester, seed: _seedVerse);
        expect(_events(), hasLength(1));
        final body = (_events().single.data as Map).cast<String, dynamic>();
        expect(body['day'], _day);
        expect(body['kind'], 'opened');
        expect(body['deviceId'], isA<String>());

        await tester.tap(find.byKey(BibleHomeKeys.share));
        await _settle(tester);
        await tester.tap(find.byKey(BibleHomeKeys.share));
        await _settle(tester);
        expect(_shared, hasLength(2));
        // Le studio de partage (M4) reçoit la référence du jour.
        expect(_shared.first, 'Romains 8:28');

        await tester.tap(find.byKey(BibleHomeKeys.favorite));
        await _settle(tester);
        final marks = await db.select(db.localBibleMarks).get();
        expect(marks, hasLength(1));
        expect(marks.single.kind, 'favorite');
        expect(
          (marks.single.book, marks.single.chapter, marks.single.verseFrom),
          ('Rom', 8, 28),
        );
        expect(marks.single.dirty, isTrue);
        expect(find.byIcon(Icons.favorite), findsOneWidget);

        expect(
          [for (final r in _events()) (r.data as Map)['kind']],
          ['opened', 'shared', 'favorited'],
        );
      });
    });

    test('un geste compté ne repart pas ; un échec est retenté', () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      var status = 500;
      final wire = FakeAdapter((o) => jsonReply(status, {'counted': true}));
      final dio = Dio(BaseOptions(baseUrl: 'http://test'))
        ..httpClientAdapter = wire;
      final events = VerseOfDayEvents(
        db: db,
        dio: dio,
        deviceId: () async => 'device-0123456789',
      );

      await events.record(_day, VerseOfDayEventKind.opened);
      expect(wire.requests, hasLength(1));
      status = 200;
      await events.record(_day, VerseOfDayEventKind.opened);
      await events.record(_day, VerseOfDayEventKind.opened);
      expect(wire.requests, hasLength(2));
      await events.record('2026-10-14', VerseOfDayEventKind.opened);
      await events.record(_day, VerseOfDayEventKind.shared);
      expect(wire.requests, hasLength(4));
    });
  });

  testWidgets('Continuer la lecture : la position et la progression du livre',
      (tester) async {
    _phone(tester);
    await _run(tester, () async {
      await _pump(
        tester,
        seed: (db) async {
          await db.bibleDao.markChapterRead(
            member: false,
            book: 'John',
            chapter: 1,
          );
          await db.bibleDao.markChapterRead(
            member: false,
            book: 'John',
            chapter: 2,
          );
          await db.bibleDao.savePosition(
            member: false,
            versionCode: 'EXA',
            book: 'John',
            chapter: 3,
            verse: 16,
          );
        },
      );
      expect(find.byKey(BibleHomeKeys.continueReading), findsOneWidget);
      expect(find.text('Jean 3'), findsOneWidget);
      expect(
          find.text(_fr.bibleHomeBookProgress(2, 21, 'Jean')), findsOneWidget);
      await tester.ensureVisible(find.byKey(BibleHomeKeys.continueReading));
      await tester.tap(find.byKey(BibleHomeKeys.continueReading));
      await _settle(tester);
      expect(find.text('lecteur John 3 16'), findsOneWidget);
    });
  });

  testWidgets('sans position : pas de carte « Continuer »', (tester) async {
    _phone(tester);
    await _run(tester, () async {
      await _pump(tester);
      expect(find.byKey(BibleHomeKeys.continueReading), findsNothing);
    });
  });

  testWidgets(
      'le passage du dimanche : le plus récent passé, ses références '
      'et son enseignement', (tester) async {
    _phone(tester);
    await _run(tester, () async {
      await _pump(
        tester,
        seed: (db) async {
          for (final (id, day, title) in [
            (1, '2026-10-04', 'Ancien'),
            (2, '2026-10-11', 'La foi'),
            (3, '2026-10-18', 'À venir'),
          ]) {
            await db.into(db.bibleSundayPassages).insert(
                  BibleSundayPassagesCompanion.insert(
                    id: Value(id),
                    day: day,
                    title: Value(title),
                    teachingId: const Value('t-42'),
                    references: const Value(
                      '[{"book":"Heb","chapter":11,"verseFrom":1,"verseTo":3},'
                      '{"book":"Rom","chapter":10},{"book":"Nope","chapter":1}]',
                    ),
                  ),
                );
          }
        },
      );
      expect(find.byKey(BibleHomeKeys.sunday), findsOneWidget);
      expect(find.text('La foi'), findsOneWidget);
      expect(find.text('À venir'), findsNothing);
      expect(find.text('Hébreux 11:1-3'), findsOneWidget);
      expect(find.text('Romains 10'), findsOneWidget);
      expect(find.byKey(BibleHomeKeys.sundayRef(2)), findsNothing);

      await tester.ensureVisible(find.byKey(BibleHomeKeys.sundayRef(0)));
      await tester.tap(find.byKey(BibleHomeKeys.sundayRef(0)));
      await _settle(tester);
      expect(find.text('lecteur Heb 11 1-3'), findsOneWidget);
    });
  });

  testWidgets('l\'enseignement du dimanche ouvre le lecteur média',
      (tester) async {
    _phone(tester);
    await _run(tester, () async {
      await _pump(
        tester,
        seed: (db) => db.into(db.bibleSundayPassages).insert(
              BibleSundayPassagesCompanion.insert(
                id: const Value(1),
                day: '2026-10-11',
                teachingId: const Value('t-42'),
                references: const Value('[{"book":"John","chapter":1}]'),
              ),
            ),
      );
      await tester.ensureVisible(find.byKey(BibleHomeKeys.sundayTeaching));
      await tester.tap(find.byKey(BibleHomeKeys.sundayTeaching));
      await _settle(tester);
      expect(find.text('enseignement t-42'), findsOneWidget);
    });
  });

  testWidgets(
      'les raccourcis des autres tranches, disposés dans l\'ordre ; '
      'la recherche ouvre celui de M3', (tester) async {
    _phone(tester);
    await _run(tester, () async {
      await _pump(
        tester,
        shortcuts: [
          _shortcut('offline', 40),
          _shortcut('plans', 10),
          _shortcut('search', 50),
          _shortcut('quiz', 30),
        ],
      );
      final xs = [
        for (final id in ['plans', 'quiz', 'offline', 'search'])
          tester.getTopLeft(find.byKey(BibleHomeKeys.shortcut(id))).dx,
      ];
      expect(xs, orderedEquals([...xs]..sort()));
      await tester.tap(find.byKey(BibleHomeKeys.search));
      await tester.tap(find.byKey(BibleHomeKeys.shortcut('plans')));
      expect(_tapped, ['search', 'plans']);
    });
  });

  testWidgets('sans raccourci « search », pas de barre de recherche',
      (tester) async {
    _phone(tester);
    await _run(tester, () async {
      await _pump(tester);
      expect(find.byKey(BibleHomeKeys.search), findsNothing);
    });
  });

  testWidgets('la carte du quiz : présente si un quiz est à l\'affiche',
      (tester) async {
    _phone(tester);
    await _run(tester, () async {
      final (db, _) = await _pump(tester, shortcuts: [_shortcut('quiz', 30)]);
      expect(find.byKey(BibleHomeKeys.quiz), findsNothing);

      await db.into(db.bibleQuizzes).insert(
            BibleQuizzesCompanion.insert(
              id: const Value(7),
              title: 'Les patriarches',
              ageBand: const Value('adults'),
              questions: const Value(
                '[{"kind":"truefalse","prompt":"Abraham ?",'
                '"choices":["Vrai","Faux"],"answer":0}]',
              ),
              featuredFrom: const Value('2026-10-12'),
              featuredUntil: const Value('2026-10-18'),
              publishedAt: Value(DateTime.utc(2026, 10, 1)),
            ),
          );
      await _settle(tester);
      expect(find.byKey(BibleHomeKeys.quiz), findsOneWidget);
      expect(find.text('Les patriarches'), findsOneWidget);
      await tester.ensureVisible(find.byKey(BibleHomeKeys.quiz));
      await tester.tap(find.byKey(BibleHomeKeys.quiz));
      await _settle(tester);
      // Le quiz de M6 s'ouvre directement sur le jeu.
      expect(find.byType(QuizPlayScreen), findsOneWidget);
      expect(_tapped, isEmpty);
    });
  });

  testWidgets('un quiz hors de sa fenêtre n\'a pas de carte', (tester) async {
    _phone(tester);
    await _run(tester, () async {
      await _pump(
        tester,
        seed: (db) => db.into(db.bibleQuizzes).insert(
              BibleQuizzesCompanion.insert(
                id: const Value(7),
                title: 'Passé',
                ageBand: const Value('adults'),
                questions: const Value(
                  '[{"kind":"truefalse","prompt":"?",'
                  '"choices":["Vrai","Faux"],"answer":0}]',
                ),
                featuredFrom: const Value('2026-10-01'),
                featuredUntil: const Value('2026-10-07'),
                publishedAt: Value(DateTime.utc(2026, 10, 1)),
              ),
            ),
      );
      expect(find.byKey(BibleHomeKeys.quiz), findsNothing);
    });
  });

  testWidgets('iPad : deux colonnes au-delà de 700 px', (tester) async {
    tester.view.physicalSize = const Size(1024, 1366);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _run(tester, () async {
      await _pump(
        tester,
        shortcuts: [_shortcut('plans', 10)],
        seed: (db) => db.into(db.bibleSundayPassages).insert(
              BibleSundayPassagesCompanion.insert(
                id: const Value(1),
                day: '2026-10-11',
                title: const Value('La foi'),
                references: const Value('[{"book":"John","chapter":1}]'),
              ),
            ),
      );
      expect(find.byKey(BibleHomeKeys.twoColumns), findsOneWidget);
      final plans =
          tester.getTopLeft(find.byKey(BibleHomeKeys.shortcut('plans')));
      final sunday = tester.getTopLeft(find.byKey(BibleHomeKeys.sunday));
      expect(sunday.dx, greaterThan(plans.dx + 300));
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('téléphone : une seule colonne', (tester) async {
    _phone(tester);
    await _run(tester, () async {
      await _pump(tester);
      expect(find.byKey(BibleHomeKeys.twoColumns), findsNothing);
    });
  });

  test('la liste intégrée : 365 références valides et distinctes', () {
    expect(fallbackVerses, hasLength(365));
    expect(fallbackVerses.toSet(), hasLength(365));
    for (final r in fallbackVerses) {
      expect(isValidBibleRef(parseFallbackVerse(r)), isTrue, reason: r);
    }
    expect(fallbackVerseFor(DateTime(2026, 1, 1)).labelFr,
        parseFallbackVerse(fallbackVerses.first).labelFr);
    expect(fallbackVerseFor(DateTime(2028, 12, 31)).labelFr,
        parseFallbackVerse(fallbackVerses.last).labelFr);
    expect(decodeBibleReferences('pas du json'), isEmpty);
  });
}
