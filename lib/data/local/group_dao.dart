import 'package:drift/drift.dart';

import 'app_database.dart';
import 'tables/announcement_tables.dart';
import 'tables/group_tables.dart';
import 'tables/mediatheque_tables.dart';
import 'tables/profile_tables.dart';

part 'group_dao.g.dart';

/// Un groupe dont **je suis membre**, et mon rôle dedans.
///
/// L'unité de l'**inbox** : une ligne `group_members` portant **mon** `userId`
/// est exactement ce qui range un groupe ici plutôt qu'en découverte. Depuis les
/// DM, `group_members` porte le roster complet — la requête filtre donc sur moi
/// pour ne rendre que **mon** appartenance (une ligne par groupe, mon rôle).
///
/// [peerProfile] n'est renseigné que pour un **DM** (`group.isDirect`) : c'est le
/// profil de l'**autre** membre, d'où le fil tire son titre et son avatar. `null`
/// pour un vrai groupe, ou tant que le profil n'est pas encore synchronisé.
class MyGroup {
  const MyGroup({
    required this.group,
    required this.membership,
    this.peerUserId,
    this.peerProfile,
  });

  final GroupRow group;
  final GroupMemberRow membership;

  /// L'`userId` de l'autre membre d'un DM — présent dès que le roster est là,
  /// **même si son profil ne l'est pas encore** (d'où un champ distinct de
  /// [peerProfile]). C'est la cible pour rouvrir le DM depuis la liste.
  final String? peerUserId;
  final ProfileRow? peerProfile;
}

/// Une ligne de la **liste des membres** d'un groupe : l'appartenance (avec son
/// rôle) et le profil joint (nom, avatar), `null` tant qu'il n'est pas arrivé —
/// la jointure est **tolérante**, un membre sans profil s'affiche par ses
/// initiales plutôt que de disparaître.
class GroupMemberEntry {
  const GroupMemberEntry({required this.membership, this.profile});

  final GroupMemberRow membership;
  final ProfileRow? profile;
}

/// Un groupe **et son identité de propriétaire**, résolue par jointure.
///
/// [ownerAccount] / [ownerContributor] ne valent que pour un groupe
/// institutionnel (`owner_kind` = `official_account` | `contributor`) ; ils
/// peuvent être nuls tant que la collection d'institution ne les a pas encore
/// livrés — la jointure est **tolérante**, l'en-tête d'institution s'affiche
/// alors sans nom plutôt que de faire disparaître le groupe.
class GroupWithOwner {
  const GroupWithOwner({
    required this.group,
    this.membership,
    this.ownerAccount,
    this.ownerContributor,
    this.peerUserId,
    this.peerProfile,
  });

  final GroupRow group;

  /// Mon appartenance à ce groupe, `null` si je n'en suis pas membre (la fiche
  /// reste consultable — un non-membre peut décider d'y participer).
  final GroupMemberRow? membership;

  final OfficialAccountRow? ownerAccount;
  final ContributorRow? ownerContributor;

  /// L'`userId` de l'autre membre d'un DM (présent même sans son profil).
  final String? peerUserId;

  /// Le profil de l'**autre** membre — seulement pour un DM (`group.isDirect`).
  final ProfileRow? peerProfile;
}

/// **Les lectures du magasin, côté messagerie de groupe.**
///
/// Un DAO distinct, comme `AnnouncementDao` l'est de `MediathequeDao` : d'autres
/// collections, un autre modèle, d'autres écrans. Il ne **filtre pas** la portée
/// de branche ni la visibilité — le serveur ne remonte déjà que ce que l'acteur
/// a le droit de voir (décision D13) — et ne connaît pas « moi » : la seule
/// question qu'il pose au magasin est structurelle (« ai-je une appartenance sur
/// ce groupe ? »), jamais identitaire.
@DriftAccessor(
  tables: [
    Groups,
    GroupMembers,
    GroupMessages,
    GroupJoinRequests,
    OfficialAccounts,
    Contributors,
    Profiles,
  ],
)
class GroupDao extends DatabaseAccessor<AppDatabase> with _$GroupDaoMixin {
  GroupDao(super.db);

  /// **Mes groupes** (inbox), avec mon rôle. Les désactivés y restent — un
  /// membre garde l'accès en lecture seule à l'archive.
  ///
  /// Trié par activité récente (approximée par `updatedAt` du groupe) ; le
  /// repository réordonne ensuite sur l'horodatage du dernier message, qu'il a
  /// sous la main.
  Selectable<MyGroup> watchMyGroups(String? myUserId) {
    // `group_members` porte désormais le roster : on filtre sur MOI pour ne
    // garder que mon appartenance (une ligne par groupe, mon rôle). Sans session
    // (`myUserId` nul), la sentinelle vide ne matche aucun uuid → inbox vide.
    final me = myUserId ?? '';
    // Le pair d'un DM : l'autre membre, joint seulement si `groups.is_direct`
    // (la condition dans le ON évite toute multiplication sur un vrai groupe).
    final peer = alias(groupMembers, 'peer');
    final peerProfile = alias(profiles, 'peer_profile');
    final query = select(groups).join([
      innerJoin(
        groupMembers,
        groupMembers.groupId.equalsExp(groups.id) &
            groupMembers.userId.equals(me),
      ),
      leftOuterJoin(
        peer,
        peer.groupId.equalsExp(groups.id) &
            peer.userId.equals(me).not() &
            groups.isDirect.equals(true),
      ),
      leftOuterJoin(peerProfile, peerProfile.id.equalsExp(peer.userId)),
    ])
      ..orderBy([
        OrderingTerm.desc(groups.updatedAt),
        OrderingTerm.asc(groups.id),
      ]);
    return query.map(
      (row) => MyGroup(
        group: row.readTable(groups),
        membership: row.readTable(groupMembers),
        peerUserId: row.readTableOrNull(peer)?.userId,
        peerProfile: row.readTableOrNull(peerProfile),
      ),
    );
  }

  /// **Les identifiants de mes groupes** — les `group_id` distincts où je porte
  /// une appartenance, filtrés sur **moi** (`myUserId`).
  ///
  /// Écouté en `Stream` (`.watch()`) par le `RealtimeService` pour le
  /// **réabonnement réactif** du temps-réel (D2/D7 de `docs/temps-reel-sse.md`) :
  /// à chaque changement de `group_members` — un DM qui naît, un groupe
  /// rejoint/quitté — le service diffe cet ensemble et (dés)abonne les canaux
  /// `groups/{id}` correspondants. Un DM **est** une ligne `groups`, donc ce même
  /// flux couvre groupes **et** DM d'un coup (canal commun `groups/{id}`).
  ///
  /// On ne rend **que** les identifiants : c'est tout ce qu'il faut pour nommer un
  /// canal, et le service ne peint rien (D1). `distinct` par prudence (une seule
  /// ligne est la mienne par groupe de toute façon). Sans session (`myUserId`
  /// nul), la sentinelle vide ne matche aucun uuid → aucun abonnement.
  Selectable<String> watchMyGroupIds(String? myUserId) {
    final me = myUserId ?? '';
    final query = selectOnly(groupMembers, distinct: true)
      ..addColumns([groupMembers.groupId])
      ..where(groupMembers.userId.equals(me));
    return query.map((row) => row.read(groupMembers.groupId)!);
  }

  /// **Les groupes à rejoindre** : actifs, publics (`open`|`request`), dont je ne
  /// suis pas membre. La portée de branche est déjà tenue par le serveur.
  ///
  /// L'état « demande en attente » ne se joint pas ici : il vit dans
  /// [pendingRequestGroupIds], que le repository croise avec cette liste. Deux
  /// requêtes simples valent mieux qu'une colonne agrégée fragile.
  Selectable<GroupRow> discoverableGroups(String? myUserId) {
    final me = myUserId ?? '';
    // « Suis-je membre » se lit désormais sur MA ligne du roster (le roster porte
    // aussi les autres). Un DM (`is_direct`) n'entre jamais en découverte.
    final isMember = existsQuery(
      select(groupMembers)
        ..where((m) => m.groupId.equalsExp(groups.id) & m.userId.equals(me)),
    );
    return select(groups)
      ..where(
        (g) =>
            g.isActive.equals(true) &
            g.isDirect.equals(false) &
            g.joinPolicy.isIn(const ['open', 'request']) &
            isMember.not(),
      )
      ..orderBy([
        (g) => OrderingTerm.asc(g.name),
        (g) => OrderingTerm.asc(g.id),
      ]);
  }

  /// **Les identifiants de groupes pour lesquels j'ai une demande `pending`.**
  ///
  /// Croisé avec [discoverableGroups] par le repository pour décider « Demander à
  /// rejoindre » vs. « En attente ». Sur un groupe que je n'administre pas, la
  /// collection ne porte que **ma** demande, donc l'ensemble se lit « les groupes
  /// où j'attends ».
  Selectable<String> pendingRequestGroupIds() {
    final query = selectOnly(groupJoinRequests, distinct: true)
      ..addColumns([groupJoinRequests.groupId])
      ..where(groupJoinRequests.status.equals('pending'));
    return query.map((row) => row.read(groupJoinRequests.groupId)!);
  }

  /// **Les messages d'un groupe**, en ordre croissant — le serveur est
  /// autoritaire sur l'ordre (tri par `id` = UUIDv7), on l'approxime par la date
  /// de création puis l'identifiant.
  Selectable<GroupMessageRow> watchMessages(String groupId) =>
      select(groupMessages)
        ..where((m) => m.groupId.equals(groupId))
        ..orderBy([
          (m) => OrderingTerm.asc(m.createdAt),
          (m) => OrderingTerm.asc(m.id),
        ]);

  /// **Tous les messages non tombstonés**, du plus récent au plus ancien — le
  /// repository en tire l'aperçu et l'heure de la dernière activité par groupe.
  Selectable<GroupMessageRow> latestMessages() => select(groupMessages)
    ..orderBy([
      (m) => OrderingTerm.desc(m.createdAt),
      (m) => OrderingTerm.desc(m.id),
    ]);

  /// **Un groupe et son identité de propriétaire**, plus **mon** appartenance
  /// (le roster est filtré sur moi — sinon le join multiplierait la ligne par
  /// membre) et, pour un DM, le profil de l'autre.
  Selectable<GroupWithOwner> watchGroup(String groupId, String? myUserId) {
    final me = myUserId ?? '';
    final peer = alias(groupMembers, 'peer');
    final peerProfile = alias(profiles, 'peer_profile');
    final query = select(groups).join([
      leftOuterJoin(
        groupMembers,
        groupMembers.groupId.equalsExp(groups.id) &
            groupMembers.userId.equals(me),
      ),
      leftOuterJoin(
        peer,
        peer.groupId.equalsExp(groups.id) &
            peer.userId.equals(me).not() &
            groups.isDirect.equals(true),
      ),
      leftOuterJoin(peerProfile, peerProfile.id.equalsExp(peer.userId)),
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
      (row) => GroupWithOwner(
        group: row.readTable(groups),
        membership: row.readTableOrNull(groupMembers),
        ownerAccount: row.readTableOrNull(officialAccounts),
        ownerContributor: row.readTableOrNull(contributors),
        peerUserId: row.readTableOrNull(peer)?.userId,
        peerProfile: row.readTableOrNull(peerProfile),
      ),
    );
  }

  /// **La liste des membres d'un groupe** (PRD `messagerie-directe.md` D12) :
  /// chaque appartenance jointe **tolérablement** à son profil (nom, avatar).
  /// Trié admins d'abord (`leader` puis `moderator` puis `member`), puis par nom
  /// affiché. Le magasin ne garde que les membres **actifs** (une rétractation
  /// retire la ligne), aucun filtre de tombstone n'est donc nécessaire ici.
  Selectable<GroupMemberEntry> watchGroupMembers(String groupId) {
    final query = select(groupMembers).join([
      leftOuterJoin(profiles, profiles.id.equalsExp(groupMembers.userId)),
    ])
      ..where(groupMembers.groupId.equals(groupId))
      ..orderBy([
        // `leader`(0) < `moderator`(1) < `member`(2) — l'ordre alphabétique
        // inverse ne le donne pas, d'où le CASE explicite.
        OrderingTerm.asc(
          CaseWhenExpression<int>(
            cases: [
              CaseWhen(groupMembers.role.equals('leader'),
                  then: const Constant(0)),
              CaseWhen(groupMembers.role.equals('moderator'),
                  then: const Constant(1)),
            ],
            orElse: const Constant(2),
          ),
        ),
        OrderingTerm.asc(profiles.displayName),
        OrderingTerm.asc(groupMembers.userId),
      ]);
    return query.map(
      (row) => GroupMemberEntry(
        membership: row.readTable(groupMembers),
        profile: row.readTableOrNull(profiles),
      ),
    );
  }

  /// **Résout le DM avec `otherUserId`** : le groupe `is_direct` dont les membres
  /// sont {moi, lui}. `null` tant que le fil n'existe pas (création paresseuse au
  /// premier message, PRD `messagerie-directe.md` D6/D13) — l'écran de DM est
  /// alors vide et adressé par `userId`, et se rebranche ici après le premier
  /// envoi, quand la sync a ramené le groupe.
  Selectable<GroupRow> directGroupWith(String? myUserId, String otherUserId) {
    final me = myUserId ?? '';
    final mine = alias(groupMembers, 'mine');
    final other = alias(groupMembers, 'other');
    final query = select(groups).join([
      innerJoin(
        mine,
        mine.groupId.equalsExp(groups.id) & mine.userId.equals(me),
      ),
      innerJoin(
        other,
        other.groupId.equalsExp(groups.id) & other.userId.equals(otherUserId),
      ),
    ])
      ..where(groups.isDirect.equals(true));
    return query.map((row) => row.readTable(groups));
  }

  /// **Les demandes d'adhésion en attente** d'un groupe, à valider par ses
  /// admins.
  Selectable<GroupJoinRequestRow> watchPendingRequests(String groupId) =>
      select(groupJoinRequests)
        ..where((r) => r.groupId.equals(groupId) & r.status.equals('pending'))
        ..orderBy([(r) => OrderingTerm.asc(r.createdAt)]);

  // ── Institutions propriétaires (décision D23) ───────────────────────────────

  /// **Un compte officiel par identifiant** — la source de la fiche d'institution
  /// pour un groupe `owner_kind = official_account`.
  Selectable<OfficialAccountRow> officialAccountById(int id) =>
      select(officialAccounts)..where((a) => a.id.equals(id));

  /// **Un intervenant par identifiant** — la source de la fiche pour un groupe
  /// `owner_kind = contributor`.
  Selectable<ContributorRow> contributorById(int id) =>
      select(contributors)..where((c) => c.id.equals(id));

  /// **Les groupes actifs d'un compte officiel**, pour sa fiche.
  Selectable<GroupRow> groupsOwnedByAccount(int accountId) => select(groups)
    ..where(
      (g) =>
          g.isActive.equals(true) & g.ownerOfficialAccountId.equals(accountId),
    )
    ..orderBy([(g) => OrderingTerm.asc(g.name)]);

  /// **Les groupes actifs d'un intervenant**, pour sa fiche.
  Selectable<GroupRow> groupsOwnedByContributor(int contributorId) =>
      select(groups)
        ..where(
          (g) =>
              g.isActive.equals(true) &
              g.ownerContributorId.equals(contributorId),
        )
        ..orderBy([(g) => OrderingTerm.asc(g.name)]);
}
