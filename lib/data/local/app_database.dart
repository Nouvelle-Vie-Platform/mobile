import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

// Le type que porte la colonne `sections` de `legal_documents`. Il est nommé
// **sans préfixe** par le code généré (`app_database.g.dart`, une `part` de ce
// fichier) : sans cet import, la classe de données ne compile pas.
import '../../models/legal_document_view.dart';
import 'announcement_dao.dart';
// Utilisé par le code généré (`app_database.g.dart`), qui est une `part` de ce
// fichier : le convertisseur de carte de traduction y est instancié.
import 'converters/i18n_map_converter.dart';
// Idem : le convertisseur des sections d'un document légal est instancié par le
// code généré.
import 'converters/legal_sections_converter.dart';
import 'gathering_dao.dart';
import 'legal_dao.dart';
import 'mediatheque_dao.dart';
import 'playback_dao.dart';
import 'sync_dao.dart';
import 'tables/announcement_tables.dart';
import 'tables/gathering_tables.dart';
import 'tables/legal_tables.dart';
import 'tables/mediatheque_tables.dart';
import 'tables/playback_tables.dart';
import 'tables/sync_tables.dart';

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
    GatheringTypes,
    Gatherings,
    StatusBackgrounds,
    OfficialAccounts,
    OfficialAccountMemberships,
    Announcements,
    PlaybackProgress,
    LocalPlaybackPositions,
    LegalDocuments,
  ],
  daos: [
    SyncDao,
    MediathequeDao,
    GatheringDao,
    AnnouncementDao,
    PlaybackDao,
    LegalDao,
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
  @override
  int get schemaVersion => 5;

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
        },
        beforeOpen: (details) async {
          // La ligne d'état global doit exister avant la première allocation de
          // jeton d'écriture. La recréer ici couvre une base ouverte après une
          // migration qui l'aurait manquée — un `INSERT OR IGNORE`, donc sans
          // effet sur une base saine.
          await _ensureGlobalStateRow();
        },
      );

  Future<void> _ensureGlobalStateRow() async {
    await into(syncState).insert(
      const SyncStateCompanion(id: Value(kSyncStateRowId)),
      mode: InsertMode.insertOrIgnore,
    );
  }
}
