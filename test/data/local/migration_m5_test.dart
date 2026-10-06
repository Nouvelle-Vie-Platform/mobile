// Palier **v23 → v24 (M5, #144)** — la sourdine par discussion.
//
// Un fichier à part de `migration_test.dart` : les tranches de la messagerie
// ont écrit leur palier en parallèle, puis ont été numérotées dans l'ordre des
// fusions (M8 v22, M3 v23, M5 v24). Voir `_migrateM5ToV24` dans
// `app_database.dart`.

import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';

import 'schema/schema.dart';

void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  test('v23 → v24 : la table de ma sourdine apparaît', () async {
    final connection = await verifier.startAt(23);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 24);
  });

  test('v1 → v24 : un appareil resté en v1 rejoue tous les paliers', () async {
    final connection = await verifier.startAt(1);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 24);
  });

  test('v23 → v24 : le fil et la lecture survivent, la sourdine naît vide',
      () async {
    // Ce que le palier ne doit pas toucher : le reste du magasin, curseurs
    // compris. La table neuve naît vide et sans curseur — vide veut dire
    // « aucune sourdine », exactement l'état d'avant cette version ; le
    // prochain manifeste l'annoncera `from_zero`.
    final schema = await verifier.schemaAt(23);
    schema.rawDatabase.execute(
      "INSERT INTO group_messages (id, group_id, author_id, is_system, body, "
      "created_at, sync_stamp) VALUES ('m-1', 'g-1', 'u-1', 0, 'Amen', "
      "1700000000, 7)",
    );
    schema.rawDatabase.execute(
      "INSERT INTO group_reads (group_id, last_read_message_id, last_read_at, "
      "sync_stamp) VALUES ('g-1', 'm-1', 1700000000, 8)",
    );
    schema.rawDatabase.execute(
      "INSERT INTO sync_cursors (collection, cursor, synced_at) "
      "VALUES ('group_messages', 'un-curseur-opaque', 1)",
    );

    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 24);

    expect((await db.select(db.groupMessages).get()).single.body, 'Amen');
    expect((await db.groupDao.readOf('g-1'))?.lastReadMessageId, 'm-1');
    expect(await db.syncDao.cursorFor('group_messages'), 'un-curseur-opaque');
    expect(await db.select(db.groupMutes).get(), isEmpty);
    expect(await db.syncDao.cursorFor('group_mutes'), isNull);
  });
}
