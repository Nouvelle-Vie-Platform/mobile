/// Tables des **cinq collections répliquées de la rubrique « Échanges »** (#96,
/// cadrage `server-portal/docs/echanges-branchement-plan.md`, décisions 1 à 3),
/// plus **une table locale seule** pour l'écho optimiste de l'envoi.
///
/// Les règles de `mediatheque_tables.dart` valent ici mot pour mot : aucune clé
/// étrangère entre collections, **on stocke ce que le serveur envoie**, chaque
/// ligne répliquée porte son jeton d'écriture ([SyncedRow]).
///
/// ## Les cinq, et ce que chacune apporte
///
/// | table | partition serveur | tombstone | ce qu'elle apporte |
/// |---|---|---|---|
/// | `profiles` | `private` | — | **le nom d'un auteur**, enfin |
/// | `groups` | `branch` | aucun | le groupe, son effectif, sa politique |
/// | `group_members` | `private` | `deletedAt` | le roster de mes groupes |
/// | `group_join_requests` | `private` | `deletedAt` | mes demandes ∪ celles que j'administre |
/// | `group_messages` | `branch` | `deletedAt` | le fil |
///
/// ## `profiles` **périme** un prérequis qui bloquait le branchement
///
/// `docs/messagerie-groupe.md` §2 et §6.1 déclaraient bloquant le fait que « le
/// mobile n'a aujourd'hui aucun moyen d'afficher le nom de l'auteur d'un
/// message ». C'était vrai sous ADR-0029, qui refusait toute collection
/// d'utilisateurs. `profiles` est la **réversion assumée** de cette décision, et
/// le compromis qui la justifie est son périmètre : jamais un annuaire, seulement
/// les personnes que je **côtoie** (co-membre actif d'un groupe dont je suis
/// moi-même membre actif).
///
/// ## Deux types de clé primaire, et ce n'est pas une inattention
///
/// `groups.id`, `group_messages.id` et `profiles.id` sont des **UUID** (texte) ;
/// `group_members.id` et `group_join_requests.id` sont des **entiers**
/// (`increments` côté serveur). Le protocole préserve le type natif de bout en
/// bout pour ne jamais comparer `'10' < '9'` — c'est `referenceId` ou `contentId`
/// qui tranche, collection par collection, dans `sync_rows.dart`.
///
/// ## Deux collections sans tombstone, et la limite se paie côté client
///
/// Ni `groups` ni `profiles` n'en a. Quitter un groupe privé, ou cesser d'être le
/// co-membre de quelqu'un, ne produit donc **aucun signal de retrait** : la ligne
/// reste en magasin jusqu'à une resynchronisation complète. La conséquence est
/// bornée, et elle l'est par la **lecture** : `GroupDao` ne liste une
/// conversation que si j'y ai une appartenance **active** (`group_members`, qui a
/// un tombstone, lui). Un groupe orphelin cesse donc d'apparaître sans qu'aucune
/// ligne n'ait été effacée — exactement la mécanique « pas de contenu, pas de
/// section » de l'accueil.
library;

import 'package:drift/drift.dart';

import 'mediatheque_tables.dart' show SyncedRow;

/// Collection `profiles` (partition `private`) — la projection minimale de
/// `users` qui donne un **nom** à chaque `userId`.
///
/// Quatre clés servies, et c'est tout : `id`, `displayName`, `avatarUrl`,
/// `updatedAt`. **Il n'y a pas de `createdAt`** — le transformer ne l'émet pas, et
/// une colonne locale qui l'attendrait resterait nulle pour toujours.
@DataClassName('ProfileRow')
class Profiles extends Table with SyncedRow {
  @override
  String get tableName => 'profiles';

  /// L'UUID de `users`. C'est lui que `group_messages.authorId`,
  /// `group_members.userId` et `groups.ownerId` désignent.
  TextColumn get id => text()();

  /// « Prénom Nom » élagué, à défaut le titre, à défaut **`null`**.
  ///
  /// ⚠️ Le nul est un cas **légitime**, pas une erreur de livraison : un compte
  /// qui n'a jamais rempli son profil n'a pas de nom à montrer. La lecture
  /// retombe alors sur l'avatar neutre, et **jamais** sur un « Utilisateur
  /// inconnu », qui ressemblerait à une donnée (même règle que
  /// `ContentView.authorName`).
  TextColumn get displayName => text().nullable()();

  /// **Toujours `null` aujourd'hui** : `users` ne porte aucune colonne d'avatar.
  /// La colonne existe parce que le serveur sert la clé, et qu'on stocke ce que
  /// le serveur envoie — le jour où il la remplira, rien n'est à migrer.
  TextColumn get avatarUrl => text().nullable()();

  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Collection `groups` (partition `branch`, mais le périmètre réel est
/// l'**appartenance** : national ∪ branche visible ∪ groupes rejoints).
///
/// **Sans tombstone** — la table serveur n'a pas de `deleted_at` ; retirer un
/// groupe met `isActive` à `false`, et c'est cette ligne-là qui voyage.
@DataClassName('GroupRow')
class Groups extends Table with SyncedRow {
  @override
  String get tableName => 'groups';

  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();

  /// `open` | `invite_only` | `request`. **Stocké tel quel, jamais en enum** :
  /// la valeur est une colonne `varchar` côté serveur, dont la contrainte vit
  /// dans le validateur et non dans le schéma. Un enum figerait à la compilation
  /// une liste que le serveur peut allonger, et une politique inconnue ferait
  /// alors **lever** la désérialisation — donc couper le cycle, donc emporter
  /// toutes les collections rangées après celle-ci. Une chaîne inconnue, elle,
  /// se replie à l'affichage : le groupe n'est simplement pas proposé.
  TextColumn get joinPolicy => text()();

  /// `all` | `admins` — le régime d'écriture **permanent**.
  TextColumn get postPolicy => text()();

  /// Le **verrou temporaire**, indépendant et cumulatif avec [postPolicy] : les
  /// deux refusent l'écriture à un simple membre, et un `leader`/`moderator`
  /// écrit toujours. C'est ce que le serveur vérifie à chaque envoi ; le client
  /// les lit pour **ne pas offrir** une barre de saisie qui prendrait un 403.
  BoolColumn get isWriteLocked =>
      boolean().withDefault(const Constant(false))();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  /// Un **tête-à-tête**. Le serveur en fait un groupe comme un autre (c'est ce
  /// qui donne gratuitement le fil, le tombstone de modération et le curseur) ;
  /// le client n'en tire qu'un habillage — pas de liste de membres, le titre est
  /// le nom de l'autre.
  BoolColumn get isDirect => boolean().withDefault(const Constant(false))();

  /// **`ownerId` est l'UUID de `groups.owner_user_id`**, et il est nul pour un
  /// groupe institutionnel. Le transformer serveur le renomme — il n'y a pas de
  /// clé `ownerUserId` sur le fil.
  TextColumn get ownerId => text().nullable()();

  /// `user` | `official_account` | `contributor` — lequel des trois propriétaires
  /// est renseigné. C'est lui qui dit **où joindre le nom de l'animateur** :
  /// `profiles` (cette collection-ci), `official_accounts` ou `contributors`, les
  /// trois déjà en magasin.
  TextColumn get ownerKind => text()();

  IntColumn get ownerOfficialAccountId => integer().nullable()();
  IntColumn get ownerContributorId => integer().nullable()();

  /// Les membres **actifs**, comptés par le serveur (tombstones exclus).
  ///
  /// On ne le recalcule pas depuis `group_members` : ce roster-là n'arrive que
  /// pour les groupes dont je suis membre, et un groupe à rejoindre afficherait
  /// alors « 0 membre ».
  IntColumn get memberCount => integer().withDefault(const Constant(0))();

  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Collection `group_members` (partition `private`) — le roster de **mes**
/// groupes : ma ligne **et** celles de mes co-membres.
///
/// **Avec tombstone**, et il porte deux gestes distincts : mon propre départ (ma
/// ligne voyage tombstonée, c'est ce qui retire le groupe de mon téléphone) et le
/// retrait d'un co-membre (sa ligne part, le roster se referme). Le tombstone
/// passe par le chemin commun — `readsAsRetraction` trie en amont et la ligne
/// quitte le magasin par son identifiant, sans qu'aucune colonne locale n'en
/// garde la trace.
@DataClassName('GroupMemberRow')
class GroupMembers extends Table with SyncedRow {
  @override
  String get tableName => 'group_members';

  /// Un **entier** (`increments` côté serveur), et la même ligne ressuscite à la
  /// ré-adhésion : l'unicité `(group_id, user_id)` n'est pas partielle, donc
  /// `deleted_at → NULL` réanime cet `id`-ci plutôt que d'en créer un second.
  IntColumn get id => integer()();

  TextColumn get groupId => text()();
  TextColumn get userId => text()();

  /// `member` | `moderator` | `leader`. Stocké tel quel, pour la raison de
  /// [Groups.joinPolicy].
  TextColumn get role => text()();

  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Collection `group_join_requests` (partition `private`) — mes demandes ∪ celles
/// des groupes que j'administre.
///
/// **Le tombstone est servi pour la conformité du flux, et n'est pas le canal de
/// la décision** : une approbation ou un refus voyage par le changement de
/// [status] et le bump d'`updated_at`, jamais par un `deleted_at`. Un client qui
/// attendrait le tombstone pour apprendre le verdict ne l'apprendrait jamais.
@DataClassName('GroupJoinRequestRow')
class GroupJoinRequests extends Table with SyncedRow {
  @override
  String get tableName => 'group_join_requests';

  IntColumn get id => integer()();
  TextColumn get groupId => text()();
  TextColumn get userId => text()();

  /// `pending` | `approved` | `rejected`. Stocké tel quel, pour la raison de
  /// [Groups.joinPolicy].
  TextColumn get status => text()();

  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Collection `group_messages` (partition `branch`, périmètre réel =
/// l'appartenance) — **le fil**.
///
/// ## L'origine se lit sur le couple `(authorId, isSystem)`, et les deux colonnes
/// existent pour ça
///
/// | [authorId] | [isSystem] | ce que c'est |
/// |---|---|---|
/// | uuid | `false` | un membre |
/// | `null` | `true` | le serveur |
/// | `null` | `false` | **un auteur retiré** (ADR-0032) |
///
/// Le nul avait un seul sens jusqu'à la suppression de compte : « message
/// système ». Il en a deux depuis, et c'est pourquoi [isSystem] est une colonne
/// à part entière et non une valeur déduite. Un magasin qui ne stockerait que
/// `authorId` rendrait la troisième ligne du tableau **indistinguable** de la
/// deuxième, et aucun test d'écran ne pourrait plus la rattraper.
///
/// ## Il n'y a **pas** de colonne `updatedAt`, et ce n'est pas un oubli
///
/// Le transformer serveur ne l'émet pas, bien que la colonne existe en base et
/// porte le curseur composé. Une colonne locale qui l'attendrait resterait nulle
/// pour toujours, et donnerait à croire qu'un message n'a jamais été touché —
/// alors que le détachement d'auteur, précisément, le touche.
@DataClassName('GroupMessageRow')
class GroupMessages extends Table with SyncedRow {
  @override
  String get tableName => 'group_messages';

  /// UUIDv7 **assigné par le serveur** : il trie temporellement, et c'est lui
  /// que la lecture REST repasse en `?since=`. Le client ne le fabrique jamais —
  /// ce qu'il fabrique est [clientMessageId].
  TextColumn get id => text()();

  TextColumn get groupId => text()();

  /// **Nullable, et le nul a deux sens** : voir l'en-tête de la classe.
  TextColumn get authorId => text().nullable()();

  /// **Vrai = le serveur parle** (adhésion, changement de rôle). Jamais produit
  /// par un client.
  BoolColumn get isSystem => boolean().withDefault(const Constant(false))();

  /// **Nullable depuis la v20** (#140, piège 1 du plan
  /// `messagerie-whatsapp-plan.md`), et c'est un garde-fou, pas une commodité.
  ///
  /// Un message-média (vocal, image) n'a pas de texte : le serveur le sert avec
  /// `body: null` dès que l'application annonce une version au-delà du plancher
  /// de compatibilité (`GROUP_MEDIA_COMPAT_FLOOR_VERSION`), et **toujours** sur le
  /// canal `users/{id}`, qui n'a pas de requête où lire la version. Une colonne
  /// `NOT NULL` faisait lever `groupMessageRowOf` — donc rejeter la page, donc
  /// **couper le cycle de synchronisation** à chaque tour, sans que rien ne le
  /// dise. Le nul se rend à l'écran comme un message que cette version ne sait
  /// pas encore montrer (`chatMediaUnsupported`), jamais comme un vide.
  TextColumn get body => text().nullable()();

  /// **La clé d'idempotence**, telle que ce client l'a frappée (UUIDv7) — ou nul
  /// pour un message qu'un autre client a envoyé sans clé.
  ///
  /// C'est par elle que l'écho optimiste se **réconcilie** : la ligne en attente
  /// ([PendingGroupMessages]) disparaît de l'écran dès que la ligne serveur
  /// portant la même clé entre au magasin. Sans elle, la réconciliation se ferait
  /// sur le texte, et deux « amen » successifs n'en feraient plus qu'un.
  TextColumn get clientMessageId => text().nullable()();

  /// L'instant de **rédaction**, posé par le client qui a envoyé. Nul pour un
  /// message dont l'émetteur ne l'a pas renseigné.
  DateTimeColumn get clientCreatedAt => dateTime().nullable()();

  /// L'instant **serveur**. Non nul sur le fil, mais la colonne reste nullable :
  /// une table locale n'a pas à supposer ce qu'une autre base garantit.
  DateTimeColumn get createdAt => dateTime().nullable()();

  // ── Tranche M2 (#141) : supprimé, modifié, transféré, réponse ──────────────

  /// **Le tombstone est gardé** depuis M2 : un message supprimé pour tous ne
  /// quitte plus le magasin, il se peint « Ce message a été supprimé » à sa
  /// place (le serveur ne sert plus son contenu). Voir `keepsTombstones` dans
  /// `synced_collection.dart`.
  DateTimeColumn get deletedAt => dateTime().nullable()();

  /// Dernière modification par l'auteur — la bulle porte « Modifié ».
  DateTimeColumn get editedAt => dateTime().nullable()();

  /// Une copie **transférée** — la bulle porte « Transféré ».
  BoolColumn get isForwarded => boolean().withDefault(const Constant(false))();

  /// **La citation**, photographiée par le serveur sur la réponse (`replyTo`) :
  /// de quoi la peindre sans le message d'origine en magasin. Le message cité.
  TextColumn get replyToMessageId => text().nullable()();

  /// L'auteur cité — le nom se joint sur `profiles`, comme celui d'une bulle.
  TextColumn get replyToAuthorId => text().nullable()();

  /// L'extrait du texte cité (borné par le serveur). Nul pour un média sans
  /// légende, ou une origine supprimée.
  TextColumn get replyToExcerpt => text().nullable()();

  /// La forme du média cité (`audio`, `image`…), stockée telle quelle.
  TextColumn get replyToMediaKind => text().nullable()();

  /// L'origine a été supprimée pour tous : la citation dit « Message supprimé ».
  BoolColumn get replyToDeleted =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// **Table locale seule** — l'écho optimiste d'un message en cours d'envoi.
///
/// Même patron que `local_playback_positions` : elle n'est dans aucun registre de
/// synchronisation, ne porte **pas** de `sync_stamp`, et aucun cycle ne la touche.
///
/// ## Pourquoi une table et non un état en mémoire
///
/// L'écho est là pour qu'un membre qui tape « amen » le voie **avant** que le
/// réseau togolais ait fini d'y penser (décision 2 du cadrage, rupture assumée
/// avec le composeur d'annonces). Un état en mémoire tiendrait cette promesse
/// jusqu'à la première reconstruction d'écran et la perdrait au premier passage
/// en arrière-plan — c'est-à-dire au geste qui suit l'envoi. Le magasin la tient
/// pour de bon, et c'est le même raisonnement que la position d'écoute à chaud :
/// l'écriture locale est continue et gratuite, seul l'appel réseau est incertain.
///
/// ## Pourquoi la clé primaire est le `clientMessageId`
///
/// Parce que c'est la **clé d'idempotence**, et qu'elle doit être la même des
/// deux côtés : celle que l'envoi poste au serveur, celle que la réconciliation
/// cherche dans [GroupMessages], et celle qui empêche un double appui de laisser
/// deux échos. Un identifiant local de plus serait une seconde identité pour la
/// même chose.
@DataClassName('PendingGroupMessageRow')
class PendingGroupMessages extends Table {
  @override
  String get tableName => 'pending_group_messages';

  /// L'UUIDv7 frappé par ce client. Voir l'en-tête.
  TextColumn get clientMessageId => text()();

  TextColumn get groupId => text()();
  TextColumn get body => text()();

  /// L'horloge de l'**appareil** : l'écho s'affiche au bas du fil, et il n'a pas
  /// d'instant serveur à présenter — il n'en a pas encore.
  DateTimeColumn get createdAt => dateTime()();

  /// **L'envoi a échoué**, et l'écran doit le dire.
  ///
  /// Sans ce drapeau, un message perdu resterait « en cours d'envoi » pour
  /// toujours : le pire des deux mondes, puisque la personne croirait avoir
  /// parlé. Il est posé sur **tout** refus — réseau, 401, 403, 422, 5xx — parce
  /// que de l'écran, tous disent la même chose : « ce message n'est pas parti ».
  BoolColumn get failed => boolean().withDefault(const Constant(false))();

  /// **Répondre** (M2, #141) : le message cité, repassé au renvoi. L'écho peint
  /// sa citation en joignant le message d'origine en magasin.
  TextColumn get replyToMessageId => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {clientMessageId};
}

/// Collection `group_reads` (partition `private`, #140) — **ma** position de
/// lecture dans chacun de mes groupes, et rien de celle des autres.
///
/// Servie par le serveur depuis M1a (`group_reads_descriptor.ts`) : `{ id,
/// groupId, lastReadMessageId, lastReadAt }`. **Rangée par `groupId`** (le
/// contrat le demande) : `id` est celui de l'appartenance, gardé parce qu'on
/// stocke ce que le serveur envoie. Une appartenance jamais lue n'a pas de ligne,
/// et l'absence veut dire « rien lu » — voir le calcul des non-lus dans
/// `GroupDao`.
///
/// **Sans tombstone** : quitter un groupe ne retire pas la lecture, et un groupe
/// que je ne vois plus n'a plus de pastille à peindre.
///
/// ⚠️ **Monotone.** Le canal `read.advanced` peut livrer deux lectures dans le
/// désordre ; seule une ligne plus avancée que la locale est rangée — voir
/// `MessagingStoreWriter`.
@DataClassName('GroupReadRow')
class GroupReads extends Table with SyncedRow {
  @override
  String get tableName => 'group_reads';

  TextColumn get groupId => text()();

  /// L'identifiant de l'appartenance côté serveur (un entier). Non lu.
  IntColumn get membershipId => integer().nullable()();

  /// Le dernier message lu. **Pas de clé étrangère**, ni ici ni côté serveur :
  /// un message purgé ne remet pas la lecture à zéro.
  TextColumn get lastReadMessageId => text().nullable()();

  /// L'instant de la lecture. C'est le repli du calcul des non-lus quand le
  /// message lu n'est pas (ou plus) dans le magasin.
  DateTimeColumn get lastReadAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {groupId};
}

/// **Table locale seule** (#140) — une lecture avancée par ce téléphone et
/// **pas encore confirmée** par `POST /groups/:id/read`.
///
/// C'est l'outbox de la lecture, sur le patron de [PendingGroupMessages] : posée
/// **avant** l'appel réseau, retirée à sa confirmation, rejouée tant qu'elle
/// reste (`GroupReadAdvancer.replay`). La route est idempotente et monotone
/// (piège 5 du plan) : rejouer est toujours sûr.
///
/// Elle sert aussi le **calcul des non-lus** : un message lu ici, hors ligne,
/// cesse aussitôt d'être compté — la pastille ne doit pas attendre le réseau pour
/// s'éteindre. Le compteur prend la plus avancée des deux lectures (serveur et
/// locale).
///
/// Dans aucun registre de synchronisation, sans `sync_stamp`, et aucun cycle ne
/// la touche.
@DataClassName('PendingGroupReadRow')
class PendingGroupReads extends Table {
  @override
  String get tableName => 'pending_group_reads';

  TextColumn get groupId => text()();

  /// Le message le plus récent que le fil a affiché.
  TextColumn get messageId => text()();

  /// Son instant **serveur** : la position se compare dans l'ordre du fil,
  /// `(createdAt, id)`, et il faut donc les deux.
  DateTimeColumn get messageCreatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {groupId};
}

/// Collection `group_arrangements` (partition `private`, #146, tranche M8) —
/// **mon** rangement de chacune de mes discussions : archivée, épinglée.
///
/// Servie par le serveur (`group_arrangements_descriptor.ts`) : `{ id, groupId,
/// archivedAt, pinnedAt, arrangedAt }`. **Rangée par `groupId`**, comme la
/// lecture. Une discussion jamais rangée n'a pas de ligne ; désarchiver revient
/// avec `archivedAt: null`, sans tombstone.
///
/// ⚠️ **Jamais en arrière.** Deux `arrangement.changed` venus de deux appareils
/// peuvent arriver dans le désordre : une ligne dont [arrangedAt] est antérieur
/// à la locale n'est pas rangée — voir `MessagingStoreWriter`.
@DataClassName('GroupArrangementRow')
class GroupArrangements extends Table with SyncedRow {
  @override
  String get tableName => 'group_arrangements';

  TextColumn get groupId => text()();

  /// L'identifiant de l'appartenance côté serveur (un entier). Non lu.
  IntColumn get membershipId => integer().nullable()();

  /// La discussion a quitté la liste principale pour la rangée « Archivées ».
  /// Elle **y reste** quand un message arrive : le serveur ne désarchive jamais,
  /// et le client non plus.
  DateTimeColumn get archivedAt => dateTime().nullable()();

  /// La discussion est épinglée en tête de liste (trois au plus).
  DateTimeColumn get pinnedAt => dateTime().nullable()();

  /// L'instant serveur du dernier changement — l'ordre des événements.
  DateTimeColumn get arrangedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {groupId};
}

/// **Table locale seule** (#146) — un rangement fait sur ce téléphone et **pas
/// encore confirmé** par `PUT /groups/:id/arrangement`.
///
/// L'outbox du rangement, sur le patron de [PendingGroupReads] : posée **avant**
/// l'appel réseau, elle **l'emporte à la lecture** sur la ligne servie — la
/// discussion quitte la liste à l'instant du geste, réseau ou pas —, retirée à
/// la confirmation, rejouée tant qu'elle reste. Elle porte l'**état voulu**
/// complet, jamais une bascule : la route est idempotente, rejouer est sûr.
@DataClassName('PendingGroupArrangementRow')
class PendingGroupArrangements extends Table {
  @override
  String get tableName => 'pending_group_arrangements';

  TextColumn get groupId => text()();

  BoolColumn get archived => boolean()();

  BoolColumn get pinned => boolean()();

  /// L'horloge de l'appareil au moment du geste : l'ordre d'une épingle neuve
  /// avant sa confirmation, et l'identité de la demande (une demande plus
  /// récente posée pendant l'aller-retour n'est pas effacée par la réponse de
  /// la précédente).
  DateTimeColumn get requestedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {groupId};
}

/// Collection `group_mutes` (partition `private`, tranche M5) — **ma** sourdine
/// dans chacun de mes groupes, et rien de celle des autres.
///
/// Servie par le serveur (`group_mutes_descriptor.ts`) : `{ id, groupId,
/// mutedUntil, mutedForever, muteChangedAt }`. **Rangée par `groupId`**, comme
/// [GroupReads] : `id` est celui de l'appartenance. Une appartenance jamais
/// réglée n'a pas de ligne, et l'absence veut dire « pas de sourdine ».
///
/// **La sourdine est active** si [mutedForever], ou si [mutedUntil] est dans le
/// futur. Une sourdine bornée **échue** reste telle quelle en magasin : elle est
/// lue comme levée, et rien n'a à passer l'effacer à l'heure dite.
///
/// **Sans tombstone** : réactiver voyage comme une ligne remise à zéro. Le canal
/// (`mute.changed`) peut livrer deux réglages dans le désordre ; seule une ligne
/// au moins aussi récente que la locale ([muteChangedAt]) est rangée — voir
/// `MessagingStoreWriter`.
@DataClassName('GroupMuteRow')
class GroupMutes extends Table with SyncedRow {
  @override
  String get tableName => 'group_mutes';

  TextColumn get groupId => text()();

  /// L'identifiant de l'appartenance côté serveur (un entier). Non lu.
  IntColumn get membershipId => integer().nullable()();

  /// La fin d'une sourdine bornée (8 h, 1 semaine), ou `null`.
  DateTimeColumn get mutedUntil => dateTime().nullable()();

  /// « Toujours ». Jamais cumulé avec [mutedUntil] (`CHECK` côté serveur).
  BoolColumn get mutedForever => boolean().withDefault(const Constant(false))();

  /// L'instant serveur du dernier réglage — ce qui départage deux lignes
  /// arrivées dans le désordre.
  DateTimeColumn get muteChangedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {groupId};
}

/// Collection `group_message_reactions` (partition `branch`, périmètre réel =
/// l'appartenance — tranche M2, #141) : **la** réaction d'une personne à un
/// message, une ligne par personne et par message.
///
/// **Avec tombstone** : retirer sa réaction pose `deletedAt`, et la ligne
/// quitte le magasin par le chemin commun. Changer d'emoji réécrit la même ligne
/// (même `id`). L'agrégat sous la bulle se calcule **à la lecture**
/// (`GroupDao.threadOf`).
@DataClassName('GroupMessageReactionRow')
class GroupMessageReactions extends Table with SyncedRow {
  @override
  String get tableName => 'group_message_reactions';

  /// UUIDv7 serveur.
  TextColumn get id => text()();
  TextColumn get groupId => text()();
  TextColumn get messageId => text()();
  TextColumn get userId => text()();

  /// Un emoji, stocké tel quel.
  TextColumn get emoji => text()();

  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Collection `group_message_hides` (partition `private` — tranche M2, #141) :
/// les messages que **j'ai** supprimés pour moi. Le fil ne les montre plus, sur
/// aucun de mes appareils ; personne d'autre ne le sait.
///
/// **Rangée par `messageId`** — c'est ce que le fil interroge. L'`id` serveur
/// (un entier) est gardé, parce qu'on stocke ce que le serveur envoie. Sans
/// tombstone : on ne « démasque » pas.
@DataClassName('GroupMessageHideRow')
class GroupMessageHides extends Table with SyncedRow {
  @override
  String get tableName => 'group_message_hides';

  TextColumn get messageId => text()();
  TextColumn get groupId => text()();

  /// L'identifiant serveur du masquage. Non lu.
  IntColumn get hideId => integer().nullable()();

  DateTimeColumn get createdAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {messageId};
}
