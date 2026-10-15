// Palier du **module Bible** (#199) : `AppDatabase.kBibleSchemaVersion` = v29,
// après les notes (v28). Le seul palier du chantier : M2 à M7 n'en ajoutent
// pas. Il exige `test/data/local/schema/schema_v29.dart` (`make gen && make
// migrations`).

import 'package:drift/drift.dart' show Table, TableInfo, Value;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';

import 'schema/schema.dart';

void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  const v = AppDatabase.kBibleSchemaVersion;

  test('v29 est la version courante', () {
    expect(v, 29);
    expect(GeneratedHelper.versions.last, v);
  });

  test('v28 → v29 : les seize objets du module', () async {
    final connection = await verifier.startAt(v - 1);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, v);
  });

  test('v1 → v29 : un appareil resté en v1 rejoue tous les paliers', () async {
    final connection = await verifier.startAt(1);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, v);
  });

  test(
      'v28 → v29 : les notes survivent, la Bible naît vide et sans curseur, '
      'l\'index plein texte répond', () async {
    final schema = await verifier.schemaAt(v - 1);
    schema.rawDatabase.execute(
      "INSERT INTO spiritual_notes (id, title, body, pinned, sync_stamp) "
      "VALUES ('n-1', 'Courses', '', 0, 1)",
    );

    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, v);

    expect((await db.select(db.spiritualNotes).get()).single.title, 'Courses');
    for (final TableInfo<Table, Object?> table in [
      db.bibleMarks,
      db.bibleReadingStates,
      db.biblePlanEnrollments,
      db.bibleQuizResults,
      db.bibleVerseOfDays,
      db.bibleSundayPassages,
      db.biblePlans,
      db.bibleChallenges,
      db.bibleQuizzes,
      db.bibleVersions,
      db.localBibleMarks,
      db.localBibleReadingState,
      db.localBiblePlanEnrollments,
      db.localBibleQuizResults,
      db.bibleInstalledVersions,
    ]) {
      expect(await db.select(table).get(), isEmpty,
          reason: table.actualTableName);
    }
    for (final key in const [
      'bible_marks',
      'bible_reading_states',
      'bible_plan_enrollments',
      'bible_quiz_results',
      'bible_verse_of_days',
      'bible_sunday_passages',
      'bible_plans',
      'bible_challenges',
      'bible_quizzes',
      'bible_versions',
    ]) {
      expect(await db.syncDao.cursorFor(key), isNull, reason: key);
    }

    // Une marque d'invité se range, avec ses défauts.
    await db.into(db.localBibleMarks).insert(
          LocalBibleMarksCompanion.insert(
            id: 'm-1',
            kind: 'favorite',
            book: 'John',
            chapter: 3,
            verseFrom: const Value(16),
            clientCreatedAt: DateTime.utc(2026, 10, 13),
            clientUpdatedAt: DateTime.utc(2026, 10, 13),
          ),
        );
    final mark = (await db.select(db.localBibleMarks).get()).single;
    expect(mark.dirty, isTrue);
    expect(mark.deletedAt, isNull);

    // FTS5, sans accent : « eternel » trouve « Éternel ».
    await db.customStatement(
      'INSERT INTO bible_fts (version_code, book, chapter, verse, verse_text) '
      "VALUES ('EXA', 'Ps', 23, 1, 'L''Éternel est mon berger')",
    );
    final hits = await db
        .customSelect(
          "SELECT book, verse FROM bible_fts WHERE bible_fts MATCH 'eternel'",
        )
        .get();
    expect(hits.single.read<String>('book'), 'Ps');
  });
}
