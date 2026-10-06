/// **Le palier des accusés** (#142, M3) — ⚠️ numéroté v22 **à titre
/// provisoire** : le coordinateur le renumérote (v22, v23…) dans l'ordre des
/// fusions des tranches de la messagerie. Il exige le schéma exporté
/// (`make migrations` : `drift_schemas/` et `test/data/local/schema/`).
library;

import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';

import 'schema/schema.dart';

void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  test('v21 → v22 : les accusés et les confirmations apparaissent', () async {
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

  test('v21 → v22 : le fil survit ; les deux tables naissent vides', () async {
    final schema = await verifier.schemaAt(21);
    schema.rawDatabase.execute(
      "INSERT INTO group_messages (id, group_id, author_id, is_system, body, "
      "created_at, sync_stamp) VALUES ('m-1', 'g-1', 'u-1', 0, 'Amen', "
      "1700000000, 7)",
    );
    schema.rawDatabase.execute(
      "INSERT INTO sync_cursors (collection, cursor, synced_at) "
      "VALUES ('group_messages', 'un-curseur-opaque', 1)",
    );

    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 22);

    expect((await db.select(db.groupMessages).get()).single.body, 'Amen');
    expect(await db.syncDao.cursorFor('group_messages'), 'un-curseur-opaque');
    expect(await db.select(db.messageReceipts).get(), isEmpty);
    expect(await db.select(db.deliveryAcks).get(), isEmpty);
    // Pas de curseur : le prochain manifeste annonce `from_zero`, et le premier
    // cycle ramène les accusés des messages envoyés avant cette version.
    expect(await db.syncDao.cursorFor('message_receipts'), isNull);
  });
}
