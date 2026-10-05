/// **Mes requêtes** (#148) — la collection répliquée `my_interactions`.
library;

import 'package:drift/drift.dart';

import 'mediatheque_tables.dart' show SyncedRow;

/// Collection `my_interactions` (partition `private`, **avec** tombstone) :
/// les demandes de prière, suggestions et réclamations que **j'ai** envoyées,
/// et leur statut de traitement.
///
/// Le serveur la cloisonne sur `owner_id = soi` (`my_interactions_descriptor.ts`)
/// : une ligne qui arrive ici est la mienne. Le magasin, lui, **survit à la
/// déconnexion** — c'est pourquoi [authorId] est stocké et que la lecture filtre
/// dessus (`InteractionDao`) : une autre personne qui se connecte sur le même
/// téléphone ne doit jamais lire les requêtes de la précédente.
///
/// Les trois énumérations du domaine (`type`, `status`, `visibility`) sont
/// stockées **en chaîne brute** (règle 5 du magasin : on stocke ce que le
/// serveur envoie) ; c'est la lecture qui les traduit, et une valeur inconnue
/// d'un serveur plus récent s'y lit sans planter.
@DataClassName('MyInteractionRow')
class MyInteractions extends Table with SyncedRow {
  @override
  String get tableName => 'my_interactions';

  /// UUIDv7 — pré-généré par le client à l'envoi (`POST /interactions`).
  TextColumn get id => text()();

  /// `prayer_request` | `suggestion` | `complaint`.
  TextColumn get type => text()();

  /// `new` | `in_progress` | `resolved` | `archived`.
  TextColumn get status => text()();

  /// `community` | `private` — seule une prière peut être `community`.
  TextColumn get visibility => text()();

  /// Anonymat **souple** (ADR-0007) : masqué aux autres, jamais à moi.
  BoolColumn get isAnonymous => boolean().withDefault(const Constant(false))();

  TextColumn get title => text()();
  TextColumn get content => text()();

  /// Moi, par construction — stocké pour **filtrer** à la lecture (voir
  /// l'en-tête), et nullable parce que le magasin ne refuse pas une page pour
  /// une clé manquante : une ligne sans auteur n'est simplement lue par
  /// personne.
  TextColumn get authorId => text().nullable()();

  DateTimeColumn get clientCreatedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
