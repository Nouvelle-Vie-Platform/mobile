/// Tables de **plomberie** du magasin local : curseurs, état global, jetons de
/// resynchronisation.
///
/// Elles ne portent aucune donnée d'église. Elles portent ce qui permet de
/// réappliquer le flux delta sans jamais mentir sur ce qui a été appliqué
/// (ADR-0026, ADR-0027).
library;

import 'package:drift/drift.dart';

/// **Un curseur par collection** — jamais un curseur global.
///
/// Le curseur est **opaque** : le client le stocke et le rejoue, il ne le
/// décode ni ne le construit jamais (ADR-0026, §2.4 du cadrage). Une ligne
/// n'existe ici qu'à partir du moment où **une page a été appliquée** pour
/// cette collection ; son absence vaut « depuis zéro ».
///
/// La règle qui donne son sens à cette table est ailleurs (voir
/// `SyncDao.applyPage`) : le curseur d'une page se valide **dans la même
/// transaction que les lignes qu'il couvre**. Écrit séparément, il produirait à
/// la première coupure un curseur avancé sur des lignes jamais appliquées —
/// un trou définitif, que le keyset ne repassera jamais et que seul un
/// `full_resync` refermerait, alors que rien ne le déclenchera.
///
/// **La `scope_version` n'a rien à faire ici** : elle est un état *global*
/// (une valeur pour treize collections), pas une propriété de collection. Voir
/// [SyncState].
@DataClassName('SyncCursorRow')
class SyncCursors extends Table {
  @override
  String get tableName => 'sync_cursors';

  /// Clé de collection du protocole (`teachings`, `teaching_types`, …). C'est
  /// **le seul discriminant** du rangement : une ligne se range d'après le
  /// canal par lequel elle est arrivée, jamais d'après un champ qu'elle porte
  /// (ADR-0026, décision 1).
  TextColumn get collection => text()();

  /// Curseur opaque de la dernière page appliquée. `null` = « depuis zéro ».
  TextColumn get cursor => text().nullable()();

  /// Instant de la dernière page **effectivement appliquée**.
  DateTimeColumn get syncedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {collection};
}

/// **État global de l'acteur, sur une seule ligne.**
///
/// Deux emplacements, et pas un (ADR-0026) : les curseurs se rangent par
/// collection dans [SyncCursors] ; ce qui est global se range ici.
///
/// La `scope_version` est un état **global** — une valeur pour les treize
/// collections. Rangée dans la table des curseurs, elle serait validée
/// collection par collection : une coupure après que `teachings` a validé sa
/// page (donc sa version neuve) mais avant qu'`announcements` ait purgé
/// laisserait le manifeste suivant recevoir une version **à jour**, et le
/// resync qu'`announcements` n'a jamais fait ne serait **plus jamais**
/// redemandé (ADR-0027).
///
/// Sa discipline est l'**inverse** de celle du curseur : retenue en mémoire
/// pendant tout le cycle, persistée **en dernier**, une fois que chaque
/// collection marquée a purgé et re-tiré jusqu'à `has_more: false`. Une
/// synchronisation interrompue ne persiste rien : elle rejoue le resync au tour
/// suivant. Ce magasin ne fait qu'offrir l'emplacement ; la discipline
/// appartient au moteur.
@DataClassName('SyncStateRow')
class SyncState extends Table {
  @override
  String get tableName => 'sync_state';

  /// Toujours [kSyncStateRowId] — l'unicité de la ligne est une contrainte de
  /// base, pas une convention qu'un appelant pourrait oublier.
  IntColumn get id => integer()
      .withDefault(const Constant(kSyncStateRowId))
      // Écrit en SQL brut, et non `id.equals(kSyncStateRowId)`, qui ferait un
      // getter récursif. La valeur reste celle de [kSyncStateRowId].
      .check(const CustomExpression<bool>('id = 1'))();

  /// Version de périmètre connue. `null` = jamais synchronisé.
  IntColumn get scopeVersion => integer().nullable()();

  /// Prochain jeton d'écriture à distribuer.
  ///
  /// C'est un **compteur monotone local**, pas une date : le balayage de fin de
  /// resync compare des jetons, et une horloge d'appareil qui recule pendant un
  /// cycle ferait supprimer des lignes fraîchement écrites — silencieusement.
  /// Il n'a aucun sens hors de l'appareil et ne voyage jamais.
  IntColumn get nextStamp => integer().withDefault(const Constant(1))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Identifiant de l'unique ligne de [SyncState].
const int kSyncStateRowId = 1;

/// **Jeton de resynchronisation, un par collection.**
///
/// Sa présence signifie : « un remplacement complet est en cours sur cette
/// collection ». Il est posé dans la transaction qui apprend le `full_resync`,
/// il survit à une coupure, et il n'est levé qu'à la transaction finale du
/// cycle.
///
/// Le resync est un **remplacement, pas une destruction suivie d'une
/// reconstruction** : on ne vide jamais d'abord. Vider est une transaction,
/// re-tirer en est N ; entre les deux, le magasin — qui peint les écrans —
/// serait partiellement vide. Une connexion qui tombe après la purge laisserait
/// un fidèle **sans son catalogue et sans rien reçu**, alors qu'il était hors
/// ligne avec ses enseignements trente secondes plus tôt.
///
/// [stamp] est le jeton d'écriture alloué à l'ouverture du cycle : à la fin,
/// les lignes dont le jeton d'écriture lui est **antérieur** sont celles que ce
/// cycle n'a pas revues, et ce sont exactement celles-là qui partent.
@DataClassName('ResyncTokenRow')
class ResyncTokens extends Table {
  @override
  String get tableName => 'resync_tokens';

  /// Clé de collection du protocole.
  TextColumn get collection => text()();

  /// Jeton d'écriture alloué à l'ouverture du cycle.
  IntColumn get stamp => integer()();

  /// Instant d'ouverture du cycle — diagnostic seulement, jamais comparé.
  DateTimeColumn get startedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {collection};
}
