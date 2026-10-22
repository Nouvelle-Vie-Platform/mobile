// Palier du **magasin durable des médias de la messagerie** (#223) :
// `AppDatabase.kMessageMediaSchemaVersion` = v30, après le module Bible (v29).
// Il exige `test/data/local/schema/schema_v30.dart`, produit par `make gen &&
// make migrations`.
//
// Le troisième test est celui qui porte la décision : le chemin local vit dans
// une table **locale seule**, et non en colonne de `group_messages`, parce que
// le tirage réécrit cette collection en `insertOrReplace` — une colonne y
// serait effacée au prochain cycle.

import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/sync/sync_rows.dart';

import 'schema/schema.dart';

void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  const v = AppDatabase.kMessageMediaSchemaVersion;

  // « v30 est la version courante » a déménagé dans
  // `migration_versification_test.dart` avec le palier v31 : l'assertion
  // appartient au **dernier** palier, qui est le seul à savoir qu'il l'est.
  test('v30 reste un palier de la liste', () {
    expect(v, 30);
    expect(GeneratedHelper.versions, contains(v));
    expect(AppDatabase.kMessageMediaSchemaVersion,
        AppDatabase.kBibleSchemaVersion + 1);
  });

  test('v29 → v30 : la table du magasin durable', () async {
    final connection = await verifier.startAt(v - 1);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, v);
  });

  test('v1 → v30 : un appareil resté en v1 rejoue tous les paliers', () async {
    final connection = await verifier.startAt(1);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, v);
  });

  test('v29 → v30 : le fil survit, et le magasin naît vide et sans curseur',
      () async {
    final schema = await verifier.schemaAt(v - 1);
    schema.rawDatabase.execute(
      "INSERT INTO group_messages (id, group_id, body, sync_stamp) "
      "VALUES ('m-1', 'g-1', 'amen', 1)",
    );

    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, v);

    expect((await db.select(db.groupMessages).get()).single.body, 'amen');
    expect(await db.select(db.localMessageMedia).get(), isEmpty);
    // Hors de tout registre de synchronisation : rien à annoncer, rien à
    // effacer.
    expect(await db.syncDao.cursorFor('local_message_media'), null);
  });

  test(
      "le chemin local survit à un tirage, là où une colonne de "
      "`group_messages` serait effacée", () async {
    final db = AppDatabase(await verifier.startAt(v));
    addTearDown(db.close);

    const item = <String, Object?>{
      'id': 'm-1',
      'groupId': 'g-1',
      'mediaKind': 'image',
      'mediaKey': 'k-1',
      'createdAt': '2026-10-15T08:00:00.000Z',
    };

    // Le message arrive, puis son image descend sur l'appareil.
    await db.syncDao.applyPage(
      db.syncDao.groupMessagesCollection,
      upserts: [groupMessageRowOf(item)],
      cursor: 'c1',
    );
    await db.groupDao.rememberLocalMedia('m-1', path: '/magasin/m-1/i.jpg');

    // Le serveur renvoie la **même** ligne au cycle suivant (M2 : une
    // modification, un tombstone, ou le curseur effacé par le palier v26).
    await db.syncDao.applyPage(
      db.syncDao.groupMessagesCollection,
      upserts: [groupMessageRowOf(item)],
      cursor: 'c2',
    );

    expect(
      (await db.select(db.localMessageMedia).get()).single.path,
      '/magasin/m-1/i.jpg',
      reason: 'une table locale seule ne passe pas sous `insertOrReplace`',
    );

    // **La mesure qui tranche l'emplacement**, et non une supposition : le
    // mode d'écriture du tirage, `INSERT OR REPLACE`, remet à son défaut
    // toute colonne que l'insertion ne cite pas. Une colonne `media_path`
    // posée sur `group_messages` — que `groupMessageRowOf` ne citerait pas —
    // serait donc effacée à chaque cycle qui repasse sur la ligne. Démontré
    // ici sur la table du magasin, la seule dont ce test maîtrise le schéma.
    await db.customStatement(
      "INSERT OR REPLACE INTO local_message_media (message_id) "
      "VALUES ('m-1')",
    );
    expect(
      (await db.select(db.localMessageMedia).get()).single.path,
      null,
      reason: 'si le chemin survivait à ceci, une colonne conviendrait aussi',
    );
  });

  test('noter la vignette ne perd pas le fichier, et inversement', () async {
    final db = AppDatabase(await verifier.startAt(v));
    addTearDown(db.close);

    await db.groupDao.rememberLocalMedia('m-1', path: '/magasin/m-1/v.mp4');
    await db.groupDao
        .rememberLocalMedia('m-1', thumbPath: '/magasin/m-1/thumb_v.jpg');

    final row = (await db.select(db.localMessageMedia).get()).single;
    expect(row.path, '/magasin/m-1/v.mp4');
    expect(row.thumbPath, '/magasin/m-1/thumb_v.jpg');
  });
}
