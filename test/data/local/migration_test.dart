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
