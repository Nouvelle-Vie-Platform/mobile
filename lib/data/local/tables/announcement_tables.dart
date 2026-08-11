/// Tables de **données** des quatre collections répliquées des annonces :
/// `status_backgrounds`, `official_accounts`, `official_account_memberships` et
/// `announcements` (PRD serveur `annonces-comptes-officiels.md`, ADR-0029 à
/// ADR-0031).
///
/// Les trois règles de `mediatheque_tables.dart` valent ici **mot pour mot** —
/// aucune clé étrangère entre collections, on stocke ce que le serveur envoie,
/// chaque ligne porte son jeton d'écriture. Rien de neuf n'est inventé.
///
/// Ce que ce fichier a de propre tient en deux phrases.
///
/// **Une annonce ne porte plus ni auteur ni couleur, mais deux identifiants.**
/// `accountId` se joint sur `official_accounts`, `backgroundId` sur
/// `status_backgrounds` — c'est la décision 3 d'ADR-0026 appliquée à un
/// deuxième domaine : *une valeur résolue par le serveur est une valeur figée
/// qu'il ne saura jamais rafraîchir*. Recopier le nom du compte dans chaque
/// annonce aurait laissé les téléphones sur l'ancien nom après un renommage,
/// indéfiniment et en silence : renommer un compte ne bouscule l'`updatedAt`
/// d'aucune annonce, donc aucune ligne ne repasserait par le flux delta pour
/// corriger la valeur figée.
///
/// **Les trois arrêts du dégradé et l'encre sont stockés tels que servis, et
/// jamais recalculés.** Le serveur les a dérivés à l'écriture (ADR-0030) ; le
/// client peint. Un client qui recalculerait sa propre variation d'une couleur
/// de base rendrait deux dégradés différents pour la même annonce selon la
/// version installée — sur un mur de statuts, ça se voit.
library;

import 'package:drift/drift.dart';

import 'mediatheque_tables.dart';

/// Collection `status_backgrounds` — le **référentiel partagé des fonds** de
/// statut (partition `reference`).
///
/// Il remplace la palette de cinq teintes codées en dur qu'a portée
/// `lib/theme/status_palette.dart` : une palette dans le binaire est une
/// décision figée à la livraison, alors qu'un fond se choisit dans le portail
/// et s'ajoute sans mise à jour de l'application.
///
/// [baseColor], [topColor] et [bottomColor] arrivent **dérivés par le serveur**
/// et se stockent bruts, en `#RRGGBB`. [ink] dit quelle encre reste lisible
/// dessus — le contraste aussi a été décidé à l'écriture, et le client n'a pas à
/// le recalculer.
///
/// [isActive] est une **donnée**, pas un filtre : un fond désactivé ne doit plus
/// être **proposé** à la composition, mais les annonces qui le portent déjà
/// continuent de s'afficher avec lui. Le filtrer au stockage ferait perdre leur
/// habillage à des statuts parfaitement valides.
@DataClassName('StatusBackgroundRow')
class StatusBackgrounds extends Table with SyncedRow {
  @override
  String get tableName => 'status_backgrounds';

  IntColumn get id => integer()();

  /// Libellé **monolingue** du fond, tel que l'administrateur l'a nommé. Ce
  /// n'est pas un texte d'interface : il ne sert qu'au sélecteur de composition.
  TextColumn get label => text()();

  /// Teinte de référence du fond (`#RRGGBB`).
  TextColumn get baseColor => text()();

  /// Arrêt **haut** du dégradé, dérivé par le serveur à l'écriture.
  TextColumn get topColor => text()();

  /// Arrêt **bas** du dégradé, dérivé par le serveur à l'écriture.
  TextColumn get bottomColor => text()();

  /// `light` | `dark` — l'encre lisible sur ce fond. Stocké **tel quel**,
  /// jamais en enum côté magasin : une valeur inconnue se replie à l'affichage
  /// plutôt que de faire échouer l'application d'une page entière.
  TextColumn get ink => text()();

  IntColumn get position => integer().withDefault(const Constant(0))();

  /// `false` = le fond n'est plus proposé à la composition. Les annonces qui le
  /// portent gardent leur habillage.
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Collection `official_accounts` — les **comptes officiels d'église** (COE)
/// sous lesquels une annonce est publiée (partition `branch`).
///
/// C'est ce référentiel qui porte l'en-tête d'un statut : `shortName ?? name`.
/// L'annonce, elle, ne porte que [OfficialAccounts.id].
///
/// Partition `branch` et non `reference` : un compte appartient à une branche,
/// et le garde-fou « périmètre modifié » doit donc pouvoir lever
/// `full_resync_required` dessus — un fidèle qui change de branche ne doit pas
/// garder en magasin les comptes de l'ancienne.
@DataClassName('OfficialAccountRow')
class OfficialAccounts extends Table with SyncedRow {
  @override
  String get tableName => 'official_accounts';

  IntColumn get id => integer()();

  TextColumn get name => text()();

  /// Nom court, préféré à [name] dans l'en-tête quand il existe : « Diaconat »
  /// plutôt que « Diaconat de la Maison du Miracle — Bè Kpota », sur une ligne
  /// où l'ellipse guette.
  TextColumn get shortName => text().nullable()();

  /// Branche du compte ; `null` = portée **nationale**, jamais « inconnue ».
  IntColumn get branchId => integer().nullable()();

  /// URL **relative** de l'avatar : l'hôte de l'API change d'un environnement à
  /// l'autre, la résolution appartient au client (`utils/media_url.dart`).
  TextColumn get avatarUrl => text().nullable()();

  /// Fond par défaut du compte — **entier nu, sans clé étrangère** vers
  /// `status_backgrounds`. Il n'habille aucune annonce : c'est la valeur que le
  /// composeur propose. Une annonce porte toujours le sien.
  IntColumn get backgroundId => integer().nullable()();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Collection `official_account_memberships` — **mes** appartenances aux
/// comptes officiels, et rien d'autre.
///
/// La collection est **scoppée sur l'acteur** : le serveur n'y sert jamais
/// l'appartenance de quelqu'un d'autre. Une ligne ici veut donc dire « je suis
/// membre de ce compte », et c'est tout ce que le client en tire — l'existence
/// d'au moins une ligne fait apparaître l'affordance d'écriture.
///
/// **Un confort d'affichage, jamais une autorisation.** Le serveur revérifie à
/// chaque écriture : un membre retiré du bureau dont le téléphone n'a pas
/// synchronisé verra encore le bouton et recevra un 403. Traiter cette table
/// comme un droit acquis reviendrait à faire de la copie locale d'un fidèle la
/// source de vérité de ses permissions.
@DataClassName('OfficialAccountMembershipRow')
class OfficialAccountMemberships extends Table with SyncedRow {
  @override
  String get tableName => 'official_account_memberships';

  IntColumn get id => integer()();

  /// **Entier nu, sans clé étrangère** vers `official_accounts` : les deux
  /// collections se resynchronisent séparément.
  IntColumn get accountId => integer()();

  /// Porteur de l'appartenance — moi, par construction de la collection.
  TextColumn get userId => text()();

  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Collection `announcements` — les statuts de l'onglet Annonces (partition
/// `branch`, tombstones par `deletedAt`).
///
/// Trois champs de l'ancien modèle mobile n'y sont **pas**, et leur absence est
/// la moitié de ce lot :
///
/// - **`author`** — remplacé par [accountId], qui se joint. Voir l'en-tête de ce
///   fichier ;
/// - **`backgroundColor`** — remplacé par [backgroundId], qui se joint ;
/// - **`tag`** — abandonné : le compte officiel occupe déjà l'en-tête, et « COE »
///   en auteur *et* en pastille serait la même information dite deux fois.
///
/// [expiresAt] est stocké **brut** et n'est jamais filtré ici. Le serveur ne
/// retire pas les annonces expirées du flux delta, et c'est voulu : un statut
/// « valable jusqu'à ce soir » doit disparaître **à la seconde**, y compris
/// hors-ligne. Seule une comparaison faite à la lecture peut tenir cette
/// promesse — un filtre au stockage attendrait la prochaine synchronisation, un
/// filtre serveur aussi.
@DataClassName('AnnouncementRow')
class Announcements extends Table with SyncedRow {
  @override
  String get tableName => 'announcements';

  /// UUID servi par le serveur, **en chaîne**.
  TextColumn get id => text()();

  /// **Entier nu, sans clé étrangère** vers `official_accounts`. La jointure
  /// est tolérante : une annonce dont le compte n'est pas encore arrivé
  /// s'affiche quand même, sans en-tête inventé.
  IntColumn get accountId => integer()();

  /// Branche de l'annonce ; `null` = portée **nationale**. Le client ne s'en
  /// sert pas pour filtrer — le périmètre est décidé par le serveur, qui ne
  /// sert que ce que l'acteur a le droit de voir.
  IntColumn get branchId => integer().nullable()();

  /// Absent ⇒ bloc de texte centré, façon WhatsApp.
  TextColumn get title => text().nullable()();

  TextColumn get body => text().nullable()();

  /// Mise à disposition, en UTC. **Non nulle** : c'est la clé de tri du mur de
  /// statuts, et une annonce sans date n'a pas de place où aller.
  DateTimeColumn get publishedAt => dateTime()();

  /// `null` = n'expire jamais (le défaut).
  DateTimeColumn get expiresAt => dateTime().nullable()();

  /// **Entier nu, sans clé étrangère** vers `status_backgrounds`. `null` =
  /// aucun fond choisi : le rendu retombe alors sur la teinte dérivée du hash
  /// de l'[id] (`lib/theme/status_palette.dart`).
  IntColumn get backgroundId => integer().nullable()();

  /// Image de fond, URL **relative** comme partout ailleurs.
  TextColumn get backgroundImageUrl => text().nullable()();

  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();

  /// Auteur humain de la publication — l'identité derrière le compte. Elle ne
  /// s'affiche pas : le statut est signé par le **compte**, pas par la personne.
  TextColumn get ownerId => text().nullable()();

  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
