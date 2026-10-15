/// **Les quatre tables des notes** (#190, chantier « Notes et Bible ») — et
/// le patron est celui de `playback_tables.dart` : une collection répliquée,
/// remplie **par la synchronisation seule**, à côté d'une table locale que
/// l'application écrit.
///
/// - [SpiritualNotes] et [NoteCategories] sont deux collections **privées**
///   (`spiritual_notes`, `note_categories`), `SyncedRow`, tombstone par
///   `deletedAt`. L'application n'y écrit **jamais** (ADR-0026) : elle poste
///   (`POST /notes`, `POST /notes/categories`) et le flux delta ramène la ligne.
/// - [LocalNotes] porte les **brouillons** : la note telle que ce téléphone la
///   tient, écrite à chaque frappe, envoyée 2 s après la dernière. Une ligne y
///   **existe** tant que la ligne synchronisée n'est pas revenue avec un
///   `updatedAt ≥ clientUpdatedAt` ; `dirty` dit s'il reste un envoi à faire.
/// - [PendingNoteMedia] est l'outbox des pièces jointes (tranche N4). Créée au
///   même palier pour qu'il n'y ait qu'une migration ; **vide et inutilisée**
///   dans cette tranche.
///
/// **Aucune clé étrangère**, ni vers `teachings` ni entre notes et catégories :
/// une note survit à la rétractation de son enseignement, et une catégorie
/// supprimée fait repasser ses notes « sans catégorie » par le delta (le
/// serveur avance leur `updated_at` dans la même transaction).
library;

import 'package:drift/drift.dart';

import 'mediatheque_tables.dart';

/// Collection `spiritual_notes` — privée, avec tombstone.
///
/// Colonnes du contrat N1 : `id` (UUIDv7 client), `ownerId`, `teachingId`,
/// `title`, `content` (Delta Quill en JSON, ou nul), `body` (le texte aplati :
/// aperçu et recherche), `categoryId`, `pinned`, `clientCreatedAt`,
/// `createdAt`, `updatedAt`.
@DataClassName('SpiritualNoteRow')
class SpiritualNotes extends Table with SyncedRow {
  @override
  String get tableName => 'spiritual_notes';

  TextColumn get id => text()();
  TextColumn get ownerId => text().nullable()();
  TextColumn get teachingId => text().nullable()();
  TextColumn get title => text().nullable()();

  /// Le Delta Quill, **tel que servi** (JSON brut). Lu par l'éditeur riche de
  /// N3 ; cette tranche n'écrit qu'un Delta minimal (`plainToDeltaJson`).
  TextColumn get content => text().nullable()();
  TextColumn get body => text().withDefault(const Constant(''))();
  TextColumn get categoryId => text().nullable()();
  BoolColumn get pinned => boolean().withDefault(const Constant(false))();
  DateTimeColumn get clientCreatedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Collection `note_categories` — privée, avec tombstone.
///
/// `color` est l'une des six clés du contrat (`blue | pink | green | yellow |
/// orange | purple`), stockée **brute** : une couleur inconnue d'une version
/// future se peint neutre, jamais en erreur.
@DataClassName('NoteCategoryRow')
class NoteCategories extends Table with SyncedRow {
  @override
  String get tableName => 'note_categories';

  TextColumn get id => text()();
  TextColumn get ownerId => text().nullable()();
  TextColumn get name => text()();
  TextColumn get color => text()();
  DateTimeColumn get clientCreatedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// **Locale seule** : le brouillon de ce téléphone. Mêmes colonnes que la
/// collection, plus l'état d'envoi.
///
/// Sans [SyncedRow], et c'est structurel : sans `sync_stamp`, elle ne peut pas
/// entrer au registre des collections par distraction.
@DataClassName('LocalNoteRow')
class LocalNotes extends Table {
  @override
  String get tableName => 'local_notes';

  TextColumn get id => text()();
  TextColumn get teachingId => text().nullable()();
  TextColumn get title => text().nullable()();
  TextColumn get content => text().nullable()();
  TextColumn get body => text().withDefault(const Constant(''))();
  TextColumn get categoryId => text().nullable()();
  BoolColumn get pinned => boolean().withDefault(const Constant(false))();
  DateTimeColumn get clientCreatedAt => dateTime()();

  /// L'horloge de l'**appareil** à la dernière frappe. Envoyée au serveur
  /// (`clientUpdatedAt`) pour qu'un rejeu en retard n'écrase pas une frappe
  /// plus récente faite ailleurs, et comparée à l'`updatedAt` serveur pour
  /// savoir quand cette ligne peut partir.
  DateTimeColumn get clientUpdatedAt => dateTime()();

  /// Reste-t-il un envoi à faire ? Vrai à chaque frappe, faux après un `2xx`.
  BoolColumn get dirty => boolean().withDefault(const Constant(true))();

  /// Le dernier échec d'envoi, pour le diagnostic — aucun écran ne le lit.
  TextColumn get lastError => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// **L'outbox des pièces jointes** (N4) — définie ici, remplie par personne
/// dans cette tranche.
@DataClassName('PendingNoteMediaRow')
class PendingNoteMedia extends Table {
  @override
  String get tableName => 'pending_note_media';

  TextColumn get noteId => text()();

  /// L'identifiant de l'embed dans le Delta, frappé par le client.
  TextColumn get embedId => text()();
  TextColumn get kind => text()();
  TextColumn get localPath => text()();
  TextColumn get thumbPath => text().nullable()();
  TextColumn get mime => text().nullable()();
  IntColumn get size => integer().nullable()();
  IntColumn get duration => integer().nullable()();

  /// La clé posée par le serveur une fois téléversé.
  TextColumn get key => text().nullable()();
  TextColumn get thumbKey => text().nullable()();
  TextColumn get error => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {noteId, embedId};
}
