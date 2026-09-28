/// Table de la collection répliquée `seasons` — la période datée dont le **fond
/// vertical** habille les deux lecteurs, l'enseignement et le direct.
///
/// Les règles de `mediatheque_tables.dart` valent ici mot pour mot : aucune clé
/// étrangère entre collections, **on stocke ce que le serveur envoie**, chaque
/// ligne porte son jeton d'écriture ([SyncedRow]).
///
/// ## Pourquoi la collection, et pas un `GET /season`
///
/// Même motif que `legal_documents` : **le fond doit être là sans réseau**. Un
/// lecteur est précisément ce qu'on ouvre dans un couloir ou un taxi, et une
/// route de lecture ferait dépendre le décor de l'écran d'un aller-retour que
/// le magasin rend inutile (ADR-0026 — le magasin est autoritaire, le réseau
/// ne peint jamais).
///
/// ## La saison du jour se décide **ici**, pas sur le serveur
///
/// La table voyage **entière**, saisons passées et futures comprises, et c'est
/// le téléphone qui élit celle du jour ([SeasonDao]). Deux raisons, et la
/// seconde est la vraie :
///
/// 1. lui seul sait quel jour on est **hors ligne** ;
/// 2. une saison qui commence à minuit ne doit pas attendre la prochaine
///    synchronisation pour habiller l'écran.
///
/// ## Ni tombstone, ni résurrection à craindre
///
/// Le descripteur serveur pose `tombstoneColumn: null` : une saison se
/// **supprime** pour de bon, et la disparition ne voyage donc pas. Un appareil
/// qui a reçu une saison supprimée continue de l'appliquer jusqu'à sa date de
/// fin. C'est l'arbitrage assumé côté serveur (rendre la suppression logique
/// demanderait de reprendre la contrainte d'exclusion `seasons_no_overlap`), et
/// [SeasonDao] en borne le coût : à égalité de dates, **le plus grand `id`
/// gagne**, donc la saison recréée l'emporte sur celle qu'on venait d'effacer.
library;

import 'package:drift/drift.dart';

import 'mediatheque_tables.dart' show SyncedRow;

/// Collection `seasons` (partition `reference` : une saison n'appartient à
/// aucune branche et part aux trois lecteurs de la même façon).
@DataClassName('SeasonRow')
class Seasons extends Table with SyncedRow {
  @override
  String get tableName => 'seasons';

  /// PK **SERIAL** côté serveur : une saison s'administre au portail, jamais
  /// hors ligne.
  IntColumn get id => integer()();

  /// Le nom de la saison. Ne s'affiche nulle part aujourd'hui ; il voyage parce
  /// qu'il est ce qui rend une ligne lisible dans un journal ou une inspection
  /// de base, quand on cherche pourquoi le fond n'est pas celui qu'on croyait.
  TextColumn get name => text()();

  /// Le fond **paysage**, toujours servi (il est requis au portail).
  TextColumn get backgroundUrl => text()();

  /// Le fond **vertical**, celui des téléphones. `null` = la saison n'en a pas
  /// déposé, et le lecteur retombe sur le paysage — recadré, ce qui reste
  /// préférable à un aplat de couleur.
  TextColumn get backgroundVerticalUrl => text().nullable()();

  /// Premier jour, **inclus**, en `YYYY-MM-DD`.
  ///
  /// **Une chaîne, jamais un `DateTime`** — la règle 2 de `sync_rows.dart`, la
  /// même que `teachings.recordedAt` : un jour n'est pas un instant, et le
  /// convertir en poserait un (minuit, dans un fuseau qu'il faudrait choisir),
  /// que le moindre décalage ferait afficher la veille. La comparaison reste
  /// exacte : en ISO, l'ordre lexicographique **est** l'ordre chronologique.
  TextColumn get startsOn => text()();

  /// Dernier jour, **inclus**, en `YYYY-MM-DD`. Voir [startsOn].
  TextColumn get endsOn => text()();

  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
