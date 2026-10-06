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
    GroupReads,
    PendingGroupReads,
    GroupMutes,
    OfficialAccounts,
    Contributors,
    // M8 (#146) : mon rangement, lu par la liste des conversations.
    GroupArrangements,
    PendingGroupArrangements,
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

  /// **Les jointures de la position de lecture d'un groupe** (#140), à poser
  /// derrière un `FROM … AS g` : la lecture servie (`r`), son message s'il est en
  /// magasin (`rm`), et la lecture locale pas encore confirmée (`pr`).
  ///
  /// Écrites **une fois** et partagées par la liste des conversations et par le
  /// fil : le compteur de la tuile et le séparateur « N messages non lus » ne
  /// doivent jamais pouvoir dire deux choses différentes.
  static const String _readJoins = '''
LEFT JOIN group_reads AS r ON r.group_id = g.id
LEFT JOIN group_messages AS rm ON rm.id = r.last_read_message_id
LEFT JOIN pending_group_reads AS pr ON pr.group_id = g.id''';

  /// **La jointure de ma sourdine** (M5), à poser derrière un `FROM … AS g` :
  /// `mu`, ou rien si je n'ai jamais réglé la sourdine de ce groupe.
  static const String _muteJoin =
      'LEFT JOIN group_mutes AS mu ON mu.group_id = g.id';

  /// **La formule des non-lus du contrat serveur** (M1a §2), pour un message
  /// d'alias [m], **moi** étant la variable `?[me]`. Exige [_readJoins].
  ///
  /// Un message est non lu s'il n'est pas du serveur, pas de moi, et
  /// **postérieur aux deux lectures** — la servie et la locale —, c'est-à-dire à
  /// la plus avancée des deux. « Postérieur » se juge dans l'ordre du fil,
  /// `(createdAt, id)` :
  ///
  /// - aucune lecture servie → tout est non lu (le premier message direct reçu) ;
  /// - le message lu est en magasin → comparaison exacte au couple ;
  /// - il n'y est pas (purgé, hors historique) → repli sur `lastReadAt`.
  ///
  /// ⚠️ `author_id IS NULL OR …` et non `author_id <> moi` seul : en SQL, une
  /// comparaison à `NULL` est `NULL`, et le message d'un **auteur retiré**
  /// (ADR-0032) cesserait silencieusement de compter. Les tombstones, eux, ont
  /// quitté le magasin.
  static String _isUnread(String m, int me) => '''
($m.is_system = 0
 AND ($m.author_id IS NULL OR $m.author_id <> ?$me)
 AND (r.group_id IS NULL
      OR COALESCE(rm.created_at, r.last_read_at) IS NULL
      OR $m.created_at > COALESCE(rm.created_at, r.last_read_at)
      OR (rm.id IS NOT NULL AND $m.created_at = rm.created_at AND $m.id > rm.id))
 AND (pr.group_id IS NULL
      OR $m.created_at > pr.message_created_at
      OR ($m.created_at = pr.message_created_at AND $m.id > pr.message_id)))''';

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
  COALESCE(last.created_at, g.updated_at, g.created_at) AS activity_at,
  (SELECT COUNT(*) FROM group_messages AS u
    WHERE u.group_id = g.id AND ${_isUnread('u', 1)}) AS unread_count,
  -- M8 (#146) : mon rangement effectif — le geste local en attente l'emporte.
  CASE WHEN pa.group_id IS NOT NULL THEN pa.archived
       ELSE ga.archived_at IS NOT NULL END AS is_archived,
  CASE WHEN pa.group_id IS NOT NULL
       THEN (CASE WHEN pa.pinned THEN COALESCE(ga.pinned_at, pa.requested_at) END)
       ELSE ga.pinned_at END AS pinned_at,
  mu.muted_until      AS muted_until,
  mu.muted_forever    AS muted_forever
FROM group_members AS me
JOIN "groups" AS g ON g.id = me.group_id
$_readJoins
LEFT JOIN group_arrangements AS ga ON ga.group_id = g.id
LEFT JOIN pending_group_arrangements AS pa ON pa.group_id = g.id
$_muteJoin
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
      readsFrom: {
        groups,
        groupMembers,
        groupMessages,
        profiles,
        groupReads,
        pendingGroupReads,
        groupArrangements,
        pendingGroupArrangements,
        groupMutes,
      },
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
        unreadCount: row.read<int>('unread_count'),
        isArchived: row.read<bool>('is_archived'),
        pinnedAt: row.read<DateTime?>('pinned_at'),
        mutedUntil: row.read<DateTime?>('muted_until'),
        mutedForever: row.read<bool?>('muted_forever') ?? false,
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
  /// ## Les [limit] plus récents seulement (#140)
  ///
  /// L'historique s'affiche **par pages** : le fil s'ouvre sur les derniers
  /// messages, et l'écran élargit la fenêtre quand on remonte. Le tri descendant
  /// borné est fait à l'intérieur, l'ordre chronologique rétabli à l'extérieur.
  /// `null` = tout le fil.
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
  /// porte le même `clientMessageId` — qu'elle arrive par le tirage ou par le
  /// canal `users/{id}` (#140). La supprimer au retour du `POST` aurait fait
  /// **disparaître** le message de l'écran pendant le temps — court mais réel —
  /// qui sépare la réponse de l'arrivée de la ligne. Un message qui clignote est
  /// pire qu'un message marqué « en cours d'envoi ». [purgeReconciled] ramasse
  /// ensuite ; aucun écran n'en dépend.
  ///
  /// ## `is_unread` porte la formule des non-lus (#140)
  ///
  /// La même que le compteur de la liste ([_isUnread]) : c'est elle qui place le
  /// séparateur « N messages non lus ». Un écho n'est jamais non lu.
  Selectable<ThreadEntryRecord> threadOf(
    String groupId,
    String userId, {
    int? limit,
  }) {
    return customSelect(
      '''
SELECT * FROM (
SELECT
  m.id            AS entry_id,
  m.body          AS body,
  m.author_id     AS author_id,
  m.is_system     AS is_system,
  m.created_at    AS created_at,
  0               AS is_pending,
  0               AS has_failed,
  author.display_name AS author_name,
  author.avatar_url   AS author_avatar_url,
  CASE WHEN ${_isUnread('m', 2)} THEN 1 ELSE 0 END AS is_unread
FROM group_messages AS m
JOIN (SELECT ?1 AS id) AS g
$_readJoins
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
  me.avatar_url,
  0
FROM pending_group_messages AS p
LEFT JOIN profiles AS me ON me.id = ?2
WHERE p.group_id = ?1
  AND NOT EXISTS (
    SELECT 1 FROM group_messages AS gm
     WHERE gm.client_message_id = p.client_message_id
  )
ORDER BY created_at DESC, entry_id DESC
LIMIT ?3
)
ORDER BY created_at ASC, entry_id ASC
''',
      variables: [
        Variable<String>(groupId),
        Variable<String>(userId),
        // `LIMIT -1` : sans borne, en SQLite.
        Variable<int>(limit ?? -1),
      ],
      readsFrom: {
        groupMessages,
        profiles,
        pendingGroupMessages,
        groupReads,
        pendingGroupReads,
      },
    ).map(
      (row) => ThreadEntryRecord(
        id: row.read<String>('entry_id'),
        body: row.read<String?>('body'),
        authorId: row.read<String?>('author_id'),
        isSystem: row.read<bool>('is_system'),
        createdAt: row.read<DateTime?>('created_at'),
        isPending: row.read<bool>('is_pending'),
        hasFailed: row.read<bool>('has_failed'),
        authorName: row.read<String?>('author_name'),
        authorAvatarUrl: row.read<String?>('author_avatar_url'),
        isUnread: row.read<bool>('is_unread'),
      ),
    );
  }

  /// **Le nombre de non-lus d'un groupe**, une fois (#140) — la formule de
  /// [_isUnread]. Sert à l'ouverture du fil : la fenêtre de l'historique doit
  /// être assez large pour contenir le premier non-lu, sur lequel le fil s'ouvre.
  Future<int> unreadCountOf(String groupId, String userId) {
    return customSelect(
      '''
SELECT COUNT(*) AS n
FROM group_messages AS m
JOIN (SELECT ?1 AS id) AS g
$_readJoins
WHERE m.group_id = ?1 AND ${_isUnread('m', 2)}
''',
      variables: [Variable<String>(groupId), Variable<String>(userId)],
      readsFrom: {groupMessages, groupReads, pendingGroupReads},
    ).map((row) => row.read<int>('n')).getSingle();
  }

  /// **Le magasin connaît-il ce groupe ?** (#140) Un événement du canal
  /// `users/{id}` qui cite un groupe inconnu — un tête-à-tête ouvert par l'autre,
  /// un ajout fait au portail — doit déclencher une synchronisation, qui ramène
  /// le reste (profils, roster).
  Future<bool> knowsGroup(String groupId) async {
    final row = await (select(groups)..where((g) => g.id.equals(groupId)))
        .getSingleOrNull();
    return row != null;
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
  /// paresseux) — l'écran du premier message, `DirectChatScreen` (#145).
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

  // ── #145 (M6) ─────────────────────────────────────────────────────────────

  /// **Mes contacts de groupe** (#145, décisions 8 et 9) : les personnes avec
  /// qui je partage **au moins un groupe qui n'est pas un tête-à-tête**, moi
  /// exclu, triées par nom (les sans-nom à la fin).
  ///
  /// C'est **exactement** la règle du serveur (`sharedGroupContacts`) : un
  /// sélecteur plus large proposerait des personnes qu'il refuserait — démarrer
  /// un tête-à-tête, ou les inscrire dans un groupe qu'on crée. Les appartenances
  /// retirées ont quitté le magasin (tombstone), il n'y a rien à filtrer de plus.
  ///
  /// Une personne dont `profiles` n'a pas encore livré la ligne n'est pas
  /// proposée : sans profil, ni nom ni avatar à montrer, et la synchronisation
  /// suivante l'amènera.
  Selectable<({String userId, String? displayName, String? avatarUrl})>
      contactsOf(String userId) {
    return customSelect(
      '''
SELECT DISTINCT p.id AS user_id, p.display_name AS display_name,
       p.avatar_url AS avatar_url
FROM group_members AS ours
JOIN "groups" AS g ON g.id = ours.group_id AND g.is_direct = 0
JOIN group_members AS theirs ON theirs.group_id = ours.group_id
JOIN profiles AS p ON p.id = theirs.user_id
WHERE ours.user_id = ?1
  AND theirs.user_id <> ?1
ORDER BY p.display_name IS NULL, p.display_name COLLATE NOCASE, p.id
''',
      variables: [Variable<String>(userId)],
      readsFrom: {groups, groupMembers, profiles},
    ).map(
      (row) => (
        userId: row.read<String>('user_id'),
        displayName: row.read<String?>('display_name'),
        avatarUrl: row.read<String?>('avatar_url'),
      ),
    );
  }

  /// **Un battement à chaque changement de ce que lit la fiche d'un groupe**
  /// (#145) : le groupe, son roster, les noms et les propriétaires.
  ///
  /// La fiche observait `groups` seul et relisait le roster à chaque émission :
  /// un changement de rôle (nommer admin) n'écrit que `group_members`, et la
  /// fiche — qui en tire désormais les gestes offerts — restait sur l'ancien
  /// rôle jusqu'à ce que la ligne du groupe bouge. Une émission de plus quand
  /// une table voisine change ne coûte qu'une relecture.
  Stream<void> groupDetailChanges() => customSelect(
        'SELECT 1',
        readsFrom: {
          groups,
          groupMembers,
          profiles,
          officialAccounts,
          contributors,
        },
      ).watch().map((_) {});

  // ── fin #145 ──────────────────────────────────────────────────────────────

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

  /// **L'envoi repart** (#140) : l'écho repasse « en cours », et l'écran cesse
  /// de dire « pas parti » pendant qu'on réessaie.
  Future<void> markPendingSending(String clientMessageId) {
    return (update(pendingGroupMessages)
          ..where((p) => p.clientMessageId.equals(clientMessageId)))
        .write(const PendingGroupMessagesCompanion(failed: Value(false)));
  }

  /// **Les échos que le serveur n'a pas encore confirmés** (#140) — ceux que le
  /// renvoi automatique rejoue, du plus ancien au plus récent : l'ordre de
  /// rédaction est celui dans lequel ils doivent repartir.
  ///
  /// Ceux que le magasin a déjà réconciliés (la ligne serveur est arrivée) sont
  /// écartés : les renvoyer ne créerait pas de doublon — la clé d'idempotence
  /// l'interdit —, mais coûterait un aller-retour pour rien.
  Future<List<PendingGroupMessageRow>> unconfirmedPending() {
    return (select(pendingGroupMessages)
          ..where(
            (p) => notExistsQuery(
              select(groupMessages)
                ..where((g) => g.clientMessageId.equalsExp(p.clientMessageId)),
            ),
          )
          ..orderBy([(p) => OrderingTerm.asc(p.createdAt)]))
        .get();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // La lecture — l'outbox `pending_group_reads` (#140)
  // ───────────────────────────────────────────────────────────────────────────

  /// **Pose une lecture locale**, si elle avance sur la précédente.
  ///
  /// Monotone, comme la route serveur : un fil rouvert sur un message plus
  /// ancien (une page d'historique) ne recule pas la lecture. Rend `true` si la
  /// lecture a avancé, c'est-à-dire s'il y a quelque chose à envoyer.
  Future<bool> rememberRead({
    required String groupId,
    required String messageId,
    required DateTime messageCreatedAt,
  }) {
    return transaction(() async {
      final current = await (select(pendingGroupReads)
            ..where((r) => r.groupId.equals(groupId)))
          .getSingleOrNull();
      if (current != null && !_after(messageCreatedAt, messageId, current)) {
        return false;
      }
      await into(pendingGroupReads).insert(
        PendingGroupReadsCompanion.insert(
          groupId: groupId,
          messageId: messageId,
          messageCreatedAt: messageCreatedAt,
        ),
        mode: InsertMode.insertOrReplace,
      );
      return true;
    });
  }

  static bool _after(DateTime at, String id, PendingGroupReadRow current) {
    final byTime = at.compareTo(current.messageCreatedAt);
    if (byTime != 0) return byTime > 0;
    return id.compareTo(current.messageId) > 0;
  }

  /// Les lectures locales encore à confirmer — ce que le renvoi rejoue.
  Future<List<PendingGroupReadRow>> pendingReads() =>
      select(pendingGroupReads).get();

  /// **La lecture est confirmée** : la ligne locale part — mais seulement si
  /// elle désigne toujours ce message. Une lecture plus récente posée pendant
  /// l'aller-retour reste, et partira à son tour.
  Future<void> forgetRead({
    required String groupId,
    required String messageId,
  }) {
    return (delete(pendingGroupReads)
          ..where(
            (r) => r.groupId.equals(groupId) & r.messageId.equals(messageId),
          ))
        .go();
  }

  /// **La lecture servie d'un groupe**, ou `null` — pour juger si une ligne
  /// arrivée par le canal avance (`read.advanced` est monotone, l'ordre
  /// d'arrivée ne l'est pas).
  Future<GroupReadRow?> readOf(String groupId) =>
      (select(groupReads)..where((r) => r.groupId.equals(groupId)))
          .getSingleOrNull();

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

  // ───────────────────────────────────────────────────────────────────────────
  // Les notifications et la sourdine (M5)
  // ───────────────────────────────────────────────────────────────────────────

  /// **Ma sourdine dans un groupe**, ou `null` si je ne l'ai jamais réglée.
  Selectable<GroupMuteRow> muteOf(String groupId) =>
      select(groupMutes)..where((m) => m.groupId.equals(groupId));

  /// **Le dernier message d'un groupe**, quel qu'en soit l'auteur — la position
  /// jusqu'où « Marquer comme lu » avance la lecture. `null` sur un fil vide.
  Future<GroupMessageRow?> latestMessageOf(String groupId) {
    return (select(groupMessages)
          ..where((m) => m.groupId.equals(groupId))
          ..orderBy([
            (m) => OrderingTerm.desc(m.createdAt),
            (m) => OrderingTerm.desc(m.id),
          ])
          ..limit(1))
        .getSingleOrNull();
  }

  /// **De quoi dresser la notification d'une conversation** (M5), lu du
  /// magasin et de lui seul — ou `null` si [userId] n'en est pas membre.
  ///
  /// Les messages sont **les non-lus** au sens du contrat ([_isUnread]) : ni les
  /// miens, ni ceux du serveur, et rien d'antérieur à ma lecture. C'est ce qui
  /// fait qu'une notification se vide quand la discussion est lue ailleurs, et
  /// qu'un message système (« X a rejoint le groupe ») ne réveille personne.
  /// Les [limit] plus récents, du plus ancien au plus récent — l'ordre où la
  /// notification les empile.
  Future<ConversationDigest?> conversationDigestOf(
    String groupId,
    String userId, {
    int limit = 6,
  }) async {
    final header = await customSelect(
      '''
SELECT
  g.id                AS group_id,
  g.name              AS group_name,
  g.is_direct         AS is_direct,
  peer.display_name   AS peer_name,
  peer.avatar_url     AS peer_avatar_url,
  mu.muted_until      AS muted_until,
  mu.muted_forever    AS muted_forever,
  (SELECT COUNT(*) FROM group_messages AS u
    WHERE u.group_id = g.id AND ${_isUnread('u', 2)}) AS unread_count
FROM group_members AS me
JOIN "groups" AS g ON g.id = me.group_id
$_readJoins
$_muteJoin
LEFT JOIN profiles AS peer ON peer.id = (
  SELECT other.user_id FROM group_members AS other
   WHERE other.group_id = g.id AND other.user_id <> me.user_id
   ORDER BY other.id LIMIT 1
)
WHERE me.group_id = ?1 AND me.user_id = ?2
''',
      variables: [Variable<String>(groupId), Variable<String>(userId)],
      readsFrom: {
        groups,
        groupMembers,
        groupMessages,
        profiles,
        groupReads,
        pendingGroupReads,
        groupMutes,
      },
    ).getSingleOrNull();
    if (header == null) return null;

    final lines = await customSelect(
      '''
SELECT * FROM (
SELECT
  m.id                AS id,
  m.body              AS body,
  m.author_id         AS author_id,
  m.is_system         AS is_system,
  m.created_at        AS created_at,
  author.display_name AS author_name
FROM group_messages AS m
JOIN (SELECT ?1 AS id) AS g
$_readJoins
LEFT JOIN profiles AS author ON author.id = m.author_id
WHERE m.group_id = ?1 AND ${_isUnread('m', 2)}
ORDER BY m.created_at DESC, m.id DESC
LIMIT ?3
)
ORDER BY created_at ASC, id ASC
''',
      variables: [
        Variable<String>(groupId),
        Variable<String>(userId),
        Variable<int>(limit),
      ],
      readsFrom: {groupMessages, profiles, groupReads, pendingGroupReads},
    ).get();

    return ConversationDigest(
      groupId: header.read<String>('group_id'),
      groupName: header.read<String?>('group_name'),
      isDirect: header.read<bool?>('is_direct') ?? false,
      peerName: header.read<String?>('peer_name'),
      peerAvatarUrl: header.read<String?>('peer_avatar_url'),
      unreadCount: header.read<int>('unread_count'),
      mutedUntil: header.read<DateTime?>('muted_until'),
      mutedForever: header.read<bool?>('muted_forever') ?? false,
      messages: [
        for (final row in lines)
          DigestMessage(
            id: row.read<String>('id'),
            body: row.read<String?>('body'),
            authorId: row.read<String?>('author_id'),
            authorName: row.read<String?>('author_name'),
            createdAt: row.read<DateTime?>('created_at'),
          ),
      ],
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
    this.unreadCount = 0,
    this.isArchived = false,
    this.pinnedAt,
    this.mutedUntil,
    this.mutedForever = false,
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

  /// `null` aussi quand le dernier message est un **média** (#140) : la tuile
  /// le sait par [lastCreatedAt], qui reste renseigné.
  final String? lastBody;
  final bool? lastIsSystem;
  final String? lastAuthorId;
  final DateTime? lastCreatedAt;

  /// Les messages non lus de cette conversation — la formule du contrat serveur
  /// (`GroupDao._isUnread`).
  final int unreadCount;

  /// **Archivée par moi** (#146) — effective, outbox comprise.
  final bool isArchived;

  /// **Épinglée par moi**, et depuis quand (#146) — `null` sinon.
  final DateTime? pinnedAt;

  /// Ma sourdine (M5) — la fin d'une sourdine bornée, ou `null`.
  final DateTime? mutedUntil;

  /// « Toujours » (M5).
  final bool mutedForever;

  /// **La conversation est-elle en sourdine à [now] ?** Une sourdine bornée
  /// échue est levée : elle n'est jamais effacée, elle cesse simplement d'être
  /// dans le futur.
  bool isMutedAt(DateTime now) => isGroupMuted(
        mutedUntil: mutedUntil,
        mutedForever: mutedForever,
        now: now,
      );
}

/// **La règle de la sourdine**, écrite une fois (M5) : « toujours », ou une
/// échéance encore dans le futur. Celle du pusher serveur, à l'horloge près.
bool isGroupMuted({
  required DateTime? mutedUntil,
  required bool mutedForever,
  required DateTime now,
}) =>
    mutedForever || (mutedUntil != null && mutedUntil.isAfter(now));

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
    required this.isSystem,
    required this.isPending,
    required this.hasFailed,
    this.body,
    this.authorId,
    this.createdAt,
    this.authorName,
    this.authorAvatarUrl,
    this.isUnread = false,
  });

  /// L'UUIDv7 serveur pour un message confirmé, le `clientMessageId` pour un
  /// écho.
  final String id;

  /// `null` pour un message-média (#140, piège 1). Un écho porte toujours un
  /// texte.
  final String? body;
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

  /// Non lu au sens du contrat (#140) — jamais vrai pour un écho.
  final bool isUnread;
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

/// **Ce que le magasin sait d'une conversation à notifier** (M5) — lu par
/// [GroupDao.conversationDigestOf], mis en forme par
/// `lib/data/push/conversation_notification.dart`.
///
/// Elle porte des colonnes, elle ne tranche rien : le titre, l'aperçu masqué
/// et la sourdine se décident plus haut.
@immutable
class ConversationDigest {
  const ConversationDigest({
    required this.groupId,
    required this.isDirect,
    required this.unreadCount,
    required this.messages,
    this.groupName,
    this.peerName,
    this.peerAvatarUrl,
    this.mutedUntil,
    this.mutedForever = false,
  });

  final String groupId;
  final String? groupName;
  final bool isDirect;

  /// L'autre d'un tête-à-tête — `null` pour un groupe, ou tant que son profil
  /// n'est pas arrivé.
  final String? peerName;

  /// **Toujours `null` aujourd'hui** : `users` ne porte pas d'avatar (voir
  /// `Profiles.avatarUrl`). Gardé pour le jour où il en portera.
  final String? peerAvatarUrl;

  /// Tous mes non-lus de cette conversation — pas seulement ceux de [messages].
  final int unreadCount;

  /// Les non-lus les plus récents, du plus ancien au plus récent.
  final List<DigestMessage> messages;

  final DateTime? mutedUntil;
  final bool mutedForever;

  bool isMutedAt(DateTime now) => isGroupMuted(
        mutedUntil: mutedUntil,
        mutedForever: mutedForever,
        now: now,
      );
}

/// Un message non lu, avec ce que le magasin possède de son auteur.
///
/// [authorName] est nul quand l'auteur a été retiré (`authorId` nul, ADR-0032)
/// **ou** quand son profil n'est pas encore arrivé — [authorId] départage les
/// deux. Jamais un message du serveur : la formule des non-lus les écarte.
@immutable
class DigestMessage {
  const DigestMessage({
    required this.id,
    this.body,
    this.authorId,
    this.authorName,
    this.createdAt,
  });

  final String id;

  /// `null` pour un message-média (#140).
  final String? body;
  final String? authorId;
  final String? authorName;
  final DateTime? createdAt;
}
