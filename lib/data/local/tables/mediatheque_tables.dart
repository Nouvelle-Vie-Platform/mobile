/// Tables de **données** des quatre collections répliquées du chantier
/// médiathèque : `branches`, `teaching_types`, `contributors`, `teachings`.
///
/// Trois règles traversent ce fichier, et aucune n'est négociable (ADR-0026) :
///
/// 1. **Aucune clé étrangère entre collections.** Contre-intuitif venant de
///    SQL, et voulu : les collections arrivent et se resynchronisent
///    séparément, rien ne garantit qu'un enseignement et son intervenant soient
///    à jour au même instant. Une contrainte d'intégrité ferait échouer
///    l'application d'une page parfaitement valide — et, par l'invariant
///    transactionnel, la page **entière** avec elle. `contributorId` et
///    `teachingTypeId` sont des entiers nus.
/// 2. **On stocke ce que le serveur envoie, pas ce que l'écran affiche.** La
///    carte de traduction entière et non la langue choisie, la couleur brute et
///    non la couleur résolue, toutes les rubriques y compris celles qui ont
///    quitté l'accueil. Ce qui dépend d'autre chose se joint à la lecture.
/// 3. **Chaque ligne porte son jeton d'écriture** ([SyncedRow.syncStamp]) :
///    c'est ce qui permet au balayage de fin de resync de ne supprimer que les
///    lignes que le cycle n'a pas revues, sans avoir rien vidé d'abord.
library;

import 'package:drift/drift.dart';

import '../converters/i18n_map_converter.dart';

/// Jeton d'écriture porté par **toute** ligne d'une collection répliquée.
///
/// Valeur d'un compteur monotone local (`sync_state.next_stamp`), allouée à
/// chaque transaction d'application. Elle n'a aucun sens hors de l'appareil et
/// ne voyage jamais : elle ne sert qu'à répondre à « cette ligne a-t-elle été
/// revue depuis le début du cycle de resync ? ».
mixin SyncedRow on Table {
  /// Jeton de la transaction qui a écrit cette ligne pour la dernière fois.
  ///
  /// Le défaut existe pour que l'appelant n'ait **pas** à le renseigner : le
  /// jeton est une mécanique du magasin, posée par `SyncDao`, pas une donnée du
  /// serveur. Une ligne qui arriverait ici sans jeton porterait `0`, donc
  /// serait traitée comme jamais revue — la panne va dans le sens sûr.
  IntColumn get syncStamp => integer().withDefault(const Constant(0))();
}

/// Collection `branches` (partition `reference`, aucun tombstone).
///
/// `id` est un **SERIAL** côté serveur : il se compare directement à
/// `User.branchId`.
@DataClassName('BranchRow')
class Branches extends Table with SyncedRow {
  @override
  String get tableName => 'branches';

  IntColumn get id => integer()();
  TextColumn get name => text()();
  BoolColumn get isMotherChurch =>
      boolean().withDefault(const Constant(false))();
  TextColumn get address => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get postalBox => text().nullable()();
  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Collection `teaching_types` — la **rubrique** d'un enseignement.
///
/// C'est le serveur qui compose l'accueil : [position] donne l'ordre, [layout]
/// la mise en page, [visibleOnHome] la visibilité. Le référentiel est servi
/// **entier**, masquées comprises — c'est [visibleOnHome] qui apprend au client
/// qu'une rubrique a quitté l'accueil, et le filtrer à l'écriture ferait
/// disparaître l'information au lieu de la propager.
///
/// **Elle se supprime durement et sans tombstone.** C'est la seule collection
/// de référence qu'un administrateur peut supprimer, et la ligne cesse
/// simplement d'apparaître dans le flux : **aucun message de retrait ne
/// voyage**. Le téléphone garderait une section fantôme définitivement vide. La
/// correction est côté lecture et se répare toute seule — « pas
/// d'enseignement, pas de section », voir `MediathequeDao.homeSections`.
@DataClassName('TeachingTypeRow')
class TeachingTypes extends Table with SyncedRow {
  @override
  String get tableName => 'teaching_types';

  IntColumn get id => integer()();

  /// Carte de traduction **entière** `{fr, en, ee}` — jamais la langue retenue.
  /// Le repli se fait à la lecture, via `utils/i18n_text.dart` → `pick`.
  TextColumn get label => text().map(const I18nMapConverter())();

  /// Clé stable que le mobile reconnaît : elle survit au renommage du libellé.
  TextColumn get slug => text()();

  TextColumn get icon => text().nullable()();

  /// Couleur de la rubrique — **dernier maillon** de la cascade. Un
  /// enseignement dont la couleur est nulle hérite de celle-ci, et l'héritage
  /// se calcule à la lecture : le stocker sur l'enseignement figerait une
  /// valeur que changer la couleur d'une rubrique ne mettrait jamais à jour.
  TextColumn get color => text().nullable()();

  IntColumn get position => integer().withDefault(const Constant(0))();

  /// `false` = la rubrique a quitté l'accueil, mais ses enseignements restent.
  BoolColumn get visibleOnHome => boolean().withDefault(const Constant(true))();

  /// `hero` | `carousel` | `list`. Stocké **tel quel**, jamais en enum : un
  /// enum est une décision figée à l'écriture, et le référentiel est
  /// administrable. Une valeur inconnue se replie à l'affichage.
  TextColumn get layout => text().nullable()();

  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Collection `contributors` — l'intervenant d'un enseignement.
///
/// Le serveur sert `id`, `name`, `bio`, `createdAt`, `updatedAt`. **Ni
/// catégorie, ni civilité** : ne pas prévoir de colonnes pour ce qui ne voyage
/// pas.
@DataClassName('ContributorRow')
class Contributors extends Table with SyncedRow {
  @override
  String get tableName => 'contributors';

  IntColumn get id => integer()();
  TextColumn get name => text()();
  TextColumn get bio => text().nullable()();
  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Collection `teachings` — le contenu de la médiathèque.
///
/// **Pas de champ de famille**, et il n'y en aura pas : un enseignement et un
/// rassemblement sont deux collections, deux types, deux écrans. La clé de
/// collection est le seul discriminant (ADR-0026, décision 1).
///
/// Un élément de ce flux est **soit** un enseignement complet, **soit** une
/// rétractation réduite à `{ id, deletedAt }`. La décision se prend avant toute
/// construction : une rétractation efface la ligne locale, et rien n'est
/// désérialisé. Ce magasin n'en garde aucune trace — le retrait est un retrait,
/// garder le titre d'un contenu dépublié annulerait le geste.
@DataClassName('TeachingRow')
class Teachings extends Table with SyncedRow {
  @override
  String get tableName => 'teachings';

  /// UUIDv7 servi par le serveur, **en chaîne**.
  TextColumn get id => text()();

  TextColumn get ownerId => text().nullable()();

  /// Branche organisatrice ; `null` = portée **nationale**.
  IntColumn get branchId => integer().nullable()();

  /// **Entier nu, sans clé étrangère** vers `contributors` : les deux
  /// collections se resynchronisent séparément. Un enseignement dont
  /// l'intervenant manque doit pouvoir être écrit, puis s'afficher.
  IntColumn get contributorId => integer().nullable()();

  /// **Entier nu, sans clé étrangère** vers `teaching_types`, même raison.
  IntColumn get teachingTypeId => integer().nullable()();

  /// Titre **monolingue** : le serveur sert une chaîne, pas une carte de
  /// traduction (contrairement à `teaching_types.label`).
  TextColumn get title => text()();

  TextColumn get description => text().nullable()();
  BoolColumn get isLive => boolean().withDefault(const Constant(false))();
  BoolColumn get isFullService =>
      boolean().withDefault(const Constant(false))();

  /// URL HLS publique. **Peut être nulle** : un enseignement existe avant son
  /// média, et c'est une absence à dessiner, pas un cas impossible.
  TextColumn get playlistUrl => text().nullable()();

  /// URL **relative** (`/uploads/teachings/….jpg`) : l'hôte de l'API change
  /// d'un environnement à l'autre, la résolution appartient au client.
  TextColumn get imageLandscapeUrl => text().nullable()();
  TextColumn get imagePortraitUrl => text().nullable()();

  DateTimeColumn get publishedAt => dateTime().nullable()();
  DateTimeColumn get clientCreatedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  /// **Un jour de calendrier, pas un instant** : `YYYY-MM-DD`, stocké en texte.
  /// Le lire en `DateTime` l'ancrerait à un instant, que le fuseau du lecteur
  /// afficherait un jour trop tôt. La date d'un culte ne se décale pas.
  TextColumn get recordedAt => text().nullable()();

  /// Couleur **brute** de la colonne serveur. `null` = « hérite de ma
  /// rubrique » : la cascade se termine à la lecture, sur une rubrique que le
  /// magasin possède déjà. Stocker la couleur résolue figerait une valeur que
  /// changer la couleur d'une rubrique ne toucherait jamais.
  TextColumn get color => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
