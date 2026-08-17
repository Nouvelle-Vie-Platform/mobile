import 'package:drift/drift.dart';

import 'app_database.dart';
import 'tables/announcement_tables.dart';
import 'tables/group_tables.dart';
import 'tables/mediatheque_tables.dart';

part 'group_dao.g.dart';

/// Un groupe dont **je suis membre**, et mon rôle dedans.
///
/// L'unité de l'**inbox** : la présence d'une ligne `group_members` (scoppée sur
/// moi par le serveur) est exactement ce qui range un groupe ici plutôt qu'en
/// découverte.
class MyGroup {
  const MyGroup({required this.group, required this.membership});

  final GroupRow group;
  final GroupMemberRow membership;
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
  });

  final GroupRow group;

  /// Mon appartenance à ce groupe, `null` si je n'en suis pas membre (la fiche
  /// reste consultable — un non-membre peut décider d'y participer).
  final GroupMemberRow? membership;

  final OfficialAccountRow? ownerAccount;
  final ContributorRow? ownerContributor;
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
  Selectable<MyGroup> watchMyGroups() {
    final query = select(groups).join([
      innerJoin(
        groupMembers,
        groupMembers.groupId.equalsExp(groups.id),
      ),
    ])
      ..orderBy([
        OrderingTerm.desc(groups.updatedAt),
        OrderingTerm.asc(groups.id),
      ]);
    return query.map(
      (row) => MyGroup(
        group: row.readTable(groups),
        membership: row.readTable(groupMembers),
      ),
    );
  }

  /// **Les groupes à rejoindre** : actifs, publics (`open`|`request`), dont je ne
  /// suis pas membre. La portée de branche est déjà tenue par le serveur.
  ///
  /// L'état « demande en attente » ne se joint pas ici : il vit dans
  /// [pendingRequestGroupIds], que le repository croise avec cette liste. Deux
  /// requêtes simples valent mieux qu'une colonne agrégée fragile.
  Selectable<GroupRow> discoverableGroups() {
    final isMember = existsQuery(
      select(groupMembers)..where((m) => m.groupId.equalsExp(groups.id)),
    );
    return select(groups)
      ..where(
        (g) =>
            g.isActive.equals(true) &
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

  /// **Un groupe et son identité de propriétaire**, plus mon appartenance.
  Selectable<GroupWithOwner> watchGroup(String groupId) {
    final query = select(groups).join([
      leftOuterJoin(
        groupMembers,
        groupMembers.groupId.equalsExp(groups.id),
      ),
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
      ),
    );
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
