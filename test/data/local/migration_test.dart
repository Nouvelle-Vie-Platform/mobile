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
import 'package:maison_du_miracle/data/local/tables/download_tables.dart';
import 'package:maison_du_miracle/models/auth_channels.dart';

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

  test(
      'v8 → v9 : les tables download_titles et download_notifications naissent',
      () async {
    final connection = await verifier.startAt(8);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 9);
  });

  test('v9 → v10 : la colonne teachings.image_square_url naît', () async {
    final connection = await verifier.startAt(9);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 10);
  });

  test('v1 → v10 : un appareil resté en v1 rejoue les neuf paliers', () async {
    final connection = await verifier.startAt(1);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 10);
  });

  test(
      'v8 → v9 : les téléchargements survivent, les deux tables naissent vides',
      () async {
    // Deux créations de table **additives** (#194) : `download_titles` et
    // `download_notifications`. Aucune ligne `downloads` n'est réécrite — c'est
    // un fichier réel sur l'appareil du fidèle.
    final schema = await verifier.schemaAt(8);
    schema.rawDatabase.execute(
      "INSERT INTO downloads (content_type, content_id, quality, state, "
      "bytes_received, bytes_total, created_at) "
      "VALUES ('teaching', 't-1', 'mid', 'complete', 200, 200, 1000)",
    );

    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 9);

    final download = (await db.select(db.downloads).get()).single;
    expect(download.contentId, 't-1');
    expect(download.state, DownloadState.complete);
    // Les deux tables locales seules naissent vides : `download_titles` se
    // remplit au prochain téléchargement, `download_notifications` au premier
    // retrait d'un enseignement téléchargé.
    expect(await db.select(db.downloadTitles).get(), isEmpty);
    expect(await db.select(db.downloadNotifications).get(), isEmpty);
  });

  test(
      'v9 → v10 : le catalogue survit, `imageSquareUrl` naît nul sur une ligne '
      'écrite avant la migration', () async {
    // Un seul changement **additif** (#209) : la colonne `image_square_url`
    // s'ajoute à `teachings`, nullable. Aucune ligne n'est réécrite — c'est le
    // catalogue hors ligne du fidèle, la pièce qui se corrige le plus mal une
    // fois publiée.
    final schema = await verifier.schemaAt(9);
    schema.rawDatabase.execute(
      "INSERT INTO teachings (id, title, sync_stamp) VALUES ('t-1', 'Dieu a le "
      "dernier mot', 1)",
    );

    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 10);

    final teaching = (await db.select(db.teachings).get()).single;
    expect(teaching.title, 'Dieu a le dernier mot');
    // La colonne ajoutée est nulle sur une ligne écrite avant la migration :
    // « pas de carré », jusqu'à ce qu'un cycle ramène son `imageSquareUrl`.
    expect(teaching.imageSquareUrl, isNull);
  });

  test('v12 → v13 : la table des invités apparaît', () async {
    // Le palier des **invités** (#77) : une création de table, et rien d'autre.
    // Aucune colonne n'est ajoutée à `teachings`, aucune ligne n'est réécrite —
    // un enseignement sans invité est l'état par défaut, et il le reste.
    final connection = await verifier.startAt(12);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 13);
  });

  test('v1 → v13 : un appareil resté en v1 rejoue les douze paliers', () async {
    // Le cas qu'on oublie de tester : un téléphone qui n'a pas été ouvert depuis
    // plusieurs livraisons ne saute aucun palier, il les traverse l'un après
    // l'autre. Un `onUpgrade` écrit en `if (from == 12)` passerait le test
    // précédent et laisserait cet appareil-là sans sa table.
    final connection = await verifier.startAt(1);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 13);
  });

  test('v12 → v13 : le catalogue survit, et la table des invités naît vide',
      () async {
    // Ce qu'un fidèle hors ligne risquerait de perdre, c'est son catalogue : le
    // palier ne le touche pas. La table neuve, elle, naît vide — son curseur
    // n'existe pas encore, le prochain manifeste l'annoncera `from_zero`, et le
    // premier cycle ramènera **tous** les crédits du catalogue, y compris ceux
    // posés avant cette version.
    final schema = await verifier.schemaAt(12);
    schema.rawDatabase.execute(
      "INSERT INTO teachings (id, title, sync_stamp) VALUES ('t-1', 'Dieu a le "
      "dernier mot', 1)",
    );

    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 13);

    expect((await db.select(db.teachings).get()).single.title,
        'Dieu a le dernier mot');
    expect(await db.select(db.teachingGuests).get(), isEmpty);
  });

  test('v13 → v14 : la table du vocabulaire apparaît', () async {
    // Le palier du **vocabulaire réglé** (#81) : une création de table, et rien
    // d'autre. Aucune valeur de `.arb` ne change, aucune colonne existante ne
    // bouge.
    final connection = await verifier.startAt(13);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 14);
  });

  test('v1 → v14 : un appareil resté en v1 rejoue les treize paliers',
      () async {
    final connection = await verifier.startAt(1);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 14);
  });

  test('v13 → v14 : le catalogue survit, et le vocabulaire naît vide',
      () async {
    // Ce qu'un fidèle hors ligne risquerait de perdre, c'est son catalogue : le
    // palier ne le touche pas. La table neuve, elle, naît vide — et **vide veut
    // dire « le mot du dépôt partout »**, c'est-à-dire exactement ce que
    // l'application affichait déjà avant la migration. Son curseur n'existe pas
    // encore, le prochain manifeste l'annoncera `from_zero`.
    final schema = await verifier.schemaAt(13);
    schema.rawDatabase.execute(
      "INSERT INTO teachings (id, title, sync_stamp) VALUES ('t-1', 'Dieu a le "
      "dernier mot', 1)",
    );

    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 14);

    expect((await db.select(db.teachings).get()).single.title,
        'Dieu a le dernier mot');
    expect(await db.select(db.presentationVocabulary).get(), isEmpty);
    // Aucun curseur posé : la collection n'a jamais été tirée.
    expect(
      await db.syncDao.cursorFor('presentation_vocabulary'),
      isNull,
    );
  });

  test('v14 → v15 : la table des canaux de connexion apparaît', () async {
    // Le palier des **canaux** (#83) : une création de table, et rien d'autre.
    // Aucune colonne existante ne bouge, et l'écran d'identifiant ne change pas
    // de comportement tant que le premier cycle n'a rien ramené.
    final connection = await verifier.startAt(14);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 15);
  });

  test('v1 → v15 : un appareil resté en v1 rejoue les quatorze paliers',
      () async {
    final connection = await verifier.startAt(1);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 15);
  });

  test('v14 → v15 : le catalogue survit, et l\'offre naît vide', () async {
    // Ce qu'un fidèle hors ligne risquerait de perdre, c'est son catalogue : le
    // palier ne le touche pas. La table neuve, elle, naît vide — et **vide veut
    // dire « je n'ai pas encore reçu les réglages »**, jamais « aucun canal ».
    // Le repli lu par l'écran est alors l'**e-mail seul**, c'est-à-dire ce que
    // l'application proposait déjà avant la migration. Son curseur n'existe pas
    // encore, le prochain manifeste l'annoncera `from_zero`.
    final schema = await verifier.schemaAt(14);
    schema.rawDatabase.execute(
      "INSERT INTO teachings (id, title, sync_stamp) VALUES ('t-1', 'Dieu a le "
      "dernier mot', 1)",
    );

    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 15);

    expect((await db.select(db.teachings).get()).single.title,
        'Dieu a le dernier mot');
    expect(await db.select(db.authChannels).get(), isEmpty);
    // La table vide se lit comme l'e-mail seul, et jamais comme « aucun
    // canal » : un repli vide fermerait la porte, un repli permissif
    // remettrait le sélecteur menteur.
    final offer = await db.authChannelsDao.readOffer();
    expect(offer, AuthChannelOffer.emailOnly);
    expect(offer.offersChoice, isFalse);
    // Aucun curseur posé : la collection n'a jamais été tirée.
    expect(await db.syncDao.cursorFor('auth_channels'), isNull);
  });

  test('v15 → v16 : la table du réglage du parc apparaît', () async {
    // Le palier du **réglage d'exploitation du parc** (#91) : une création de
    // table, et rien d'autre. Aucune colonne existante ne bouge, et le bandeau
    // de mise à jour ne change pas de comportement tant que le premier cycle
    // n'a rien ramené.
    final connection = await verifier.startAt(15);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 16);
  });

  test('v1 → v16 : un appareil resté en v1 rejoue les quinze paliers',
      () async {
    final connection = await verifier.startAt(1);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 16);
  });

  test('v15 → v16 : le catalogue survit, et il n\'y a pas de seuil', () async {
    // Ce qu'un fidèle hors ligne risquerait de perdre, c'est son catalogue : le
    // palier ne le touche pas. La table neuve, elle, naît vide — et **vide veut
    // dire « pas de seuil »**, jamais « seuil à zéro ». Le bandeau reste donc tu
    // immédiatement après la migration, exactement comme avant elle : c'est la
    // décision explicite de #80, et un bandeau « mettez à jour » apparu tout
    // seul au premier démarrage suivant une mise à jour serait le plus mauvais
    // premier contact possible.
    final schema = await verifier.schemaAt(15);
    schema.rawDatabase.execute(
      "INSERT INTO teachings (id, title, sync_stamp) VALUES ('t-1', 'Dieu a le "
      "dernier mot', 1)",
    );

    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 16);

    expect((await db.select(db.teachings).get()).single.title,
        'Dieu a le dernier mot');
    expect(await db.select(db.deviceSettings).get(), isEmpty);
    expect(
      await db.deviceSettingsDao.readUpdateBannerMinVersion(),
      isNull,
      reason: 'pas de seuil, pas de bandeau — jamais l\'inverse',
    );
    // Aucun curseur posé : la collection n'a jamais été tirée.
    expect(await db.syncDao.cursorFor('device_settings'), isNull);
  });

  test('v16 → v18 : les six tables d\'Échanges naissent', () async {
    // Le palier de la rubrique **« Échanges »** (#96) : cinq collections
    // répliquées et une table locale seule, et rien d'autre. Aucune colonne
    // existante ne bouge.
    //
    // ⚠️ **v16 et non v17**, et ce n'est pas une inattention : la v17 appartient à
    // la tranche jumelle #82 (les entrées de menu), qui n'est pas encore fusionnée.
    // `drift_schemas/` n'exporte donc pas de v17, et `GeneratedHelper.versions`
    // porte un trou — `[1…16, 18]`. Au rebasage sur #82, ce test devient
    // `v17 → v18` et le trou se referme ; la paire avec `v1 → v18` ci-dessous, elle,
    // ne bouge pas.
    final connection = await verifier.startAt(16);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 18);
  });

  test('v1 → v18 : un appareil resté en v1 rejoue tous les paliers', () async {
    final connection = await verifier.startAt(1);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 18);
  });

  test('v16 → v18 : le catalogue survit, et la rubrique naît vide', () async {
    // Ce qu'un fidèle hors ligne risquerait de perdre, c'est son catalogue : le
    // palier ne le touche pas. Les six tables, elles, naissent **vides** — et vide
    // veut dire ici « je n'ai pas encore reçu mes conversations », ce que les
    // écrans rendent comme une **absence** et non comme une erreur. Un magasin vide
    // ne se plaint pas.
    //
    // Il n'y avait de toute façon **rien à reprendre** : la rubrique était
    // intégralement fictive avant ce palier (`SampleData` — quatre groupes, sept
    // conversations et le même fil de cinq messages pour toutes).
    final schema = await verifier.schemaAt(16);
    schema.rawDatabase.execute(
      "INSERT INTO teachings (id, title, sync_stamp) VALUES ('t-1', 'Dieu a le "
      "dernier mot', 1)",
    );

    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 18);

    expect((await db.select(db.teachings).get()).single.title,
        'Dieu a le dernier mot');
    expect(await db.select(db.profiles).get(), isEmpty);
    expect(await db.select(db.groups).get(), isEmpty);
    expect(await db.select(db.groupMembers).get(), isEmpty);
    expect(await db.select(db.groupJoinRequests).get(), isEmpty);
    expect(await db.select(db.groupMessages).get(), isEmpty);
    // La table **locale seule** de l'écho optimiste naît vide elle aussi, et le
    // reste jusqu'au premier envoi : aucun cycle ne l'écrit.
    expect(await db.select(db.pendingGroupMessages).get(), isEmpty);
    // Aucun curseur posé : les cinq collections n'ont jamais été tirées, et le
    // prochain manifeste les annoncera `from_zero`.
    for (final key in const [
      'profiles',
      'groups',
      'group_members',
      'group_join_requests',
      'group_messages',
    ]) {
      expect(await db.syncDao.cursorFor(key), isNull, reason: key);
    }
  });

  test('v16 → v17 : la table des entrées de menu apparaît', () async {
    // Le palier des **menus** (#82) : une création de table, et rien d'autre.
    // Aucune colonne existante ne bouge, et ni la médiathèque ni l'accueil ne
    // changent de comportement tant que le premier cycle n'a rien ramené.
    final connection = await verifier.startAt(16);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 17);
  });

  test('v1 → v17 : un appareil resté en v1 rejoue les seize paliers', () async {
    final connection = await verifier.startAt(1);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 17);
  });

  test('v16 → v17 : le catalogue survit, et il n\'y a pas de menu', () async {
    // Ce qu'un fidèle hors ligne risquerait de perdre, c'est son catalogue : le
    // palier ne le touche pas. La table neuve, elle, naît vide — et **vide veut
    // dire « aucun menu reçu »**, jamais « aucun onglet ». La médiathèque montre
    // alors son onglet implicite (le catalogue entier) et l'accueil reste piloté
    // par les rubriques : c'est la coexistence bornée du cadrage § 14, et c'est
    // ce qui permet à un appareil de monter de version avant que le portail n'ait
    // réglé quoi que ce soit.
    final schema = await verifier.schemaAt(16);
    schema.rawDatabase.execute(
      "INSERT INTO teachings (id, title, sync_stamp) VALUES ('t-1', 'Dieu a le "
      "dernier mot', 1)",
    );
    schema.rawDatabase.execute(
      "INSERT INTO teaching_types (id, label, slug, sync_stamp) "
      "VALUES (1, '{\"fr\":\"Dimanche\"}', 'dimanche', 1)",
    );

    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 17);

    expect((await db.select(db.teachings).get()).single.title,
        'Dieu a le dernier mot');
    // La rubrique survit, et c'est elle qui fait foi pour l'accueil tant
    // qu'aucune entrée de menu n'est allumée.
    expect((await db.select(db.teachingTypes).get()).single.slug, 'dimanche');
    expect(await db.select(db.menuEntries).get(), isEmpty);
    // Aucun curseur posé : la collection n'a jamais été tirée, le prochain
    // manifeste l'annoncera `from_zero`.
    expect(await db.syncDao.cursorFor('menu_entries'), isNull);
  });

  test('v18 → v19 : les cinq colonnes du média des annonces naissent',
      () async {
    // Le palier du média des annonces (#130) : cinq colonnes nullables sur
    // `announcements`, et rien d'autre côté schéma.
    final connection = await verifier.startAt(18);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 19);
  });

  test('v1 → v19 : un appareil resté en v1 rejoue tous les paliers', () async {
    // ⚠️ Le cas qui compte : `announcements` naît au palier v2 → v3 **dans sa
    // forme courante**, colonnes du média comprises. Le palier v18 → v19 ne
    // doit donc pas les ajouter une seconde fois (« duplicate column »).
    final connection = await verifier.startAt(1);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 19);
  });

  test('v2 → v19 : la table des annonces, créée en route, a son média',
      () async {
    final connection = await verifier.startAt(2);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 19);
  });

  test(
      'v18 → v19 : les annonces survivent sans média, et leur curseur part '
      'pour que le média jeté revienne', () async {
    // Un téléphone resté en v18 a pu recevoir une annonce audio ou vidéo du
    // serveur (`server-portal#477`) : il en a gardé le texte et **jeté le
    // média**, faute de colonne, et son curseur est passé dessus. Sans
    // l'effacer, l'annonce resterait muette jusqu'à sa prochaine modification
    // au portail — c'est-à-dire, presque toujours, pour toujours.
    final schema = await verifier.schemaAt(18);
    schema.rawDatabase.execute(
      "INSERT INTO announcements (id, account_id, body, published_at, "
      "is_pinned, sync_stamp) "
      "VALUES ('a-1', 1, 'Un mot du pasteur.', 1700000000, 0, 1)",
    );
    schema.rawDatabase.execute(
      "INSERT INTO sync_cursors (collection, cursor, synced_at) "
      "VALUES ('announcements', 'un-curseur-opaque', 1)",
    );
    schema.rawDatabase.execute(
      "INSERT INTO sync_cursors (collection, cursor, synced_at) "
      "VALUES ('teachings', 'un-autre-curseur', 1)",
    );

    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 19);

    // La ligne reste : remplacer, jamais purger d'abord (règle 3). Le mur ne
    // se vide pas pendant la reprise.
    final row = (await db.select(db.announcements).get()).single;
    expect(row.body, 'Un mot du pasteur.');
    expect(row.mediaKind, isNull);
    expect(row.mediaUrl, isNull);
    expect(row.mediaPosterUrl, isNull);
    expect(row.mediaDurationMs, isNull);
    expect(row.mediaWaveform, isNull);

    expect(
      await db.syncDao.cursorFor('announcements'),
      isNull,
      reason: 'sans effacement, la collection ne serait jamais re-tirée et le '
          'média jeté en v18 ne reviendrait pas',
    );
    // Le palier ne vise qu'une collection : les autres gardent leur place.
    expect(await db.syncDao.cursorFor('teachings'), 'un-autre-curseur');
  });

  test('v19 → v20 : le corps nul, la lecture et son outbox', () async {
    // Le palier de la messagerie fiable (#140) : `group_messages.body` perd son
    // `NOT NULL` (recréation de table), `group_reads` et `pending_group_reads`
    // naissent.
    final connection = await verifier.startAt(19);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 20);
  });

  test('v1 → v20 : un appareil resté en v1 rejoue tous les paliers', () async {
    // ⚠️ `group_messages` naît au palier v17 → v18 **dans sa forme courante**,
    // donc déjà nullable : le palier v19 → v20 ne doit pas la recréer (garde
    // `from >= 18`).
    final connection = await verifier.startAt(1);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 20);
  });

  test('v18 → v20 : deux paliers d\'un coup', () async {
    final connection = await verifier.startAt(18);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 20);
  });

  test(
      'v19 → v20 : le fil survit à la recréation de la table, curseur compris, '
      'et un message-média s\'y range enfin', () async {
    // Ce qu'un fidèle hors ligne risquerait de perdre, c'est sa conversation :
    // `alterTable` recrée `group_messages` et **recopie** chaque ligne. Le
    // curseur reste — une page refusée par l'ancienne contrainte n'avait pas
    // avancé le curseur, elle sera re-tirée et acceptée.
    final schema = await verifier.schemaAt(19);
    schema.rawDatabase.execute(
      "INSERT INTO group_messages (id, group_id, author_id, is_system, body, "
      "created_at, sync_stamp) VALUES ('m-1', 'g-1', 'u-1', 0, 'Amen', "
      "1700000000, 7)",
    );
    schema.rawDatabase.execute(
      "INSERT INTO pending_group_messages (client_message_id, group_id, body, "
      "created_at, failed) VALUES ('c-1', 'g-1', 'Gloire', 1700000001, 1)",
    );
    schema.rawDatabase.execute(
      "INSERT INTO sync_cursors (collection, cursor, synced_at) "
      "VALUES ('group_messages', 'un-curseur-opaque', 1)",
    );

    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 20);

    // En SQL brut : la v20 n'a pas les colonnes de M2 (voir [_onlyMessageBody]).
    final kept = await db
        .customSelect('SELECT body, author_id, sync_stamp FROM group_messages')
        .getSingle();
    expect(kept.read<String?>('body'), 'Amen');
    expect(kept.read<String?>('author_id'), 'u-1');
    expect(kept.read<int>('sync_stamp'), 7,
        reason: 'le jeton d\'écriture est recopié');
    expect(
      (await db.select(db.pendingGroupMessages).get()).single.failed,
      isTrue,
      reason: 'un écho en échec doit encore pouvoir repartir',
    );
    expect(
      await db.syncDao.cursorFor('group_messages'),
      'un-curseur-opaque',
    );

    // Et le corps nul passe — c'est tout l'objet du palier.
    await db.into(db.groupMessages).insert(
          GroupMessagesCompanion.insert(id: 'm-2', groupId: 'g-1'),
        );
    final voice = await db
        .customSelect("SELECT body FROM group_messages WHERE id = 'm-2'")
        .getSingle();
    expect(voice.read<String?>('body'), isNull);

    // Les deux tables neuves naissent vides, sans curseur.
    expect(await db.select(db.groupReads).get(), isEmpty);
    expect(await db.select(db.pendingGroupReads).get(), isEmpty);
    expect(await db.syncDao.cursorFor('group_reads'), isNull);
  });

  test('v20 → v21 : la table de mes requêtes apparaît', () async {
    // Le palier de **mes requêtes** (#148) : une création de table, et rien
    // d'autre.
    final connection = await verifier.startAt(20);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 21);
  });

  test('v1 → v21 : un appareil resté en v1 rejoue tous les paliers', () async {
    final connection = await verifier.startAt(1);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 21);
  });

  test('v20 → v21 : le fil survit, et mes requêtes naissent vides', () async {
    // Ce que le palier ne doit pas toucher : le reste du magasin, curseurs
    // compris. La table neuve naît vide et sans curseur — le prochain
    // manifeste l'annoncera `from_zero`, et le premier cycle ramènera aussi les
    // requêtes envoyées avant cette version.
    final schema = await verifier.schemaAt(20);
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
    await verifier.migrateAndValidate(db, 21);

    expect(await _onlyMessageBody(db), 'Amen');
    expect(await db.syncDao.cursorFor('group_messages'), 'un-curseur-opaque');
    expect(await db.select(db.myInteractions).get(), isEmpty);
    expect(await db.syncDao.cursorFor('my_interactions'), isNull);
  });

  test('v21 → v22 : le rangement et son outbox apparaissent', () async {
    // Le palier d'**archiver, épingler** (#146) : deux créations de table, et
    // rien d'autre.
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

  test('v21 → v22 : le fil et la lecture survivent, le rangement naît vide',
      () async {
    // Ce que le palier ne doit pas toucher : le reste du magasin, curseurs
    // compris. Les deux tables neuves naissent vides, et `group_arrangements`
    // sans curseur — le prochain manifeste l'annoncera `from_zero`, et le
    // premier cycle ramènera les rangements faits sur un autre appareil.
    final schema = await verifier.schemaAt(21);
    schema.rawDatabase.execute(
      "INSERT INTO group_messages (id, group_id, author_id, is_system, body, "
      "created_at, sync_stamp) VALUES ('m-1', 'g-1', 'u-1', 0, 'Amen', "
      "1700000000, 7)",
    );
    schema.rawDatabase.execute(
      "INSERT INTO group_reads (group_id, last_read_message_id, last_read_at, "
      "sync_stamp) VALUES ('g-1', 'm-1', 1700000000, 8)",
    );
    schema.rawDatabase.execute(
      "INSERT INTO sync_cursors (collection, cursor, synced_at) "
      "VALUES ('group_messages', 'un-curseur-opaque', 1)",
    );

    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 22);

    expect(await _onlyMessageBody(db), 'Amen');
    expect(
      (await db.select(db.groupReads).get()).single.lastReadMessageId,
      'm-1',
    );
    expect(await db.syncDao.cursorFor('group_messages'), 'un-curseur-opaque');
    expect(await db.select(db.groupArrangements).get(), isEmpty);
    expect(await db.select(db.pendingGroupArrangements).get(), isEmpty);
    expect(await db.syncDao.cursorFor('group_arrangements'), isNull);
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

/// Le corps de l'unique message du fil, lu **en SQL brut** : une migration de
/// test vers une version antérieure à M2 (#141) laisse `group_messages` sans les
/// colonnes de M2, que la lecture typée exige (`is_forwarded` non nul).
Future<String?> _onlyMessageBody(AppDatabase db) async =>
    (await db.customSelect('SELECT body FROM group_messages').getSingle())
        .read<String?>('body');
