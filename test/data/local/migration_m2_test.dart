// Palier **M2** du magasin (#141) — ⚠️ PROVISOIRE : `AppDatabase.kM2SchemaVersion`
// (22 aujourd'hui) sera renuméroté à la fusion des tranches parallèles, et ce
// fichier avec lui. Il exige `test/data/local/schema/schema_v22.dart`, produit
// par `make gen && make migrations`.

import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';

import 'schema/schema.dart';

void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  const v = AppDatabase.kM2SchemaVersion;

  test('v21 → v22 : les gestes sur un message', () async {
    final connection = await verifier.startAt(v - 1);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, v);
  });

  test('v1 → v22 : un appareil resté en v1 rejoue tous les paliers', () async {
    final connection = await verifier.startAt(1);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, v);
  });

  test('v18 → v22 : la recréation de v20 produit déjà la forme M2', () async {
    final connection = await verifier.startAt(18);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, v);
  });

  test(
      'v21 → v22 : le fil et l\'écho en attente survivent, les colonnes neuves '
      'prennent leur défaut, les deux collections naissent vides', () async {
    final schema = await verifier.schemaAt(v - 1);
    schema.rawDatabase.execute(
      "INSERT INTO group_messages (id, group_id, author_id, is_system, body, "
      "created_at, sync_stamp) VALUES ('m-1', 'g-1', 'u-1', 0, 'Amen', "
      "1700000000, 7)",
    );
    schema.rawDatabase.execute(
      "INSERT INTO pending_group_messages (client_message_id, group_id, body, "
      "created_at, failed) VALUES ('c-1', 'g-1', 'Gloire', 1700000000, 0)",
    );
    schema.rawDatabase.execute(
      "INSERT INTO sync_cursors (collection, cursor, synced_at) "
      "VALUES ('group_messages', 'un-curseur-opaque', 1)",
    );

    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, v);

    final message = (await db.select(db.groupMessages).get()).single;
    expect(message.body, 'Amen');
    expect(message.deletedAt, isNull);
    expect(message.isForwarded, isFalse);
    expect(message.replyToDeleted, isFalse);
    expect(message.replyToMessageId, isNull);
    expect(
      (await db.select(db.pendingGroupMessages).get()).single.replyToMessageId,
      isNull,
    );
    expect(await db.syncDao.cursorFor('group_messages'), 'un-curseur-opaque');
    expect(await db.select(db.groupMessageReactions).get(), isEmpty);
    expect(await db.select(db.groupMessageHides).get(), isEmpty);
  });
}
