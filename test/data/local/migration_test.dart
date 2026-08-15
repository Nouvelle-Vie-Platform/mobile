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

  test('le schéma déclaré correspond au schéma v7 exporté', () async {
    // Le garde-fou de tous les jours : quiconque touche à une table sans
    // exporter la version correspondante casse ce test avant de casser un
    // téléphone.
    final connection = await verifier.startAt(7);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 7);
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

  test('v3 → v4 : les deux tables de la reprise de lecture apparaissent',
      () async {
    final connection = await verifier.startAt(3);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 4);
  });

  test('v1 → v4 : un appareil resté en v1 rejoue les trois paliers', () async {
    final connection = await verifier.startAt(1);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 4);
  });

  test('v3 → v4 : le catalogue déjà téléchargé survit au palier', () async {
    // Le palier ne fait que **créer deux tables** : aucune position de lecture
    // n'existait avant cette version — il n'y avait dans l'application aucun
    // chemin, ni en lecture ni en écriture, pour une reprise. Il n'y a donc
    // rien à reprendre, et c'est encore le catalogue que ce test protège.
    final schema = await verifier.schemaAt(3);
    schema.rawDatabase.execute(
      "INSERT INTO teachings (id, title, sync_stamp) VALUES ('t-1', 'Dieu a le "
      "dernier mot', 1)",
    );

    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 4);

    final rows = await db.select(db.teachings).get();
    expect(rows.single.title, 'Dieu a le dernier mot');
    // La collection répliquée naît vide : son curseur n'existe pas encore, le
    // prochain manifeste l'annoncera `from_zero`, et le premier cycle ramènera
    // **toute** la progression du fidèle — y compris celle accumulée sur un
    // autre appareil avant cette version.
    expect(await db.select(db.playbackProgress).get(), isEmpty);
    // La table locale seule, elle, ne se remplira qu'à la première écoute.
    expect(await db.select(db.localPlaybackPositions).get(), isEmpty);
  });

  test('v4 → v5 : la table des documents légaux apparaît', () async {
    final connection = await verifier.startAt(4);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 5);
  });

  test('v1 → v5 : un appareil resté en v1 rejoue les quatre paliers', () async {
    final connection = await verifier.startAt(1);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 5);
  });

  test('v4 → v5 : le catalogue déjà téléchargé survit au palier', () async {
    // Le palier ne fait que **créer une table** : aucun document légal
    // n'existait avant cette version — les trois destinations du menu latéral
    // rendaient une absence. Il n'y a donc rien à reprendre, et c'est encore
    // le catalogue que ce test protège.
    final schema = await verifier.schemaAt(4);
    schema.rawDatabase.execute(
      "INSERT INTO teachings (id, title, sync_stamp) VALUES ('t-1', 'Dieu a le "
      "dernier mot', 1)",
    );

    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 5);

    final rows = await db.select(db.teachings).get();
    expect(rows.single.title, 'Dieu a le dernier mot');
    // La collection naît vide : son curseur n'existe pas encore, le prochain
    // manifeste l'annoncera `from_zero`, et le premier cycle ramènera les trois
    // genres d'un coup — la collection n'a aucun filtre de périmètre.
    expect(await db.select(db.legalDocuments).get(), isEmpty);
  });

  test('v5 → v6 : le palier passe, et vide les fonds de statut', () async {
    final connection = await verifier.startAt(5);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 6);
  });

  test('v1 → v6 : un appareil resté en v1 rejoue les cinq paliers', () async {
    final connection = await verifier.startAt(1);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 6);
  });

  test('v5 → v6 : le catalogue survit, le fond et son curseur partent',
      () async {
    // Le palier ne crée rien : il **efface** `status_backgrounds` et son
    // curseur, parce que le libellé y était stocké en chaîne nue et qu'il passe
    // en carte de traduction. Un libellé nu ne se décode pas en carte, et le
    // convertisseur — tolérant par choix — rendrait une carte **vide** sans se
    // plaindre : le sélecteur de fonds afficherait des pastilles sans nom,
    // indéfiniment.
    //
    // Effacer le curseur est ce qui fait annoncer la collection `from_zero` au
    // manifeste suivant. L'oublier laisserait une table vide qu'aucun cycle ne
    // viendrait remplir — le pire des deux mondes.
    final schema = await verifier.schemaAt(5);
    schema.rawDatabase.execute(
      "INSERT INTO teachings (id, title, sync_stamp) VALUES ('t-1', 'Dieu a le "
      "dernier mot', 1)",
    );
    schema.rawDatabase.execute(
      "INSERT INTO status_backgrounds (id, label, base_color, top_color, "
      "bottom_color, ink, position, is_active, sync_stamp) "
      "VALUES (1, 'Bleu de marque', '#223B8C', '#2E4CAE', '#16265C', 'light', "
      "1, 1, 1)",
    );
    schema.rawDatabase.execute(
      "INSERT INTO sync_cursors (collection, cursor, synced_at) "
      "VALUES ('status_backgrounds', 'un-curseur-opaque', 1)",
    );

    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 6);

    // Le catalogue, lui, ne bouge pas : le palier ne vise qu'une table.
    final teachings = await db.select(db.teachings).get();
    expect(teachings.single.title, 'Dieu a le dernier mot');

    expect(await db.select(db.statusBackgrounds).get(), isEmpty);
    final cursors = await db.select(db.syncCursors).get();
    expect(
      cursors.where((c) => c.collection == 'status_backgrounds'),
      isEmpty,
      reason: 'sans effacement du curseur, la collection ne serait jamais '
          're-tirée et la table resterait vide pour toujours',
    );
  });

  test('v6 → v7 : la table des réglages apparaît, et naît vide', () async {
    // Le palier ne fait que **créer une table**. Elle reste vide jusqu'au
    // premier choix : l'absence de ligne *est* le défaut, et une valeur écrite
    // d'office serait indiscernable d'une décision du fidèle.
    final schema = await verifier.schemaAt(6);
    schema.rawDatabase.execute(
      "INSERT INTO teachings (id, title, sync_stamp) VALUES ('t-1', 'Dieu a le "
      "dernier mot', 1)",
    );

    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 7);

    expect((await db.select(db.teachings).get()).single.title,
        'Dieu a le dernier mot');
    expect(await db.select(db.appSettings).get(), isEmpty);
  });

  test('v1 → v7 : un appareil resté en v1 rejoue les six paliers', () async {
    final connection = await verifier.startAt(1);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 7);
  });

  test('v7 → v8 : la table downloads apparaît et teachings gagne `download`',
      () async {
    final connection = await verifier.startAt(7);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 8);
  });

  test('v1 → v8 : un appareil resté en v1 rejoue les sept paliers', () async {
    final connection = await verifier.startAt(1);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 8);
  });

  test('v7 → v8 : le catalogue survit, `download` naît nul, downloads vide',
      () async {
    // Deux changements **additifs** (#190) : `downloads` naît (locale seule) et
    // `teachings.download` s'ajoute, nullable. Aucune ligne n'est réécrite —
    // c'est le catalogue hors ligne du fidèle, la pièce qui se corrige le plus
    // mal une fois publiée.
    final schema = await verifier.schemaAt(7);
    schema.rawDatabase.execute(
      "INSERT INTO teachings (id, title, sync_stamp) VALUES ('t-1', 'Dieu a le "
      "dernier mot', 1)",
    );

    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 8);

    final teaching = (await db.select(db.teachings).get()).single;
    expect(teaching.title, 'Dieu a le dernier mot');
    // La colonne ajoutée est nulle sur une ligne écrite avant la migration :
    // « pas téléchargeable », jusqu'à ce qu'un cycle ramène son `download`.
    expect(teaching.download, isNull);
    // La table locale seule naît vide et le reste jusqu'au premier
    // téléchargement — elle n'est alimentée que par le moteur, jamais la synchro.
    expect(await db.select(db.downloads).get(), isEmpty);
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
