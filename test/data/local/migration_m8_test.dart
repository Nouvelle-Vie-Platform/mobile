// **Palier v21 → v22 (PROVISOIRE)** — archiver, épingler une discussion (#146,
// tranche M8). Un fichier à part de `migration_test.dart`, que chaque tranche de
// la messagerie allonge : le coordinateur renumérote les paliers dans l'ordre
// des fusions (v22, v23…), et ce fichier se renumérote avec le sien.
//
// Exige les schémas exportés (`make gen && make migrations`) : `schema_v22.dart`.

import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';

import 'schema/schema.dart';

void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  test('v21 → v22 : le rangement et son outbox apparaissent', () async {
    final connection = await verifier.startAt(21);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 22);
  });

  test('v1 → v22 : un appareil resté en v1 rejoue tous les paliers', () async {
    final connection = await verifier.startAt(1);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 22);
  });

  test('v21 → v22 : le fil et la lecture survivent, le rangement naît vide',
      () async {
    // Ce que le palier ne doit pas toucher : le reste du magasin, curseurs
    // compris. Les deux tables neuves naissent vides, et `group_arrangements`
    // sans curseur — le prochain manifeste l'annoncera `from_zero`, et le
    // premier cycle ramènera les rangements faits sur un autre appareil.
    final schema = await verifier.schemaAt(21);
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
    await verifier.migrateAndValidate(db, 22);

    expect((await db.select(db.groupMessages).get()).single.body, 'Amen');
    expect(
      (await db.select(db.groupReads).get()).single.lastReadMessageId,
      'm-1',
    );
    expect(await db.syncDao.cursorFor('group_messages'), 'un-curseur-opaque');
    expect(await db.select(db.groupArrangements).get(), isEmpty);
    expect(await db.select(db.pendingGroupArrangements).get(), isEmpty);
    expect(await db.syncDao.cursorFor('group_arrangements'), isNull);
  });
}
