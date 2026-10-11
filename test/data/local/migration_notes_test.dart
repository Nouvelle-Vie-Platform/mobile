// Palier des **notes** (#190) : `AppDatabase.kNotesSchemaVersion` = v28, après
// la médiathèque en pages (v27). Il exige
// `test/data/local/schema/schema_v28.dart`, produit par `make gen && make
// migrations`.

import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';

import 'schema/schema.dart';

void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  const v = AppDatabase.kNotesSchemaVersion;

  test('v27 → v28 : les quatre tables des notes', () async {
    final connection = await verifier.startAt(v - 1);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, v);
  });

  test('v1 → v28 : un appareil resté en v1 rejoue tous les paliers', () async {
    final connection = await verifier.startAt(1);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, v);
  });

  test(
      'v27 → v28 : le catalogue survit, les notes naissent vides et sans '
      'curseur', () async {
    final schema = await verifier.schemaAt(v - 1);
    schema.rawDatabase.execute(
      "INSERT INTO teachings (id, title, sync_stamp) VALUES ('t-1', 'Dieu a le "
      "dernier mot', 1)",
    );

    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, v);

    expect((await db.select(db.teachings).get()).single.title,
        'Dieu a le dernier mot');
    expect(await db.select(db.spiritualNotes).get(), isEmpty);
    expect(await db.select(db.noteCategories).get(), isEmpty);
    expect(await db.select(db.localNotes).get(), isEmpty);
    expect(await db.select(db.pendingNoteMedia).get(), isEmpty);
    for (final key in const ['spiritual_notes', 'note_categories']) {
      expect(await db.syncDao.cursorFor(key), isNull, reason: key);
    }

    // Un brouillon s'y range, avec ses défauts.
    await db.into(db.localNotes).insert(
          LocalNotesCompanion.insert(
            id: 'n-1',
            clientCreatedAt: DateTime.utc(2026, 10, 11),
            clientUpdatedAt: DateTime.utc(2026, 10, 11),
          ),
        );
    final row = (await db.select(db.localNotes).get()).single;
    expect(row.dirty, isTrue);
    expect(row.body, '');
    expect(row.pinned, isFalse);
  });
}
