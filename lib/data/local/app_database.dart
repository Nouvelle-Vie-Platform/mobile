import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

// Le type que porte la colonne `sections` de `legal_documents`. Il est nommé
// **sans préfixe** par le code généré (`app_database.g.dart`, une `part` de ce
// fichier) : sans cet import, la classe de données ne compile pas.
import '../../models/legal_document_view.dart';
// Idem : la classe de données de `teachings.download` (`TeachingDownload`) est
// nommée **sans préfixe** par le code généré ; sans cet import, elle ne compile
// pas.
import '../../models/teaching_download.dart';
import 'announcement_dao.dart';
import 'auth_channels_dao.dart';
// Utilisé par le code généré (`app_database.g.dart`), qui est une `part` de ce
// fichier : le convertisseur de carte de traduction y est instancié.
import 'converters/i18n_map_converter.dart';
// Idem : le convertisseur du contrat de téléchargement (`teachings.download`,
// ADR-0038) est instancié par le code généré.
import 'converters/teaching_download_converter.dart';
import 'downloads_dao.dart';
// Idem : le convertisseur des sections d'un document légal est instancié par le
// code généré.
import 'converters/legal_sections_converter.dart';
import 'device_settings_dao.dart';
import 'gathering_dao.dart';
import 'group_dao.dart';
import 'legal_dao.dart';
import 'mediatheque_dao.dart';
import 'menu_dao.dart';
import 'playback_dao.dart';
import 'settings_dao.dart';
import 'sync_dao.dart';
import 'season_dao.dart';
import 'tables/announcement_tables.dart';
import 'tables/auth_tables.dart';
import 'tables/download_tables.dart';
import 'tables/gathering_tables.dart';
import 'tables/group_tables.dart';
import 'tables/legal_tables.dart';
import 'tables/mediatheque_tables.dart';
import 'tables/playback_tables.dart';
import 'tables/settings_tables.dart';
import 'tables/sync_tables.dart';
import 'tables/decor_tables.dart';
import 'tables/device_tables.dart';
import 'tables/menu_tables.dart';
import 'tables/season_tables.dart';
import 'tables/vocabulary_tables.dart';
import 'vocabulary_dao.dart';

part 'app_database.g.dart';

/// Nom du fichier de base sur l'appareil (`<documents>/maison_du_miracle.sqlite`
/// sur les plateformes natives, une base OPFS/IndexedDB sur le web).
const String kLocalDatabaseName = 'maison_du_miracle';

/// **Le magasin local — c'est lui qui peint les écrans** (ADR-0026, décision 2).
///
/// Tout écran adossé à une collection répliquée lit ce magasin, jamais une
/// réponse HTTP. La synchronisation y écrit ; elle ne rend rien. L'alternative —
/// le réseau peint, le cache sert de repli — donne deux chemins de rendu pour la
/// même donnée, donc deux jeux de bugs, et rend le hors-ligne conditionnel alors
/// qu'il est le régime normal de cette application.
///
/// L'exigence qui a imposé une base embarquée plutôt qu'un cache fichier ou un
/// stockage clé-valeur est la **transaction** : le curseur d'une page doit
/// avancer dans la même transaction que les lignes qu'il couvre. Voir
/// [SyncDao.applyPage].
///
/// Les migrations sont **versionnées dès la v1** : une migration ratée sur un
/// téléphone installé n'est pas un test rouge, c'est une application qui ne
/// démarre plus chez un fidèle, sans correction possible à distance.
@DriftDatabase(
  tables: [
    SyncCursors,
    SyncState,
    ResyncTokens,
    Branches,
    TeachingTypes,
    Contributors,
    Teachings,
    TeachingGuests,
    GatheringTypes,
    Gatherings,
    StatusBackgrounds,
    OfficialAccounts,
    OfficialAccountMemberships,
    Announcements,
    PlaybackProgress,
    LocalPlaybackPositions,
    LegalDocuments,
    Seasons,
    PresentationVocabulary,
    MenuEntries,
    Decor,
    AuthChannels,
    DeviceSettings,
    Profiles,
    Groups,
    GroupMembers,
    GroupJoinRequests,
    GroupMessages,
    PendingGroupMessages,
    AppSettings,
    Downloads,
    DownloadTitles,
    DownloadNotifications,
  ],
  daos: [
    SyncDao,
    MediathequeDao,
    GatheringDao,
    AnnouncementDao,
    PlaybackDao,
    LegalDao,
    SeasonDao,
    VocabularyDao,
    MenuDao,
    AuthChannelsDao,
    DeviceSettingsDao,
    GroupDao,
    SettingsDao,
    DownloadsDao,
    DownloadNotificationsDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Constructeur explicite — c'est celui qu'utilisent les tests, avec une base
  /// **en mémoire** : tout le magasin se vérifie sur la VM Dart, sans appareil.
  AppDatabase(super.e);

  /// Base de l'application, à l'emplacement standard de la plateforme.
  AppDatabase.defaults() : super(driftDatabase(name: kLocalDatabaseName));

  /// **v5** — `legal_documents`, issue #55 : la collection répliquée des
  /// documents légaux (CGU, confidentialité, à propos), **référentiel**.
  ///
  /// **v6** — `status_backgrounds.label` en carte de traduction. Correction
  /// d'un désaccord avec le contrat serveur qui faisait lever la
  /// désérialisation sur chaque ligne, et **coupait le cycle de
  /// synchronisation** avant les six collections suivantes.
  ///
  /// **v7** — `app_settings`, la table des réglages **locaux seuls** (qualité
  /// d'écoute, de direct, de téléchargement). Aucune collection du protocole ne
  /// la touche.
  ///
  /// **v8** — le socle du téléchargement offline (#190, ADR-0038/0039) : la
  /// table **locale seule** `downloads` (comme `local_playback_positions`,
  /// jamais synchronisée), et une colonne `download` **ajoutée** à `teachings`
  /// (le contrat `{version, duration, renditions}` que la sync ramène). Deux
  /// changements **additifs** : rien du catalogue déjà téléchargé ne bouge.
  ///
  /// **v9** — le cycle de vie serveur ↔ copie locale (#194, ADR-0039/0025).
  /// **Deux tables locales seules, purement additives** : `download_titles` (le
  /// titre dénormalisé au téléchargement, pour **nommer** un enseignement retiré
  /// dont la source a disparu du magasin) et `download_notifications` (les avis
  /// de purge affichés dans la page Téléchargements). Des **tables** et non une
  /// colonne sur `downloads` : `createTable` emploie la forme courante, donc une
  /// colonne apparaîtrait dès le palier v8 et se heurterait au schéma v8 gelé
  /// (voir `download_titles`). Rien du catalogue déjà téléchargé ne bouge.
  ///
  /// **v13** — `teaching_guests` (#77), le pivot des **invités** d'un contenu de
  /// médiathèque : une collection répliquée de plus, une création de table, et
  /// rien d'autre. Aucune nouvelle famille de contenu, aucune colonne ajoutée à
  /// `teachings`.
  ///
  /// **v14** — `presentation_vocabulary` (#81), les mots réglés au portail : une
  /// collection répliquée de plus, une création de table, et rien d'autre.
  /// Aucune valeur de `.arb` ne change, et la table naît **vide** — ce qui veut
  /// dire « le mot du dépôt partout », exactement ce que l'application affiche
  /// déjà.
  ///
  /// **v15** — `auth_channels` (#83), par quelles portes l'application propose
  /// d'entrer : une collection répliquée de plus, une création de table, et rien
  /// d'autre. La table naît **vide**, et vide veut dire « je n'ai pas encore reçu
  /// les réglages » — le repli est alors l'**e-mail seul**, c'est-à-dire ce que
  /// l'écran d'identifiant choisissait déjà par défaut.
  ///
  /// **v16** — `device_settings` (#91), le **réglage d'exploitation du parc** et
  /// par lui le seuil du bandeau de mise à jour : une collection répliquée de
  /// plus, une création de table, et rien d'autre. La table naît **vide**, et
  /// vide veut dire « pas de seuil », donc **aucun bandeau** — exactement ce que
  /// l'application affiche déjà, puisque son seuil rendait `null` en dur.
  ///
  /// **v17** — `menu_entries` (#82), les **entrées de menu** : une collection
  /// répliquée de plus, une création de table, et rien d'autre. La table naît
  /// **vide**, et vide veut dire « aucun menu reçu » — la médiathèque retombe
  /// alors sur son unique onglet implicite (le catalogue entier) et l'accueil
  /// reste piloté par les rubriques, exactement comme avant la migration. C'est
  /// la **coexistence bornée** décrite par le cadrage § 14, et c'est elle qui
  /// permet à un appareil de monter de version avant que le portail n'ait réglé
  /// quoi que ce soit.
  ///
  /// **v18** — la rubrique **« Échanges »** (#96) : **six créations de table, et
  /// rien d'autre**. Cinq collections répliquées — `profiles`, `groups`,
  /// `group_members`, `group_join_requests`, `group_messages` — et une table
  /// **locale seule**, `pending_group_messages`, qui porte l'écho optimiste d'un
  /// envoi (même patron que `local_playback_positions` : aucun registre, aucun
  /// curseur, aucun cycle ne la touche).
  ///
  /// Aucune colonne existante ne bouge et aucune ligne n'est réécrite : la
  /// rubrique était **intégralement fictive** avant ce palier (`SampleData`), il
  /// n'y a donc rien à reprendre. Les six tables naissent **vides**, et vide veut
  /// dire ici « je n'ai pas encore reçu mes conversations » — ce que les écrans
  /// rendent déjà comme une absence, jamais comme une erreur.
  @override
  int get schemaVersion => 18;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _ensureGlobalStateRow();
        },
        onUpgrade: (m, from, to) async {
          // Les paliers se rangent ici, **un par version**, et chacun se teste
          // (`test/data/local/migration_test.dart`). Ne jamais recréer la base
          // pour se simplifier la vie : le magasin est la seule copie du
          // catalogue d'un fidèle hors ligne.

          // v1 → v2 — les rassemblements (issue #34). **Deux créations de
          // table, et rien d'autre** : aucune colonne existante ne bouge, aucune
          // donnée n'est recopiée, donc rien du catalogue déjà téléchargé n'est
          // en jeu. Les deux tables naissent vides et le premier cycle de
          // synchronisation les remplit — leurs curseurs n'existent pas encore,
          // le manifeste les annoncera `from_zero`.
          if (from < 2) {
            await m.createTable(gatheringTypes);
            await m.createTable(gatherings);
          }

          // v2 → v3 — les annonces (issue #35). **Quatre créations de table, et
          // rien d'autre** : le mur de statuts était jusqu'ici peint par
          // `SampleData`, il n'y a donc aucune donnée locale à reprendre, et
          // aucune colonne existante ne bouge. Les quatre tables naissent vides
          // et le premier cycle les remplit — leurs curseurs n'existent pas
          // encore, le manifeste les annoncera `from_zero`.
          if (from < 3) {
            await m.createTable(statusBackgrounds);
            await m.createTable(officialAccounts);
            await m.createTable(officialAccountMemberships);
            await m.createTable(announcements);
          }

          // v3 → v4 — la reprise de lecture (issue #43). **Deux créations de
          // table, et rien d'autre** : aucune position n'existait auparavant
          // (zéro occurrence de `playback_progress` dans l'application), il n'y
          // a donc rien à reprendre et aucune colonne existante ne bouge.
          //
          // `playback_progress` naît vide, son curseur n'existe pas encore et
          // le prochain manifeste l'annoncera `from_zero` : le premier cycle
          // ramène **toute** la progression du fidèle, y compris celle
          // accumulée sur un autre appareil avant cette version.
          //
          // `local_playback_positions` naît vide et le reste jusqu'à la
          // première écoute — elle n'est alimentée que par le lecteur.
          if (from < 4) {
            await m.createTable(playbackProgress);
            await m.createTable(localPlaybackPositions);
          }

          // v4 → v5 — les documents légaux (issue #55). **Une création de
          // table, et rien d'autre** : aucun document n'existait auparavant
          // (les trois destinations du menu latéral rendaient une absence), il
          // n'y a donc rien à reprendre et aucune colonne existante ne bouge.
          //
          // La table naît vide, son curseur n'existe pas encore et le prochain
          // manifeste l'annoncera `from_zero` : le premier cycle ramène les
          // trois genres d'un coup — la collection n'a aucun filtre de
          // périmètre.
          if (from < 5) {
            await m.createTable(legalDocuments);
          }

          // v5 → v6 — `status_backgrounds.label` passe en **carte de
          // traduction**, pour rejoindre ce que le serveur déclare depuis
          // toujours (`jsonb`, ADR-0023). La colonne reste du texte côté SQLite,
          // seul son contenu change de forme : rien à altérer, tout à re-tirer.
          //
          // **On efface la table ET son curseur**, dans cet ordre de pensée : un
          // libellé nu (« Bleu de marque ») ne se décode pas en carte, et le
          // convertisseur, tolérant par choix, rendrait une carte **vide** sans
          // se plaindre — le sélecteur de fonds afficherait des pastilles sans
          // nom, indéfiniment. Effacer le curseur est ce qui fait annoncer la
          // collection `from_zero` au manifeste suivant ; l'oublier laisserait
          // une table vide qu'aucun cycle ne viendrait remplir.
          //
          // Le coût est nul : ce référentiel n'a jamais pu s'écrire. `_text`
          // levait sur chaque ligne servie, donc aucune page n'a jamais été
          // appliquée et aucun curseur n'a jamais été posé. On efface par
          // rigueur, pas par nécessité.
          if (from < 6) {
            await delete(statusBackgrounds).go();
            await (delete(syncCursors)
                  ..where((c) => c.collection.equals('status_backgrounds')))
                .go();
          }

          // v6 → v7 — les réglages média. **Une création de table, et rien
          // d'autre** : aucun réglage n'existait auparavant (le dépôt n'avait
          // aucun mécanisme de persistance de préférence — le mode sombre
          // lui-même se perd à chaque lancement), donc rien à reprendre.
          //
          // La table naît **vide et le reste** jusqu'au premier choix : une
          // ligne écrite d'office serait indiscernable d'une décision du
          // fidèle, et changer le défaut dans une version suivante ne
          // toucherait plus personne. L'absence de ligne *est* le défaut.
          if (from < 7) {
            await m.createTable(appSettings);
          }

          // v7 → v8 — le socle du téléchargement offline (#190). **Deux
          // changements, tous deux additifs** :
          //
          // 1. `downloads` naît, **locale seule** (même patron que
          //    `local_playback_positions`) : elle n'est dans aucun registre de
          //    synchronisation, ne porte pas de `sync_stamp`, et se remplit au
          //    premier téléchargement — jamais par un cycle de synchro. Aucun
          //    curseur ne la concerne.
          // 2. `teachings.download` s'**ajoute** : une colonne texte nullable
          //    portant le contrat `{version, duration, renditions}` (ADR-0038).
          //    `addColumn` sur une colonne nullable ne réécrit aucune ligne et
          //    n'a pas de valeur par défaut à poser — les enseignements déjà en
          //    magasin la portent à `NULL` (« pas téléchargeable »), jusqu'à ce
          //    que le prochain cycle ramène leur `download` s'ils en ont un.
          //
          // Rien du catalogue déjà téléchargé n'est en jeu : aucune donnée n'est
          // recopiée, aucune colonne existante ne change de forme.
          //
          // **La garde `to >= 8` n'est pas décorative** — c'est le premier
          // palier qui **ajoute une colonne** à une table existante, et non une
          // table entière. Le vérificateur de schéma ignore une table
          // surnuméraire mais **signale une colonne surnuméraire** : sans la
          // garde, `addColumn` s'exécuterait dès qu'un test migre vers une
          // version intermédiaire (v1→v7 appelle `onUpgrade(1, 7)`), et
          // `teachings.download` apparaîtrait dans un schéma v7 qui ne la
          // connaît pas. Les paliers précédents ne créent que des tables, d'où
          // leur simple `if (from < n)`.
          if (from < 8 && to >= 8) {
            await m.createTable(downloads);
            await m.addColumn(teachings, teachings.download);
          }

          // v8 → v9 — le cycle de vie de la copie téléchargée (#194). **Deux
          // créations de table, et rien d'autre** :
          //
          // 1. `download_titles` : le titre dénormalisé au téléchargement, pour
          //    **nommer** une copie purgée après un retrait (l'enseignement a
          //    alors quitté le magasin, le join ne rend plus rien).
          // 2. `download_notifications` : les avis de purge affichés dans la
          //    page Téléchargements.
          //
          // **Des tables, pas une colonne sur `downloads`** : `createTable`
          // emploie la forme courante de la table, donc une colonne ajoutée à
          // `downloads` apparaîtrait dès le palier v8 (v1→v8 crée la table à
          // jour) — colonne surnuméraire refusée contre le schéma v8 gelé, et
          // `addColumn` v9 doublonnant sur un appareil venu d'avant v8. Une
          // table neuve est purement additive : le vérificateur l'ignore aux
          // versions antérieures, d'où le simple `if (from < 9)`, comme les
          // paliers qui ne créaient que des tables (v2 à v5, v7).
          if (from < 9) {
            await m.createTable(downloadTitles);
            await m.createTable(downloadNotifications);
          }

          // v9 → v10 — le visuel **carré** des enseignements (issue #209, côté
          // serveur). **Un ajout de colonne, et rien d'autre** : le serveur sert
          // désormais `imageSquareUrl` dans le flux delta (même
          // `TeachingTransformer` que le paysage et le portrait), et le magasin
          // doit pouvoir le stocker brut (règle 5 — « on stocke ce que le serveur
          // envoie »).
          //
          // `addColumn` sur une colonne nullable ne réécrit aucune ligne et n'a
          // pas de valeur par défaut à poser : les enseignements déjà en magasin
          // la portent à `NULL` (« pas de carré »), jusqu'à ce que le prochain
          // cycle ramène leur `imageSquareUrl` s'ils en ont un. Rien du catalogue
          // déjà téléchargé n'est en jeu.
          //
          // **La garde `to >= 10` n'est pas décorative** — même raison qu'au
          // palier v7→v8 : le vérificateur de schéma ignore une table
          // surnuméraire mais **signale une colonne surnuméraire**. Sans la
          // garde, `addColumn` s'exécuterait dès qu'un test migre vers une
          // version intermédiaire (v1→v9 appelle `onUpgrade(1, 9)`), et
          // `teachings.image_square_url` apparaîtrait dans un schéma v9 qui ne la
          // connaît pas.
          if (from < 10 && to >= 10) {
            await m.addColumn(teachings, teachings.imageSquareUrl);
          }

          // v10 → v11 — les **saisons**, dont le fond vertical habille les deux
          // lecteurs. **Une création de table, et rien d'autre** : aucune
          // colonne existante ne bouge, aucune donnée n'est recopiée. La table
          // naît vide et le premier cycle la remplit — son curseur n'existe pas
          // encore, le manifeste l'annoncera `from_zero`.
          //
          // Pas de garde `to >= 11`, contrairement aux paliers qui ajoutent une
          // colonne : le vérificateur de schéma **ignore une table
          // surnuméraire** et ne signale qu'une colonne surnuméraire. Même
          // raison qu'aux paliers v2 à v5, v7 et v9.
          if (from < 11) {
            await m.createTable(seasons);
          }

          // v11 → v12 — le **décor par défaut**, l'étage de la cascade du fond
          // qui sert quand aucune saison ne couvre le jour. Une création de
          // table, et rien d'autre ; même raison qu'au palier précédent pour
          // l'absence de garde `to >= 12`.
          if (from < 12) {
            await m.createTable(decor);
          }

          // v12 → v13 — les **invités** d'un contenu de médiathèque (#77). Une
          // création de table, et rien d'autre : le pivot `teaching_guests`
          // naît vide, son curseur n'existe pas encore, et le prochain
          // manifeste l'annoncera `from_zero` — le premier cycle ramène donc
          // **tous** les crédits du catalogue, y compris ceux posés avant cette
          // version.
          //
          // Aucune colonne n'est ajoutée à `teachings`, et aucune ligne n'est
          // réécrite : un enseignement sans invité est l'état par défaut, et il
          // le reste. Pas de garde `to >= 13` pour la raison des paliers qui ne
          // créent que des tables (v2 à v5, v7, v9, v11, v12) : le
          // vérificateur de schéma **ignore une table surnuméraire** et ne
          // signale qu'une colonne surnuméraire.
          if (from < 13) {
            await m.createTable(teachingGuests);
          }

          // v13 → v14 — le **vocabulaire réglé au portail** (#81). Une création
          // de table, et rien d'autre : aucune colonne existante ne bouge,
          // aucune ligne n'est réécrite, et **aucune valeur de `.arb` ne
          // change**.
          //
          // La table naît **vide**, et c'est un état plein de sens : vide veut
          // dire « le mot du dépôt partout », ce que l'application affiche déjà.
          // Son curseur n'existe pas encore, le prochain manifeste l'annoncera
          // `from_zero`, et le premier cycle ramènera **tous** les mots réglés,
          // y compris ceux posés avant cette version. D'ici là — et si le
          // serveur est en retard d'une version, auquel cas la collection prend
          // un `404` et se saute — rien ne se dégrade : les `.arb` compilés
          // font foi.
          //
          // Pas de garde `to >= 14` pour la raison des paliers qui ne créent que
          // des tables (v2 à v5, v7, v9, v11 à v13) : le vérificateur de schéma
          // **ignore une table surnuméraire** et ne signale qu'une colonne
          // surnuméraire.
          if (from < 14) {
            await m.createTable(presentationVocabulary);
          }

          // v14 → v15 — les **canaux de connexion** (#83). Une création de
          // table, et rien d'autre : aucune colonne existante ne bouge, aucune
          // ligne n'est réécrite, et l'écran d'identifiant ne change pas de
          // comportement tant que le premier cycle n'a rien ramené.
          //
          // La table naît **vide**, et c'est un état plein de sens : vide veut
          // dire « je n'ai pas encore reçu les réglages », jamais « aucun
          // canal ». Le repli est alors l'**e-mail seul** — le canal qui envoie
          // réellement un code, et celui que l'écran choisissait déjà par
          // défaut. Son curseur n'existe pas encore, le prochain manifeste
          // l'annoncera `from_zero`, et le premier cycle ramènera la ligne du
          // portail. D'ici là — et si le serveur est en retard d'une version,
          // auquel cas la collection prend un `404` et se saute — rien ne se
          // dégrade.
          //
          // Pas de garde `to >= 15` pour la raison des paliers qui ne créent que
          // des tables (v2 à v5, v7, v9, v11 à v14) : le vérificateur de schéma
          // **ignore une table surnuméraire** et ne signale qu'une colonne
          // surnuméraire.
          if (from < 15) {
            await m.createTable(authChannels);
          }

          // v15 → v16 — le **réglage d'exploitation du parc** (#91). Une
          // création de table, et rien d'autre : aucune colonne existante ne
          // bouge, aucune ligne n'est réécrite, et le bandeau de mise à jour ne
          // change pas de comportement tant que le premier cycle n'a rien
          // ramené.
          //
          // La table naît **vide**, et c'est un état plein de sens : vide veut
          // dire « je n'ai pas encore reçu les réglages », ce que le DAO lit
          // comme « pas de seuil » — donc **aucun bandeau**, jamais l'inverse.
          // Son curseur n'existe pas encore, le prochain manifeste l'annoncera
          // `from_zero`, et le premier cycle ramènera la ligne du portail.
          // D'ici là — et si le serveur est en retard d'une version, auquel cas
          // la collection prend un `404` et se saute — rien ne se dégrade : le
          // bandeau reste tu, exactement comme avant la migration.
          //
          // Pas de garde `to >= 16` pour la raison des paliers qui ne créent
          // que des tables (v2 à v5, v7, v9, v11 à v15) : le vérificateur de
          // schéma **ignore une table surnuméraire** et ne signale qu'une
          // colonne surnuméraire.
          if (from < 16) {
            await m.createTable(deviceSettings);
          }

          // v16 → v17 — les **entrées de menu** (#82). Une création de table, et
          // rien d'autre : aucune colonne existante ne bouge, aucune ligne n'est
          // réécrite, et ni la médiathèque ni l'accueil ne changent de
          // comportement tant que le premier cycle n'a rien ramené.
          //
          // La table naît **vide**, et c'est un état plein de sens : vide veut
          // dire « aucun menu reçu », jamais « aucun onglet ». La médiathèque
          // montre alors son onglet implicite — le catalogue entier, sans
          // filtre —, et l'accueil reste piloté par `teaching_types.visible_on_home`.
          // Son curseur n'existe pas encore, le prochain manifeste l'annoncera
          // `from_zero`, et le premier cycle ramènera le menu du portail. D'ici
          // là — et si le serveur est en retard d'une version, auquel cas la
          // collection prend un `404` et se saute — rien ne se dégrade.
          //
          // Pas de garde `to >= 17` pour la raison des paliers qui ne créent
          // que des tables (v2 à v5, v7, v9, v11 à v16) : le vérificateur de
          // schéma **ignore une table surnuméraire** et ne signale qu'une
          // colonne surnuméraire.
          if (from < 17) {
            await m.createTable(menuEntries);
          }

          // v17 → v18 — la rubrique **« Échanges »** (#96). **Six créations de
          // table, et rien d'autre** : cinq collections répliquées et une table
          // locale seule.
          //
          // Rien du catalogue d'un fidèle n'est en jeu, et rien de ses
          // conversations non plus : la rubrique était **intégralement fictive**
          // jusqu'ici (`SampleData` — quatre groupes, sept conversations et le
          // même fil de cinq messages pour toutes), il n'y a donc **aucune
          // donnée locale à reprendre**. Aucune colonne existante ne bouge.
          //
          // Les cinq collections naissent vides, leurs curseurs n'existent pas
          // encore, et le prochain manifeste les annoncera `from_zero` : le
          // premier cycle ramène les groupes, le roster, les profils et le fil
          // d'un coup. D'ici là — et sur un serveur en retard d'une version,
          // auquel cas les collections prennent un `404` et se sautent — les
          // écrans montrent une **absence**, pas une erreur : un magasin vide ne
          // se plaint pas, et c'est ce que `GroupDao` rend.
          //
          // `pending_group_messages` naît vide et le reste jusqu'au premier
          // envoi — elle n'est alimentée que par le composeur de messages, et
          // aucun cycle de synchronisation ne l'écrit ni ne la lit.
          //
          // Pas de garde `to >= 18` pour la raison des paliers qui ne créent que
          // des tables (v2 à v5, v7, v9, v11 à v16) : le vérificateur de schéma
          // **ignore une table surnuméraire** et ne signale qu'une colonne
          // surnuméraire.
          if (from < 18) {
            await m.createTable(profiles);
            await m.createTable(groups);
            await m.createTable(groupMembers);
            await m.createTable(groupJoinRequests);
            await m.createTable(groupMessages);
            await m.createTable(pendingGroupMessages);
          }
        },
        beforeOpen: (details) async {
          // La ligne d'état global doit exister avant la première allocation de
          // jeton d'écriture. La recréer ici couvre une base ouverte après une
          // migration qui l'aurait manquée — un `INSERT OR IGNORE`, donc sans
          // effet sur une base saine.
          await _ensureGlobalStateRow();
        },
      );

  /// **Vide le magasin entier**, puis le remet dans l'état d'une base neuve.
  ///
  /// Une seule chose l'appelle, et une seule doit l'appeler : la **suppression
  /// de compte**. Ce n'est pas un utilitaire de confort — c'est la contrepartie
  /// locale d'un effacement serveur.
  ///
  /// Trois choses qui se ratent en silence :
  ///
  /// 1. **Les curseurs partent avec les lignes.** Garder un curseur sur une
  ///    table vidée est le trou permanent que l'invariant central du magasin
  ///    interdit : le manifeste répondrait « rien de neuf » et la collection ne
  ///    se remplirait plus jamais. Effacer les deux ensemble fait annoncer
  ///    `from_zero` au compte suivant.
  /// 2. **La progression d'écoute est une collection répliquée**, et le
  ///    garde-fou de source interdit de la nommer dans un `delete`. On boucle
  ///    donc sur `allTables`, ce qui est aussi la manière dont le moteur écrit
  ///    lui-même (`delete(collection.table)`) — la table n'est jamais nommée.
  /// 3. **On ne supprime pas le fichier.** Sur le web il n'y en a pas — la base
  ///    vit dans le navigateur (`sqlite3.wasm`) —, et fermer puis rouvrir
  ///    l'instance laisserait les DAO déjà distribués pointer sur une base
  ///    close. Vider en une transaction donne le même résultat sur les trois
  ///    cibles, sans toucher au cycle de vie de l'objet.
  ///
  /// La ligne d'état global est reposée : elle doit exister avant la première
  /// allocation de jeton d'écriture, donc avant la première page appliquée au
  /// compte suivant.
  Future<void> eraseEverything() async {
    await transaction(() async {
      for (final table in allTables) {
        await delete(table).go();
      }
      await _ensureGlobalStateRow();
    });
  }

  Future<void> _ensureGlobalStateRow() async {
    await into(syncState).insert(
      const SyncStateCompanion(id: Value(kSyncStateRowId)),
      mode: InsertMode.insertOrIgnore,
    );
  }
}
