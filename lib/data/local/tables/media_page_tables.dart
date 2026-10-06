/// Tables des trois collections répliquées de **la médiathèque en pages** (M4,
/// mobile #167 ; serveur #540, plan `server-portal/docs/mediatheque-pages-plan.md`) :
/// `media_pages` (un onglet), `media_page_chips` (ses puces) et
/// `media_page_sections` (ses sections).
///
/// Les règles de `mediatheque_tables.dart` valent mot pour mot : aucune clé
/// étrangère entre collections — `mediaPageId` est un **entier nu**, une puce
/// arrivée avant sa page attend le cycle suivant —, on stocke ce que le serveur
/// envoie, chaque ligne porte son jeton d'écriture ([SyncedRow]).
///
/// **Avec tombstone**, à la différence de `menu_entries` : une page n'a rien à
/// décocher, la retirer c'est la supprimer, et sans tombstone l'onglet
/// resterait sur chaque téléphone. Le tombstone retire la ligne (défaut du
/// moteur).
///
/// Les rubriques et branches sont des **slugs**, résolus à la lecture ; les
/// gabarits, tris et familles sont des **chaînes libres**, traduites à la
/// lecture (`models/media_page_view.dart`).
library;

import 'package:drift/drift.dart';

import '../converters/i18n_map_converter.dart';
import '../converters/string_list_converter.dart';
import 'mediatheque_tables.dart' show SyncedRow;

/// Collection `media_pages` (partition `reference`, servie sans compte).
/// `locked` et `ranked_at` restent au portail.
@DataClassName('MediaPageRow')
class MediaPages extends Table with SyncedRow {
  @override
  String get tableName => 'media_pages';

  IntColumn get id => integer()();

  /// La clé du dépôt (`public.nav.*` pour une page reprise d'une entrée de
  /// menu), traduite par `l10n/menu_labels.dart`. Indissociable de [label].
  TextColumn get labelKey => text().nullable()();

  /// La surcharge, carte entière. `null` = le libellé porté par [labelKey].
  TextColumn get label => text().map(const I18nMapConverter()).nullable()();

  /// Un ordre relatif, jamais un numéro stable.
  IntColumn get position => integer().withDefault(const Constant(0))();

  /// Le filtre de la page, composé avec la source de chacune de ses sections.
  TextColumn get destinationFamily => text().nullable()();
  TextColumn get destinationRubric => text().nullable()();
  TextColumn get destinationBranch => text().nullable()();
  TextColumn get destinationSearch => text().nullable()();

  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Collection `media_page_chips` : un filtre qui, choisi, affine **chaque**
/// section de sa page.
@DataClassName('MediaPageChipRow')
class MediaPageChips extends Table with SyncedRow {
  @override
  String get tableName => 'media_page_chips';

  IntColumn get id => integer()();
  IntColumn get mediaPageId => integer()();

  /// Toujours servi (non nul côté serveur) : le libellé est la seule identité
  /// d'une puce.
  TextColumn get label => text().map(const I18nMapConverter())();
  IntColumn get position => integer().withDefault(const Constant(0))();

  TextColumn get filterRubric => text().nullable()();
  TextColumn get filterBranch => text().nullable()();
  TextColumn get filterSearch => text().nullable()();

  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Collection `media_page_sections` : une source, un tri, un gabarit, un
/// plafond.
@DataClassName('MediaPageSectionRow')
class MediaPageSections extends Table with SyncedRow {
  @override
  String get tableName => 'media_page_sections';

  IntColumn get id => integer()();
  IntColumn get mediaPageId => integer()();
  IntColumn get position => integer().withDefault(const Constant(0))();

  /// Un mot du vocabulaire réglable (`sectionLatestTeachings`), prioritaire
  /// sur [title]. Les deux nuls : pas d'en-tête.
  TextColumn get titleKey => text().nullable()();
  TextColumn get title => text().map(const I18nMapConverter()).nullable()();

  /// `hero` · `carousel` · `list` · `grid`, en chaîne libre.
  TextColumn get layout => text()();

  /// `latest` · `popular` · `manual`, en chaîne libre.
  TextColumn get sort => text()();
  IntColumn get maxItems => integer().withDefault(const Constant(10))();

  /// La source. La famille est requise côté serveur.
  TextColumn get destinationFamily => text()();
  TextColumn get destinationRubric => text().nullable()();
  TextColumn get destinationBranch => text().nullable()();
  TextColumn get destinationSearch => text().nullable()();

  /// Tri `manual` : la sélection ordonnée. `null` = rien choisi.
  TextColumn get manualIds =>
      text().map(const StringListConverter()).nullable()();

  /// Tri `popular` : le classement matérialisé chaque nuit. `null` = jamais
  /// calculé, et la section montre alors les plus récents.
  TextColumn get rankedIds =>
      text().map(const StringListConverter()).nullable()();

  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
