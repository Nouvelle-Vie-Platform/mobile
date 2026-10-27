/// **Mes plans sur l'appareil et la file d'envoi** (M5, #203) : l'invité lit
/// ses brouillons seuls, le membre le miroir sous sa file ; l'envoi (`POST`,
/// `DELETE`, `clientUpdatedAt`), l'échec qui reste en file, la purge au retour
/// du miroir ; et le masquage des plans et défis non publiés.
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/features/bible/data/bible_providers.dart';
import 'package:maison_du_miracle/features/bible/plans/plan_logic.dart';
import 'package:maison_du_miracle/features/bible/plans/plans_api.dart';
import 'package:maison_du_miracle/features/bible/plans/plans_providers.dart';
import 'package:maison_du_miracle/features/bible/plans/plans_store.dart';
import 'package:maison_du_miracle/state/sync_providers.dart';

import '../../../data/local/local_database_fixtures.dart';
import '../../../helpers/fake_api.dart';

({BiblePlansApi api, FakeAdapter wire}) _api(
    ResponseBody Function(RequestOptions o) reply) {
  final wire = FakeAdapter(reply);
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
    ..httpClientAdapter = wire;
  return (api: BiblePlansApi(dio), wire: wire);
}

void main() {
  late AppDatabase db;
  late BiblePlansStore store;
  setUp(() {
    db = openTestDatabase();
    store = BiblePlansStore(db);
  });
  tearDown(() => db.close());

  Future<void> mirror(
    String id, {
    String completed = '[0]',
    DateTime? updatedAt,
  }) =>
      db.syncDao.applyPage(
        db.syncDao.biblePlanEnrollmentsCollection,
        upserts: [
          BiblePlanEnrollmentsCompanion.insert(
            id: id,
            source: 'builtin',
            planCode: const Value('nt-90'),
            startedOn: const Value('2026-10-01'),
            completedDays: Value(completed),
            clientCreatedAt: Value(DateTime.utc(2026, 10, 1)),
            updatedAt: Value(updatedAt ?? DateTime.utc(2026, 10, 2)),
          ),
        ],
        cursor: 'c-$id',
      );

  test('l\'invité ne lit que ses brouillons, jamais le miroir', () async {
    await mirror('srv-1');
    final e = await store.enroll(
      source: PlanSource.builtin,
      planCode: BuiltinPlanCode.ps30,
      startedOn: DateTime(2026, 10, 13),
    );
    expect((await store.enrollments(member: false)).map((x) => x.id), [e.id]);
    expect(
      (await store.enrollments(member: true)).map((x) => x.id).toSet(),
      {e.id, 'srv-1'},
    );
    final row = await db.select(db.localBiblePlanEnrollments).getSingle();
    expect(row.dirty, isTrue);
    expect(row.startedOn, '2026-10-13');
    expect(row.planId, isNull);
  });

  test('la file du membre recouvre le miroir ; quitter le masque', () async {
    await mirror('srv-1');
    final e = (await store.enrollments(member: true)).single;
    await store.save(e.copyWith(completedDays: {0, 1, 2}));
    expect((await store.enrollments(member: true)).single.completedDays,
        {0, 1, 2});

    await store.remove(e, member: true);
    expect(await store.enrollments(member: true), isEmpty);
    expect(
        (await db.select(db.localBiblePlanEnrollments).getSingle()).deletedAt,
        isNotNull);
  });

  test('l\'invité qui quitte un plan efface sa ligne', () async {
    final e = await store.enroll(
      source: PlanSource.custom,
      custom: const CustomPlanSpec(title: 'Ruth', books: ['Ruth'], days: 2),
      startedOn: DateTime(2026, 10, 13),
    );
    await store.remove(e, member: false);
    expect(await db.select(db.localBiblePlanEnrollments).get(), isEmpty);
  });

  test('la file envoie le POST attendu, puis purge au retour du miroir',
      () async {
    final (:api, :wire) = _api((_) => jsonReply(200, {}));
    final e = await store.enroll(
      source: PlanSource.custom,
      custom: const CustomPlanSpec(title: 'Défi', books: ['Ruth'], days: 2),
      startedOn: DateTime(2026, 10, 13),
      now: DateTime.utc(2026, 10, 13, 8),
    );
    await store.save(e.copyWith(completedDays: {1, 0}),
        now: DateTime.utc(2026, 10, 13, 9));

    await store.resendDirty(api);
    expect(wire.requests.single.method, 'POST');
    expect(wire.requests.single.path, '/bible/plan-enrollments');
    expect(wire.lastBody, {
      'id': e.id,
      'source': 'custom',
      'planCode': null,
      'planId': null,
      'custom': {
        'title': 'Défi',
        'books': ['Ruth'],
        'days': 2,
      },
      'startedOn': '2026-10-13',
      'completedDays': [0, 1],
      'challengeId': null,
      'clientCreatedAt': '2026-10-13T08:00:00.000Z',
      'clientUpdatedAt': '2026-10-13T09:00:00.000Z',
    });
    final sent = await db.select(db.localBiblePlanEnrollments).getSingle();
    expect(sent.dirty, isFalse);

    // Le cycle suivant : le delta l'a ramenée ; purgée, rien ne repart.
    await mirror(e.id, updatedAt: DateTime.utc(2026, 10, 13, 9, 0, 1));
    await store.resendDirty(api);
    expect(wire.requests, hasLength(1));
    expect(await db.select(db.localBiblePlanEnrollments).get(), isEmpty);
    expect((await store.enrollments(member: true)).single.id, e.id);
  });

  test('une ligne envoyée que le miroir ne ramène pas est purgée quand même',
      () async {
    final (:api, :wire) = _api((_) => jsonReply(200, {}));
    await store.enroll(
      source: PlanSource.builtin,
      planCode: BuiltinPlanCode.nt90,
      startedOn: DateTime(2026, 10, 13),
    );
    await store.resendDirty(api);
    expect((await db.select(db.localBiblePlanEnrollments).getSingle()).dirty,
        isFalse);
    // Fondue ou refusée côté serveur : son id ne reviendra jamais.
    await store.resendDirty(api);
    expect(await db.select(db.localBiblePlanEnrollments).get(), isEmpty);
    expect(wire.requests, hasLength(1));
  });

  test('un plan quitté part en DELETE, et reste masqué jusqu\'au delta',
      () async {
    final (:api, :wire) = _api((_) => errorReply(404, 'E_NOT_FOUND'));
    await mirror('srv-1');
    final e = (await store.enrollments(member: true)).single;
    await store.remove(e, member: true);

    await store.resendDirty(api);
    expect(wire.lastRequest.method, 'DELETE');
    expect(wire.lastRequest.path, '/bible/plan-enrollments/srv-1');
    // 404 = déjà parti : envoyé.
    final row = await db.select(db.localBiblePlanEnrollments).getSingle();
    expect(row.dirty, isFalse);
    expect(await store.enrollments(member: true), isEmpty);

    await db.syncDao.applyPage(db.syncDao.biblePlanEnrollmentsCollection,
        deletedIds: ['srv-1'], cursor: 'c2');
    await store.resendDirty(api);
    expect(await db.select(db.localBiblePlanEnrollments).get(), isEmpty);
  });

  test('un échec d\'envoi reste en file, et repart au cycle suivant', () async {
    var fail = true;
    final (:api, :wire) = _api(
      (_) => fail ? errorReply(500, 'E_SERVER') : jsonReply(200, {}),
    );
    await store.enroll(
      source: PlanSource.builtin,
      planCode: BuiltinPlanCode.nt90,
      startedOn: DateTime(2026, 10, 13),
    );
    await store.resendDirty(api);
    var row = await db.select(db.localBiblePlanEnrollments).getSingle();
    expect(row.dirty, isTrue);
    expect(row.lastError, isNotNull);
    expect(wire.lastBody['planCode'], 'nt-90');

    fail = false;
    await store.resendDirty(api);
    row = await db.select(db.localBiblePlanEnrollments).getSingle();
    expect(row.dirty, isFalse);
    expect(wire.requests, hasLength(2));
  });

  group('Les providers', () {
    ProviderContainer container({required bool member, BiblePlansApi? api}) {
      final c = ProviderContainer(overrides: [
        appDatabaseProvider.overrideWithValue(db),
        bibleIsMemberProvider.overrideWithValue(member),
        bibleTodayProvider.overrideWithValue(DateTime(2026, 10, 3)),
        if (api != null) biblePlansApiProvider.overrideWithValue(api),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    Future<T> settle<T>(ProviderContainer c, ProviderListenable<T> p) async {
      final sub = c.listen(p, (_, __) {});
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      // L'abonnement reste ouvert jusqu'à la fin du conteneur : un provider
      // sans auditeur est mis en pause (Riverpod 3), son flux Drift avec.
      return sub.read();
    }

    test('plans et défis non publiés masqués ; défi fini masqué', () async {
      await db.syncDao.applyPage(
        db.syncDao.biblePlansCollection,
        upserts: [
          BiblePlansCompanion.insert(
            id: 'p-pub',
            title: const {'fr': 'Publié'},
            days: const Value('[[{"book":"Ruth","chapter":1}]]'),
            publishedAt: Value(DateTime.utc(2026, 9, 1)),
          ),
          BiblePlansCompanion.insert(
            id: 'p-draft',
            title: const {'fr': 'Brouillon'},
          ),
        ],
        cursor: 'p1',
      );
      await db.syncDao.applyPage(
        db.syncDao.bibleChallengesCollection,
        upserts: [
          for (final (id, pub, ends) in [
            ('c-live', true, '2026-10-31'),
            ('c-draft', false, '2026-10-31'),
            ('c-over', true, '2026-10-02'),
          ])
            BibleChallengesCompanion.insert(
              id: id,
              title: {'fr': id},
              planId: const Value('p-pub'),
              startsOn: const Value('2026-10-01'),
              endsOn: Value(ends),
              publishedAt: Value(pub ? DateTime.utc(2026, 9, 1) : null),
            ),
        ],
        cursor: 'c1',
      );
      final c = container(member: false);
      expect(
          (await settle(c, biblePublishedPlansProvider))
              .value!
              .map((p) => p.id),
          ['p-pub']);
      expect((await settle(c, bibleChallengesProvider)).value!.map((p) => p.id),
          ['c-live']);
    });

    test('lecture du jour, badges, et cochage par les chapitres lus envoyé',
        () async {
      // Une position déjà là : `watchReadingState(member: true)` part de la
      // ligne locale (sans elle, son `asyncExpand` reste suspendu au flux du
      // miroir et ne voit plus rien — défaut de M1, signalé).
      await db.bibleDao.markChapterRead(member: true, book: 'Gen', chapter: 1);
      final (:api, :wire) = _api((_) => jsonReply(200, {}));
      final c = container(member: true, api: api);
      // Ruth en 4 jours, commencé le 1er : aujourd'hui (3) est le jour 2.
      final e = await store.enroll(
        source: PlanSource.custom,
        custom: const CustomPlanSpec(title: 'Ruth', books: ['Ruth'], days: 4),
        startedOn: DateTime(2026, 10, 1),
      );
      expect(await settle(c, biblePlanReadingDoneTodayProvider), isFalse);

      for (final ch in [1, 2, 3]) {
        await db.bibleDao
            .markChapterRead(member: true, book: 'Ruth', chapter: ch);
      }
      expect(await settle(c, biblePlanReadingDoneTodayProvider), isTrue);
      final t = (await settle(c, biblePlanTrackersProvider))!.single;
      expect(t.progress.completed, {0, 1, 2});
      expect(t.progress.streak, 3);
      expect(await settle(c, bibleBadgesProvider), {BibleBadge.firstDay});

      // La file écrit les jours cochés par la lecture avant de les envoyer.
      await c.read(biblePlansOutboxProvider)();
      expect(wire.lastBody['id'], e.id);
      expect(wire.lastBody['completedDays'], [0, 1, 2]);
      expect(jsonDecode(jsonEncode(wire.lastBody['custom'])), {
        'title': 'Ruth',
        'books': ['Ruth'],
        'days': 4
      });
    });

    test('la file ne fait rien pour un invité', () async {
      final (:api, :wire) = _api((_) => jsonReply(200, {}));
      final c = ProviderContainer(overrides: [
        appDatabaseProvider.overrideWithValue(db),
        bibleIsMemberProvider.overrideWithValue(false),
        biblePlansApiProvider.overrideWithValue(api),
      ]);
      addTearDown(c.dispose);
      await store.enroll(
        source: PlanSource.builtin,
        planCode: BuiltinPlanCode.ps30,
        startedOn: DateTime(2026, 10, 1),
      );
      await c.read(biblePlansOutboxProvider)();
      expect(wire.requests, isEmpty);
    });
  });
}
