import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'announcement_dao.dart';
// Utilisé par le code généré (`app_database.g.dart`), qui est une `part` de ce
// fichier : le convertisseur de carte de traduction y est instancié.
import 'converters/i18n_map_converter.dart';
import 'gathering_dao.dart';
import 'mediatheque_dao.dart';
import 'sync_dao.dart';
import 'tables/announcement_tables.dart';
import 'tables/gathering_tables.dart';
import 'tables/mediatheque_tables.dart';
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
  ],
  daos: [SyncDao, MediathequeDao, GatheringDao, AnnouncementDao],
)
class AppDatabase extends _$AppDatabase {
  /// Constructeur explicite — c'est celui qu'utilisent les tests, avec une base
  /// **en mémoire** : tout le magasin se vérifie sur la VM Dart, sans appareil.
  AppDatabase(super.e);

  /// Base de l'application, à l'emplacement standard de la plateforme.
  AppDatabase.defaults() : super(driftDatabase(name: kLocalDatabaseName));

  /// **v3** — les quatre tables des annonces (`status_backgrounds`,
  /// `official_accounts`, `official_account_memberships`, `announcements`)
  /// entrent au magasin, issue #35.
  @override
  int get schemaVersion => 3;

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
