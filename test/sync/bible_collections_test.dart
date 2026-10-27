/// **Les dix collections du module Bible, de bout en bout** (#199) : les
/// lignes servies (contrats du plan §3, types d'identifiants du §6) traversent
/// `sync_rows.dart`, une rétractation voyage, un serveur en retard ne coûte
/// rien, et les privées ne sont jamais des référentiels.
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/core/network/api_client.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/sync/branch_filter.dart';
import 'package:maison_du_miracle/data/sync/sync_api.dart';
import 'package:maison_du_miracle/data/sync/sync_engine.dart';
import 'package:maison_du_miracle/data/sync/synced_collection.dart';

import '../data/local/local_database_fixtures.dart';
import '../helpers/fake_sync_server.dart';
import '../helpers/sync_fixtures.dart';

const _owner = 'b6f0a1c2-0000-4000-8000-000000000001';
const _planId = '019f9000-0000-7000-8000-0000000000p1';

const Map<String, List<Map<String, Object?>>> _payloads = {
  'bible_versions': [
    {
      'id': 1,
      'code': 'LSG',
      'name': 'Louis Segond 1910',
      'language': 'fr',
      'license': 'Domaine public',
      'sizeBytes': 4200000,
      'sortOrder': 1,
      'archiveUrl': null,
      'publishedAt': '2026-10-13T08:00:00.000Z',
      'deletedAt': null,
    },
  ],
  'bible_verse_of_days': [
    {
      'id': 7,
      'day': '2026-10-13',
      'book': 'John',
      'chapter': 3,
      'verseFrom': 16,
      'verseTo': null,
      'comment': 'Tant aimé',
      'backgroundId': 2,
      'publishedAt': '2026-10-12T08:00:00.000Z',
      'deletedAt': null,
    },
  ],
  'bible_sunday_passages': [
    {
      'id': 3,
      'day': '2026-10-18',
      'references': [
        {'book': 'Ps', 'chapter': 23},
      ],
      'title': 'Le berger',
      'teachingId': null,
      'gatheringId': null,
      'deletedAt': null,
    },
  ],
  'bible_plans': [
    {
      'id': _planId,
      'title': 'Évangiles en 40 jours',
      'description': null,
      'coverBackgroundId': null,
      'days': [
        [
          {'book': 'Matt', 'chapter': 1},
        ],
      ],
      'publishedAt': '2026-10-01T08:00:00.000Z',
      'deletedAt': null,
    },
  ],
  'bible_challenges': [
    {
      'id': '019f9000-0000-7000-8000-0000000000c1',
      'planId': _planId,
      'title': 'Défi de l\'Avent',
      'startsOn': '2026-12-01',
      'endsOn': '2026-12-24',
      'publishedAt': '2026-10-01T08:00:00.000Z',
      'deletedAt': null,
    },
  ],
  'bible_quizzes': [
    {
      'id': 4,
      'title': 'Les patriarches',
      'ageBand': 'kids',
      'difficulty': 1,
      'questions': [
        {
          'kind': 'truefalse',
          'prompt': 'Abraham est le père d\'Isaac.',
          'choices': ['Vrai', 'Faux'],
          'answer': 0,
        },
      ],
      'publishedAt': '2026-10-01T08:00:00.000Z',
      'deletedAt': null,
    },
  ],
  'bible_marks': [
    {
      'id': '019f9000-0000-7000-8000-0000000000m1',
      'ownerId': _owner,
      'kind': 'highlight',
      'book': 'John',
      'chapter': 3,
      'verseFrom': 16,
      'verseTo': 18,
      'color': 'yellow',
      'clientCreatedAt': '2026-10-13T07:00:00.000Z',
      'clientUpdatedAt': '2026-10-13T07:00:00.000Z',
      'createdAt': '2026-10-13T07:00:01.000Z',
      'updatedAt': '2026-10-13T07:00:01.000Z',
      'deletedAt': null,
    },
    // Une marque **au mot** (#252, server-portal#620) : sa traduction, et un
    // `charFrom` à **0** — le premier caractère du verset, valeur légitime
    // qu'un test de vérité avalerait.
    {
      'id': '019f9000-0000-7000-8000-0000000000m2',
      'ownerId': _owner,
      'kind': 'highlight',
      'book': 'Ps',
      'chapter': 23,
      'verseFrom': 1,
      'verseTo': 1,
      'color': 'green',
      'versionCode': 'LSG',
      'charFrom': 0,
      'charTo': 11,
      'clientCreatedAt': '2026-10-27T07:00:00.000Z',
      'clientUpdatedAt': '2026-10-27T07:00:00.000Z',
      'createdAt': '2026-10-27T07:00:01.000Z',
      'updatedAt': '2026-10-27T07:00:01.000Z',
      'deletedAt': null,
    },
  ],
  'bible_reading_states': [
    {
      'id': '019f9000-0000-7000-8000-0000000000r1',
      'ownerId': _owner,
      'versionCode': 'EXA',
      'book': 'John',
      'chapter': 3,
      'verse': 16,
      'readChapters': {
        'John': [1, 2, 3],
      },
      'streakDays': 4,
      'lastReadOn': '2026-10-13',
      'updatedAt': '2026-10-13T07:00:01.000Z',
      'deletedAt': null,
    },
  ],
  'bible_plan_enrollments': [
    {
      'id': '019f9000-0000-7000-8000-0000000000e1',
      'ownerId': _owner,
      'source': 'published',
      'planCode': null,
      'planId': _planId,
      'custom': null,
      'startedOn': '2026-10-01',
      'completedDays': [1, 2],
      'challengeId': null,
      'updatedAt': '2026-10-13T07:00:01.000Z',
      'deletedAt': null,
    },
  ],
  'bible_quiz_results': [
    {
      'id': '019f9000-0000-7000-8000-0000000000q1',
      'ownerId': _owner,
      'quizId': 4,
      'score': 8,
      'total': 10,
      'durationSeconds': 95,
      'playedAt': '2026-10-13T07:00:00.000Z',
      'updatedAt': '2026-10-13T07:00:01.000Z',
      'deletedAt': null,
    },
  ],
};

void main() {
  late FakeSyncServer server;
  late Dio dio;
  late AppDatabase db;

  setUp(() {
    server = FakeSyncServer();
    dio = Dio(BaseOptions(baseUrl: 'https://eenv.brainsial.com'))
      ..interceptors.add(unwrapEnvelopeInterceptor)
      ..httpClientAdapter = server;
    db = openTestDatabase();
  });

  tearDown(() => db.close());

  Map<String, Object?> manifest(String cursor) => {
        'scope_version': 1,
        'collections': [
          for (final key in _payloads.keys)
            manifestEntry(
              key,
              partition: kSyncCollections[key]!,
              currentCursor: cursor,
              hasChanges: true,
              fromZero: cursor == 'c1',
            ),
        ],
      };

  SyncEngine engine() => SyncEngine(
        api: SyncApi(dio: dio),
        dao: db.syncDao,
        collections: syncedCollections()
            .where((c) => _payloads.containsKey(c.key))
            .toList(growable: false),
      );

  test('le registre : six référentiels, quatre privées, hors branche', () {
    final keys = syncedCollections().map((c) => c.key).toList();
    for (final key in _payloads.keys) {
      expect(keys, contains(key));
      expect(isBranchScoped(key), isFalse, reason: key);
    }
    const references = [
      'bible_verse_of_days',
      'bible_sunday_passages',
      'bible_plans',
      'bible_challenges',
      'bible_quizzes',
      'bible_versions',
    ];
    for (final key in _payloads.keys) {
      expect(
        kSyncCollections[key],
        references.contains(key) ? 'reference' : 'private',
        reason: key,
      );
    }
    // Référentiels avant privées ; plans avant défis ; quiz avant scores.
    final lastReference =
        references.map(keys.indexOf).reduce((a, b) => a > b ? a : b);
    expect(lastReference, lessThan(keys.indexOf('bible_marks')));
    expect(keys.indexOf('bible_plans'),
        lessThan(keys.indexOf('bible_challenges')));
  });

  test('les dix collections entrent au magasin', () async {
    server.serveManifest(manifest('c1'));
    for (final e in _payloads.entries) {
      server.serveCollection(
        e.key,
        deltaPage(items: e.value, nextCursor: 'c1'),
      );
    }

    final report = await engine().synchronize();
    expect(report.pulled.toSet(), _payloads.keys.toSet());

    final version = (await db.select(db.bibleVersions).get()).single;
    expect((version.id, version.code, version.sizeBytes), (1, 'LSG', 4200000));
    final vod = (await db.select(db.bibleVerseOfDays).get()).single;
    expect((vod.id, vod.day, vod.verseFrom, vod.backgroundId),
        (7, '2026-10-13', 16, 2));
    final sunday = (await db.select(db.bibleSundayPassages).get()).single;
    expect(sunday.references, '[{"book":"Ps","chapter":23}]');
    final plan = (await db.select(db.biblePlans).get()).single;
    expect(plan.id, _planId);
    expect(plan.days, '[[{"book":"Matt","chapter":1}]]');
    final challenge = (await db.select(db.bibleChallenges).get()).single;
    expect(challenge.planId, _planId);
    final quiz = (await db.select(db.bibleQuizzes).get()).single;
    expect((quiz.id, quiz.ageBand), (4, 'kids'));
    final marks = await db.select(db.bibleMarks).get();
    final mark = marks.firstWhere((m) => m.book == 'John');
    expect((mark.kind, mark.verseTo, mark.color), ('highlight', 18, 'yellow'));
    // Une marque d'avant #252 n'a aucun des trois champs, et c'est ce qui la
    // garde valable dans toutes les traductions.
    expect((mark.versionCode, mark.charFrom, mark.charTo), (null, null, null));
    final word = marks.firstWhere((m) => m.book == 'Ps');
    expect((word.versionCode, word.charFrom, word.charTo), ('LSG', 0, 11));
    final state = (await db.select(db.bibleReadingStates).get()).single;
    expect(state.readChapters, '{"John":[1,2,3]}');
    expect(state.streakDays, 4);
    final enrollment = (await db.select(db.biblePlanEnrollments).get()).single;
    expect((enrollment.planId, enrollment.completedDays), (_planId, '[1,2]'));
    final result = (await db.select(db.bibleQuizResults).get()).single;
    expect((result.quizId, result.score, result.total), (4, 8, 10));

    // La position d'un membre se lit sur le miroir.
    final s = (await db.bibleDao.watchReadingState(member: true).first)!;
    expect((s.book, s.chapter, s.verse), ('John', 3, 16));
  });

  test('une rétractation retire la ligne, entière ou UUID', () async {
    server.serveManifests([manifest('c1'), manifest('c2')]);
    for (final e in _payloads.entries) {
      server.servePages(e.key, [
        deltaPage(items: e.value, nextCursor: 'c1'),
        deltaPage(items: [
          // La première ligne de chaque collection ; `bible_marks` en a deux
          // depuis #252, et sa seconde (la marque au mot) doit rester.
          {
            'id': e.value.first['id'],
            'deletedAt': '2026-10-14T00:00:00.000Z',
          },
        ], nextCursor: 'c2'),
      ]);
    }

    await engine().synchronize();
    expect(await db.select(db.bibleQuizzes).get(), hasLength(1));
    await engine().synchronize();
    expect(await db.select(db.bibleQuizzes).get(), isEmpty);
    expect(await db.select(db.biblePlans).get(), isEmpty);
    expect((await db.select(db.bibleMarks).get()).single.book, 'Ps');
    expect(await db.select(db.bibleVersions).get(), isEmpty);
  });

  test('le 404 d\'un serveur en retard saute les collections', () async {
    server.serveManifest(manifest('c1'));
    final report = await engine().synchronize();
    expect(report.pulled, isEmpty);
    expect(await db.select(db.bibleVersions).get(), isEmpty);
  });
}
