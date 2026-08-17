/// Tables de **données** des collections répliquées de la **messagerie de
/// groupe** (PRD serveur `messagerie-groupes-officiels.md`, doc humain
/// `groups.md`) : `groups`, `group_members`, `group_messages` et
/// `group_join_requests`.
///
/// Les trois règles de `mediatheque_tables.dart` valent ici **mot pour mot** —
/// aucune clé étrangère entre collections, on stocke ce que le serveur envoie,
/// chaque ligne porte son jeton d'écriture. Rien de neuf n'est inventé côté
/// magasin : ce lot **remplace la messagerie fictive** (`SampleData`,
/// `InMemoryChurchRepository`) par de vraies collections de synchronisation.
///
/// **Ce que ce domaine a de propre**, et qu'il faut connaître :
///
/// - **Un groupe a un propriétaire polymorphe** (décision D3) : `owner_kind`
///   discrimine entre `user`, `official_account` et `contributor`, et **une**
///   des trois colonnes `owner*Id` est renseignée. L'identité de l'institution
///   (logo, nom) ne voyage **pas** ici : elle se **joint** sur les collections
///   déjà répliquées `official_accounts` / `contributors` — décision 3
///   d'ADR-0026 appliquée à un domaine de plus.
/// - **`group_members` ne porte que MES appartenances** (le serveur scope la
///   collection sur l'acteur, comme `official_account_memberships`). Une ligne
///   ici veut dire « je suis membre de ce groupe », avec mon rôle. C'est ce qui
///   sépare, à la lecture, l'**inbox** (groupes dont j'ai une appartenance) de
///   la **découverte** (groupes publics dont je n'en ai pas).
/// - **`group_messages` est un contenu à curseur, avec tombstone** : une
///   suppression de message voyage en rétractation `{ id, deletedAt }`
///   (ADR-0017), et l'origine se lit sur le couple `(authorId, isSystem)`,
///   jamais sur `authorId` seul (ADR-0032, `docs/messagerie-groupe.md`).
/// - **`group_join_requests` porte l'état d'adhésion** (décision D12) : ma
///   demande en attente (pour afficher « En attente »), et — pour un groupe que
///   j'administre — les demandes d'autrui à valider.
library;

import 'package:drift/drift.dart';

import 'mediatheque_tables.dart';

/// Collection `groups` — les **espaces de discussion** (partition `branch`,
/// tombstones par `deletedAt`).
///
/// Le serveur ne remonte à un non-membre que les groupes **publics**
/// (`open`|`request`) **dans sa portée de branche** (décision D13) : le client
/// n'a donc **aucun filtre de portée à recalculer**, il obéit au périmètre servi
/// — exactement comme pour les annonces. Il ne distingue que « suis-je membre »
/// (jointure sur `group_members`), ce qui range le groupe en inbox ou en
/// découverte.
@DataClassName('GroupRow')
class Groups extends Table with SyncedRow {
  @override
  String get tableName => 'groups';

  /// UUID servi par le serveur, **en chaîne** (il sert aussi de cible aux
  /// messages et aux appartenances).
  TextColumn get id => text()();

  TextColumn get name => text()();

  TextColumn get description => text().nullable()();

  /// Discriminant du propriétaire : `user` | `official_account` | `contributor`
  /// (décision D3). Stocké **tel quel**, jamais refermé sur un enum côté
  /// magasin — une valeur inconnue se replie à l'affichage plutôt que de coûter
  /// la page entière.
  TextColumn get ownerKind => text()();

  /// Propriétaire **humain**, `null` pour un groupe institutionnel (décision
  /// D4 : une institution n'a pas de chef humain). Entier ? Non — un `users.id`
  /// est un UUID, donc une chaîne.
  TextColumn get ownerUserId => text().nullable()();

  /// Propriétaire **compte officiel** — entier nu, sans clé étrangère vers
  /// `official_accounts` (les collections se resynchronisent séparément). La
  /// jointure d'identité est tolérante.
  IntColumn get ownerOfficialAccountId => integer().nullable()();

  /// Propriétaire **intervenant** — entier nu, sans clé étrangère vers
  /// `contributors`.
  IntColumn get ownerContributorId => integer().nullable()();

  /// `open` | `request` | `invite_only` (décision D11). `request` est la valeur
  /// **nouvelle** : public, mais sur validation. Stocké tel quel.
  TextColumn get joinPolicy => text()();

  /// `all` | `admins` (décision D14). `admins` = **diffusion** : seuls les
  /// leaders/modérateurs écrivent, les membres lisent.
  TextColumn get postPolicy => text().withDefault(const Constant('all'))();

  /// Verrou d'écriture temporaire (décision D15) : quand actif, seuls les admins
  /// écrivent, quel que soit [postPolicy].
  BoolColumn get isWriteLocked =>
      boolean().withDefault(const Constant(false))();

  /// `false` = groupe **désactivé** (décision D18) : messages archivés en
  /// lecture seule, réactivable. Écarté de la **découverte**, mais conservé en
  /// inbox pour ses membres.
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  /// Effectif, servi par le serveur (décision : la liste des membres ne voyage
  /// pas — pas de collection `users`, ADR-0029 — mais le compte, oui).
  IntColumn get memberCount => integer().nullable()();

  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Collection `group_members` — **mes** appartenances aux groupes, et rien
/// d'autre (partition `private`, tombstones par `deletedAt`).
///
/// Scoppée sur l'acteur par le serveur : une ligne ici est **mon** appartenance,
/// avec **mon** rôle. Quitter un groupe la fait quitter le magasin (rétractation
/// `deletedAt`). Un **confort d'affichage, jamais une autorisation** : le
/// serveur revérifie à chaque écriture (un membre rétrogradé dont le téléphone
/// n'a pas synchronisé verra encore le composeur et recevra un 403).
@DataClassName('GroupMemberRow')
class GroupMembers extends Table with SyncedRow {
  @override
  String get tableName => 'group_members';

  /// SERIAL côté serveur — **entier** (hypothèse à réconcilier, cf. l'en-tête de
  /// `sync_rows.dart`).
  IntColumn get id => integer()();

  /// **Entier ? Non** : cible un `groups.id` (UUID), donc une chaîne. Entier nu
  /// au sens « sans clé étrangère ».
  TextColumn get groupId => text()();

  /// Porteur de l'appartenance — moi, par construction de la collection.
  TextColumn get userId => text()();

  /// `leader` | `moderator` | `member`. Ce qui décide si le composeur s'affiche
  /// sous `post_policy = admins` et sous verrou, et si l'UI de validation des
  /// demandes s'offre.
  TextColumn get role => text()();

  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Collection `group_messages` — les **messages** (partition `private`,
/// tombstones par `deletedAt`, ADR-0017).
///
/// **L'origine se lit sur le couple `(authorId, isSystem)`**, jamais sur
/// `authorId` seul (ADR-0032) :
///
/// | `authorId` | `isSystem` | origine |
/// | --- | --- | --- |
/// | uuid | `false` | un membre |
/// | `null` | `true` | message **système** (serveur) |
/// | `null` | `false` | **auteur retiré** — compte supprimé |
///
/// Le nul a deux sens depuis la suppression de compte : un client qui teste le
/// nul seul afficherait les messages d'un membre parti comme des annonces du
/// serveur.
@DataClassName('GroupMessageRow')
class GroupMessages extends Table with SyncedRow {
  @override
  String get tableName => 'group_messages';

  /// UUIDv7 servi par le serveur — **en chaîne**, et c'est aussi le **curseur**.
  TextColumn get id => text()();

  TextColumn get groupId => text()();

  /// Auteur, **nullable** : voir le tableau de l'en-tête.
  TextColumn get authorId => text().nullable()();

  /// `true` = message **système** émis par le serveur (adhésion, départ, verrou…).
  BoolColumn get isSystem => boolean().withDefault(const Constant(false))();

  /// Corps du message. Nullable : un message système peut n'en pas porter, et
  /// une ligne tombstonée n'arrive de toute façon jamais jusqu'ici (triée en
  /// amont par `readsAsRetraction`).
  TextColumn get body => text().nullable()();

  /// Horodatage d'affichage (ordre de rédaction réel, ADR-0018), en UTC.
  DateTimeColumn get clientCreatedAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Collection `group_join_requests` — la **file d'adhésion** (décision D12,
/// partition `private`, tombstones par `deletedAt`).
///
/// Ce que le serveur scope ici (**hypothèse à réconcilier**) : ma propre demande
/// en attente (pour afficher « En attente » sur un groupe `request`), **et**,
/// pour un groupe que j'administre, les demandes d'autrui à valider.
@DataClassName('GroupJoinRequestRow')
class GroupJoinRequests extends Table with SyncedRow {
  @override
  String get tableName => 'group_join_requests';

  /// SERIAL côté serveur — **entier** (hypothèse à réconcilier).
  IntColumn get id => integer()();

  TextColumn get groupId => text()();

  /// Demandeur — moi, ou (si j'administre le groupe) un autre fidèle.
  TextColumn get userId => text()();

  /// `pending` | `approved` | `rejected`. Une demande résolue peut rester
  /// visible un temps ; la découverte ne regarde que `pending`.
  TextColumn get status => text()();

  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
