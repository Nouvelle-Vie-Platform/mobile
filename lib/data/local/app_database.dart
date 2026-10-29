import 'dart:convert';

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
import 'bible_dao.dart';
import 'chat_organization_dao.dart';
// Utilisé par le code généré (`app_database.g.dart`), qui est une `part` de ce
// fichier : le convertisseur de carte de traduction y est instancié.
import 'converters/i18n_map_converter.dart';
// Idem : le convertisseur du contrat de téléchargement (`teachings.download`,
// ADR-0038) est instancié par le code généré.
import 'converters/teaching_download_converter.dart';
// Idem : le convertisseur de la forme d'onde d'un statut audio
// (`announcements.media_waveform`, #130) est instancié par le code généré.
import 'converters/waveform_converter.dart';
import 'downloads_dao.dart';
// Idem : le convertisseur des sections d'un document légal est instancié par le
// code généré.
import 'converters/legal_sections_converter.dart';
// Idem : les identifiants choisis et classés d'une section de médiathèque
// (`media_page_sections`, #167).
import 'converters/string_list_converter.dart';
import 'device_settings_dao.dart';
import 'gathering_dao.dart';
import 'group_dao.dart';
import 'interaction_dao.dart';
import 'legal_dao.dart';
import 'media_pages_dao.dart';
import 'mediatheque_dao.dart';
import 'menu_dao.dart';
import 'notes_dao.dart';
import 'playback_dao.dart';
import 'receipts_dao.dart';
import 'settings_dao.dart';
import 'sync_dao.dart';
import 'season_dao.dart';
import 'tables/announcement_tables.dart';
import 'tables/auth_tables.dart';
import 'tables/bible_tables.dart';
import 'tables/download_tables.dart';
import 'tables/gathering_tables.dart';
import 'tables/group_tables.dart';
import 'tables/interaction_tables.dart';
import 'tables/legal_tables.dart';
import 'tables/media_page_tables.dart';
import 'tables/mediatheque_tables.dart';
import 'tables/playback_tables.dart';
import 'tables/receipt_tables.dart';
import 'tables/settings_tables.dart';
import 'tables/sync_tables.dart';
import 'tables/decor_tables.dart';
import 'tables/device_tables.dart';
import 'tables/menu_tables.dart';
import 'tables/note_tables.dart';
import 'tables/season_tables.dart';
import 'tables/vocabulary_tables.dart';
import 'vocabulary_dao.dart';

part 'app_database.g.dart';

/// Nom du fichier de base sur l'appareil (`<documents>/maison_du_miracle.sqlite`
/// sur les plateformes natives, une base OPFS/IndexedDB sur le web).
const String kLocalDatabaseName = 'maison_du_miracle';

/// **La version du worker, dans son adresse** — et c'est ce qui permet à une
/// version neuve de prendre la place de l'ancienne.
///
/// Un *shared worker* est identifié par **l'URL de son script**, et il
/// **survit au rechargement** : tant qu'un onglet du site lui reste connecté,
/// le navigateur réutilise l'instance **déjà démarrée**, avec le script qu'elle
/// a chargé — même si le serveur en sert un autre depuis. Une pose peut donc
/// ne produire aucun effet jusqu'à ce que le fidèle ferme tous ses onglets, ou
/// quitte son navigateur.
///
/// Mesuré le 29/10/2026, deux fois : le correctif du worker était en ligne,
/// vérifié octet par octet, et la page continuait de lever
/// `LinkError … xFileControl` — le navigateur rejouait l'ancien worker. Un
/// profil neuf, lui, n'a jamais montré l'erreur.
///
/// Le paramètre change donc l'URL à chaque montée de `drift`, ce qui force le
/// navigateur à **démarrer un worker neuf** au lieu d'en rejoindre un périmé.
/// Il doit suivre la version déclarée dans `web/WEB_ASSETS.md` : un test le
/// vérifie.
const String kDriftWorkerVersion = '2.34.4';

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
    // La médiathèque en pages (#167).
    MediaPages,
    MediaPageChips,
    MediaPageSections,
    Decor,
    AuthChannels,
    DeviceSettings,
    Profiles,
    Groups,
    GroupMembers,
    GroupJoinRequests,
    GroupMessages,
    PendingGroupMessages,
    // T1 des médias locaux (#223) : le magasin durable d'un média reçu.
    LocalMessageMedia,
    GroupReads,
    PendingGroupReads,
    MyInteractions,
    // Les notes (#190) : deux collections privées, le brouillon local et
    // l'outbox des pièces jointes (N4).
    SpiritualNotes,
    NoteCategories,
    LocalNotes,
    PendingNoteMedia,
    // M8 (#146) : mon rangement des discussions, et son outbox.
    GroupArrangements,
    PendingGroupArrangements,
    // Accusés de mes messages, et ce que ce téléphone a confirmé recevoir
    // (#142, M3).
    MessageReceipts,
    DeliveryAcks,
    GroupMutes,
    // M2 (#141) : réactions et « supprimé pour moi ».
    GroupMessageReactions,
    GroupMessageHides,
    AppSettings,
    Downloads,
    DownloadTitles,
    DownloadNotifications,
    // Le module Bible (#199) : toutes ses tables, en une étape (v29).
    BibleMarks,
    BibleReadingStates,
    BiblePlanEnrollments,
    BibleQuizResults,
    BibleVerseOfDays,
    BibleSundayPassages,
    BiblePlans,
    BibleChallenges,
    BibleQuizzes,
    BibleVersions,
    LocalBibleMarks,
    LocalBibleReadingState,
    LocalBiblePlanEnrollments,
    LocalBibleQuizResults,
    BibleInstalledVersions,
  ],
  // L'index plein texte FTS5 de la Bible (#199), qu'une table Dart ne sait
  // pas déclarer.
  include: {'tables/bible_fts.drift'},
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
    MediaPagesDao,
    AuthChannelsDao,
    DeviceSettingsDao,
    GroupDao,
    InteractionDao,
    NotesDao,
    // M8 (#146) : archiver, épingler, rechercher.
    ChatOrganizationDao,
    ReceiptsDao,
    SettingsDao,
    DownloadsDao,
    DownloadNotificationsDao,
    BibleDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Constructeur explicite — c'est celui qu'utilisent les tests, avec une base
  /// **en mémoire** : tout le magasin se vérifie sur la VM Dart, sans appareil.
  AppDatabase(super.e);

  /// Base de l'application, à l'emplacement standard de la plateforme.
  ///
  /// ⚠️ **`web:` n'est pas facultatif, et l'omettre ne se voit nulle part
  /// ailleurs qu'en production.** `drift_flutter` lève un `ArgumentError`
  /// **synchrone** quand ce paramètre manque et qu'on est compilé pour le web
  /// (`drift_flutter/lib/src/web.dart`) : « When compiling to the web, the
  /// `web` parameter needs to be set. » Comme `appDatabaseProvider` construit
  /// cette base dans un `Provider` **synchrone**, l'exception devient l'état du
  /// provider, et **chaque `ref.read` la relance** — tous les écrans adossés au
  /// magasin tombent d'un coup, en affichant « vérifiez votre connexion
  /// internet » puisqu'ils ne savent pas distinguer une base illisible d'un
  /// réseau absent.
  ///
  /// Constaté en production le 29/10/2026, et la mesure du banc sur appareil le
  /// disait déjà sans qu'on l'entende : **`sqlite3.wasm` n'était jamais
  /// demandé**. Il ne pouvait pas l'être — la base levait avant d'aller
  /// chercher quoi que ce soit.
  ///
  /// Les deux adresses sont **relatives**, donc résolues contre le `<base
  /// href>` de la page : elles suivent le bundle, qu'il soit servi à la racine
  /// d'un sous-domaine ou sous un préfixe.
  AppDatabase.defaults()
      : super(driftDatabase(
          name: kLocalDatabaseName,
          web: DriftWebOptions(
            sqlite3Wasm: Uri.parse('sqlite3.wasm'),
            driftWorker: Uri.parse('drift_worker.js?v=$kDriftWorkerVersion'),
          ),
        ));

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
  ///
  /// **v19** — le **média des annonces** (#130) : cinq colonnes nullables sur
  /// `announcements` (`media_kind`, `media_url`, `media_poster_url`,
  /// `media_duration_ms`, `media_waveform`), et l'oubli de son curseur — un
  /// téléphone en v18 a pu recevoir une annonce audio ou vidéo et en jeter le
  /// média faute de colonne. Voir le palier.
  ///
  /// **v20** — la messagerie fiable (#140, tranche M1b) : `group_messages.body`
  /// devient **nullable** (piège 1 du plan : un message-média arrive avec
  /// `body: null`, et la contrainte coupait le cycle), et deux tables naissent —
  /// la collection répliquée `group_reads` (ma position de lecture) et la table
  /// locale seule `pending_group_reads` (l'outbox de cette lecture).
  ///
  /// **v21** — **mes requêtes** (#148) : `my_interactions`, une collection
  /// répliquée **privée** de plus, une création de table, et rien d'autre. Elle
  /// naît **vide**, et vide veut dire « aucune requête reçue » — l'onglet
  /// Requêtes montre son état vide, ce que l'écran affichait déjà (il ne lisait
  /// rien).
  ///
  /// **v22** (#146) — **archiver, épingler** : `group_arrangements`, une
  /// collection répliquée **privée** de plus, et `pending_group_arrangements`,
  /// son outbox locale. Deux créations de table, et rien d'autre.
  ///
  /// **v23** (#142, M3) — les accusés de mes messages et les distributions
  /// confirmées. Voir [_migrateM3ToV23].
  ///
  /// **v24** (M5, #144) — **ma sourdine** : `group_mutes`, une collection
  /// répliquée **privée** de plus, une création de table et rien d'autre. Voir
  /// [_migrateM5ToV24].
  ///
  /// **v25** (M2, #141) — les **gestes sur un message** (tranche M2,
  /// #141). Le palier vit dans [_migrateM2ToV25], et son numéro dans
  /// [kM2SchemaVersion] — la seule ligne à changer si un
  /// palier venait s'intercaler.
  ///
  /// **v26** (M4, #143) — **le média porté par le message** : sept colonnes
  /// sur `group_messages` (clé, forme, durée, méta, taille, type, vignette),
  /// dix sur `pending_group_messages` (l'écho d'un média : fichier local, type,
  /// méta, clés montées, cause d'échec), et l'oubli du curseur de
  /// `group_messages`. Voir [_migrateM4ToV26] et [kM4SchemaVersion].
  ///
  /// **v27** (#167) — **la médiathèque en pages** : `media_pages`,
  /// `media_page_chips`, `media_page_sections`, trois collections répliquées
  /// de plus, trois créations de table ; et `branches.slug`, avec l'oubli du
  /// curseur de `branches`. Voir [kMediaPagesSchemaVersion].
  ///
  /// **v29** (#199) — **le module Bible, tout entier** : dix miroirs de
  /// collections (quatre privées, six de référence), quatre tables locales
  /// `local_bible_*`, `bible_installed_versions` et l'index FTS5
  /// `bible_fts`. Seize créations, et rien d'autre. Voir
  /// [kBibleSchemaVersion].
  ///
  /// **v30** (#223) — **le magasin durable des médias de la messagerie** :
  /// `local_message_media`, **une** création de table locale seule, et rien
  /// d'autre. Aucune colonne de `group_messages` ne bouge, et c'est délibéré —
  /// voir l'en-tête de [LocalMessageMedia]. Voir
  /// [kMessageMediaSchemaVersion].
  ///
  /// **v31** (C3, mobile#240) — **la versification propre à chaque version** :
  /// `bible_installed_versions.versification`, **une** colonne nullable, et
  /// rien d'autre. Aucune ligne n'est réécrite, et nulle veut dire « aucun
  /// relevé » : le canon figé sert de repli, donc la Bible factice et les
  /// versions déjà installées se lisent exactement comme avant. Voir
  /// [kVersificationSchemaVersion].
  ///
  /// **v32** (#252, server-portal#620) — **le surlignage de quelques mots** :
  /// `version_code`, `char_from` et `char_to`, trois colonnes nullables, sur
  /// le miroir `bible_marks` **et** sur `local_bible_marks`. Aucune ligne
  /// n'est réécrite : nulles partout veut dire « marque au verset, valable
  /// dans toutes les traductions », ce que sont toutes les marques déjà
  /// posées. Voir [kWordMarkSchemaVersion].
  ///
  /// **v33** (#263, server-portal#628) — **les cartes de traduction des plans,
  /// des défis et des quiz** : aucune colonne ne bouge — elles étaient déjà
  /// en `TEXT` et seul leur convertisseur change —, mais **ce qu'elles
  /// contiennent** change, et les lignes déjà en magasin portent une chaîne
  /// nue que `I18nMapConverter` lirait comme une carte vide, donc un titre
  /// blanc. Le palier les replie. Voir [kBibleI18nSchemaVersion].
  @override
  int get schemaVersion => kBibleI18nSchemaVersion;

  /// **Le palier de la tranche M2** (#141) : v25, après M8 (v22), M3 (v23) et
  /// M5 (v24).
  static const int kM2SchemaVersion = 25;

  /// **Le palier de la tranche M4** (#143) : v26, après M2 (v25).
  static const int kM4SchemaVersion = 26;

  /// **Le palier de la médiathèque en pages** (#167) : v27, après M4 (v26).
  /// Sans rapport avec la tranche M4 de la messagerie, malgré le nom de
  /// tranche que le plan médiathèque lui donne aussi.
  static const int kMediaPagesSchemaVersion = 27;

  /// **Le palier des notes** (#190) : v28, après la médiathèque en pages
  /// (v27). Quatre créations de table, et rien d'autre — N4 et N5 n'ajoutent
  /// pas de table.
  static const int kNotesSchemaVersion = 28;

  /// **Le palier du module Bible** (#199) : v29, après les notes (v28). Le
  /// seul palier du chantier — M2 à M7 n'ajoutent ni table ni colonne.
  static const int kBibleSchemaVersion = 29;

  /// **Le palier du magasin des médias de la messagerie** (#223) : v30, après
  /// le module Bible (v29). Le seul palier du chantier — T2, T3 et T4
  /// n'ajoutent ni table ni colonne.
  static const int kMessageMediaSchemaVersion = 30;

  /// **Le palier de la versification par version** (mobile#240) : v31, après
  /// le magasin des médias (v30). Une colonne, et rien d'autre.
  static const int kVersificationSchemaVersion = 31;

  /// **Le palier du surlignage au mot** (mobile#252) : v32, après la
  /// versification (v31). Trois colonnes nullables sur chacune des deux
  /// tables de marques, et rien d'autre.
  static const int kWordMarkSchemaVersion = 32;

  /// **Le palier des cartes de traduction du module Bible** (mobile#263) :
  /// v33, après le surlignage au mot (v32). **Aucune DDL** — les quatre
  /// colonnes concernées (`bible_plans.title` et `.description`,
  /// `bible_challenges.title`, `bible_quizzes.title`) étaient et restent en
  /// `TEXT` ; le palier ne fait que **replier leur contenu** en carte.
  static const int kBibleI18nSchemaVersion = 33;

  /// Les trois champs du mot (#252), ajoutés ensemble au palier v32 — et
  /// retirés ensemble d'une table **créée** pour une version antérieure
  /// (migrations de test seulement, comme [_announcementMediaColumns]).
  List<GeneratedColumn<Object>> get _markWordColumns => [
        bibleMarks.versionCode,
        bibleMarks.charFrom,
        bibleMarks.charTo,
      ];

  /// Les mêmes sur la table locale.
  List<GeneratedColumn<Object>> get _localMarkWordColumns => [
        localBibleMarks.versionCode,
        localBibleMarks.charFrom,
        localBibleMarks.charTo,
      ];

  /// Les sept colonnes du média d'un message (M4), ajoutées ensemble au palier
  /// v26 — et retirées ensemble d'une table créée pour une version antérieure
  /// (migrations de test seulement, comme [_announcementMediaColumns]).
  List<GeneratedColumn<Object>> get _groupMessageMediaColumns => [
        groupMessages.mediaKey,
        groupMessages.mediaKind,
        groupMessages.mediaDuration,
        groupMessages.mediaMeta,
        groupMessages.mediaSize,
        groupMessages.mediaMime,
        groupMessages.mediaThumbnailKey,
      ];

  /// Les dix colonnes de l'écho d'un média (M4), même règle.
  List<GeneratedColumn<Object>> get _pendingMediaColumns => [
        pendingGroupMessages.mediaKind,
        pendingGroupMessages.mediaPath,
        pendingGroupMessages.mediaThumbPath,
        pendingGroupMessages.mediaMime,
        pendingGroupMessages.mediaMeta,
        pendingGroupMessages.mediaDuration,
        pendingGroupMessages.mediaSize,
        pendingGroupMessages.mediaKey,
        pendingGroupMessages.mediaThumbnailKey,
        pendingGroupMessages.mediaError,
      ];

  /// Les cinq colonnes du média d'une annonce, ajoutées ensemble au palier
  /// v18 → v19 — et retirées ensemble d'une table créée pour une version
  /// antérieure (palier v2 → v3, migrations de test seulement).
  List<GeneratedColumn<Object>> get _announcementMediaColumns => [
        announcements.mediaKind,
        announcements.mediaUrl,
        announcements.mediaPosterUrl,
        announcements.mediaDurationMs,
        announcements.mediaWaveform,
      ];

  /// `group_messages` dans sa forme v18 et v19 — `body` encore `NOT NULL`.
  /// Pour les migrations de test vers une version antérieure à la v20
  /// seulement (palier v17 → v18) ; un téléphone migre toujours jusqu'à
  /// `schemaVersion`, où `createTable` donne la forme courante.
  static const String _groupMessagesV18 =
      'CREATE TABLE IF NOT EXISTS "group_messages" ('
      '"sync_stamp" INTEGER NOT NULL DEFAULT 0, '
      '"id" TEXT NOT NULL, '
      '"group_id" TEXT NOT NULL, '
      '"author_id" TEXT NULL, '
      '"is_system" INTEGER NOT NULL DEFAULT 0 CHECK ("is_system" IN (0, 1)), '
      '"body" TEXT NOT NULL, '
      '"client_message_id" TEXT NULL, '
      '"client_created_at" INTEGER NULL, '
      '"created_at" INTEGER NULL, '
      'PRIMARY KEY ("id"))';

  /// `group_messages` dans sa forme v20 à v24 — `body` nullable, **sans** les
  /// colonnes de la tranche M2. Pour les migrations de test vers une version
  /// antérieure à [kM2SchemaVersion] seulement : un téléphone migre toujours
  /// jusqu'à `schemaVersion`, où `createTable` donne la forme courante.
  static const String _groupMessagesV20 =
      'CREATE TABLE IF NOT EXISTS "group_messages" ('
      '"sync_stamp" INTEGER NOT NULL DEFAULT 0, '
      '"id" TEXT NOT NULL, '
      '"group_id" TEXT NOT NULL, '
      '"author_id" TEXT NULL, '
      '"is_system" INTEGER NOT NULL DEFAULT 0 CHECK ("is_system" IN (0, 1)), '
      '"body" TEXT NULL, '
      '"client_message_id" TEXT NULL, '
      '"client_created_at" INTEGER NULL, '
      '"created_at" INTEGER NULL, '
      'PRIMARY KEY ("id"))';

  /// `pending_group_messages` dans sa forme v18 à v24 — **sans** la colonne de
  /// réponse de la tranche M2. Mêmes réserves que [_groupMessagesV20].
  static const String _pendingGroupMessagesV18 =
      'CREATE TABLE IF NOT EXISTS "pending_group_messages" ('
      '"client_message_id" TEXT NOT NULL, '
      '"group_id" TEXT NOT NULL, '
      '"body" TEXT NOT NULL, '
      '"created_at" INTEGER NOT NULL, '
      '"failed" INTEGER NOT NULL DEFAULT 0 CHECK ("failed" IN (0, 1)), '
      'PRIMARY KEY ("client_message_id"))';

  /// `bible_installed_versions` dans sa forme v29 et v30 — **sans**
  /// `versification` (palier v31). Pour les migrations de test vers une
  /// version antérieure à [kVersificationSchemaVersion] seulement, comme
  /// [_groupMessagesV20] : un téléphone migre toujours jusqu'à
  /// `schemaVersion`, où `createTable` donne la forme courante.
  static const String _bibleInstalledVersionsV29 =
      'CREATE TABLE IF NOT EXISTS "bible_installed_versions" ('
      '"code" TEXT NOT NULL, '
      '"name" TEXT NOT NULL, '
      '"language" TEXT NULL, '
      '"size_bytes" INTEGER NULL, '
      '"local_path" TEXT NULL, '
      '"installed_at" INTEGER NOT NULL, '
      '"indexed" INTEGER NOT NULL DEFAULT 0 CHECK ("indexed" IN (0, 1)), '
      'PRIMARY KEY ("code"))';

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
            // `createTable` emploie la forme **courante** de la table, qui porte
            // depuis la v19 les cinq colonnes du média. Sur un téléphone, `to`
            // vaut toujours `schemaVersion` et elles y sont attendues ; seule une
            // migration de test vers une version intermédiaire (v1 → v3…v18) doit
            // retrouver la forme d'alors, que le vérificateur compare colonne par
            // colonne. Voir le palier v18 → v19.
            if (to < 19) {
              for (final column in _announcementMediaColumns) {
                await m.dropColumn(announcements, column.name);
              }
            }
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
            // `createTable` emploie la forme **courante**, où `body` est
            // nullable depuis la v20. Sur un téléphone, `to` vaut toujours
            // `schemaVersion` ; seule une migration de test vers une version
            // intermédiaire (v1 → v18, v16 → v19…) doit retrouver la forme
            // d'alors, `NOT NULL` compris — même raison que les colonnes du
            // média des annonces au palier v2 → v3. SQLite ne sait pas
            // resserrer une contrainte : la table d'alors s'écrit telle quelle.
            if (to < 20) {
              await customStatement(_groupMessagesV18);
            } else if (to < kM2SchemaVersion) {
              // La forme v20 à v24 : les colonnes de M2 n'existaient pas encore.
              await customStatement(_groupMessagesV20);
            } else {
              await m.createTable(groupMessages);
              // M4 : la forme courante porte le média ; une cible antérieure
              // à la v26 ne l'a pas encore.
              await _dropM4ColumnsBefore26(m, to, groupMessages);
            }
            if (to < kM2SchemaVersion) {
              await customStatement(_pendingGroupMessagesV18);
            } else {
              await m.createTable(pendingGroupMessages);
              await _dropM4ColumnsBefore26(m, to, pendingGroupMessages);
            }
          }

          // v18 → v19 — le **média des annonces** (#130, tranche 4/4 de
          // « Sparks »). **Cinq ajouts de colonne, nullables**, et l'oubli du
          // curseur d'`announcements`.
          //
          // 1. `media_kind`, `media_url`, `media_poster_url`,
          //    `media_duration_ms`, `media_waveform` s'ajoutent, toutes
          //    nullables : aucune ligne n'est réécrite, et une annonce déjà en
          //    magasin les porte à `NULL` — « pas de média », ce qu'elle était.
          // 2. **Le curseur d'`announcements` est effacé**, et c'est la moitié
          //    du palier. Le serveur sert ces champs depuis `server-portal#477` ;
          //    un téléphone resté en v18 a donc pu recevoir une annonce audio ou
          //    vidéo, en a gardé le texte et **jeté le média** faute de colonne.
          //    Son curseur est passé dessus : sans le remettre à zéro, cette
          //    annonce resterait muette jusqu'à ce que quelqu'un la modifie au
          //    portail — c'est-à-dire, le plus souvent, pour toujours. Effacé, le
          //    manifeste suivant annonce la collection `from_zero` et le premier
          //    cycle réécrit chaque ligne **par-dessus** (règle 3 : remplacer,
          //    jamais purger d'abord). Les lignes restent : le mur ne se vide pas
          //    pendant la reprise.
          //
          // ⚠️ **`from >= 3` n'est pas décoratif** : un appareil venu d'avant la
          // v3 vient de créer `announcements` **dans sa forme courante** (palier
          // v2 → v3), colonnes du média comprises — les ajouter une seconde fois
          // lèverait « duplicate column ». Et la garde `to >= 19` a la raison
          // des paliers v7 → v8 et v9 → v10 : le vérificateur de schéma signale
          // une colonne surnuméraire.
          if (from >= 3 && from < 19 && to >= 19) {
            for (final column in _announcementMediaColumns) {
              await m.addColumn(announcements, column);
            }
          }
          if (from < 19 && to >= 19) {
            await (delete(syncCursors)
                  ..where((c) => c.collection.equals('announcements')))
                .go();
          }

          // v19 → v20 — **la messagerie fiable** (#140). Trois gestes :
          //
          // 1. `group_messages.body` perd son `NOT NULL`. SQLite ne sait pas
          //    relâcher une contrainte de colonne : `alterTable` recrée la table
          //    dans sa forme courante et **recopie chaque ligne** (le fil d'un
          //    fidèle hors ligne survit, jetons d'écriture compris). Aucune ligne
          //    n'est à réécrire : toutes portaient un texte, puisque la
          //    contrainte refusait les autres — en coupant le cycle (piège 1 du
          //    plan). Le curseur reste : une page refusée n'avait pas avancé le
          //    curseur, elle sera simplement re-tirée et acceptée cette fois.
          // 2. `group_reads` naît vide, son curseur n'existe pas : le prochain
          //    manifeste l'annoncera `from_zero`.
          // 3. `pending_group_reads` naît vide et le reste jusqu'au premier fil
          //    lu.
          //
          // ⚠️ **`from >= 18`** : avant la v18, `group_messages` vient d'être
          // créée **dans sa forme courante** au palier v17 → v18, donc déjà
          // nullable — la recréer serait inutile. Pas de garde `to >= 20` sur les
          // créations : le vérificateur de schéma ignore une table surnuméraire.
          // Elle en faut une sur la recréation, qui produit la forme **courante**
          // et ferait échouer la validation d'une cible antérieure.
          if (from >= 18 && from < 20 && to >= kM2SchemaVersion) {
            // Recréée dans la forme **courante**, colonnes de M2 et du média
            // (M4) comprises : leurs paliers ne la retouchent donc pas (garde
            // `from >= 20` plus bas). Ces colonnes-là n'ont rien à recopier
            // (`newColumns`) ; une cible antérieure à la v26 perd le média.
            await m.alterTable(
              TableMigration(
                groupMessages,
                newColumns: [
                  ..._m2MessageColumns,
                  ..._groupMessageMediaColumns
                ],
              ),
            );
            await _dropM4ColumnsBefore26(m, to, groupMessages);
          } else if (from >= 18 && from < 20 && to >= 20) {
            // Migration de test vers la v20 à la v24 : la forme d'alors.
            await _recreateGroupMessagesV20();
          }
          if (from < 20) {
            await m.createTable(groupReads);
            await m.createTable(pendingGroupReads);
          }

          // v20 → v21 — **mes requêtes** (#148). Une création de table, et rien
          // d'autre : aucune colonne existante ne bouge, aucune ligne n'est
          // réécrite. `my_interactions` naît vide, son curseur n'existe pas
          // encore, et le prochain manifeste l'annoncera `from_zero` : le
          // premier cycle ramène **toutes** mes requêtes, y compris celles
          // envoyées avant cette version. Sur un serveur en retard d'une
          // version, la collection prend un `404` et se saute — l'onglet
          // Requêtes montre alors son état vide, jamais une erreur.
          //
          // Pas de garde `to >= 21` pour la raison des paliers qui ne créent que
          // des tables : le vérificateur de schéma **ignore une table
          // surnuméraire**.
          if (from < 21) {
            await m.createTable(myInteractions);
          }

          // v21 → v22 — **archiver, épingler** (#146). Deux créations de table,
          // et rien d'autre : aucune colonne existante ne bouge, aucune ligne
          // n'est réécrite.
          //
          // - `group_arrangements` naît vide, son curseur n'existe pas : le
          //   prochain manifeste l'annoncera `from_zero` et le premier cycle
          //   ramènera les rangements faits sur un autre appareil. Sur un
          //   serveur en retard d'une version, la collection prend un `404` et
          //   se saute — aucune discussion n'est alors archivée ni épinglée, ce
          //   qui est l'état d'avant.
          // - `pending_group_arrangements` naît vide et le reste jusqu'au
          //   premier geste.
          //
          // Pas de garde `to >= 22` pour la raison des paliers qui ne créent que
          // des tables : le vérificateur de schéma **ignore une table
          // surnuméraire**.
          if (from < 22) {
            await m.createTable(groupArrangements);
            await m.createTable(pendingGroupArrangements);
          }
          // v22 → v23 — accusés de mes messages et distributions confirmées
          // (#142, M3).
          if (from < 23 && to >= 23) {
            await _migrateM3ToV23(m);
          }
          // v23 → v24 — ma sourdine (M5, #144) — voir [_migrateM5ToV24].
          if (from < 24 && to >= 24) {
            await _migrateM5ToV24(m);
          }
          // v24 → v25 — les gestes sur un message (M2, #141) — voir
          // [_migrateM2ToV25].
          if (from < kM2SchemaVersion && to >= kM2SchemaVersion) {
            await _migrateM2ToV25(m, from);
          }
          // v25 → v26 — le média porté par le message (M4, #143) — voir
          // [_migrateM4ToV26].
          if (from < kM4SchemaVersion && to >= kM4SchemaVersion) {
            await _migrateM4ToV26(m, from);
          }
          // v26 → v27 — la médiathèque en pages (#167). Trois créations de
          // table, et `branches.slug` plus bas. Elles naissent **vides**, et vide veut dire
          // « aucune page reçue » : l'écran montre alors le catalogue entier,
          // comme avant. Leurs curseurs n'existent pas, le prochain manifeste
          // les annoncera `from_zero`. Pas de garde `to >= 27` : le
          // vérificateur ignore une table surnuméraire.
          if (from < kMediaPagesSchemaVersion) {
            await m.createTable(mediaPages);
            await m.createTable(mediaPageChips);
            await m.createTable(mediaPageSections);
          }
          // Même palier : `branches.slug` (server-portal#490), ce qu'un filtre
          // de branche désigne. Nullable, aucune ligne réécrite ; et le
          // curseur de `branches` est **effacé**, comme celui des annonces au
          // palier v19 : sans cela, les branches déjà en magasin garderaient
          // un slug nul — donc tout filtre de branche vide — jusqu'à ce que
          // quelqu'un les modifie au portail. `branches` existe depuis la v1 :
          // pas de garde `from >=`. La garde `to >=` a la raison du palier
          // v7 → v8 (colonne surnuméraire signalée par le vérificateur).
          if (from < kMediaPagesSchemaVersion &&
              to >= kMediaPagesSchemaVersion) {
            await m.addColumn(branches, branches.slug);
            await (delete(syncCursors)
                  ..where((c) => c.collection.equals('branches')))
                .go();
          }
          // v27 → v28 — les notes (#190). Quatre créations de table, et rien
          // d'autre : aucune colonne existante ne bouge. `spiritual_notes` et
          // `note_categories` naissent vides, sans curseur — le prochain
          // manifeste les annonce `from_zero` et le premier cycle ramène les
          // notes écrites sur un autre appareil ; sur un serveur en retard
          // d'une version, un `404` les saute. `local_notes` et
          // `pending_note_media` naissent vides et le restent jusqu'au premier
          // geste. Pas de garde `to >= 28` : le vérificateur ignore une table
          // surnuméraire.
          if (from < kNotesSchemaVersion) {
            await m.createTable(spiritualNotes);
            await m.createTable(noteCategories);
            await m.createTable(localNotes);
            await m.createTable(pendingNoteMedia);
          }
          // v28 → v29 — le module Bible (#199). Seize créations, et rien
          // d'autre. Les miroirs naissent vides, sans curseur : le prochain
          // manifeste les annonce `from_zero` (un serveur en retard d'une
          // version répond `404`, la collection est sautée). Les tables
          // locales attendent le premier geste.
          if (from < kBibleSchemaVersion) {
            for (final table in <TableInfo<Table, Object?>>[
              bibleMarks,
              bibleReadingStates,
              biblePlanEnrollments,
              bibleQuizResults,
              bibleVerseOfDays,
              bibleSundayPassages,
              biblePlans,
              bibleChallenges,
              bibleQuizzes,
              bibleVersions,
              localBibleMarks,
              localBibleReadingState,
              localBiblePlanEnrollments,
              localBibleQuizResults,
            ]) {
              await m.createTable(table);
            }
            // `bible_installed_versions` à part : `createTable` donne la forme
            // **courante**, `versification` comprise (palier v31), et le
            // vérificateur refuse cette colonne surnuméraire sur une cible
            // antérieure. Un téléphone migre toujours jusqu'à `schemaVersion`
            // et prend donc la première branche ; la seconde ne sert qu'aux
            // migrations de test vers la v29 ou la v30.
            if (to >= kVersificationSchemaVersion) {
              await m.createTable(bibleInstalledVersions);
            } else {
              await customStatement(_bibleInstalledVersionsV29);
            }
            // Même règle pour les deux tables de marques, qui gagnent au
            // palier v32 les trois champs du mot : `createTable` vient d'en
            // donner la forme **courante**, et le vérificateur refuse ces
            // colonnes sur une cible antérieure. Les retirer plutôt que
            // recopier deux DDL (le choix du palier v2 → v3 pour le média
            // d'une annonce) : une table qui vient de naître est vide, il n'y
            // a rien à y perdre.
            if (to < kWordMarkSchemaVersion) {
              for (final column in _markWordColumns) {
                await m.dropColumn(bibleMarks, column.name);
              }
              for (final column in _localMarkWordColumns) {
                await m.dropColumn(localBibleMarks, column.name);
              }
            }
            await m.create(bibleFts);
          }
          // v29 → v30 — le magasin durable des médias de la messagerie
          // (#223). **Une** création de table locale seule, et rien d'autre.
          // Elle naît vide, et vide veut dire « rien n'est encore descendu » :
          // chaque bulle résout son URL comme avant, et le magasin se remplit
          // au premier média ouvert. Aucun curseur à effacer — la table n'est
          // dans aucun registre de synchronisation. Pas de garde `to >= 30` :
          // le vérificateur ignore une table surnuméraire.
          if (from < kMessageMediaSchemaVersion) {
            await m.createTable(localMessageMedia);
          }
          // v30 → v31 — la versification propre à chaque version (C3,
          // mobile#240). **Une** colonne nullable sur une table **locale
          // seule**, et rien d'autre : aucune ligne n'est réécrite, aucun
          // curseur n'est en jeu (la table n'est dans aucun registre de
          // synchronisation). Nulle veut dire « aucun relevé » — le canon
          // figé sert de repli, donc une version déjà installée se lit comme
          // avant, et son relevé arrivera avec la vraie archive (C4).
          //
          // La garde `from >=` a la raison du palier v18 → v19 : au-dessous,
          // `bible_installed_versions` est **créée** par le palier v29 dans
          // sa forme courante, colonne comprise — un `addColumn` y
          // doublonnerait. La garde `to >=` est celle du palier v7 → v8 : le
          // vérificateur signale une colonne surnuméraire sur un palier
          // intermédiaire.
          if (from >= kBibleSchemaVersion &&
              from < kVersificationSchemaVersion &&
              to >= kVersificationSchemaVersion) {
            await m.addColumn(
              bibleInstalledVersions,
              bibleInstalledVersions.versification,
            );
          }
          // v31 → v32 — **le surlignage de quelques mots** (#252,
          // server-portal#620) : `version_code`, `char_from`, `char_to`, sur
          // le miroir `bible_marks` et sur `local_bible_marks`. Six
          // `addColumn` nullables, aucune ligne réécrite, aucun curseur en
          // jeu — **nulles partout veut dire « ce qu'on faisait avant »** :
          // une marque au verset, valable dans toutes les traductions. C'est
          // ce que portent toutes les marques déjà posées, et c'est pourquoi
          // le miroir n'a pas besoin d'être retiré pour être re-tiré.
          //
          // Les deux gardes ont les raisons du palier v31 : au-dessous de la
          // v29 les tables sont **créées** dans leur forme courante, colonnes
          // comprises (un `addColumn` y doublonnerait) ; et le vérificateur
          // signale une colonne surnuméraire sur un palier intermédiaire.
          if (from >= kBibleSchemaVersion &&
              from < kWordMarkSchemaVersion &&
              to >= kWordMarkSchemaVersion) {
            for (final column in _markWordColumns) {
              await m.addColumn(bibleMarks, column);
            }
            for (final column in _localMarkWordColumns) {
              await m.addColumn(localBibleMarks, column);
            }
          }
          // v32 → v33 — **les cartes de traduction** des plans, des défis et
          // des quiz (#263, server-portal#628). Aucune colonne n'est ajoutée,
          // retirée ni retypée : elles étaient déjà en `TEXT`, et le
          // vrai changement est que le texte y est désormais du JSON. Ce
          // palier est donc un palier de **données**, le premier du magasin.
          //
          // Il est nécessaire : le delta ne ramène que les lignes
          // **modifiées**, donc un plan déjà en magasin garderait sa chaîne
          // nue indéfiniment, et `I18nMapConverter` la lirait comme une carte
          // vide — un titre blanc, sans erreur pour le dire. On le replie ici,
          // comme le `up` du serveur : `to_jsonb(json_build_object('fr', …))`.
          //
          // La garde `from >=` a la raison des paliers v31 et v32 : au-dessous
          // de la v29 les trois tables sont **créées** par ce palier-là, donc
          // vides — il n'y a rien à replier.
          if (from >= kBibleSchemaVersion && from < kBibleI18nSchemaVersion) {
            await _foldBibleTitlesIntoCards();
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

  /// **Replie en carte `{"fr": …}` les titres déjà en magasin** (palier v33).
  ///
  /// Écrit en Dart, et non en `json_object()` : l'extension JSON1 de SQLite
  /// n'est pas garantie sur les trois cibles (Android, iOS, et le `sqlite3`
  /// du web), alors que `jsonEncode` l'est. Ces trois miroirs comptent de
  /// toute façon quelques lignes — zéro en production le jour du palier.
  ///
  /// `NOT LIKE '{%'` saute ce qui est **déjà** une carte : le palier doit
  /// pouvoir être rejoué (migration de test v29 → v33 après un cycle) sans
  /// emballer une carte dans une carte.
  Future<void> _foldBibleTitlesIntoCards() async {
    for (final (table, column) in const [
      ('bible_plans', 'title'),
      ('bible_plans', 'description'),
      ('bible_challenges', 'title'),
      ('bible_quizzes', 'title'),
    ]) {
      final rows = await customSelect(
        'SELECT rowid AS r, "$column" AS v FROM "$table" '
        'WHERE "$column" IS NOT NULL AND "$column" NOT LIKE \'{%\'',
      ).get();
      for (final row in rows) {
        await customUpdate(
          'UPDATE "$table" SET "$column" = ? WHERE rowid = ?',
          variables: [
            Variable<String>(jsonEncode({'fr': row.read<String>('v')})),
            Variable<int>(row.read<int>('r')),
          ],
        );
      }
    }
  }

  /// **Palier des accusés (#142, M3)** — deux créations de table, et rien
  /// d'autre : aucune colonne existante ne bouge, aucune donnée n'est recopiée.
  ///
  /// `message_receipts` naît vide, son curseur n'existe pas : le prochain
  /// manifeste l'annonce `from_zero`, et le premier cycle ramène les accusés
  /// des messages envoyés avant cette version. `delivery_acks` naît vide : les
  /// messages reçus des derniers jours seront confirmés une fois — la route
  /// est idempotente.
  ///
  /// Écrit à part, et appelé par un seul palier (v23).
  Future<void> _migrateM3ToV23(Migrator m) async {
    await m.createTable(messageReceipts);
    await m.createTable(deliveryAcks);
  }

  /// Les huit colonnes de `group_messages` ajoutées par la tranche M2 (#141).
  List<GeneratedColumn<Object>> get _m2MessageColumns => [
        groupMessages.deletedAt,
        groupMessages.editedAt,
        groupMessages.isForwarded,
        groupMessages.replyToMessageId,
        groupMessages.replyToAuthorId,
        groupMessages.replyToExcerpt,
        groupMessages.replyToMediaKind,
        groupMessages.replyToDeleted,
      ];

  /// **Palier M2 (#141) — les gestes sur un message**, v25 : voir
  /// [kM2SchemaVersion].
  ///
  /// 1. `group_messages` gagne huit colonnes — le tombstone **gardé**
  ///    (`deleted_at`), « Modifié », « Transféré », et la citation
  ///    photographiée. Toutes nullables ou avec défaut : un `ALTER TABLE … ADD
  ///    COLUMN`, sans réécriture, et le fil déjà en magasin survit tel quel.
  ///    **Seulement si la table existe dans sa forme v20 à v24** (`from >= 20`) :
  ///    plus bas, elle vient d'être créée ou recréée dans sa forme courante.
  /// 2. `pending_group_messages` gagne la réponse en attente, sous la même
  ///    réserve (`from >= 18`).
  /// 3. Deux collections naissent vides, sans curseur : le prochain manifeste
  ///    les annonce `from_zero`, et le premier cycle ramène réactions et
  ///    masquages antérieurs.
  ///
  /// Le curseur de `group_messages` n'est **pas** oublié : les messages déjà
  /// supprimés avant cette version ont quitté le magasin, et c'est sans
  /// conséquence — un message absent ne se peint pas, un tombstone tiré
  /// désormais se peint « supprimé ». Les citations et « Modifié » des messages
  /// déjà rangés reviendront au fil des modifications ; aucune n'existe avant
  /// que le serveur M2 ne soit en ligne.
  Future<void> _migrateM2ToV25(Migrator m, int from) async {
    if (from >= 20) {
      for (final column in _m2MessageColumns) {
        await m.addColumn(groupMessages, column);
      }
    }
    if (from >= 18) {
      await m.addColumn(
          pendingGroupMessages, pendingGroupMessages.replyToMessageId);
    }
    await m.createTable(groupMessageReactions);
    await m.createTable(groupMessageHides);
  }

  /// Recrée `group_messages` dans sa forme v20 à v24 en gardant ses lignes — le
  /// palier v19 → v20 d'une **migration de test** vers une version antérieure
  /// à [kM2SchemaVersion]. Même geste que `TableMigration`, écrit à la main
  /// parce que `TableMigration` produit la forme courante.
  Future<void> _recreateGroupMessagesV20() async {
    const columns = 'sync_stamp, id, group_id, author_id, is_system, body, '
        'client_message_id, client_created_at, created_at';
    await customStatement(
      'ALTER TABLE "group_messages" RENAME TO "group_messages_v19"',
    );
    await customStatement(_groupMessagesV20);
    await customStatement(
      'INSERT INTO "group_messages" ($columns) '
      'SELECT $columns FROM "group_messages_v19"',
    );
    await customStatement('DROP TABLE "group_messages_v19"');
  }

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

  /// **v23 → v24 (M5, #144)** — la sourdine par discussion.
  ///
  /// Une création de table, et rien d'autre : aucune colonne existante ne
  /// bouge, aucune ligne n'est réécrite. `group_mutes` naît vide, son curseur
  /// n'existe pas encore, et le prochain manifeste l'annoncera `from_zero` : le
  /// premier cycle ramène les sourdines posées depuis un autre appareil. Vide
  /// veut dire « aucune sourdine » — exactement l'état d'avant cette version.
  /// Sur un serveur en retard, la collection prend un `404` et se saute.
  ///
  /// Écrit à part, et appelé par un seul palier (v24).
  Future<void> _migrateM5ToV24(Migrator m) async {
    await m.createTable(groupMutes);
  }

  /// **v25 → v26 (tranche M4 — #143)** : le média porté par le message. Son
  /// numéro vit dans [kM4SchemaVersion].
  ///
  /// 1. `group_messages` gagne sept colonnes nullables — **seulement si la
  ///    table existait déjà dans une forme sans elles** (`from >= 20`) : créée
  ///    au palier v17 → v18, ou recréée au palier v19 → v20, elle porte déjà la
  ///    forme courante. Même garde que le palier M2.
  /// 2. `pending_group_messages` gagne dix colonnes nullables, sous la même
  ///    réserve (`from >= 18`, palier de sa création).
  /// 3. **Le curseur de `group_messages` est effacé** — même geste que le média
  ///    des annonces au palier v19. Un téléphone resté en v25 a reçu des vocaux
  ///    et des images (`body: null`) et les a rangés **sans leur média**, faute
  ///    de colonne ; son curseur est passé dessus. Effacé, le manifeste suivant
  ///    annonce la collection `from_zero` et le premier cycle réécrit chaque
  ///    ligne par-dessus (règle 3 : remplacer, jamais purger d'abord) — le fil
  ///    ne se vide pas pendant la reprise.
  ///
  /// Appelé par un seul palier, sous la garde `from < kM4SchemaVersion && to >=
  /// kM4SchemaVersion` — la même forme que les paliers M3, M5 et M2.
  Future<void> _migrateM4ToV26(Migrator m, int from) async {
    if (from >= 20) {
      for (final column in _groupMessageMediaColumns) {
        await m.addColumn(groupMessages, column);
      }
    }
    if (from >= 18) {
      for (final column in _pendingMediaColumns) {
        await m.addColumn(pendingGroupMessages, column);
      }
    }
    await (delete(syncCursors)
          ..where((c) => c.collection.equals('group_messages')))
        .go();
  }

  /// Une table du fil **créée dans sa forme courante** pour une cible
  /// antérieure à la v26 (migrations de test seulement) : on lui retire les
  /// colonnes du média, que cette cible n'a pas encore. Même geste que le
  /// palier v2 → v3 pour le média des annonces. Sur un téléphone, `to` vaut
  /// toujours `schemaVersion` et rien n'est retiré.
  Future<void> _dropM4ColumnsBefore26(
    Migrator m,
    int to,
    TableInfo<Table, Object?> table,
  ) async {
    if (to >= kM4SchemaVersion) return;
    final columns = identical(table, groupMessages)
        ? _groupMessageMediaColumns
        : _pendingMediaColumns;
    for (final column in columns) {
      await m.dropColumn(table, column.name);
    }
  }

  Future<void> _ensureGlobalStateRow() async {
    await into(syncState).insert(
      const SyncStateCompanion(id: Value(kSyncStateRowId)),
      mode: InsertMode.insertOrIgnore,
    );
  }
}
