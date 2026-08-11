// Tests de **migration** du magasin local.
//
// Une migration ratée sur un téléphone installé n'est pas un test rouge : c'est
// une application qui ne démarre plus chez un fidèle, sans correction possible
// à distance. Le schéma de chaque version est donc **exporté** dans
// `drift_schemas/`, et chaque transition se rejoue ici sur une base réelle.
//
// Le schéma exporté est produit par `make migrations` (voir `build.yaml`). En
// ajoutant une version : bumper `AppDatabase.schemaVersion`, écrire le palier
// dans `MigrationStrategy.onUpgrade`, relancer `make gen && make migrations`,
// puis ajouter ici le test de transition `n-1 → n`.

import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';

import 'local_database_fixtures.dart';
import 'schema/schema.dart';

void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  test('le schéma déclaré correspond au schéma v3 exporté', () async {
    // Le garde-fou de tous les jours : quiconque touche à une table sans
    // exporter la version correspondante casse ce test avant de casser un
    // téléphone.
    final connection = await verifier.startAt(3);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 3);
  });

  test('v1 → v2 : les deux tables de rassemblement apparaissent', () async {
    // **Le seul test qui compte vraiment de ce fichier.** Une migration ratée
    // sur un téléphone installé n'est pas un test rouge : c'est une application
    // qui ne démarre plus chez un fidèle, sans correction possible à distance.
    // On part donc d'une base réellement à la v1, telle qu'un appareil déjà
    // installé la porte, et on rejoue le palier.
    final connection = await verifier.startAt(1);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 2);
  });

  test('v1 → v2 : le catalogue déjà téléchargé survit au palier', () async {
    // Le palier ne fait que **créer deux tables** — aucune colonne existante ne
    // bouge, aucune donnée n'est recopiée. Ce test le prouve plutôt que de le
    // supposer : c'est exactement ce qu'un fidèle hors ligne risque de perdre.
    final schema = await verifier.schemaAt(1);
    schema.rawDatabase.execute(
      "INSERT INTO teachings (id, title, sync_stamp) VALUES ('t-1', 'Dieu a le "
      "dernier mot', 1)",
    );

    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 2);

    final rows = await db.select(db.teachings).get();
    expect(rows.single.title, 'Dieu a le dernier mot');
    // Et les deux nouvelles tables sont là, vides : leurs curseurs n'existent
    // pas encore, le prochain manifeste les annoncera `from_zero`.
    expect(await db.select(db.gatherings).get(), isEmpty);
    expect(await db.select(db.gatheringTypes).get(), isEmpty);
  });

  test('v2 → v3 : les quatre tables d\'annonce apparaissent', () async {
    final connection = await verifier.startAt(2);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 3);
  });

  test('v1 → v3 : un appareil resté en v1 rejoue les deux paliers', () async {
    // Le cas qu'on oublie de tester : un téléphone qui n'a pas été ouvert
    // depuis deux livraisons ne saute pas la v2, il traverse les paliers l'un
    // après l'autre. Un `onUpgrade` écrit en `if (from == 2)` passerait ce test
    // en v2 → v3 et laisserait cet appareil-là sans ses tables.
    final connection = await verifier.startAt(1);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 3);
  });

  test('v2 → v3 : le catalogue déjà téléchargé survit au palier', () async {
    // Le palier ne fait que **créer quatre tables** : le mur de statuts était
    // encore peint par `SampleData`, il n'y a aucune donnée locale à reprendre.
    // Ce qu'un fidèle hors ligne risquerait de perdre, c'est son catalogue — et
    // c'est ce que ce test protège.
    final schema = await verifier.schemaAt(2);
    schema.rawDatabase.execute(
      "INSERT INTO teachings (id, title, sync_stamp) VALUES ('t-1', 'Dieu a le "
      "dernier mot', 1)",
    );

    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 3);

    final rows = await db.select(db.teachings).get();
    expect(rows.single.title, 'Dieu a le dernier mot');
    // Et les quatre nouvelles tables sont là, vides : leurs curseurs n'existent
    // pas encore, le prochain manifeste les annoncera `from_zero`.
    expect(await db.select(db.announcements).get(), isEmpty);
    expect(await db.select(db.officialAccounts).get(), isEmpty);
    expect(await db.select(db.officialAccountMemberships).get(), isEmpty);
    expect(await db.select(db.statusBackgrounds).get(), isEmpty);
  });

  test('la version de schéma couvre bien toutes les versions exportées', () {
    final db = openTestDatabase();
    addTearDown(db.close);

    expect(db.schemaVersion, GeneratedHelper.versions.last);
  });

  test('une base neuve démarre avec sa ligne d\'état global', () async {
    final db = openTestDatabase();
    addTearDown(db.close);

    // `onCreate` doit la poser : sans elle, la première allocation de jeton
    // d'écriture lèverait, et donc la toute première page appliquée.
    final rows = await db.select(db.syncState).get();
    expect(rows, hasLength(1));
    expect(rows.single.scopeVersion, isNull);

    await db.syncDao.applyPage(
      db.syncDao.branchesCollection,
      upserts: [branchRow(1, 'Lomé')],
      cursor: 'c1',
    );
    expect(await db.select(db.branches).get(), hasLength(1));
  });
}
