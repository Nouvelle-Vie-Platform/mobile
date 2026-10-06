// Palier **M4** du magasin (#143) : `AppDatabase.kM4SchemaVersion` = v26, après
// M2 (v25). Il exige `test/data/local/schema/schema_v26.dart`, produit par
// `make gen && make migrations`.

import 'package:drift/drift.dart' hide isNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';

import 'schema/schema.dart';

void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  const v = AppDatabase.kM4SchemaVersion;

  test('v25 → v26 : le média du message et de son écho', () async {
    final connection = await verifier.startAt(v - 1);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, v);
  });

  test('v1 → v26 : un appareil resté en v1 rejoue tous les paliers', () async {
    // `group_messages` et `pending_group_messages` naissent au palier v17 →
    // v18 **dans leur forme courante** : le palier v26 ne doit pas leur
    // ajouter une seconde fois les colonnes du média.
    final connection = await verifier.startAt(1);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, v);
  });

  test('v18 → v26 : la recréation du palier v20 porte déjà le média', () async {
    final connection = await verifier.startAt(18);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, v);
  });

  test('v24 → v26 : les paliers M2 et M4 s\'enchaînent', () async {
    final connection = await verifier.startAt(24);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, v);
  });

  test(
      'v25 → v26 : le fil et l\'écho survivent, le curseur du fil est oublié, '
      'et un média s\'y range enfin', () async {
    final schema = await verifier.schemaAt(v - 1);
    schema.rawDatabase.execute(
      "INSERT INTO group_messages (id, group_id, author_id, is_system, body, "
      "created_at, sync_stamp, is_forwarded, reply_to_deleted) VALUES "
      "('m-1', 'g-1', 'u-1', 0, NULL, 1700000000, 7, 1, 0)",
    );
    schema.rawDatabase.execute(
      "INSERT INTO pending_group_messages (client_message_id, group_id, body, "
      "created_at, failed) VALUES ('c-1', 'g-1', 'Gloire', 1700000001, 1)",
    );
    schema.rawDatabase.execute(
      "INSERT INTO sync_cursors (collection, cursor, synced_at) "
      "VALUES ('group_messages', 'un-curseur-opaque', 1)",
    );
    schema.rawDatabase.execute(
      "INSERT INTO sync_cursors (collection, cursor, synced_at) "
      "VALUES ('groups', 'un-autre-curseur', 1)",
    );

    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, v);

    final kept = (await db.select(db.groupMessages).get()).single;
    expect(kept.syncStamp, 7);
    // Les colonnes de M2 ont traversé le palier.
    expect(kept.isForwarded, isTrue);
    expect(kept.mediaKind, isNull,
        reason: 'le média se remplira au tirage from_zero');
    final echo = (await db.select(db.pendingGroupMessages).get()).single;
    expect(echo.body, 'Gloire');
    expect(echo.failed, isTrue);
    expect(echo.mediaKind, isNull);

    // Le curseur du fil est oublié — et lui seul.
    expect(await db.syncDao.cursorFor('group_messages'), isNull);
    expect(await db.syncDao.cursorFor('groups'), 'un-autre-curseur');

    await db.into(db.groupMessages).insert(
          GroupMessagesCompanion.insert(
            id: 'm-2',
            groupId: 'g-1',
            mediaKind: const Value('location'),
            mediaMeta: const Value('{"latitude":6.13,"longitude":1.22}'),
          ),
        );
    final location = await (db.select(db.groupMessages)
          ..where((m) => m.id.equals('m-2')))
        .getSingle();
    expect(location.mediaKind, 'location');
  });
}
