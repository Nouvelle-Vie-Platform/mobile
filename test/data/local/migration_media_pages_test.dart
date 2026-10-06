// Palier de **la médiathèque en pages** (#167) :
// `AppDatabase.kMediaPagesSchemaVersion` = v27, après M4 (v26). Il exige
// `test/data/local/schema/schema_v27.dart`, produit par `make gen && make
// migrations`.

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';

import 'schema/schema.dart';

void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  const v = AppDatabase.kMediaPagesSchemaVersion;

  test('v26 → v27 : les trois tables de la médiathèque en pages', () async {
    final connection = await verifier.startAt(v - 1);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, v);
  });

  test('v1 → v27 : un appareil resté en v1 rejoue tous les paliers', () async {
    final connection = await verifier.startAt(1);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, v);
  });

  test(
      'v26 → v27 : le catalogue et le menu survivent, les pages naissent '
      'vides et sans curseur', () async {
    final schema = await verifier.schemaAt(v - 1);
    schema.rawDatabase.execute(
      "INSERT INTO teachings (id, title, sync_stamp) VALUES ('t-1', 'Dieu a le "
      "dernier mot', 1)",
    );
    schema.rawDatabase.execute(
      "INSERT INTO menu_entries (id, destination_kind, sync_stamp) "
      "VALUES (-2, 'catalogue', 1)",
    );

    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, v);

    expect((await db.select(db.teachings).get()).single.title,
        'Dieu a le dernier mot');
    // Le fard des anciens clients reste en magasin, sans effet : la
    // médiathèque ne lit plus `media_*`.
    expect((await db.select(db.menuEntries).get()).single.id, -2);
    expect(await db.select(db.mediaPages).get(), isEmpty);
    expect(await db.select(db.mediaPageChips).get(), isEmpty);
    expect(await db.select(db.mediaPageSections).get(), isEmpty);
    for (final key in const [
      'media_pages',
      'media_page_chips',
      'media_page_sections',
    ]) {
      expect(await db.syncDao.cursorFor(key), isNull, reason: key);
    }

    // Une section s'y range, liste d'identifiants comprise.
    await db.into(db.mediaPageSections).insert(
          MediaPageSectionsCompanion.insert(
            id: const Value(1),
            mediaPageId: 1,
            layout: 'list',
            sort: 'manual',
            destinationFamily: 'teaching',
            manualIds: const Value(['t-1']),
          ),
        );
    expect(
      (await db.select(db.mediaPageSections).get()).single.manualIds,
      ['t-1'],
    );
  });

  test(
      'v26 → v27 : `branches.slug` s\'ajoute nul, et le curseur de '
      '`branches` est oublié — seul le sien', () async {
    final schema = await verifier.schemaAt(v - 1);
    schema.rawDatabase.execute(
      "INSERT INTO branches (id, name, sync_stamp) VALUES (3, 'Aného', 1)",
    );
    for (final key in const ['branches', 'teachings']) {
      schema.rawDatabase.execute(
        "INSERT INTO sync_cursors (collection, cursor, synced_at) "
        "VALUES ('$key', 'un-curseur-opaque', 1)",
      );
    }

    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, v);

    final branch = (await db.select(db.branches).get()).single;
    expect(branch.name, 'Aného');
    expect(branch.slug, isNull);
    // Effacé : le prochain manifeste l'annonce `from_zero`, et le premier
    // cycle réécrit chaque branche avec son slug.
    expect(await db.syncDao.cursorFor('branches'), isNull);
    expect(await db.syncDao.cursorFor('teachings'), isNotNull);
  });
}
