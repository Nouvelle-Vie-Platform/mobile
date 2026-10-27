// Palier des **cartes de traduction du module Bible** (mobile#263) :
// `AppDatabase.kBibleI18nSchemaVersion` = v33, après le surlignage au mot
// (v32). Il exige `test/data/local/schema/schema_v33.dart`, produit par
// `make gen && make migrations`.
//
// C'est le premier palier de **données** du magasin : aucune colonne n'est
// ajoutée, retirée ni retypée — les quatre concernées étaient déjà en `TEXT`.
// Ce qui change, c'est que leur texte est désormais du JSON, et le delta ne
// ramène que les lignes **modifiées** : sans ce palier, un plan déjà en
// magasin garderait sa chaîne nue, que `I18nMapConverter` lit comme une carte
// vide — un titre blanc, sans rien pour le dire.

import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';

import 'schema/schema.dart';

void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  const v = AppDatabase.kBibleI18nSchemaVersion;

  test('v33 est la version courante', () {
    expect(v, 33);
    expect(GeneratedHelper.versions.last, v);
    expect(v, AppDatabase.kWordMarkSchemaVersion + 1);
  });

  test('v32 → v33 : aucune colonne ne bouge', () async {
    final connection = await verifier.startAt(v - 1);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, v);
  });

  test('v1 → v33 : un appareil resté en v1 rejoue tous les paliers', () async {
    final connection = await verifier.startAt(1);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, v);
  });

  test('v32 → v33 : les titres déjà en magasin se replient sur `fr`', () async {
    final schema = await verifier.schemaAt(v - 1);
    // Trois lignes telles que le serveur les servait avant T1 : des chaînes
    // nues. C'est ce que porte un téléphone qui a synchronisé hier.
    schema.rawDatabase.execute(
      "INSERT INTO bible_plans (sync_stamp, id, title, description, days) "
      "VALUES (1, 'p-1', 'Évangiles en 40 jours', 'Un chapitre par jour', "
      "'[[{\"book\":\"Matt\",\"chapter\":1}]]')",
    );
    schema.rawDatabase.execute(
      "INSERT INTO bible_challenges (sync_stamp, id, plan_id, title) "
      "VALUES (1, 'c-1', 'p-1', 'Défi de l''Avent')",
    );
    schema.rawDatabase.execute(
      "INSERT INTO bible_quizzes (sync_stamp, id, title, age_band) "
      "VALUES (1, 4, 'Les patriarches', 'kids')",
    );

    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, v);

    final plan = (await db.select(db.biblePlans).get()).single;
    expect(plan.title, {'fr': 'Évangiles en 40 jours'});
    expect(plan.description, {'fr': 'Un chapitre par jour'});
    expect((await db.select(db.bibleChallenges).get()).single.title,
        {'fr': 'Défi de l\'Avent'});
    expect((await db.select(db.bibleQuizzes).get()).single.title,
        {'fr': 'Les patriarches'});
  });

  test(
      'v32 → v33 : une description absente le reste, et une carte déjà en '
      'place n\'est pas emballée deux fois', () async {
    final schema = await verifier.schemaAt(v - 1);
    schema.rawDatabase.execute(
      "INSERT INTO bible_plans (sync_stamp, id, title) "
      "VALUES (1, 'p-nu', 'Sans description')",
    );
    // Le palier doit pouvoir se rejouer : une migration de test v29 → v33
    // après un cycle, ou une base dont une ligne est déjà arrivée en carte.
    schema.rawDatabase.execute(
      "INSERT INTO bible_plans (sync_stamp, id, title, description) "
      "VALUES (1, 'p-carte', '{\"fr\":\"Déjà\",\"ee\":\"Xoxo\"}', "
      "'{\"fr\":\"Déjà décrite\"}')",
    );

    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, v);

    final plans = await db.select(db.biblePlans).get();
    final nu = plans.firstWhere((p) => p.id == 'p-nu');
    expect(nu.title, {'fr': 'Sans description'});
    expect(nu.description, isNull);
    final carte = plans.firstWhere((p) => p.id == 'p-carte');
    expect(carte.title, {'fr': 'Déjà', 'ee': 'Xoxo'});
    expect(carte.description, {'fr': 'Déjà décrite'});
  });
}
