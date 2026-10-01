import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import 'app_database.dart';
import 'tables/announcement_tables.dart';
import 'tables/group_tables.dart';
import 'tables/mediatheque_tables.dart';

part 'group_dao.g.dart';

/// **Les lectures du magasin, côté « Échanges »** (#96) — et les seules écritures
/// de ce domaine, qui ne touchent **que** la table locale seule.
///
/// Un DAO par domaine, comme `mediatheque_dao` et `announcement_dao` : la
/// synchronisation écrit les cinq collections répliquées, ce fichier les lit, et
/// le réseau ne peint jamais.
///
/// ## Trois règles de lecture, et chacune a coûté un raisonnement
///
/// 1. **Une conversation se lit sur `group_members`, pas sur `groups`.** Ni
///    `groups` ni `profiles` n'a de tombstone : quitter un groupe ne fait
///    disparaître aucune ligne de `groups` du magasin. Ce qui voyage, c'est la
///    **rétractation de mon appartenance**, et c'est pourquoi la liste part de
///    `group_members` et y revient. Partir de `groups` laisserait pour toujours à
///    l'écran les conversations qu'on a quittées — et ça s'afficherait
///    parfaitement.
/// 2. **Les jointures sont tolérantes**, comme partout : un message dont le
///    profil n'est pas encore arrivé se rend quand même, sans nom. L'absence
///    s'affiche comme une absence — jamais un « Utilisateur inconnu », qui
///    ressemblerait à une donnée.
/// 3. **L'écho optimiste est filtré à la lecture**, jamais supprimé à l'aveugle :
///    une ligne en attente cesse de paraître dès que la ligne serveur portant le
///    même `clientMessageId` est en magasin. Voir [threadOf].
@DriftAccessor(
  tables: [
    Groups,
    GroupMembers,
    GroupJoinRequests,
    GroupMessages,
    Profiles,
    PendingGroupMessages,
    OfficialAccounts,
    Contributors,
  ],
)
class GroupDao extends DatabaseAccessor<AppDatabase> with _$GroupDaoMixin {
  GroupDao(super.db);

  /// Les politiques d'adhésion qui rendent un groupe **proposable**.
  ///
  /// `open` (on entre) et `request` (on demande). `invite_only` — **le défaut
  /// côté serveur** — n'y est pas : proposer un groupe sur invitation serait une
  /// porte qui ne s'ouvre pas, et c'est exactement le sélecteur menteur que #83 a
  /// retiré de l'écran de connexion.
  ///
  /// Écrit **une seule fois** : la clause `IN` de [discoverableGroupsFor] est
  /// construite à partir de cet ensemble-ci, et non recopiée dans son SQL. Deux
  /// listes seraient deux occasions de n'en modifier qu'une — et l'oubli ne
  /// ferait échouer aucun test, il montrerait simplement une carte de trop ou de
  /// moins.
  static const Set<String> joinablePolicies = {'open', 'request'};

  /// **Mes conversations**, groupes et tête-à-tête mêlés, triées par récence.
  ///
  /// ## Pourquoi cette requête est écrite en SQL et non en jointures typées
  ///
  /// Elle a besoin de deux choses qu'une jointure ne sait pas exprimer, et une
  /// seule requête vaut mieux que trois flux recomposés à la main — chacun
  /// pouvant arriver à son tour et faire clignoter la liste :
  ///
  /// 1. **le dernier message de chaque groupe** (un `ORDER BY … LIMIT 1`
  ///    corrélé) ;
  /// 2. **l'autre membre d'un tête-à-tête** — un second passage sur
  ///    `group_members`, corrélé lui aussi, pour que le titre d'un DM soit le nom
  ///    de la personne et non celui que le serveur a donné au groupe.
  ///
  /// `readsFrom` est ce qui rend le flux vivant : une page de `group_messages`
  /// appliquée par la synchronisation ré-exécute la requête, et la liste se
  /// réordonne sous les yeux du fidèle.
  ///
  /// ⚠️ Le tri retombe sur `updated_at` puis `created_at` du groupe quand aucun
  /// message n'est encore arrivé. Un groupe neuf, ou un groupe dont le fil n'a
  /// pas encore été tiré, doit **apparaître** : le renvoyer en fin de liste pour
  /// défaut de message cacherait la conversation qu'on vient de rejoindre.
  Selectable<ConversationRecord> conversationsOf(String userId) {
    return customSelect(
      '''
SELECT
  g.id                AS group_id,
  g.name              AS group_name,
  g.description       AS description,
  g.is_direct         AS is_direct,
  g.member_count      AS member_count,
  g.post_policy       AS post_policy,
  g.is_write_locked   AS is_write_locked,
  g.is_active         AS is_active,
  me.role             AS my_role,
  peer.id             AS peer_id,
  peer.display_name   AS peer_name,
  peer.avatar_url     AS peer_avatar_url,
  last.body           AS last_body,
  last.is_system      AS last_is_system,
  last.author_id      AS last_author_id,
  last.created_at     AS last_created_at,
  COALESCE(last.created_at, g.updated_at, g.created_at) AS activity_at
FROM group_members AS me
JOIN "groups" AS g ON g.id = me.group_id
LEFT JOIN profiles AS peer ON peer.id = (
  SELECT other.user_id FROM group_members AS other
   WHERE other.group_id = g.id AND other.user_id <> me.user_id
   ORDER BY other.id LIMIT 1
)
LEFT JOIN group_messages AS last ON last.id = (
  SELECT m.id FROM group_messages AS m
   WHERE m.group_id = g.id
   ORDER BY m.created_at DESC, m.id DESC LIMIT 1
)
WHERE me.user_id = ?1
ORDER BY activity_at DESC, g.id DESC
''',
      variables: [Variable<String>(userId)],
      readsFrom: {groups, groupMembers, groupMessages, profiles},
    ).map(
      (row) => ConversationRecord(
        groupId: row.read<String>('group_id'),
        groupName: row.read<String>('group_name'),
        description: row.read<String?>('description'),
        isDirect: row.read<bool>('is_direct'),
        memberCount: row.read<int>('member_count'),
        postPolicy: row.read<String>('post_policy'),
        isWriteLocked: row.read<bool>('is_write_locked'),
        isActive: row.read<bool>('is_active'),
        myRole: row.read<String>('my_role'),
        peerName: row.read<String?>('peer_name'),
        peerAvatarUrl: row.read<String?>('peer_avatar_url'),
        peerId: row.read<String?>('peer_id'),
        lastBody: row.read<String?>('last_body'),
        lastIsSystem: row.read<bool?>('last_is_system'),
        lastAuthorId: row.read<String?>('last_author_id'),
        lastCreatedAt: row.read<DateTime?>('last_created_at'),
      ),
    );
  }

  /// **Les groupes à rejoindre** : politique ouverte ou sur demande, actifs, dont
  /// je ne suis pas membre.
  ///
  /// Elle existe pour une raison très concrète (décision 3 du cadrage) : la
  /// politique d'adhésion par défaut est `invite_only` et un groupe
  /// institutionnel naît avec `group_members` **vide**, si bien que le groupe de
  /// discussion créé au backoffice ne serait visible de personne. Le serveur sert
  /// déjà ces groupes-là dans le même périmètre ; c'est ici qu'on les distingue
  /// de mes conversations.
  ///
  /// `is_direct = 0` : un tête-à-tête n'est jamais découvrable — ni côté serveur,
  /// ni ici.
  ///
  /// `request_status` porte l'état de **ma** demande quand j'en ai une, et c'est
  /// tout l'usage que cette tranche a de `group_join_requests` : une carte dont
  /// la demande est en attente le dit, au lieu de proposer un geste déjà fait.
  Selectable<DiscoverRecord> discoverableGroupsFor(String userId) {
    final policies = joinablePolicies.toList(growable: false);
    // Un emplacement nommé par politique, numérotés **après** `?1` (l'acteur) :
    // les variables positionnelles de Drift commencent à 1, et les recoller à la
    // main est ce qui garde la liste des politiques à un seul endroit.
    final placeholders = [
      for (var i = 0; i < policies.length; i++) '?${i + 2}',
    ].join(', ');

    return customSelect(
      '''
SELECT
  g.id            AS group_id,
  g.name          AS group_name,
  g.description   AS description,
  g.join_policy   AS join_policy,
  g.member_count  AS member_count,
  g.owner_kind    AS owner_kind,
  owner.display_name AS owner_name,
  account.name    AS account_name,
  account.short_name AS account_short_name,
  contributor.name AS contributor_name,
  mine.status     AS request_status
FROM "groups" AS g
LEFT JOIN profiles AS owner ON owner.id = g.owner_id
LEFT JOIN official_accounts AS account ON account.id = g.owner_official_account_id
LEFT JOIN contributors AS contributor ON contributor.id = g.owner_contributor_id
LEFT JOIN group_join_requests AS mine ON mine.id = (
  SELECT r.id FROM group_join_requests AS r
   WHERE r.group_id = g.id AND r.user_id = ?1
   ORDER BY r.id DESC LIMIT 1
)
WHERE g.is_active = 1
  AND g.is_direct = 0
  AND g.join_policy IN ($placeholders)
  AND NOT EXISTS (
    SELECT 1 FROM group_members AS m
     WHERE m.group_id = g.id AND m.user_id = ?1
  )
ORDER BY g.member_count DESC, g.name ASC, g.id ASC
''',
      variables: [
        Variable<String>(userId),
        for (final policy in policies) Variable<String>(policy),
      ],
      readsFrom: {
        groups,
        groupMembers,
        groupJoinRequests,
        profiles,
        officialAccounts,
        contributors,
      },
    ).map(
      (row) => DiscoverRecord(
        groupId: row.read<String>('group_id'),
        groupName: row.read<String>('group_name'),
        description: row.read<String?>('description'),
        joinPolicy: row.read<String>('join_policy'),
        memberCount: row.read<int>('member_count'),
        ownerKind: row.read<String>('owner_kind'),
        hostName: row.read<String?>('owner_name') ??
            row.read<String?>('account_short_name') ??
            row.read<String?>('account_name') ??
            row.read<String?>('contributor_name'),
        requestStatus: row.read<String?>('request_status'),
      ),
    );
  }

  /// **Le fil d'un groupe**, du plus ancien au plus récent, **écho optimiste
  /// compris**, chaque message avec ce que le magasin possède de son auteur.
  ///
  /// ## Les messages confirmés et les messages en attente sortent de la **même**
  /// requête
  ///
  /// Un `UNION ALL`, et non deux flux recomposés : le fil doit avoir **un seul**
  /// ordre, et deux sources qui arrivent chacune à son tour feraient sauter le
  /// dernier message au moment où l'une des deux se rafraîchit. Le tri est fait
  /// une fois, par SQLite, sur un `created_at` que les deux tables stockent dans
  /// la même unité.
  ///
  /// ## La jointure d'auteur est **externe**, et c'est tout le contrat d'ADR-0032
  ///
  /// Un message dont `author_id` est nul — le serveur, ou un **auteur retiré** —
  /// n'a aucun profil à joindre, et il doit se rendre quand même. C'est à l'étage
  /// du dessus de lire le **couple** `(authorId, isSystem)` pour décider bandeau
  /// ou bulle ; cette requête ne tranche rien, elle livre les deux colonnes.
  ///
  /// ## La réconciliation est un `NOT EXISTS`, pas une suppression
  ///
  /// Une ligne en attente cesse de paraître dès qu'une ligne de `group_messages`
  /// porte le même `clientMessageId`. La supprimer au retour du `POST` aurait fait
  /// **disparaître** le message de l'écran pendant le temps — court mais réel —
  /// qui sépare la réponse du cycle de synchronisation qui ramène la ligne. Un
  /// message qui clignote est pire qu'un message marqué « en cours d'envoi ».
  /// [purgeReconciled] ramasse ensuite ; aucun écran n'en dépend.
  Selectable<ThreadEntryRecord> threadOf(String groupId, String userId) {
    return customSelect(
      '''
SELECT
  m.id            AS entry_id,
  m.body          AS body,
  m.author_id     AS author_id,
  m.is_system     AS is_system,
  m.created_at    AS created_at,
  0               AS is_pending,
  0               AS has_failed,
  author.display_name AS author_name,
  author.avatar_url   AS author_avatar_url
FROM group_messages AS m
LEFT JOIN profiles AS author ON author.id = m.author_id
WHERE m.group_id = ?1
UNION ALL
SELECT
  p.client_message_id,
  p.body,
  ?2,
  0,
  p.created_at,
  1,
  p.failed,
  me.display_name,
  me.avatar_url
FROM pending_group_messages AS p
LEFT JOIN profiles AS me ON me.id = ?2
WHERE p.group_id = ?1
  AND NOT EXISTS (
    SELECT 1 FROM group_messages AS g
     WHERE g.client_message_id = p.client_message_id
  )
ORDER BY created_at ASC, entry_id ASC
''',
      variables: [Variable<String>(groupId), Variable<String>(userId)],
      readsFrom: {groupMessages, profiles, pendingGroupMessages},
    ).map(
      (row) => ThreadEntryRecord(
        id: row.read<String>('entry_id'),
        body: row.read<String>('body'),
        authorId: row.read<String?>('author_id'),
        isSystem: row.read<bool>('is_system'),
        createdAt: row.read<DateTime?>('created_at'),
        isPending: row.read<bool>('is_pending'),
        hasFailed: row.read<bool>('has_failed'),
        authorName: row.read<String?>('author_name'),
        authorAvatarUrl: row.read<String?>('author_avatar_url'),
      ),
    );
  }

  /// **Le groupe**, avec le nom de son animateur quand le magasin le connaît.
  ///
  /// Les trois jointures de propriétaire sont posées ensemble, et `ownerKind` dit
  /// laquelle compte : `user` → `profiles`, `official_account` →
  /// `official_accounts`, `contributor` → `contributors`. Les trois collections
  /// sont déjà répliquées, et c'est précisément pourquoi les trois colonnes
  /// `owner*` sont stockées.
  Selectable<GroupWithHost> groupById(String groupId) {
    final query = select(groups).join([
      leftOuterJoin(profiles, profiles.id.equalsExp(groups.ownerId)),
      leftOuterJoin(
        officialAccounts,
        officialAccounts.id.equalsExp(groups.ownerOfficialAccountId),
      ),
      leftOuterJoin(
        contributors,
        contributors.id.equalsExp(groups.ownerContributorId),
      ),
    ])
      ..where(groups.id.equals(groupId));

    return query.map(
      (row) => GroupWithHost(
        group: row.readTable(groups),
        ownerProfile: row.readTableOrNull(profiles),
        ownerAccount: row.readTableOrNull(officialAccounts),
        ownerContributor: row.readTableOrNull(contributors),
      ),
    );
  }

  /// **Le roster d'un groupe** : les appartenances encore en magasin, nommées par
  /// `profiles` quand il les a.
  ///
  /// Il n'y a rien à filtrer sur un tombstone : une appartenance retirée a
  /// **quitté** le magasin (c'est le chemin commun du moteur), et ce qui reste est
  /// actif par construction.
  Selectable<GroupMemberWithProfile> membersOf(String groupId) {
    final query = select(groupMembers).join([
      leftOuterJoin(profiles, profiles.id.equalsExp(groupMembers.userId)),
    ])
      ..where(groupMembers.groupId.equals(groupId))
      // Les animateurs d'abord — `leader` avant `moderator` avant `member` —,
      // puis le nom. L'ordre est posé ici et non à l'affichage : deux écrans
      // listent ce roster, et deux tris finiraient par ne plus dire la même
      // chose.
      ..orderBy([
        OrderingTerm.asc(groupMembers.role),
        OrderingTerm.asc(profiles.displayName),
        OrderingTerm.asc(groupMembers.id),
      ]);

    return query.map(
      (row) => GroupMemberWithProfile(
        member: row.readTable(groupMembers),
        profile: row.readTableOrNull(profiles),
      ),
    );
  }

  /// **Un profil**, ou `null` tant que `profiles` ne l'a pas livré.
  Selectable<ProfileRow> profileById(String userId) =>
      select(profiles)..where((p) => p.id.equals(userId));

  /// **Le tête-à-tête que je partage déjà avec cette personne**, ou `null`.
  ///
  /// Un DM est un groupe `isDirect` dont le roster porte **deux** lignes : la
  /// mienne et la sienne. La requête les exige toutes les deux — un groupe direct
  /// dont je n'ai reçu qu'une moitié du roster n'est pas une conversation que je
  /// peux ouvrir.
  ///
  /// `null` veut dire « je n'ai jamais écrit à cette personne », et **pas** « je ne
  /// peux pas ». Créer le tête-à-tête se fait côté serveur en envoyant le premier
  /// message (`POST /groups/direct/:targetUserId/messages`, get-or-create
  /// paresseux), ce qui est hors du périmètre de cette tranche — voir
  /// `MemberProfileScreen`.
  Selectable<String> directGroupWith({
    required String me,
    required String other,
  }) {
    return customSelect(
      '''
SELECT g.id AS group_id
FROM "groups" AS g
JOIN group_members AS mine  ON mine.group_id  = g.id AND mine.user_id  = ?1
JOIN group_members AS yours ON yours.group_id = g.id AND yours.user_id = ?2
WHERE g.is_direct = 1
ORDER BY g.id ASC
LIMIT 1
''',
      variables: [Variable<String>(me), Variable<String>(other)],
      readsFrom: {groups, groupMembers},
    ).map((row) => row.read<String>('group_id'));
  }

  /// **Mon appartenance à un groupe**, ou `null` : c'est elle qui dit si la barre
  /// de saisie a lieu d'être, et avec quel rôle.
  Selectable<GroupMemberRow> membershipOf(String groupId, String userId) =>
      select(groupMembers)
        ..where((m) => m.groupId.equals(groupId) & m.userId.equals(userId));

  // ───────────────────────────────────────────────────────────────────────────
  // Écritures — **la table locale seule, et rien d'autre**
  // ───────────────────────────────────────────────────────────────────────────

  /// Pose l'écho d'un message qu'on vient de taper.
  ///
  /// `insertOrReplace` sur la clé d'idempotence : un second appui sur le même
  /// message ne pose pas un second écho, il réécrit le premier — et c'est la même
  /// clé qui empêchera le doublon **au réseau**.
  Future<void> rememberPending({
    required String clientMessageId,
    required String groupId,
    required String body,
    required DateTime createdAt,
  }) {
    return into(pendingGroupMessages).insert(
      PendingGroupMessagesCompanion.insert(
        clientMessageId: clientMessageId,
        groupId: groupId,
        body: body,
        createdAt: createdAt,
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  /// Un écho **par sa clé**, ou `null`. Sert au « réessayer » : il renvoie sous la
  /// **même** clé, et a donc besoin du corps et de l'instant d'origine.
  Future<PendingGroupMessageRow?> pendingById(String clientMessageId) {
    return (select(pendingGroupMessages)
          ..where((p) => p.clientMessageId.equals(clientMessageId)))
        .getSingleOrNull();
  }

  /// **L'envoi n'est pas parti**, et l'écran doit le dire.
  ///
  /// Un seul drapeau pour tous les refus : réseau, 401, 403, 422, 5xx. Ils ne
  /// disent pas la même chose au développeur, mais ils disent exactement la même
  /// chose au fidèle — « ce message n'est pas parti » —, et distinguer à l'écran
  /// des causes sur lesquelles il ne peut rien agir n'aiderait personne.
  Future<void> markPendingFailed(String clientMessageId) {
    return (update(pendingGroupMessages)
          ..where((p) => p.clientMessageId.equals(clientMessageId)))
        .write(const PendingGroupMessagesCompanion(failed: Value(true)));
  }

  /// Retire l'écho d'un message **abandonné** par qui l'avait écrit.
  Future<void> forgetPending(String clientMessageId) {
    return (delete(pendingGroupMessages)
          ..where((p) => p.clientMessageId.equals(clientMessageId)))
        .go();
  }

  /// **Ramasse les échos que le serveur a confirmés.**
  ///
  /// Appelée après un cycle de synchronisation réussi, et jamais sur le chemin du
  /// rendu : [pendingOf] filtre déjà, donc rien à l'écran ne dépend de ce
  /// nettoyage. Il existe pour que la table ne grossisse pas indéfiniment, pas
  /// pour corriger un affichage.
  Future<int> purgeReconciled() {
    return customUpdate(
      '''
DELETE FROM pending_group_messages
 WHERE client_message_id IN (
   SELECT m.client_message_id FROM group_messages AS m
    WHERE m.client_message_id IS NOT NULL
 )
''',
      updates: {pendingGroupMessages},
      updateKind: UpdateKind.delete,
    );
  }
}

/// Une ligne de la liste des conversations — ce que la tuile affiche, et rien de
/// plus.
///
/// [peerName] n'est renseigné que pour un tête-à-tête, et il peut rester nul
/// même alors : le profil de l'autre n'est pas encore arrivé, ou cette personne
/// n'a jamais rempli son nom. L'absence se dessine comme une absence.
@immutable
class ConversationRecord {
  const ConversationRecord({
    required this.groupId,
    required this.groupName,
    required this.isDirect,
    required this.memberCount,
    required this.postPolicy,
    required this.isWriteLocked,
    required this.isActive,
    required this.myRole,
    this.description,
    this.peerId,
    this.peerName,
    this.peerAvatarUrl,
    this.lastBody,
    this.lastIsSystem,
    this.lastAuthorId,
    this.lastCreatedAt,
  });

  final String groupId;
  final String groupName;
  final String? description;
  final bool isDirect;
  final int memberCount;
  final String postPolicy;
  final bool isWriteLocked;
  final bool isActive;
  final String myRole;

  final String? peerId;
  final String? peerName;
  final String? peerAvatarUrl;

  final String? lastBody;
  final bool? lastIsSystem;
  final String? lastAuthorId;
  final DateTime? lastCreatedAt;
}

/// Une carte de la rangée « groupes à rejoindre ».
@immutable
class DiscoverRecord {
  const DiscoverRecord({
    required this.groupId,
    required this.groupName,
    required this.joinPolicy,
    required this.memberCount,
    required this.ownerKind,
    this.description,
    this.hostName,
    this.requestStatus,
  });

  final String groupId;
  final String groupName;
  final String? description;
  final String joinPolicy;
  final int memberCount;
  final String ownerKind;

  /// Le nom de l'animateur, résolu depuis celle des trois collections que
  /// [ownerKind] désigne — ou `null` quand aucune ne l'a encore livré.
  final String? hostName;

  /// `pending` | `approved` | `rejected`, ou `null` si je n'ai jamais demandé.
  final String? requestStatus;
}

/// Une entrée du fil : un message confirmé **ou** un écho encore en attente.
///
/// [authorName] est nul dans **trois** cas distincts, et c'est l'étage du dessus
/// qui les départage sur le couple ([authorId], [isSystem]) : le serveur parle,
/// l'auteur a été retiré (ADR-0032), ou le profil n'est simplement pas encore
/// arrivé. Cette classe ne tranche rien — elle porte les deux colonnes.
@immutable
class ThreadEntryRecord {
  const ThreadEntryRecord({
    required this.id,
    required this.body,
    required this.isSystem,
    required this.isPending,
    required this.hasFailed,
    this.authorId,
    this.createdAt,
    this.authorName,
    this.authorAvatarUrl,
  });

  /// L'UUIDv7 serveur pour un message confirmé, le `clientMessageId` pour un
  /// écho.
  final String id;

  final String body;
  final String? authorId;
  final bool isSystem;
  final DateTime? createdAt;

  /// Vrai = la ligne vient de `pending_group_messages`, le serveur ne l'a pas
  /// confirmée.
  final bool isPending;

  /// Vrai = l'envoi a échoué. N'a de sens que si [isPending].
  final bool hasFailed;

  final String? authorName;
  final String? authorAvatarUrl;
}

/// Un groupe et les trois propriétaires possibles, dont un seul est renseigné.
@immutable
class GroupWithHost {
  const GroupWithHost({
    required this.group,
    this.ownerProfile,
    this.ownerAccount,
    this.ownerContributor,
  });

  final GroupRow group;
  final ProfileRow? ownerProfile;
  final OfficialAccountRow? ownerAccount;
  final ContributorRow? ownerContributor;

  /// Le nom de l'animateur, choisi par `ownerKind` et non par « le premier non
  /// nul » : un groupe dont le propriétaire est un compte officiel ne doit pas se
  /// mettre à afficher un intervenant parce qu'une colonne traînait.
  String? get hostName => switch (group.ownerKind) {
        'user' => ownerProfile?.displayName,
        'official_account' => ownerAccount?.shortName ?? ownerAccount?.name,
        'contributor' => ownerContributor?.name,
        _ => null,
      };
}

/// Une appartenance, et ce que le magasin possède de la personne.
@immutable
class GroupMemberWithProfile {
  const GroupMemberWithProfile({required this.member, this.profile});

  final GroupMemberRow member;
  final ProfileRow? profile;
}
