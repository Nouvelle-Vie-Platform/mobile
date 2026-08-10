/// Tables de **données** des deux collections répliquées des rassemblements :
/// `gathering_types` et `gatherings` (issue serveur #133).
///
/// **Un rassemblement n'est pas un enseignement.** Concert, convention,
/// formation, forum, croisade : ce qui *se rassemble*, par opposition à ce qui
/// *s'enseigne*. Côté serveur les deux familles partagent une table, discriminée
/// par une colonne `family` — mais **cette colonne ne voyage pas**, et ces
/// tables-ci n'en portent pas davantage : la **clé de collection est le seul
/// discriminant** (ADR-0026, décision 1). Servir un champ dont le filtre
/// garantit qu'il vaut toujours la même valeur serait une constante déguisée en
/// donnée, et installerait chez le client l'idée qu'il lui revient de trier ce
/// qui arrive par un canal. Le canal trie à sa place.
///
/// Les trois règles de `mediatheque_tables.dart` valent ici **mot pour mot**, et
/// pour les mêmes raisons — aucune clé étrangère entre collections, on stocke ce
/// que le serveur envoie, chaque ligne porte son jeton d'écriture. Rien de neuf
/// n'est inventé ici.
///
/// ## Pourquoi ces colonnes sont recopiées et non partagées par un mixin
///
/// La charge utile d'un rassemblement est **exactement** celle d'un enseignement
/// (dix-huit clés) et celle d'une rubrique de rassemblement celle d'une rubrique
/// d'enseignement (dix clés). La tentation de factoriser les colonnes dans un
/// `mixin` est donc forte, et elle est refusée : **une déclaration de table
/// Drift est son DDL**. Déplacer les colonnes de `teachings` dans un mixin en
/// changerait l'ordre dans le `CREATE TABLE` généré, donc le schéma exporté,
/// donc exigerait une migration sur les téléphones installés — pour zéro
/// changement de comportement. Le partage se fait là où il ne coûte rien : au
/// **modèle de lecture** (`models/content_view.dart`) et aux widgets.
library;

import 'package:drift/drift.dart';

import '../converters/i18n_map_converter.dart';
import 'mediatheque_tables.dart';

/// Collection `gathering_types` — la **rubrique** d'un rassemblement.
///
/// Le jumeau de `teaching_types` pour l'autre famille : même partition
/// `reference`, même charge utile, même rôle — [position] donne l'ordre,
/// [layout] la mise en page, [visibleOnHome] la visibilité, [color] le dernier
/// maillon de la cascade.
///
/// **Les deux référentiels ne se mélangent jamais** : le serveur ne livre à
/// `gathering_types` que les rubriques de la famille `gathering`, et à
/// `teaching_types` que celles de la famille `teaching`. C'est ce qui garde
/// cohérent ce que reçoit le client — une rubrique « Concerts » servie à la
/// médiathèque composerait une section que le catalogue, filtré lui aussi, ne
/// pourrait jamais remplir.
///
/// Comme `teaching_types`, elle se supprime **durement et sans tombstone** :
/// aucun message de retrait ne voyage, et c'est la lecture qui répare — « pas de
/// rassemblement, pas de section », voir `GatheringDao.homeSections`.
@DataClassName('GatheringTypeRow')
class GatheringTypes extends Table with SyncedRow {
  @override
  String get tableName => 'gathering_types';

  IntColumn get id => integer()();

  /// Carte de traduction **entière** `{fr, en, ee}` — jamais la langue retenue.
  /// Le repli se fait à la lecture, via `utils/i18n_text.dart` → `pick`.
  TextColumn get label => text().map(const I18nMapConverter())();

  /// Clé stable que le mobile reconnaît : elle survit au renommage du libellé.
  TextColumn get slug => text()();

  TextColumn get icon => text().nullable()();

  /// Couleur de la rubrique — **dernier maillon** de la cascade, résolue à la
  /// lecture et jamais à l'écriture.
  TextColumn get color => text().nullable()();

  IntColumn get position => integer().withDefault(const Constant(0))();

  /// `false` = la rubrique a quitté l'accueil, mais ses rassemblements restent.
  BoolColumn get visibleOnHome => boolean().withDefault(const Constant(true))();

  /// `hero` | `carousel` | `list`. Stocké **tel quel**, jamais en enum : le
  /// référentiel est administrable. Une valeur inconnue se replie à l'affichage.
  TextColumn get layout => text().nullable()();

  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Collection `gatherings` — les rassemblements de la médiathèque.
///
/// **Pas de champ de famille**, et il n'y en aura pas : le serveur ne le sert
/// pas, et ce n'est pas un oubli (voir l'en-tête de ce fichier).
///
/// Un élément de ce flux est **soit** un rassemblement complet, **soit** une
/// rétractation réduite à `{ id, deletedAt }` (ADR-0025), exactement comme
/// `teachings`. La décision se prend avant toute construction : une rétractation
/// efface la ligne locale, et rien n'est désérialisé.
///
/// > **La verrue, assumée et documentée** : la référence de rubrique s'appelle
/// > [teachingTypeId] — c'est le nom de la colonne FK de la table partagée côté
/// > serveur — et elle se joint sur **`gathering_types`**. Renommer le champ
/// > dans la charge utile aurait cassé les consommateurs de `teachings`, qui le
/// > lisent déjà. Le protocole a préféré une verrue nommée à une rupture
/// > silencieuse ; le magasin porte le même nom pour que la ligne locale et la
/// > ligne du fil se lisent l'une dans l'autre.
@DataClassName('GatheringRow')
class Gatherings extends Table with SyncedRow {
  @override
  String get tableName => 'gatherings';

  /// UUIDv7 servi par le serveur, **en chaîne**.
  TextColumn get id => text()();

  TextColumn get ownerId => text().nullable()();

  /// Branche organisatrice ; `null` = portée **nationale**.
  IntColumn get branchId => integer().nullable()();

  /// **Entier nu, sans clé étrangère** vers `contributors` — le référentiel des
  /// intervenants est commun aux deux familles, et les collections se
  /// resynchronisent séparément.
  IntColumn get contributorId => integer().nullable()();

  /// **Entier nu, sans clé étrangère** vers `gathering_types`. Le nom du champ
  /// est celui du fil (voir la verrue, en tête de classe) ; la table jointe est
  /// bien celle des rubriques de **rassemblement**.
  IntColumn get teachingTypeId => integer().nullable()();

  /// Titre **monolingue** : le serveur sert une chaîne, pas une carte.
  TextColumn get title => text()();

  TextColumn get description => text().nullable()();
  BoolColumn get isLive => boolean().withDefault(const Constant(false))();
  BoolColumn get isFullService =>
      boolean().withDefault(const Constant(false))();

  /// URL HLS publique. **Peut être nulle** : un rassemblement existe avant son
  /// média, et c'est une absence à dessiner, pas un cas impossible.
  TextColumn get playlistUrl => text().nullable()();

  /// URL **relative** : l'hôte de l'API change d'un environnement à l'autre, la
  /// résolution appartient au client.
  TextColumn get imageLandscapeUrl => text().nullable()();
  TextColumn get imagePortraitUrl => text().nullable()();

  DateTimeColumn get publishedAt => dateTime().nullable()();
  DateTimeColumn get clientCreatedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  /// **Un jour de calendrier, pas un instant** : `YYYY-MM-DD`, stocké en texte.
  /// La date d'un concert ne se décale pas d'un fuseau.
  TextColumn get recordedAt => text().nullable()();

  /// Couleur **brute** de la colonne serveur. `null` = « hérite de ma
  /// rubrique » : la cascade se termine à la lecture.
  TextColumn get color => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
