/// **La lecture de la messagerie de groupe** — le contrat, adossé au magasin.
///
/// Le jumeau de `StoreAnnouncementRepository` : aucune requête ne part d'ici, la
/// synchronisation écrit dans le magasin et ne rend rien, les écrans lisent le
/// magasin et n'attendent rien du réseau (ADR-0026). Tout se lit en **`Stream`**
/// et non en `Future` : une rétractation reçue pendant qu'un fidèle lit doit
/// retirer le contenu de l'écran ouvert.
///
/// L'écriture (envoi, rejoindre, demander, quitter, valider) vit **ailleurs**,
/// dans [GroupMessaging] — autre source, autre forme, autre régime hors-ligne.
library;

import 'dart:async';

import '../../models/models.dart';
import '../../utils/media_url.dart';
import '../local/group_dao.dart';
import '../local/app_database.dart';

/// Contrat de lecture de la messagerie de groupe.
abstract interface class GroupRepository {
  /// L'**inbox** : mes groupes, mêlés (au réel, seuls les groupes ; les DM 1-à-1
  /// resteront fictifs tant qu'aucun backend ne les sert), triés par récence.
  Stream<List<Conversation>> conversations();

  /// La rangée de **découverte** : groupes publics dans ma portée dont je ne
  /// suis pas membre.
  Stream<List<DiscoverGroup>> groupsToJoin();

  /// Le **détail** d'un groupe (en-tête propriétaire, politiques, mon rôle),
  /// `null` si le magasin ne le connaît pas (retiré, ou hors de ma portée).
  Stream<Conversation?> group(String groupId);

  /// Les **messages** d'un groupe, l'origine résolue sur `(authorId, isSystem)`.
  Stream<List<ChatMessage>> messages(String groupId);

  /// Les **demandes d'adhésion en attente** d'un groupe, à valider.
  Stream<List<GroupJoinRequest>> pendingRequests(String groupId);

  /// La **fiche d'une institution** (compte officiel / intervenant) — décision
  /// D23. `null` si l'institution n'est pas (encore) en magasin.
  Stream<InstitutionProfile?> institution(GroupOwnerKind kind, int id);

  /// Les **groupes d'une institution**, pour sa fiche.
  Stream<List<Conversation>> institutionGroups(GroupOwnerKind kind, int id);
}

/// **La messagerie peinte depuis le magasin local**, jamais depuis le réseau.
class StoreGroupRepository implements GroupRepository {
  StoreGroupRepository(this._dao, {required this.currentUserId});

  final GroupDao _dao;

  /// L'identité de l'acteur, pour décider `mine` sur un message. `null` avant
  /// l'ouverture de session — tous les messages se lisent alors « pas de moi »,
  /// ce qui est bénin (les bulles s'affichent à gauche).
  final String? currentUserId;

  @override
  Stream<List<Conversation>> conversations() => _combineLatest(
        _dao.watchMyGroups().watch(),
        _dao.latestMessages().watch(),
        (mine, messages) {
          final lastByGroup = <String, GroupMessageRow>{};
          for (final m in messages) {
            // `latestMessages` est trié décroissant : la première vue par groupe
            // est la plus récente.
            lastByGroup.putIfAbsent(m.groupId, () => m);
          }
          final entries = [
            for (final g in mine)
              (
                conversation: _conversationFrom(
                  g.group,
                  g.membership,
                  lastByGroup[g.group.id],
                ),
                activity: lastByGroup[g.group.id]?.createdAt,
              ),
          ]..sort((a, b) {
              // Récence d'abord (dernier message), l'identifiant en départage.
              final ta = a.activity;
              final tb = b.activity;
              if (ta != null && tb != null) return tb.compareTo(ta);
              if (ta != null) return -1;
              if (tb != null) return 1;
              return a.conversation.id.compareTo(b.conversation.id);
            });
          return List<Conversation>.unmodifiable(
            entries.map((e) => e.conversation),
          );
        },
      );

  @override
  Stream<List<DiscoverGroup>> groupsToJoin() => _combineLatest(
        _dao.discoverableGroups().watch(),
        _dao.pendingRequestGroupIds().watch(),
        (rows, pendingIds) {
          final pending = pendingIds.toSet();
          return List<DiscoverGroup>.unmodifiable([
            for (final g in rows)
              DiscoverGroup(
                id: g.id,
                name: g.name,
                // Pas de nom d'animateur au réel (ADR-0029) : vide, l'UI ne rend
                // pas la ligne. L'institution propriétaire, elle, se lit au détail.
                host: '',
                joinPolicy: GroupJoinPolicy.parse(g.joinPolicy),
                pendingRequest: pending.contains(g.id),
              ),
          ]);
        },
      );

  @override
  Stream<Conversation?> group(String groupId) =>
      _dao.watchGroup(groupId).watchSingleOrNull().map(
            (row) => row == null
                ? null
                : _conversationFrom(
                    row.group,
                    row.membership,
                    null,
                    ownerAccount: row.ownerAccount,
                    ownerContributor: row.ownerContributor,
                  ),
          );

  @override
  Stream<List<ChatMessage>> messages(String groupId) =>
      _dao.watchMessages(groupId).watch().map(
            (rows) => List<ChatMessage>.unmodifiable(rows.map(_message)),
          );

  @override
  Stream<List<GroupJoinRequest>> pendingRequests(String groupId) =>
      _dao.watchPendingRequests(groupId).watch().map(
            (rows) => List<GroupJoinRequest>.unmodifiable(
              rows.map(
                (r) => GroupJoinRequest(
                  id: r.id,
                  userId: r.userId,
                  createdAt: r.createdAt,
                ),
              ),
            ),
          );

  @override
  Stream<InstitutionProfile?> institution(GroupOwnerKind kind, int id) {
    if (kind == GroupOwnerKind.officialAccount) {
      return _dao.officialAccountById(id).watchSingleOrNull().map(
            (row) => row == null
                ? null
                : InstitutionProfile(
                    kind: kind,
                    id: row.id,
                    name: row.name,
                    avatarUrl: resolveMediaUrl(row.avatarUrl),
                  ),
          );
    }
    return _dao.contributorById(id).watchSingleOrNull().map(
          (row) => row == null
              ? null
              : InstitutionProfile(
                  kind: kind,
                  id: row.id,
                  name: row.name,
                  description: row.bio,
                ),
        );
  }

  @override
  Stream<List<Conversation>> institutionGroups(GroupOwnerKind kind, int id) {
    final rows = kind == GroupOwnerKind.officialAccount
        ? _dao.groupsOwnedByAccount(id).watch()
        : _dao.groupsOwnedByContributor(id).watch();
    return rows.map(
      (list) => List<Conversation>.unmodifiable(
        list.map((g) => _conversationFrom(g, null, null)),
      ),
    );
  }

  /// Traduit une ligne de groupe (et son appartenance, son dernier message, son
  /// institution) en [Conversation].
  Conversation _conversationFrom(
    GroupRow group,
    GroupMemberRow? membership,
    GroupMessageRow? last, {
    OfficialAccountRow? ownerAccount,
    ContributorRow? ownerContributor,
  }) {
    final ownerKind = GroupOwnerKind.parse(group.ownerKind);
    final institution = _institutionOf(
      ownerKind,
      group,
      ownerAccount,
      ownerContributor,
    );
    return Conversation(
      id: group.id,
      kind: ConversationKind.group,
      name: group.name,
      description: group.description,
      lastMessagePreview: last?.body ?? '',
      time: last?.createdAt == null ? '' : _clock(last!.createdAt!),
      role: GroupRole.parse(membership?.role),
      joinPolicy: GroupJoinPolicy.parse(group.joinPolicy),
      postPolicy: GroupPostPolicy.parse(group.postPolicy),
      isWriteLocked: group.isWriteLocked,
      isActive: group.isActive,
      ownerKind: ownerKind,
      institution: institution,
      memberCount: group.memberCount,
    );
  }

  InstitutionProfile? _institutionOf(
    GroupOwnerKind kind,
    GroupRow group,
    OfficialAccountRow? account,
    ContributorRow? contributor,
  ) {
    if (kind == GroupOwnerKind.officialAccount && account != null) {
      return InstitutionProfile(
        kind: kind,
        id: account.id,
        name: account.shortName ?? account.name,
        avatarUrl: resolveMediaUrl(account.avatarUrl),
      );
    }
    if (kind == GroupOwnerKind.contributor && contributor != null) {
      return InstitutionProfile(
        kind: kind,
        id: contributor.id,
        name: contributor.name,
        description: contributor.bio,
      );
    }
    return null;
  }

  /// **L'origine se lit sur le couple `(authorId, isSystem)`** (ADR-0032).
  ChatMessage _message(GroupMessageRow row) {
    final system = row.isSystem;
    final authorRemoved = !system && row.authorId == null;
    final mine =
        !system && row.authorId != null && row.authorId == currentUserId;
    return ChatMessage(
      // Aucune source de nom de membre (ADR-0029) : l'auteur reste vide, la
      // bulle ne rend pas de ligne d'auteur. À réconcilier si un nom voyage.
      author: '',
      text: row.body ?? '',
      time: _clock(row.createdAt ?? DateTime.now()),
      mine: mine,
      system: system,
      authorRemoved: authorRemoved,
    );
  }

  /// Heure murale locale `HH:mm` — formatage minimal du read layer, à défaut
  /// d'un helper de vue dédié à la messagerie.
  String _clock(DateTime instant) {
    final local = instant.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

/// **Deux flux du magasin, une seule émission** — le même patron que
/// `StoreAnnouncementRepository`, réécrit localement plutôt qu'ajouté en
/// dépendance `rxdart`. N'émet qu'une fois les deux sources arrivées ; une erreur
/// de l'une traverse.
Stream<R> _combineLatest<A, B, R>(
  Stream<A> first,
  Stream<B> second,
  R Function(A, B) combine,
) {
  late final StreamController<R> controller;
  StreamSubscription<A>? firstSub;
  StreamSubscription<B>? secondSub;
  A? latestFirst;
  B? latestSecond;
  var hasFirst = false;
  var hasSecond = false;

  void emit() {
    if (hasFirst && hasSecond) {
      controller.add(combine(latestFirst as A, latestSecond as B));
    }
  }

  controller = StreamController<R>(
    onListen: () {
      firstSub = first.listen(
        (value) {
          latestFirst = value;
          hasFirst = true;
          emit();
        },
        onError: controller.addError,
      );
      secondSub = second.listen(
        (value) {
          latestSecond = value;
          hasSecond = true;
          emit();
        },
        onError: controller.addError,
      );
    },
    onCancel: () async {
      await firstSub?.cancel();
      await secondSub?.cancel();
    },
  );

  return controller.stream;
}
