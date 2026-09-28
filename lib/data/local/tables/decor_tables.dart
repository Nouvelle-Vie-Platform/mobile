/// Table de la collection répliquée `decor` — le fond que l'application pose
/// **quand aucune saison ne couvre le jour**.
///
/// C'est le dernier étage *servi* de la cascade du fond : celui que le site
/// public appelle « décor de marque » et que le portail permet de remplacer.
/// Au-delà, il n'y a plus que l'image embarquée dans ce dépôt, qui ne voyage
/// pas.
///
/// ## Une table pour **une ligne**
///
/// Côté serveur, `vitrine_settings` est un singleton (`id = 1`, garanti par un
/// CHECK). La table n'en portera donc jamais qu'une. Ça a l'air
/// disproportionné, et ça ne l'est pas : passer par le flux delta donne
/// gratuitement ce qu'il aurait fallu écrire à la main derrière une route —
/// *quand* la valeur a changé. Un `GET /decor` obligerait à choisir entre
/// redemander à chaque ouverture et garder indéfiniment une image remplacée.
///
/// ## `null` est une valeur, pas une absence de ligne
///
/// Tant que personne n'a déposé de décor au portail, la ligne arrive avec ses
/// deux adresses nulles. C'est ce qui distingue « je n'ai pas encore reçu les
/// réglages » de « il n'y a pas de décor », et permet de retomber tout de suite
/// sur l'image du dépôt au lieu d'attendre une ligne qui ne viendra pas.
library;

import 'package:drift/drift.dart';

import 'mediatheque_tables.dart' show SyncedRow;

/// Collection `decor` (partition `reference`, aucun filtre de périmètre).
@DataClassName('DecorRow')
class Decor extends Table with SyncedRow {
  @override
  String get tableName => 'decor';

  /// PK **SERIAL** côté serveur. Vaut toujours `1` — la table d'origine est un
  /// singleton —, mais la colonne existe parce que le curseur composé du
  /// protocole en a besoin, et parce qu'une table locale n'a pas à supposer ce
  /// que le serveur garantit.
  IntColumn get id => integer()();

  /// Le décor **paysage**. `null` = rien n'a été déposé au portail.
  TextColumn get backgroundUrl => text().nullable()();

  /// Le décor **vertical**, celui des téléphones. `null` = pas de vertical ; on
  /// retombe sur le paysage, recadré.
  TextColumn get backgroundVerticalUrl => text().nullable()();

  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
