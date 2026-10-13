/// **Toutes les tables du module Bible** (M1, #199) — schéma v29, posé en une
/// seule étape pour les tranches M1 à M7 : **aucune autre tranche ne change le
/// schéma** (plan du module, §3 « Mobile »).
///
/// Trois familles, le patron de `note_tables.dart` :
///
/// - **Miroirs `SyncedRow`** des collections serveur, remplis par la
///   synchronisation seule (ADR-0026) — l'application n'y écrit **jamais**.
///   Privées (S1) : `bible_marks`, `bible_reading_states`,
///   `bible_plan_enrollments`, `bible_quiz_results`. De référence (S2–S5,
///   lues par les invités) : `bible_verse_of_days`, `bible_sunday_passages`,
///   `bible_plans`, `bible_challenges`, `bible_quizzes`, `bible_versions`.
/// - **Tables locales `local_bible_*`** : les brouillons de l'invité **et** la
///   file d'envoi du membre (mêmes colonnes que le miroir, plus `dirty`,
///   `clientUpdatedAt`, `lastError`). Une ligne y vit tant que le delta n'a
///   pas ramené la sienne avec `updatedAt ≥ clientUpdatedAt`.
/// - **Tables propres à l'appareil** : `bible_installed_versions`, et l'index
///   plein texte `bible_fts` (FTS5, `bible_fts.drift`).
///
/// **Identifiants** (plan §6) : entiers (SERIAL) pour `bible_verse_of_days`,
/// `bible_sunday_passages`, `bible_quizzes`, `bible_versions` — donc
/// `quizId` entier ; UUID texte pour les quatre privées, `bible_plans` et
/// `bible_challenges` — donc `planId` / `challengeId` texte. Toutes les
/// collections portent un tombstone (`deletedAt`) : il **retire** la ligne,
/// aucune colonne ne le garde.
///
/// **Les champs `jsonb`** (`readChapters`, `completedDays`, `custom`, `days`,
/// `references`, `questions`) sont rangés **bruts**, ré-encodés en JSON : c'est
/// l'écran qui les lit. **Les jours** (`lastReadOn`, `startedOn`, `day`…)
/// restent des chaînes `YYYY-MM-DD` : un jour n'est pas un instant.
///
/// Toutes les colonnes non essentielles sont nullables : une ligne servie par
/// une version du serveur plus jeune ou plus vieille d'un champ se range quand
/// même. **Aucune clé étrangère** (règle 4 du magasin).
library;

import 'package:drift/drift.dart';

import 'mediatheque_tables.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Collections privées (S1)
// ─────────────────────────────────────────────────────────────────────────────

/// `bible_marks` — favoris, surlignages, marque-pages. Avec tombstone.
@DataClassName('BibleMarkRow')
class BibleMarks extends Table with SyncedRow {
  @override
  String get tableName => 'bible_marks';

  TextColumn get id => text()();
  TextColumn get ownerId => text().nullable()();

  /// `favorite | highlight | bookmark`.
  TextColumn get kind => text()();
  TextColumn get book => text()();
  IntColumn get chapter => integer()();
  IntColumn get verseFrom => integer().nullable()();
  IntColumn get verseTo => integer().nullable()();

  /// Surlignage : `yellow | green | blue | pink | purple`, brut.
  TextColumn get color => text().nullable()();
  DateTimeColumn get clientCreatedAt => dateTime().nullable()();
  DateTimeColumn get clientUpdatedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// `bible_reading_states` — **une ligne par utilisateur** : version, position,
/// chapitres lus, série.
@DataClassName('BibleReadingStateRow')
class BibleReadingStates extends Table with SyncedRow {
  @override
  String get tableName => 'bible_reading_states';

  TextColumn get id => text()();
  TextColumn get ownerId => text().nullable()();
  TextColumn get versionCode => text().nullable()();
  TextColumn get book => text().nullable()();
  IntColumn get chapter => integer().nullable()();
  IntColumn get verse => integer().nullable()();

  /// `{ "<OSIS>": [chapitres] }`, en JSON.
  TextColumn get readChapters => text().nullable()();
  IntColumn get streakDays => integer().withDefault(const Constant(0))();

  /// `YYYY-MM-DD`.
  TextColumn get lastReadOn => text().nullable()();
  DateTimeColumn get clientUpdatedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// `bible_plan_enrollments` — mes plans suivis (intégrés, publiés, perso).
@DataClassName('BiblePlanEnrollmentRow')
class BiblePlanEnrollments extends Table with SyncedRow {
  @override
  String get tableName => 'bible_plan_enrollments';

  TextColumn get id => text()();
  TextColumn get ownerId => text().nullable()();

  /// `builtin | published | custom`.
  TextColumn get source => text()();
  TextColumn get planCode => text().nullable()();
  TextColumn get planId => text().nullable()();

  /// `{ title, books: [OSIS], days }`, en JSON.
  TextColumn get custom => text().nullable()();

  /// `YYYY-MM-DD`.
  TextColumn get startedOn => text().nullable()();

  /// `[int]`, en JSON.
  TextColumn get completedDays => text().nullable()();
  TextColumn get challengeId => text().nullable()();
  DateTimeColumn get clientCreatedAt => dateTime().nullable()();
  DateTimeColumn get clientUpdatedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// `bible_quiz_results` — mes scores.
@DataClassName('BibleQuizResultRow')
class BibleQuizResults extends Table with SyncedRow {
  @override
  String get tableName => 'bible_quiz_results';

  TextColumn get id => text()();
  TextColumn get ownerId => text().nullable()();
  IntColumn get quizId => integer()();
  IntColumn get score => integer().withDefault(const Constant(0))();
  IntColumn get total => integer().withDefault(const Constant(0))();
  IntColumn get durationSeconds => integer().nullable()();
  DateTimeColumn get playedAt => dateTime().nullable()();
  DateTimeColumn get clientUpdatedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

// ─────────────────────────────────────────────────────────────────────────────
// Collections de référence (S2–S5) — lues par tous, invités compris
// ─────────────────────────────────────────────────────────────────────────────

/// `bible_verse_of_days` (S2).
@DataClassName('BibleVerseOfDayRow')
class BibleVerseOfDays extends Table with SyncedRow {
  @override
  String get tableName => 'bible_verse_of_days';

  IntColumn get id => integer()();

  /// `YYYY-MM-DD`.
  TextColumn get day => text()();
  TextColumn get book => text()();
  IntColumn get chapter => integer()();
  IntColumn get verseFrom => integer().nullable()();
  IntColumn get verseTo => integer().nullable()();
  TextColumn get comment => text().nullable()();

  /// `status_backgrounds.id`, entier nu.
  IntColumn get backgroundId => integer().nullable()();
  DateTimeColumn get publishedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// `bible_sunday_passages` (S2).
@DataClassName('BibleSundayPassageRow')
class BibleSundayPassages extends Table with SyncedRow {
  @override
  String get tableName => 'bible_sunday_passages';

  IntColumn get id => integer()();
  TextColumn get day => text()();

  /// `[référence]`, en JSON.
  TextColumn get references => text().nullable()();
  TextColumn get title => text().nullable()();
  TextColumn get teachingId => text().nullable()();
  TextColumn get gatheringId => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// `bible_plans` (S3) — plans publiés par l'église.
@DataClassName('BiblePlanRow')
class BiblePlans extends Table with SyncedRow {
  @override
  String get tableName => 'bible_plans';

  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  IntColumn get coverBackgroundId => integer().nullable()();

  /// `[[référence]]`, en JSON.
  TextColumn get days => text().nullable()();
  DateTimeColumn get publishedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// `bible_challenges` (S3) — défis communautaires.
@DataClassName('BibleChallengeRow')
class BibleChallenges extends Table with SyncedRow {
  @override
  String get tableName => 'bible_challenges';

  TextColumn get id => text()();
  TextColumn get planId => text().nullable()();
  TextColumn get title => text()();
  TextColumn get startsOn => text().nullable()();
  TextColumn get endsOn => text().nullable()();
  DateTimeColumn get publishedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// `bible_quizzes` (S4).
@DataClassName('BibleQuizRow')
class BibleQuizzes extends Table with SyncedRow {
  @override
  String get tableName => 'bible_quizzes';

  IntColumn get id => integer()();
  TextColumn get title => text()();

  /// `kids | teens | adults`.
  TextColumn get ageBand => text().nullable()();
  IntColumn get difficulty => integer().nullable()();
  TextColumn get featuredFrom => text().nullable()();
  TextColumn get featuredUntil => text().nullable()();
  TextColumn get imageUrl => text().nullable()();

  /// `[{ kind, prompt, choices, answer, explanation?, reference? }]`, en JSON.
  TextColumn get questions => text().nullable()();
  DateTimeColumn get publishedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// `bible_versions` (S5) — le catalogue servi.
@DataClassName('BibleVersionRow')
class BibleVersions extends Table with SyncedRow {
  @override
  String get tableName => 'bible_versions';

  IntColumn get id => integer()();
  TextColumn get code => text()();
  TextColumn get name => text()();
  TextColumn get language => text().nullable()();
  TextColumn get license => text().nullable()();
  IntColumn get sizeBytes => integer().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// Nul tant que le chantier du contenu n'existe pas.
  TextColumn get archiveUrl => text().nullable()();
  DateTimeColumn get publishedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

// ─────────────────────────────────────────────────────────────────────────────
// Brouillons de l'invité et file d'envoi du membre
// ─────────────────────────────────────────────────────────────────────────────

/// Les trois colonnes d'état d'envoi, communes aux `local_bible_*`.
mixin LocalBibleOutbox on Table {
  /// L'horloge de l'appareil au dernier geste ; envoyée au serveur.
  DateTimeColumn get clientUpdatedAt => dateTime()();

  /// Reste-t-il un envoi à faire ?
  BoolColumn get dirty => boolean().withDefault(const Constant(true))();

  /// Le dernier échec d'envoi, pour le diagnostic.
  TextColumn get lastError => text().nullable()();
}

@DataClassName('LocalBibleMarkRow')
class LocalBibleMarks extends Table with LocalBibleOutbox {
  @override
  String get tableName => 'local_bible_marks';

  TextColumn get id => text()();
  TextColumn get kind => text()();
  TextColumn get book => text()();
  IntColumn get chapter => integer()();
  IntColumn get verseFrom => integer().nullable()();
  IntColumn get verseTo => integer().nullable()();
  TextColumn get color => text().nullable()();
  DateTimeColumn get clientCreatedAt => dateTime()();

  /// Posé quand la marque est retirée et que le `DELETE` reste à partir.
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// **Une seule ligne** : la position de lecture de cet appareil.
@DataClassName('LocalBibleReadingStateRow')
class LocalBibleReadingState extends Table with LocalBibleOutbox {
  @override
  String get tableName => 'local_bible_reading_state';

  TextColumn get id => text()();
  TextColumn get versionCode => text().nullable()();
  TextColumn get book => text().nullable()();
  IntColumn get chapter => integer().nullable()();
  IntColumn get verse => integer().nullable()();
  TextColumn get readChapters => text().nullable()();
  IntColumn get streakDays => integer().withDefault(const Constant(0))();
  TextColumn get lastReadOn => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('LocalBiblePlanEnrollmentRow')
class LocalBiblePlanEnrollments extends Table with LocalBibleOutbox {
  @override
  String get tableName => 'local_bible_plan_enrollments';

  TextColumn get id => text()();
  TextColumn get source => text()();
  TextColumn get planCode => text().nullable()();
  TextColumn get planId => text().nullable()();
  TextColumn get custom => text().nullable()();
  TextColumn get startedOn => text().nullable()();
  TextColumn get completedDays => text().nullable()();
  TextColumn get challengeId => text().nullable()();
  DateTimeColumn get clientCreatedAt => dateTime()();

  /// Posé quand le plan est quitté et que le `DELETE` reste à partir.
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('LocalBibleQuizResultRow')
class LocalBibleQuizResults extends Table with LocalBibleOutbox {
  @override
  String get tableName => 'local_bible_quiz_results';

  TextColumn get id => text()();
  IntColumn get quizId => integer()();
  IntColumn get score => integer().withDefault(const Constant(0))();
  IntColumn get total => integer().withDefault(const Constant(0))();
  IntColumn get durationSeconds => integer().nullable()();
  DateTimeColumn get playedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

// ─────────────────────────────────────────────────────────────────────────────
// Appareil
// ─────────────────────────────────────────────────────────────────────────────

/// Les versions installées sur ce téléphone (M4 : téléchargement, hors ligne).
/// Les deux versions factices ne s'y inscrivent pas : elles sont installées
/// d'office par le catalogue factice.
@DataClassName('BibleInstalledVersionRow')
class BibleInstalledVersions extends Table {
  @override
  String get tableName => 'bible_installed_versions';

  TextColumn get code => text()();
  TextColumn get name => text()();
  TextColumn get language => text().nullable()();
  IntColumn get sizeBytes => integer().nullable()();

  /// Le dossier des fichiers de la version, s'il y en a.
  TextColumn get localPath => text().nullable()();
  DateTimeColumn get installedAt => dateTime()();

  /// L'index `bible_fts` de cette version est-il complet ? (M3)
  BoolColumn get indexed => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {code};
}
