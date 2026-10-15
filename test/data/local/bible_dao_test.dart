/// **La position de lecture du module Bible** (#199) : la ligne locale
/// l'emporte, le miroir ne sert qu'au membre, et rien n'écrit jamais le miroir.
library;

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/local/bible_dao.dart';

import 'local_database_fixtures.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = openTestDatabase());
  tearDown(() => db.close());

  Future<void> seedMirror() => db.syncDao.applyPage(
        db.syncDao.bibleReadingStatesCollection,
        upserts: [
          BibleReadingStatesCompanion.insert(
            id: 'srv-1',
            versionCode: const Value('EXB'),
            book: const Value('Rom'),
            chapter: const Value(8),
            readChapters: const Value('{"Rom":[1,2]}'),
          ),
        ],
        cursor: 'c1',
      );

  test('rien au départ, pour personne', () async {
    expect(await db.bibleDao.watchReadingState(member: false).first, isNull);
    expect(await db.bibleDao.watchReadingState(member: true).first, isNull);
  });

  test('la position s\'écrit en local, dirty', () async {
    await db.bibleDao.savePosition(
      member: false,
      versionCode: 'EXA',
      book: 'John',
      chapter: 3,
      verse: 16,
    );
    final s = (await db.bibleDao.watchReadingState(member: false).first)!;
    expect((s.versionCode, s.book, s.chapter, s.verse), ('EXA', 'John', 3, 16));
    final row = (await db.select(db.localBibleReadingState).get()).single;
    expect(row.dirty, isTrue);
    // Une seule ligne, réécrite.
    await db.bibleDao.savePosition(
      member: false,
      versionCode: 'EXA',
      book: 'John',
      chapter: 4,
    );
    expect(await db.select(db.localBibleReadingState).get(), hasLength(1));
    expect(
      (await db.bibleDao.watchReadingState(member: false).first)!.chapter,
      4,
    );
  });

  test('un chapitre lu se range une fois, avec le jour', () async {
    final now = DateTime(2026, 10, 13, 9);
    await db.bibleDao
        .markChapterRead(member: false, book: 'John', chapter: 3, now: now);
    await db.bibleDao
        .markChapterRead(member: false, book: 'John', chapter: 3, now: now);
    await db.bibleDao
        .markChapterRead(member: false, book: 'John', chapter: 1, now: now);
    final row = (await db.select(db.localBibleReadingState).get()).single;
    expect(jsonDecode(row.readChapters!), {
      'John': [1, 3],
    });
    expect(row.lastReadOn, '2026-10-13');
    final s = (await db.bibleDao.watchReadingState(member: false).first)!;
    expect(s.hasRead('John', 3), isTrue);
    expect(s.hasRead('John', 2), isFalse);
  });

  test('membre sans position : le flux suit la ligne locale créée ensuite',
      () async {
    final seen = <BibleReadingSnapshot?>[];
    final sub = db.bibleDao.watchReadingState(member: true).listen(seen.add);
    addTearDown(sub.cancel);
    await pumpEventQueue();
    expect(seen, [isNull]);

    await db.bibleDao.markChapterRead(member: true, book: 'John', chapter: 3);
    await pumpEventQueue();
    expect(seen.last?.hasRead('John', 3), isTrue);

    await db.bibleDao.markChapterRead(member: true, book: 'John', chapter: 4);
    await pumpEventQueue();
    expect(seen.last?.hasRead('John', 4), isTrue);
  });

  group('La série de lecture', () {
    Future<LocalBibleReadingStateRow> read(
      String book,
      int chapter,
      DateTime now, {
      bool member = false,
    }) async {
      await db.bibleDao.markChapterRead(
          member: member, book: book, chapter: chapter, now: now);
      return (await db.select(db.localBibleReadingState).get()).single;
    }

    test('invité : jour même inchangé, lendemain +1, trou → 1', () async {
      var row = await read('John', 1, DateTime(2026, 10, 13, 9));
      expect((row.streakDays, row.lastReadOn), (1, '2026-10-13'));
      row = await read('John', 2, DateTime(2026, 10, 13, 18));
      expect(row.streakDays, 1);
      row = await read('John', 3, DateTime(2026, 10, 14, 7));
      expect((row.streakDays, row.lastReadOn), (2, '2026-10-14'));
      // Relire un chapitre déjà lu, un nouveau jour, compte aussi.
      row = await read('John', 3, DateTime(2026, 10, 15, 7));
      expect(row.streakDays, 3);
      row = await read('John', 4, DateTime(2026, 10, 18, 7));
      expect((row.streakDays, row.lastReadOn), (1, '2026-10-18'));
    });

    test('minuit : 23 h 59 puis 0 h 01, deux jours d\'affilée', () async {
      await read('Ps', 1, DateTime(2026, 10, 13, 23, 59));
      final row = await read('Ps', 2, DateTime(2026, 10, 14, 0, 1));
      expect(row.streakDays, 2);
    });

    test('membre : la série du miroir continue', () async {
      await db.syncDao.applyPage(
        db.syncDao.bibleReadingStatesCollection,
        upserts: [
          BibleReadingStatesCompanion.insert(
            id: 'srv-1',
            versionCode: const Value('EXA'),
            book: const Value('Rom'),
            chapter: const Value(8),
            readChapters: const Value('{"Rom":[1]}'),
            streakDays: const Value(4),
            lastReadOn: const Value('2026-10-12'),
          ),
        ],
        cursor: 'c1',
      );
      final row = await read('Rom', 2, DateTime(2026, 10, 13, 8), member: true);
      expect((row.id, row.streakDays, row.dirty), ('srv-1', 5, true));
    });

    test('affichée : rompue si le dernier jour est antérieur à hier', () {
      final now = DateTime(2026, 10, 13, 12);
      expect(BibleDao.currentStreak(5, '2026-10-13', now), 5);
      expect(BibleDao.currentStreak(5, '2026-10-12', now), 5);
      expect(BibleDao.currentStreak(5, '2026-10-11', now), 0);
      expect(BibleDao.currentStreak(0, null, now), 0);
    });
  });

  test('le miroir : lu par le membre, jamais par l\'invité', () async {
    await seedMirror();
    expect(await db.bibleDao.watchReadingState(member: false).first, isNull);
    final s = (await db.bibleDao.watchReadingState(member: true).first)!;
    expect((s.book, s.chapter, s.versionCode), ('Rom', 8, 'EXB'));
    expect(s.hasRead('Rom', 2), isTrue);
  });

  test('le membre amorce sa ligne locale depuis le miroir', () async {
    await seedMirror();
    await db.bibleDao.markChapterRead(member: true, book: 'Rom', chapter: 3);
    final row = (await db.select(db.localBibleReadingState).get()).single;
    expect(row.id, 'srv-1');
    expect(row.book, 'Rom');
    expect(jsonDecode(row.readChapters!), {
      'Rom': [1, 2, 3],
    });
    // Le miroir n'a pas bougé (ADR-0026).
    final mirror = (await db.select(db.bibleReadingStates).get()).single;
    expect(mirror.readChapters, '{"Rom":[1,2]}');
  });

  test('garde-fou : aucune écriture applicative dans un miroir Bible', () {
    const mirrors = [
      'bibleMarks',
      'bibleReadingStates',
      'biblePlanEnrollments',
      'bibleQuizResults',
      'bibleVerseOfDays',
      'bibleSundayPassages',
      'biblePlans',
      'bibleChallenges',
      'bibleQuizzes',
      'bibleVersions',
    ];
    final forbidden = RegExp(
      r'\b(into|update|delete)\(\s*(db\.)?(' + mirrors.join('|') + r')\s*\)',
    );
    final offenders = [
      for (final f in Directory('lib').listSync(recursive: true))
        if (f is File &&
            f.path.endsWith('.dart') &&
            !f.path.endsWith('.g.dart') &&
            forbidden.hasMatch(f.readAsStringSync()))
          f.path,
    ];
    expect(offenders, isEmpty);
  });
}
