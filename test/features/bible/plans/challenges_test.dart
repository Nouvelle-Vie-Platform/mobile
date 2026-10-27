/// **Les défis** (M5, #203) : les routes S3 à travers l'enveloppe (noms
/// libres, `join` et ses deux 409, classement), et l'écran — l'invité invité à
/// se connecter, le membre qui choisit un nom (recherche, 409 puis liste
/// rafraîchie), l'inscription au plan liée au défi, le classement où « vous »
/// est mis en avant. Jamais de vrai nom.
library;

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/core/network/api_client.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/features/bible/data/bible_providers.dart';
import 'package:maison_du_miracle/features/bible/plans/challenges_screen.dart';
import 'package:maison_du_miracle/features/bible/plans/plans_api.dart';
import 'package:maison_du_miracle/features/bible/plans/plans_providers.dart';
import 'package:maison_du_miracle/features/bible/plans/plans_store.dart';
import 'package:maison_du_miracle/l10n/app_localizations_fr.dart';

import '../../../data/local/local_database_fixtures.dart';
import '../../../helpers/fake_api.dart';
import '../../../helpers/pump_screen.dart';

const _cid = '019a0000-0000-7000-8000-000000000001';
final _fr = AppLocalizationsFr();

({BiblePlansApi api, FakeAdapter wire}) _api(
    ResponseBody Function(RequestOptions o) reply) {
  final wire = FakeAdapter(reply);
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
    ..httpClientAdapter = wire
    ..interceptors.add(unwrapEnvelopeInterceptor);
  return (api: BiblePlansApi(dio), wire: wire);
}

Future<void> _seedChallenge(AppDatabase db) async {
  await db.syncDao.applyPage(
    db.syncDao.biblePlansCollection,
    upserts: [
      BiblePlansCompanion.insert(
        id: 'p-1',
        title: const {'fr': 'Marc en 16 jours'},
        days: const Value('[[{"book":"Mark","chapter":1}]]'),
        publishedAt: Value(DateTime.utc(2026, 9, 1)),
      ),
    ],
    cursor: 'p',
  );
  await db.syncDao.applyPage(
    db.syncDao.bibleChallengesCollection,
    upserts: [
      BibleChallengesCompanion.insert(
        id: _cid,
        title: const {'fr': 'Défi de l\'Avent'},
        planId: const Value('p-1'),
        startsOn: const Value('2026-10-10'),
        endsOn: const Value('2026-10-25'),
        publishedAt: Value(DateTime.utc(2026, 9, 1)),
      ),
    ],
    cursor: 'c',
  );
}

/// Des tours de vraie boucle d'événements entre les images (flux Drift).
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 30));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }
}

void main() {
  group('Les routes', () {
    test('noms libres, join (201, 409 pris, 409 déjà), classement', () async {
      var joinReply =
          jsonReply(201, {'challengeId': _cid, 'pseudonym': 'Abel'});
      final (:api, :wire) = _api((o) {
        if (o.path.endsWith('/pseudonyms')) {
          return jsonReply(200, {
            'pseudonyms': ['Aaron', 'Abel'],
          });
        }
        if (o.path.endsWith('/join')) return joinReply;
        return jsonReply(200, {
          'entries': [
            {'pseudonym': 'Abigaïl', 'onTime': 5, 'streak': 3, 'rank': 1},
            {'pseudonym': 'Abel', 'onTime': 4, 'streak': 0, 'rank': 2},
          ],
          'participants': 2,
          'me': {'pseudonym': 'Abel', 'onTime': 4, 'streak': 0, 'rank': 2},
        });
      });

      expect(await api.pseudonyms(_cid), ['Aaron', 'Abel']);
      expect(wire.lastRequest.path, '/bible/challenges/$_cid/pseudonyms');

      expect(await api.join(_cid, 'Abel'), JoinOutcome.joined);
      expect(wire.lastRequest.method, 'POST');
      expect(wire.lastBody, {'pseudonym': 'Abel'});

      joinReply = errorReply(409, 'E_BIBLE_PSEUDONYM_TAKEN');
      expect(await api.join(_cid, 'Abel'), JoinOutcome.nameTaken);
      joinReply = errorReply(409, 'E_BIBLE_CHALLENGE_ALREADY_JOINED');
      expect(await api.join(_cid, 'Abel'), JoinOutcome.alreadyJoined);
      joinReply = errorReply(422, 'E_BIBLE_CHALLENGE_ENDED');
      await expectLater(api.join(_cid, 'Abel'), throwsA(isA<DioException>()));

      final board = await api.leaderboard(_cid);
      expect(wire.lastRequest.path, '/bible/challenges/$_cid/leaderboard');
      expect(board.participants, 2);
      expect(board.entries.map((e) => e.pseudonym), ['Abigaïl', 'Abel']);
      expect(board.entries.first.onTime, 5);
      expect(board.me?.rank, 2);
    });
  });

  group('L\'écran', () {
    testWidgets('l\'invité voit le défi et la carte « Connectez-vous »',
        (tester) async {
      await tester.runAsync(() async {
        final db = openTestDatabase();
        await _seedChallenge(db);
        final (:api, :wire) = _api((o) => throw StateError('aucun réseau'));
        await pumpScreen(
          tester,
          const BibleChallengesScreen(),
          database: db,
          overrides: [
            bibleIsMemberProvider.overrideWithValue(false),
            bibleTodayProvider.overrideWithValue(DateTime(2026, 10, 13)),
            biblePlansApiProvider.overrideWithValue(api),
          ],
        );
        await _settle(tester);
        expect(find.byKey(BibleChallengesScreen.guestCardKey), findsOneWidget);
        expect(find.text(_fr.biblePlansGuestTitle), findsOneWidget);
        expect(find.text('Défi de l\'Avent'), findsOneWidget);
        expect(find.byKey(BibleChallengesScreen.joinKey(_cid)), findsNothing);
        expect(wire.requests, isEmpty);
        await db.close();
      });
    });

    testWidgets(
        'le membre choisit un nom ; 409, liste rafraîchie ; l\'inscription '
        'au plan porte le défi', (tester) async {
      await tester.runAsync(() async {
        final db = openTestDatabase();
        await _seedChallenge(db);
        var joins = 0;
        var lists = 0;
        final (:api, :wire) = _api((o) {
          if (o.path.endsWith('/pseudonyms')) {
            lists++;
            return jsonReply(200, {
              'pseudonyms':
                  lists == 1 ? ['Aaron', 'Abel', 'Ruth'] : ['Aaron', 'Ruth'],
            });
          }
          joins++;
          return joins == 1
              ? errorReply(409, 'E_BIBLE_PSEUDONYM_TAKEN')
              : jsonReply(201, {'challengeId': _cid, 'pseudonym': 'Ruth'});
        });
        await pumpScreen(
          tester,
          const BibleChallengesScreen(),
          database: db,
          overrides: [
            bibleIsMemberProvider.overrideWithValue(true),
            bibleTodayProvider.overrideWithValue(DateTime(2026, 10, 13)),
            biblePlansApiProvider.overrideWithValue(api),
          ],
        );
        await _settle(tester);
        expect(find.byKey(BibleChallengesScreen.guestCardKey), findsNothing);

        await tester.tap(find.byKey(BibleChallengesScreen.joinKey(_cid)));
        await _settle(tester);
        // La recherche filtre la liste.
        await tester.enterText(find.byKey(PseudonymSheet.searchKey), 'ab');
        await _settle(tester);
        expect(find.byKey(PseudonymSheet.nameKey('Ruth')), findsNothing);
        await tester.tap(find.byKey(PseudonymSheet.nameKey('Abel')));
        await _settle(tester);

        // 409 : le message, et la liste rafraîchie sans « Abel ».
        expect(find.text(_fr.biblePlansNameTaken), findsOneWidget);
        expect(lists, 2);
        expect(find.byKey(PseudonymSheet.nameKey('Abel')), findsNothing);
        await tester.tap(find.byKey(PseudonymSheet.nameKey('Ruth')));
        await _settle(tester);

        expect(wire.lastBody, {'pseudonym': 'Ruth'});
        final row = await db.select(db.localBiblePlanEnrollments).getSingle();
        expect(row.source, PlanSource.published.name);
        expect(row.planId, 'p-1');
        expect(row.challengeId, _cid);
        expect(row.startedOn, '2026-10-10');
        expect(find.byKey(BibleChallengesScreen.leaderboardKey(_cid)),
            findsOneWidget);
        await db.close();
      });
    });

    testWidgets('le classement : pseudonymes, participants, « vous » en avant',
        (tester) async {
      await tester.runAsync(() async {
        final (:api, :wire) = _api((_) => jsonReply(200, {
              'entries': [
                {'pseudonym': 'Abigaïl', 'onTime': 5, 'streak': 3, 'rank': 1},
                {'pseudonym': 'Ruth', 'onTime': 4, 'streak': 1, 'rank': 2},
              ],
              'participants': 2,
              'me': {'pseudonym': 'Ruth', 'onTime': 4, 'streak': 1, 'rank': 2},
            }));
        await pumpScreen(
          tester,
          const BibleLeaderboardScreen(challengeId: _cid, title: 'Avent'),
          overrides: [biblePlansApiProvider.overrideWithValue(api)],
        );
        await _settle(tester);
        expect(wire.requests, hasLength(1));
        expect(
            find.textContaining(_fr.biblePlansParticipants(2)), findsOneWidget);
        expect(find.text('Abigaïl'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(BibleLeaderboardScreen.meKey),
            matching: find.text('Ruth (${_fr.biblePlansYou})'),
          ),
          findsOneWidget,
        );
      });
    });
  });
}
