// Palier de **la versification propre à chaque version** (C3, mobile#240) :
// `AppDatabase.kVersificationSchemaVersion` = v31, après le magasin des médias
// de la messagerie (v30). Il exige `test/data/local/schema/schema_v31.dart`,
// produit par `make gen && make migrations`.
//
// Le dernier test est celui qui porte la décision : le relevé vit sur
// `bible_installed_versions`, une table **locale seule**, et non sur
// `bible_versions`, le miroir répliqué que le tirage réécrit en
// `insertOrReplace` — une colonne y serait effacée au cycle suivant.

import 'package:drift/drift.dart' hide isNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/sync/sync_rows.dart';
import 'package:maison_du_miracle/features/bible/data/canon.dart';
import 'package:maison_du_miracle/features/bible/personalize/bible_catalog.dart';

import 'schema/schema.dart';

const _releve = '{"Gen":[31],"Mal":[14,17,24,0]}';

void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  const v = AppDatabase.kVersificationSchemaVersion;

  // « v31 est la version courante » a déménagé dans
  // `migration_word_marks_test.dart` avec le palier v32 : l'assertion
  // appartient au **dernier** palier, qui est le seul à savoir qu'il l'est.
  test('v31 reste un palier de la liste', () {
    expect(v, 31);
    expect(GeneratedHelper.versions, contains(v));
    expect(AppDatabase.kVersificationSchemaVersion,
        AppDatabase.kMessageMediaSchemaVersion + 1);
  });

  test('v30 → v31 : la colonne du relevé', () async {
    final connection = await verifier.startAt(v - 1);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, v);
  });

  test('v1 → v31 : un appareil resté en v1 rejoue tous les paliers', () async {
    final connection = await verifier.startAt(1);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, v);
  });

  test(
      'v30 → v31 : une version déjà installée survit, sans relevé — donc sur '
      'le canon figé', () async {
    final schema = await verifier.schemaAt(v - 1);
    schema.rawDatabase.execute(
      "INSERT INTO bible_installed_versions "
      "(code, name, installed_at, indexed) VALUES ('EWE', 'Biblia', 0, 1)",
    );

    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, v);

    final row = (await db.select(db.bibleInstalledVersions).get()).single;
    expect(row.code, 'EWE');
    expect(row.indexed, isTrue, reason: 'son index n\'est pas à refaire');
    expect(row.versification, isNull);
    // Nulle veut dire « aucun relevé » : le lecteur lit comme avant.
    final catalog = MergedBibleCatalog(installed: [row]);
    expect(catalog.versificationFor('EWE'), kCanonVersification);
  });

  test(
      "le relevé survit à un tirage, là où une colonne de `bible_versions` "
      "serait effacée", () async {
    final db = AppDatabase(await verifier.startAt(v));
    addTearDown(db.close);

    const item = <String, Object?>{
      'id': 7,
      'code': 'EWE',
      'name': 'Biblia Ewe',
      'license': '© Bible Society of Ghana',
      'publishedAt': '2026-10-22T08:00:00.000Z',
    };

    // La version est servie, puis installée avec son relevé.
    await db.syncDao.applyPage(
      db.syncDao.bibleVersionsCollection,
      upserts: [bibleVersionRowOf(item)],
      cursor: 'c1',
    );
    await db.into(db.bibleInstalledVersions).insert(
          BibleInstalledVersionsCompanion.insert(
            code: 'EWE',
            name: 'Biblia Ewe',
            installedAt: DateTime.utc(2026, 10, 22),
            versification: const Value(_releve),
          ),
        );

    // Le serveur renvoie la **même** ligne au cycle suivant.
    await db.syncDao.applyPage(
      db.syncDao.bibleVersionsCollection,
      upserts: [bibleVersionRowOf(item)],
      cursor: 'c2',
    );

    expect(
      (await db.select(db.bibleInstalledVersions).get()).single.versification,
      _releve,
      reason: 'une table locale seule ne passe pas sous `insertOrReplace`',
    );

    // **La mesure qui tranche l'emplacement**, et non une supposition : le
    // mode d'écriture du tirage remet à son défaut toute colonne que
    // l'insertion ne cite pas. Une colonne `versification` posée sur
    // `bible_versions` — que `bibleVersionRowOf` ne citerait pas — serait donc
    // effacée à chaque cycle qui repasse sur la ligne. Démontré ici sur
    // `license`, une colonne de cette même table répliquée.
    expect((await db.select(db.bibleVersions).get()).single.license,
        '© Bible Society of Ghana');
    await db.customStatement(
      "INSERT OR REPLACE INTO bible_versions (id, code, name) "
      "VALUES (7, 'EWE', 'Biblia Ewe')",
    );
    expect(
      (await db.select(db.bibleVersions).get()).single.license,
      null,
      reason: 'si la licence survivait à ceci, une colonne conviendrait aussi',
    );
  });
}
