import '../../models/echanges_view.dart';
import '../../models/group_management.dart';
import '../../models/message_media.dart';
import '../local/group_dao.dart';
import 'echanges_repository.dart';

/// La rubrique **« Échanges » peinte depuis le magasin local**, jamais depuis le
/// réseau (#96, décision 1 du cadrage).
///
/// Comme `StoreMediathequeRepository`, ce n'est pas une implémentation « HTTP » :
/// aucune requête ne part d'ici. La synchronisation écrit dans le magasin et ne
/// rend rien ; les écrans lisent le magasin et n'attendent rien du réseau
/// (ADR-0026). C'est ce qui fait qu'une conversation se relit **hors ligne**, à la
/// première image.
///
/// Le chemin REST (`GET /groups/:id/messages?since=`) existe côté serveur et n'a
/// pas été retenu : un second curseur vivrait à côté de celui du moteur, le réveil
/// push devrait savoir **quel** groupe aller chercher, et deux écritures
/// concurrentes dans la même table Drift feraient arriver un message par les deux
/// voies.
///
/// Son seul travail est de **traduire des lignes en modèle de lecture**, et les
/// deux règles qui comptent sont écrites ici :
///
/// 1. **l'origine d'un message** passe par [messageOriginOf], et nulle part
///    ailleurs ;
/// 2. **le droit d'écrire** se déduit du régime du groupe et de mon rôle, pour ne
///    pas offrir un champ dont chaque appui prendrait un 403.
class StoreEchangesRepository implements EchangesRepository {
  const StoreEchangesRepository(this._dao, {required this.userId});

  final GroupDao _dao;

  /// **Moi**, et c'est de là que sort tout le périmètre de lecture : mes
  /// conversations, ce qui est « à rejoindre » (donc ce dont je ne suis pas
  /// membre), et le `mine` de chaque bulle.
  ///
  /// Non nullable **exprès** : un porteur sans compte n'a pas de conversation, et
  /// le serveur ne lui en sert aucune. C'est au provider de rendre le double vide
  /// plutôt qu'à chaque requête d'ici de porter une branche « et si personne ».
  final String userId;

  @override
  Stream<List<ConversationView>> conversations() {
    return _dao.conversationsOf(userId).watch().map(
          (rows) => [for (final row in rows) _conversation(row)],
        );
  }

  @override
  Stream<List<DiscoverGroupView>> discoverGroups() {
    return _dao.discoverableGroupsFor(userId).watch().map(
          (rows) => [
            for (final row in rows)
              DiscoverGroupView(
                groupId: row.groupId,
                title: row.groupName,
                joinPolicy: row.joinPolicy,
                memberCount: row.memberCount,
                hostName: row.hostName,
                requestStatus: row.requestStatus,
              ),
          ],
        );
  }

  @override
  Stream<List<GroupMessageView>> thread(String groupId, {int? limit}) {
    return _dao.threadOf(groupId, userId, limit: limit).watch().map(
          (rows) => [for (final row in rows) _message(groupId, row)],
        );
  }

  @override
  Stream<List<GroupMessageView>> sharedFiles(String groupId) =>
      _dao.sharedFilesOf(groupId).watch().map(
            (rows) => [
              for (final row in rows) _message(groupId, row),
            ].where(isSharedFile).toList(),
          );

  @override
  Stream<List<GroupMessageView>> sharedLinks(String groupId) =>
      _dao.sharedLinksOf(groupId).watch().map(
            (rows) => [for (final row in rows) _message(groupId, row)],
          );

  @override
  Stream<GroupDetailView?> group(String groupId) {
    // Deux lectures, et une seule suffirait presque : la fiche a besoin du groupe
    // **et** de son roster. On observe le groupe et on relit les membres à chaque
    // émission — `groupById` lit `groups` et les trois tables de propriétaire,
    // `membersOf` lit `group_members` et `profiles`, et une page appliquée sur
    // l'une ou l'autre fait réémettre celle qui la lit. C'est ce qui garde la
    // fiche vivante sans combiner deux flux à la main.
    //
    // #145 : la fiche porte désormais les gestes d'administration, tirés de
    // **mon rôle** — qui vit dans le roster. Elle réémet donc aussi quand seul
    // le roster change (`groupDetailChanges`), et relit le groupe à chaque fois.
    return _dao.groupDetailChanges().asyncMap((_) async {
      final row = await _dao.groupById(groupId).getSingleOrNull();
      if (row == null) return null;
      final members = await _dao.membersOf(groupId).get();
      // `null` = je ne suis pas (ou plus) du roster. `_canWrite` le traite comme
      // un rôle sans droit, et c'est le bon défaut : le serveur refuserait aussi.
      final mine = members.where((m) => m.member.userId == userId);
      final myRole = mine.isEmpty ? null : mine.first.member.role;

      return GroupDetailView(
        groupId: row.group.id,
        title: row.group.name,
        isDirect: row.group.isDirect,
        memberCount: row.group.memberCount,
        canWrite: _canWrite(
          postPolicy: row.group.postPolicy,
          isWriteLocked: row.group.isWriteLocked,
          isActive: row.group.isActive,
          myRole: myRole,
        ),
        description: row.group.description,
        hostName: row.hostName,
        joinPolicy: row.group.joinPolicy,
        isActive: row.group.isActive,
        myRole: myRole,
        members: [
          for (final member in members)
            GroupMemberView(
              userId: member.member.userId,
              role: member.member.role,
              displayName: member.profile?.displayName,
              avatarUrl: member.profile?.avatarUrl,
            ),
        ],
      );
    });
  }

  @override
  Stream<MemberProfileView?> member(String memberId) {
    // Deux lectures, et la seconde n'est pas de l'habillage : c'est elle qui dit
    // si le bouton « Message » a lieu d'être. Même motif que `group` — on observe
    // le profil, on relit le tête-à-tête à chaque émission.
    return _dao.profileById(memberId).watchSingleOrNull().asyncMap((row) async {
      if (row == null) return null;
      final direct = await _dao
          .directGroupWith(me: userId, other: memberId)
          .getSingleOrNull();
      return MemberProfileView(
        userId: row.id,
        displayName: row.displayName,
        avatarUrl: row.avatarUrl,
        directGroupId: direct,
      );
    });
  }

  @override
  Stream<List<ContactView>> contacts() {
    return _dao.contactsOf(userId).watch().map(
          (rows) => [
            for (final row in rows)
              ContactView(
                userId: row.userId,
                displayName: row.displayName,
                avatarUrl: row.avatarUrl,
              ),
          ],
        );
  }

  @override
  Future<int> unreadCount(String groupId) =>
      _dao.unreadCountOf(groupId, userId);

  @override
  Stream<List<ReactorView>> reactors(String messageId) {
    return _dao.reactorsOf(messageId).watch().map(
          (rows) => [
            for (final row in rows)
              ReactorView(
                emoji: row.emoji,
                userId: row.userId,
                displayName: row.displayName,
                mine: row.userId == userId,
              ),
          ],
        );
  }

  @override
  Future<int?> newerThan(String groupId, String messageId) =>
      _dao.newerThan(groupId, messageId);

  @override
  Future<String?> oldestMessageId(String groupId) =>
      _dao.oldestMessageIdOf(groupId);

  ConversationView _conversation(ConversationRecord row) {
    return ConversationView(
      groupId: row.groupId,
      // **Le titre d'un tête-à-tête est le nom de l'autre.** Le serveur nomme
      // tous les groupes, DM compris, mais ce nom-là n'a pas été écrit pour être
      // lu. Quand le profil de l'autre n'est pas encore arrivé, on retombe sur le
      // nom du groupe : moins juste, mais au moins quelque chose à toucher.
      title: row.isDirect ? (row.peerName ?? row.groupName) : row.groupName,
      isDirect: row.isDirect,
      memberCount: row.memberCount,
      canWrite: _canWrite(
        postPolicy: row.postPolicy,
        isWriteLocked: row.isWriteLocked,
        isActive: row.isActive,
        myRole: row.myRole,
      ),
      avatarUrl: row.isDirect ? row.peerAvatarUrl : null,
      lastMessagePreview: row.lastBody,
      lastMessageAt: row.lastCreatedAt,
      unreadCount: row.unreadCount,
      archived: row.isArchived,
      pinnedAt: row.pinnedAt,
      isMuted: row.isMutedAt(DateTime.now()),
      lastMessageDeleted: row.lastDeleted,
      // L'aperçu d'un média (M4) : la forme seule, la tuile en fait un libellé.
      lastMessageMedia: row.lastDeleted
          ? null
          : MessageMedia.fromColumns(
              kind: row.lastMediaKind,
              metaJson: row.lastMediaMeta,
            )?.kind,
    );
  }

  GroupMessageView _message(String groupId, ThreadEntryRecord row) {
    // **Le seul appel de l'application**, et il lit le couple entier. Écrire
    // `row.authorId == null` à la place afficherait les messages d'un membre
    // parti comme des annonces du serveur.
    final origin = messageOriginOf(
      authorId: row.authorId,
      isSystem: row.isSystem,
    );

    return GroupMessageView(
      id: row.id,
      groupId: groupId,
      body: row.body,
      origin: origin,
      // `origin == member` est une garde et non une redondance : un message
      // d'auteur retiré porte `authorId == null`, et la comparaison à `null`
      // **doit échouer** plutôt que se replier. Supprimer son compte ferme la
      // session, donc le cas ne se pose pas de mon côté du fil — mais le code ne
      // doit pas en dépendre.
      mine: origin == MessageOrigin.member && row.authorId == userId,
      delivery: switch ((row.isPending, row.hasFailed)) {
        (false, _) => MessageDelivery.sent,
        (true, true) => MessageDelivery.failed,
        (true, false) => MessageDelivery.sending,
      },
      authorId: row.authorId,
      // **Pas de nom pour un auteur retiré**, et surtout pas « Membre retiré » :
      // ce libellé est un fait d'interface, pas un nom, et le glisser ici le
      // ferait passer dans `AppAvatar(name:)` — deux marqueurs d'identité
      // fabriqués de toutes pièces, identiques pour tous les auteurs retirés.
      // C'est l'écran qui le choisit, sur `origin`.
      authorName: origin == MessageOrigin.member ? row.authorName : null,
      authorAvatarUrl:
          origin == MessageOrigin.member ? row.authorAvatarUrl : null,
      createdAt: row.createdAt,
      unread: row.isUnread,
      // ── M2 (#141) ── un message supprimé ne garde que ce fait.
      deleted: row.deletedAt != null,
      edited: row.deletedAt == null && row.editedAt != null,
      forwarded: row.deletedAt == null && row.isForwarded,
      quote: row.deletedAt != null || row.replyToMessageId == null
          ? null
          : MessageQuoteView(
              messageId: row.replyToMessageId!,
              authorId: row.replyToAuthorId,
              authorName: row.replyToAuthorName,
              excerpt: row.replyToExcerpt,
              mediaKind: row.replyToMediaKind,
              deleted: row.replyToDeleted,
              mine:
                  row.replyToAuthorId != null && row.replyToAuthorId == userId,
            ),
      reactions: row.deletedAt != null
          ? const []
          : aggregateReactions(row.reactions, me: userId),
      myReaction: row.deletedAt != null
          ? null
          : row.reactions
              .where((r) => r.userId == userId)
              .map((r) => r.emoji)
              .firstOrNull,
      // Le média (M4, #143) : colonnes serveur, ou celles de l'écho avec son
      // fichier local — la bulle peint la photo qu'on vient de prendre sans
      // attendre la montée.
      // Supprimé pour tous (M2) : aucun média, comme aucun texte.
      media: row.deletedAt != null
          ? null
          : MessageMedia.fromColumns(
              kind: row.mediaKind,
              key: row.mediaKey,
              thumbnailKey: row.mediaThumbnailKey,
              duration: row.mediaDuration,
              metaJson: row.mediaMeta,
              size: row.mediaSize,
              mime: row.mediaMime,
              localPath: row.mediaPath,
              localThumbPath: row.mediaThumbPath,
            ),
      mediaError: MediaSendError.parse(row.mediaError),
    );
  }

  /// **Ai-je le droit d'écrire ici ?**
  ///
  /// Le serveur le revérifie à chaque envoi (`SendGroupMessage`, gardes 3 et 4) et
  /// c'est lui qui décide ; ce calcul-ci n'est **jamais une autorisation**, c'est
  /// un confort d'affichage — exactement le statut du bouton de composition d'une
  /// annonce. Son intérêt est de ne pas offrir un champ dont chaque appui
  /// prendrait un 403.
  ///
  /// Les deux régimes sont **indépendants et cumulatifs** : la diffusion
  /// (`postPolicy == 'admins'`, permanente) et le verrou (`isWriteLocked`,
  /// temporaire). Un `leader` ou un `moderator` écrit toujours. Un groupe
  /// désactivé n'accepte rien de personne.
  static bool _canWrite({
    required String postPolicy,
    required bool isWriteLocked,
    required bool isActive,
    required String? myRole,
  }) {
    if (!isActive) return false;
    final isAdmin = myRole == 'leader' || myRole == 'moderator';
    if (isAdmin) return true;
    return postPolicy != 'admins' && !isWriteLocked;
  }
}
