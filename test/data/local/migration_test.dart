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

  test('le schéma déclaré correspond au schéma v1 exporté', () async {
    // Le garde-fou de tous les jours : quiconque touche à une table sans
    // exporter la version correspondante casse ce test avant de casser un
    // téléphone.
    final connection = await verifier.startAt(1);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 1);
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
