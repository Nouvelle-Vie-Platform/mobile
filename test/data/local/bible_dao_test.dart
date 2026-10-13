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
