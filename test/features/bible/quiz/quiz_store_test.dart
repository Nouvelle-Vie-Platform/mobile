/// **Les données des quiz** (M6, mobile#204) sur un vrai magasin en mémoire :
/// dépublication par le delta, quiz de la semaine, profil d'âge, meilleurs
/// scores et badges, file d'envoi du membre et sa purge au retour du miroir.
library;

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/core/network/api_client.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/sync/sync_rows.dart';
import 'package:maison_du_miracle/features/bible/data/bible_providers.dart';
import 'package:maison_du_miracle/features/bible/quiz/quiz.dart';
import 'package:maison_du_miracle/features/bible/quiz/quiz_providers.dart';
import 'package:maison_du_miracle/state/sync_providers.dart';

import '../../../data/local/local_database_fixtures.dart';
import '../../../helpers/fake_api.dart';

String _day(int offset) => quizDay(DateTime.now().add(Duration(days: offset)));

Map<String, Object?> _quiz(
  int id, {
  String band = 'adults',
  String? from,
  String? until,
}) =>
    {
      'id': id,
      'title': 'Quiz $id',
      'ageBand': band,
      'difficulty': 1,
      'featuredFrom': from,
      'featuredUntil': until,
      'imageUrl': null,
      'questions': [
        {
          'kind': 'truefalse',
          'prompt': 'Question $id',
          'choices': ['Vrai', 'Faux'],
          'answer': 0,
        },
      ],
      'publishedAt': '2026-10-01T08:00:00.000Z',
    };

Future<void> _serve(AppDatabase db, List<Map<String, Object?>> quizzes,
    {List<int> retracted = const []}) {
  return db.syncDao.applyLiveRows(
    db.syncDao.bibleQuizzesCollection,
    upserts: [for (final q in quizzes) bibleQuizRowOf(q)],
    deletedIds: retracted,
  );
}

/// Rejoue [check] jusqu'à ce qu'il passe : les flux Drift et les providers
/// qui en dérivent se mettent à jour de façon asynchrone (machine chargée
/// comprise).
Future<void> _eventually(void Function() check) async {
  for (var i = 0;; i++) {
    try {
      check();
      return;
    } on TestFailure {
      if (i >= 250) rethrow;
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  /// Un conteneur qui **écoute** les providers lus : Riverpod 3 met en pause
  /// un provider sans écouteur.
  ProviderContainer make({required bool member}) {
    final c = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        bibleIsMemberProvider.overrideWithValue(member),
      ],
    );
    c.listen(quizzesProvider, (_, __) {});
    c.listen(featuredQuizProvider, (_, __) {});
    c.listen(quizBestScoresProvider, (_, __) {});
    c.listen(quizBadgesProvider, (_, __) {});
    return c;
  }

  setUp(() => db = openTestDatabase());
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  List<int> ids() =>
      [for (final q in container.read(quizzesProvider).value ?? []) q.id];

  test('un quiz dépublié (rétractation du delta) quitte la liste', () async {
    container = make(member: false);
    await _serve(db, [_quiz(1), _quiz(2)]);
    await _eventually(() => expect(ids(), [1, 2]));

    // `{ id, deletedAt }` : le moteur la range en `deletedIds`.
    await _serve(db, const [], retracted: [1]);
    await _eventually(() => expect(ids(), [2]));
  });

  test('le quiz de la semaine : fenêtre du jour, filtrée par le profil',
      () async {
    container = make(member: false);
    await _serve(db, [
      _quiz(1, from: _day(-10), until: _day(-3)), // passé
      _quiz(2, band: 'kids', from: _day(-1), until: _day(5)),
      _quiz(3, from: _day(-2), until: _day(4)),
      _quiz(4), // jamais en avant
    ]);
    Quiz? featured() => container.read(featuredQuizProvider);
    // Sans profil : n'importe quelle tranche, la mise en avant la plus récente.
    await _eventually(() => expect(featured()?.id, 2));

    await container.read(quizStoreProvider).setAgeBand(QuizAgeBand.adults);
    await _eventually(() => expect(featured()?.id, 3));

    await container.read(quizStoreProvider).setAgeBand(QuizAgeBand.teens);
    await _eventually(() => expect(featured(), isNull));
  });

  test('meilleur score et badges', () async {
    container = make(member: false);
    final store = container.read(quizStoreProvider);
    Set<QuizBadge> badges() => container.read(quizBadgesProvider);
    expect(badges(), isEmpty);

    await store.record(quizId: 1, score: 2, total: 5, durationSeconds: 30);
    await store.record(quizId: 1, score: 4, total: 5, durationSeconds: 30);
    await _eventually(
      () => expect(container.read(quizBestScoresProvider)[1]?.score, 4),
    );
    expect(badges(), {QuizBadge.firstQuiz});

    await store.record(quizId: 2, score: 3, total: 3, durationSeconds: 10);
    for (var id = 3; id <= 10; id++) {
      await store.record(quizId: id, score: 0, total: 3, durationSeconds: 5);
    }
    await _eventually(
      () => expect(
        badges(),
        {QuizBadge.firstQuiz, QuizBadge.perfect, QuizBadge.tenQuizzes},
      ),
    );
  });

  test('un invité ne lit jamais le miroir des scores', () async {
    await db.into(db.bibleQuizResults).insert(
          BibleQuizResultsCompanion.insert(
            id: 'autre-compte',
            quizId: 1,
            score: const Value(5),
            total: const Value(5),
          ),
        );
    container = make(member: false);
    await container
        .read(quizStoreProvider)
        .record(quizId: 2, score: 1, total: 2, durationSeconds: 5);
    await _eventually(
      () => expect(container.read(quizBestScoresProvider).keys, [2]),
    );
    container.dispose();
    container = make(member: true);
    await _eventually(
      () => expect(container.read(quizBestScoresProvider).keys, {1, 2}),
    );
  });

  group('La file d\'envoi du membre', () {
    late FakeAdapter wire;
    late Dio dio;
    var status = 200;

    setUp(() {
      status = 200;
      wire = FakeAdapter((o) => status == 200
          ? jsonReply(200, {'id': (o.data as Map)['id']})
          : status == 0
              ? throw DioException.connectionError(
                  requestOptions: o, reason: 'hors ligne')
              : errorReply(status, 'E_BIBLE_PAYLOAD_INVALID'));
      dio = Dio(BaseOptions(baseUrl: 'https://eenv.brainsial.com'))
        ..interceptors.add(unwrapEnvelopeInterceptor)
        ..httpClientAdapter = wire;
    });

    Future<List<LocalBibleQuizResultRow>> local() =>
        db.select(db.localBibleQuizResults).get();

    test('envoi, puis purge quand le miroir ramène la ligne', () async {
      container = make(member: true);
      final store = container.read(quizStoreProvider);
      await store.record(
        quizId: 4,
        score: 8,
        total: 10,
        durationSeconds: 95,
        now: DateTime.utc(2026, 10, 13, 10),
      );
      await store.sendPending(dio);

      expect(wire.requests, hasLength(1));
      expect(wire.lastRequest.method, 'POST');
      expect(wire.lastRequest.path, '/bible/quiz-results');
      final id = (await local()).single.id;
      expect(wire.lastBody, {
        'id': id,
        'quizId': 4,
        'score': 8,
        'total': 10,
        'durationSeconds': 95,
        'playedAt': '2026-10-13T10:00:00.000Z',
      });
      // Envoyée : gardée jusqu'au passage suivant (le score reste affiché).
      expect((await local()).single.dirty, isFalse);

      await db.syncDao.applyLiveRows(
        db.syncDao.bibleQuizResultsCollection,
        upserts: [
          bibleQuizResultRowOf({
            'id': id,
            'quizId': 4,
            'score': 8,
            'total': 10,
            'durationSeconds': 95,
            'playedAt': '2026-10-13T10:00:00.000Z',
            'updatedAt': '2026-10-13T10:00:01.000Z',
          }),
        ],
      );
      // Le cycle suivant : purgée, et pas renvoyée.
      await store.sendPending(dio);
      expect(await local(), isEmpty);
      expect(wire.requests, hasLength(1), reason: 'pas de double envoi');
      await _eventually(
        () => expect(container.read(quizBestScoresProvider)[4]?.score, 8),
      );
    });

    test('envoyée mais jamais ramenée par le miroir : purgée quand même',
        () async {
      container = make(member: true);
      final store = container.read(quizStoreProvider);
      await store.record(quizId: 4, score: 1, total: 2, durationSeconds: 5);
      await store.sendPending(dio);
      expect((await local()).single.dirty, isFalse);
      await store.sendPending(dio);
      expect(await local(), isEmpty);
      expect(wire.requests, hasLength(1));
    });

    test('panne réseau : rejoué ; refus 4xx : abandonné', () async {
      container = make(member: true);
      final store = container.read(quizStoreProvider);
      await store.record(quizId: 4, score: 1, total: 2, durationSeconds: 5);

      status = 0;
      await store.sendPending(dio);
      expect((await local()).single.dirty, isTrue);
      expect((await local()).single.lastError, isNotNull);

      status = 422;
      await store.sendPending(dio);
      expect((await local()).single.dirty, isFalse);
      // Abandonnée : purgée au passage suivant, jamais renvoyée.
      await store.sendPending(dio);
      expect(wire.requests, hasLength(2));
      expect(await local(), isEmpty);
    });

    test('un invité n\'envoie rien', () async {
      container = make(member: false);
      ApiClient.instance.dio.httpClientAdapter = wire;
      await container
          .read(quizStoreProvider)
          .record(quizId: 4, score: 1, total: 2, durationSeconds: 5);
      await container.read(quizOutboxProvider)();
      expect(wire.requests, isEmpty);
      expect((await local()).single.dirty, isTrue);
    });
  });
}
