/// Table de la collection répliquée `menu_entries` — **les entrées de menu**,
/// c'est-à-dire ce qui porte un libellé, une visibilité et un ordre **par
/// surface**, et une destination décrite en termes métier (#82, jumelle serveur
/// #480).
///
/// Les règles de `mediatheque_tables.dart` valent ici mot pour mot : aucune clé
/// étrangère entre collections, **on stocke ce que le serveur envoie**, chaque
/// ligne porte son jeton d'écriture ([SyncedRow]).
///
/// ## **Entrée de menu**, jamais « onglet »
///
/// L'onglet est le *rendu* d'une entrée sur **une** surface. Une même entrée
/// paraît dans la médiathèque et à l'accueil, sous deux gabarits et à deux rangs
/// indépendants — d'où quatre colonnes de surface côté serveur, dont deux
/// seulement descendent ici.
///
/// ## Le serveur sert **toutes** les lignes ; c'est le client qui masque
///
/// Une entrée éteinte sur les deux surfaces mobiles arrive quand même, et une
/// entrée sortie de sa fenêtre de publication aussi. Ce n'est pas une
/// négligence, c'est le seul choix sûr : **la collection n'a pas de tombstone**,
/// donc une ligne écartée par un filtre serveur ne quitterait pas le flux avec
/// un drapeau de retrait — elle cesserait simplement d'y paraître, et
/// l'appareil qui l'avait déjà reçue la garderait pour toujours. En servant
/// [mediaVisible] / [homeVisible] comme des **colonnes**, c'est le décochage
/// lui-même qui voyage.
///
/// Corollaire, et c'est la règle de lecture de cette collection : **rien de ce
/// qui est stocké ici n'est un filtre d'écriture**. Le masquage et la fenêtre
/// s'évaluent à la lecture, et à un seul endroit (`StoreMenuRepository`).
///
/// ## Ni enum, ni contrainte, ni clé étrangère
///
/// [destinationKind] est une **chaîne libre** : un enum côté client est une
/// décision figée à l'écriture, et un type inconnu doit faire **disparaître**
/// l'entrée en silence, sans repli sur une destination de substitution
/// (décision 13 du cadrage). [homeLayout] suit le même patron que
/// `teaching_types.layout`.
///
/// [parentId] est un **entier nu**, sans contrainte : une sous-entrée dont le
/// parent n'est pas encore en magasin ne doit pas faire échouer l'application de
/// la page — elle paraîtra au cycle suivant.
///
/// ## Huit colonnes ne descendent pas, et c'est énuméré côté serveur
///
/// La table serveur en porte **trente-neuf** ; le transformer en énumère
/// **trente et une**. Ne restent là-bas que les deux surfaces du site et leurs
/// rangs (`header*`, `footer*`), l'aperçu de partage (`share*`), le visuel
/// d'en-tête (`heroImageUrl`) et le verrou éditorial (`locked`) — un garde-fou
/// de l'écran d'administration, dont un téléphone n'a rien à faire.
library;

import 'package:drift/drift.dart';

import '../converters/i18n_map_converter.dart';
import 'mediatheque_tables.dart' show SyncedRow;

/// Collection `menu_entries` (partition `reference`, **sans tombstone**).
///
/// `partition: 'reference'` : un menu n'appartient à aucune branche — il y a un
/// site public et une application, et la barre réglée depuis Aného est celle de
/// Lomé.
///
/// Elle est servie **sans compte** côté serveur (`servesAnonymous: true`), et ce
/// n'est pas un confort : la médiathèque et l'accueil sont les deux écrans qu'un
/// porteur sans compte ouvre en premier. Sans le drapeau, le tirage rend 403 et
/// l'application d'un invité n'a **aucun** onglet — pas une liste dégradée, pas
/// un repli : rien.
///
/// **Pas de tombstone, et c'est un manque assumé.** `SaveMenu` écrit le menu en
/// entier : une entrée que le tableau posté ne nomme plus est supprimée
/// durement, et la ligne cesse d'apparaître au flux sans rien annoncer. La
/// réparation appartient au client, sur le patron « pas de contenu, pas de
/// section » — une entrée dont la destination ne ramène rien ne paraît pas.
@DataClassName('MenuEntryRow')
class MenuEntries extends Table with SyncedRow {
  @override
  String get tableName => 'menu_entries';

  /// PK **SERIAL** côté serveur, donc un `id` numérique dans le curseur
  /// composé — contrairement à `presentation_vocabulary`, dont la clé est
  /// textuelle.
  IntColumn get id => integer()();

  /// Le parent d'une sous-entrée, ou `null`. **Un entier nu, sans contrainte** :
  /// voir l'en-tête du fichier.
  ///
  /// La profondeur est bornée à un niveau côté serveur (`SaveMenu`), pas par le
  /// schéma. Le client n'a pas à la rejouer : il range les enfants sous leur
  /// parent et ignore un orphelin.
  IntColumn get parentId => integer().nullable()();

  /// La clé de traduction du dépôt — une clé `.arb` ici —, ou `null`.
  ///
  /// **Indissociable de [label]** : `label = null` ne veut pas dire « pas de
  /// libellé », mais « le libellé du dépôt », c'est-à-dire la traduction que
  /// porte cette clé. Les sept entrées reprises de l'ancienne barre arrivent
  /// ainsi, et c'est ce qui leur fait suivre les corrections du dépôt sans que
  /// personne rouvre l'écran d'administration.
  TextColumn get labelKey => text().nullable()();

  /// La **surcharge** du libellé, carte de traduction entière (ADR-0023).
  /// `null` = le libellé du dépôt, porté par [labelKey].
  TextColumn get label => text().map(const I18nMapConverter()).nullable()();

  /// Un nom d'icône du kit, ou `null`. Stocké tel quel : le kit du portail
  /// (`lucide`) n'est pas celui de l'application, et c'est à l'affichage de
  /// faire ce qu'il peut d'un nom inconnu.
  TextColumn get icon => text().nullable()();

  /// La mise en avant (bouton d'accent) et le filet séparateur. Deux
  /// décorations que le portail règle et dont chaque surface fait ce qu'elle
  /// peut : décider **ici** qu'une décoration n'est pas rendable serait la même
  /// faute que filtrer les destinations.
  BoolColumn get featured => boolean().withDefault(const Constant(false))();
  BoolColumn get divided => boolean().withDefault(const Constant(false))();

  /// `page` · `catalogue` · `theme` · `intervenant` · `externe`, **en chaîne
  /// libre**. Un type que ce binaire ne connaît pas fait disparaître l'entrée,
  /// en silence et sans repli (décision 13).
  TextColumn get destinationKind => text()();

  /// `page` : `accueil` · `contact` · `themes` · `rencontres` · `mediatheque`.
  /// Une clé **métier**, jamais un chemin : c'est la surface qui la traduit.
  TextColumn get destinationPage => text().nullable()();

  /// `catalogue` : `teaching` ou `gathering` — **quelle collection lire**.
  ///
  /// Ce n'est pas l'étiquette d'une ligne de contenu (ADR-0026 décision 1
  /// l'interdit, et le serveur ne sert toujours pas `teachings.family`) : c'est
  /// une part de l'**intention** de l'entrée, et c'est précisément ce qui
  /// apprend au client par quel canal remplir son onglet.
  TextColumn get destinationFamily => text().nullable()();

  /// `catalogue` : le **slug** d'une rubrique, ou `null` — le catalogue entier.
  ///
  /// Un slug, **jamais un `id`** : c'est ce que porte l'URL publique, et c'est ce
  /// que le client retrouve sur ses lignes de `teaching_types` /
  /// `gathering_types`.
  TextColumn get destinationRubric => text().nullable()();

  /// `catalogue` : le **slug** d'une branche, ou `null`.
  ///
  /// ⚠️ **Ce client ne sait pas le résoudre aujourd'hui**, et ce n'est pas un
  /// oubli de cette tranche : `BranchTransformer` ne sert pas de slug au flux
  /// delta (`id`, `name` composé, `city`, et rien d'autre), donc la copie locale
  /// de `branches` n'en porte aucun. Une entrée qui exige une branche ne trouve
  /// donc aucune ligne, et « pas de contenu, pas de section » la retire — ce qui
  /// est le bon sens de la panne : mieux vaut une entrée absente qu'un onglet
  /// « Aného » qui montrerait le catalogue entier.
  TextColumn get destinationBranch => text().nullable()();

  /// `catalogue` : une recherche figée, ou `null`. Elle se **compose** avec ce
  /// que la loupe de l'écran saisit : l'entrée borne, le fidèle affine.
  TextColumn get destinationSearch => text().nullable()();

  /// `theme` : la série visée (UUID côté serveur).
  ///
  /// Aucune collection de séries n'est répliquée ici, donc aucune entrée de ce
  /// type ne se rend : la colonne existe parce qu'on stocke ce que le serveur
  /// envoie, pas parce que l'écran saurait quoi en faire.
  TextColumn get destinationSeriesId => text().nullable()();

  /// `intervenant` : la fiche visée. Même remarque que [destinationSeriesId] —
  /// il n'existe pas d'écran d'intervenant sur ce client.
  IntColumn get destinationContributorId => integer().nullable()();

  /// `externe` : l'adresse `http(s)` saisie au portail. **Le seul chemin que le
  /// dépôt ne compose pas**, et le seul que personne ne peut promettre.
  TextColumn get destinationUrl => text().nullable()();

  /// Les quatre puces que l'entrée offre au visiteur. La case « recherche »
  /// attendait la loupe de cet écran.
  BoolColumn get filterRubric => boolean().withDefault(const Constant(false))();
  BoolColumn get filterBranch => boolean().withDefault(const Constant(false))();
  BoolColumn get filterFamily => boolean().withDefault(const Constant(false))();
  BoolColumn get filterSearch => boolean().withDefault(const Constant(false))();

  /// La surface « médiathèque mobile » : paraître ou non, et à quel rang.
  ///
  /// ⚠️ **[mediaPosition] est un ordre relatif, jamais un numéro stable** :
  /// `SaveMenu` renumérote `1..n` par surface à chaque enregistrement. Rien ne
  /// doit figer une valeur — ni un écran, ni un test.
  BoolColumn get mediaVisible => boolean().withDefault(const Constant(false))();
  IntColumn get mediaPosition => integer().withDefault(const Constant(0))();

  /// La surface « accueil mobile », son rang, et son **gabarit** —
  /// `hero` · `carousel` · `list`, `null` hors de cette surface. Chaîne libre,
  /// comme `teaching_types.layout` : un gabarit inconnu se replie à
  /// l'affichage.
  BoolColumn get homeVisible => boolean().withDefault(const Constant(false))();
  IntColumn get homePosition => integer().withDefault(const Constant(0))();
  TextColumn get homeLayout => text().nullable()();

  /// La fenêtre de publication, bornes **indépendantes et facultatives**,
  /// servies brutes.
  ///
  /// ⚠️ Des **instants**, pas des jours — contrairement aux deux bornes de
  /// `seasons`, qui sont des chaînes `YYYY-MM-DD` comparées comme des chaînes.
  /// Ici le serveur sert des `timestamp` et `ReadMenu` les compare à l'heure
  /// courante : la comparaison du client se fait donc à `DateTime.now()`.
  DateTimeColumn get publishedFrom => dateTime().nullable()();
  DateTimeColumn get publishedUntil => dateTime().nullable()();

  /// Le lot éditorial **de la page** que l'entrée désigne — pas celui du
  /// partage, qui ne descend pas. Deux cartes de traduction entières, comme
  /// [label], et `null` = ce que l'écran compose déjà.
  TextColumn get pageTitle => text().map(const I18nMapConverter()).nullable()();
  TextColumn get pageDescription =>
      text().map(const I18nMapConverter()).nullable()();

  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
