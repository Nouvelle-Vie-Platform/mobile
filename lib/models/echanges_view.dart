/// **Les modèles de lecture de la rubrique « Échanges »** (#96) — ce qu'un écran
/// affiche, et rien de plus.
///
/// Même rôle que `mediatheque_view.dart` : le magasin stocke ce que le serveur
/// envoie, la **présentation se calcule à la lecture** (ADR-0026, décision 3). Les
/// règles de cette rubrique sont écrites ici, une fois, et un widget qui reçoit
/// l'un de ces objets n'a plus aucune règle à appliquer — donc plus aucune
/// occasion d'en appliquer une variante.
///
/// La règle centrale est [MessageOrigin], et elle est la raison d'être du fichier.
library;

import 'package:flutter/foundation.dart';

/// **L'origine d'un message** — la seule chose qui décide bandeau ou bulle.
///
/// Elle se lit sur le **couple** `(authorId, isSystem)`, jamais sur `authorId`
/// seul : voir [messageOriginOf], qui est le seul endroit de l'application où ce
/// couple est interprété.
enum MessageOrigin {
  /// `(uuid, false)` — un membre. **Bulle**, avec la ligne d'auteur de la
  /// personne.
  member,

  /// `(null, true)` — le serveur (adhésion, changement de rôle). **Bandeau**
  /// centré, sans bulle, sans avatar, sans ligne d'auteur.
  system,

  /// `(null, false)` — **un auteur retiré** (ADR-0032 : le compte a été
  /// supprimé, `author_id` est passé à `NULL` et les messages sont restés dans le
  /// fil).
  ///
  /// **C'est une bulle**, pas un bandeau : la phrase est celle d'un fidèle, et la
  /// conversation appartient aussi à ceux qui y ont répondu. Elle porte une ligne
  /// d'auteur explicite (« Membre retiré ») et un avatar **neutre** — une
  /// initiale viendrait d'un nom qui n'existe plus.
  removedAuthor;

  /// Ce message se rend-il en **bulle** ?
  ///
  /// Deux origines sur trois, et c'est exactement le piège : écrire
  /// `authorId == null` à la place de ce getter ferait du troisième cas un
  /// bandeau, c'est-à-dire afficherait les messages d'un membre parti comme des
  /// annonces du serveur. Rien ne planterait, aucun test ne rougirait.
  bool get isBubble => this != MessageOrigin.system;
}

/// **Lit l'origine d'un message sur le couple**, et c'est le seul endroit qui le
/// fait.
///
/// | `authorId` | `isSystem` | résultat |
/// |---|---|---|
/// | uuid | `false` | [MessageOrigin.member] |
/// | `null` | `true` | [MessageOrigin.system] |
/// | `null` | `false` | [MessageOrigin.removedAuthor] |
///
/// Le nul n'a pas toujours été ambigu, et c'est ce qui rend le piège silencieux :
/// la migration `group_messages`, la vue de lecture et le transformer serveur ont
/// longtemps déclaré tous les trois « `author_id NULL` = **System Message** ». La
/// suppression de compte (ADR-0032) a pris le nul une seconde fois.
///
/// `isSystem` est testé **le premier**, exprès : c'est lui, et lui seul, qui
/// répond à « est-ce le serveur qui parle ? ». Un `authorId` renseigné avec
/// `isSystem: true` n'existe pas sur le fil — le serveur n'écrit jamais sous le
/// nom de quelqu'un — et s'il arrivait un jour, le lire comme le serveur est le
/// sens sûr : on afficherait une annonce au lieu d'attribuer à tort une phrase à
/// quelqu'un.
MessageOrigin messageOriginOf({
  required String? authorId,
  required bool isSystem,
}) {
  if (isSystem) return MessageOrigin.system;
  return authorId == null ? MessageOrigin.removedAuthor : MessageOrigin.member;
}

/// **Où en est l'envoi d'un message** — l'état que l'écho optimiste rend visible.
///
/// C'est la rupture assumée avec le composeur d'annonces (décision 2 du cadrage) :
/// une conversation ne supporte pas d'attendre le réseau, donc le message paraît
/// avant d'être parti, et l'écran doit dire **où il en est**.
enum MessageDelivery {
  /// Le serveur l'a : la ligne vient du flux delta.
  sent,

  /// Écrit, pas encore confirmé. L'écho local.
  sending,

  /// **Il n'est pas parti.** Un seul état pour tous les refus — réseau, 401, 403,
  /// 422, 5xx —, parce qu'ils disent tous la même chose au fidèle, et qu'il ne
  /// peut agir sur aucune de ces causes. Sans cet état, un message perdu resterait
  /// « en cours d'envoi » pour toujours : la personne croirait avoir parlé.
  failed,
}

/// Un message, tel qu'un écran de discussion le rend.
@immutable
class GroupMessageView {
  const GroupMessageView({
    required this.id,
    required this.groupId,
    required this.body,
    required this.origin,
    required this.mine,
    required this.delivery,
    this.authorId,
    this.authorName,
    this.authorAvatarUrl,
    this.createdAt,
    this.unread = false,
  });

  /// L'UUIDv7 serveur pour un message confirmé, le `clientMessageId` pour un écho
  /// qui n'a pas encore d'identité serveur.
  final String id;

  final String groupId;

  /// Le texte, ou **`null` pour un message-média** (#140, piège 1) — vocal ou
  /// image, que cette version ne sait pas encore montrer. L'écran le dit
  /// (`chatMediaUnsupported`) ; il ne rend jamais une bulle vide.
  final String? body;

  /// **La seule chose qui décide bandeau ou bulle.** Voir [MessageOrigin].
  final MessageOrigin origin;

  /// `authorId != null && authorId == session.user.id`.
  ///
  /// Se **dérive**, ne se sert pas. Et un message d'auteur retiré n'est **jamais**
  /// `mine` : la comparaison à `null` doit échouer, pas se replier.
  final bool mine;

  final MessageDelivery delivery;

  final String? authorId;

  /// Le nom de l'auteur, `null` quand le magasin ne l'a pas (profil pas encore
  /// arrivé, ou compte sans nom renseigné).
  ///
  /// ⚠️ **« Membre retiré » n'est pas ici.** C'est un libellé d'interface, pas un
  /// nom : il vit dans les `.arb` (`chatAuthorRemoved`), la vue le choisit sur
  /// [origin], et il ne se glisse **jamais** dans `AppAvatar(name:)` — qui en
  /// tirerait les initiales « MR » et une couleur dérivée de la longueur du
  /// libellé, deux marqueurs d'identité fabriqués de toutes pièces et identiques
  /// pour tous les auteurs retirés.
  final String? authorName;

  final String? authorAvatarUrl;

  /// L'instant serveur pour un message confirmé, l'horloge de l'appareil pour un
  /// écho. `null` n'arrive que sur une ligne mal formée — l'heure ne se rend
  /// alors pas, plutôt que de montrer une date inventée.
  final DateTime? createdAt;

  /// **Non lu** au sens du contrat serveur (#140) : ni du serveur, ni de moi, et
  /// postérieur à ma lecture. C'est ce qui place le séparateur « N messages non
  /// lus » à l'ouverture du fil. Jamais vrai pour un écho.
  final bool unread;

  /// Un message **confirmé par le serveur** — qui a donc une identité serveur,
  /// et peut servir de position de lecture. Un écho n'en a pas.
  bool get isConfirmed => delivery == MessageDelivery.sent;
}

/// Une conversation de la liste à plat du hub — groupe ou tête-à-tête.
@immutable
class ConversationView {
  const ConversationView({
    required this.groupId,
    required this.title,
    required this.isDirect,
    required this.memberCount,
    required this.canWrite,
    this.avatarUrl,
    this.lastMessagePreview,
    this.lastMessageAt,
    this.unreadCount = 0,
    this.archived = false,
    this.pinnedAt,
    this.isMuted = false,
  });

  final String groupId;

  /// Le nom du groupe, ou — pour un tête-à-tête — **le nom de l'autre**.
  ///
  /// Le serveur donne un nom à tout groupe, DM compris, mais ce nom-là n'a pas
  /// été écrit pour être lu : afficher « direct:a1b2… » là où le fidèle attend
  /// « Pasteur Amavi » serait une fuite d'implémentation. Quand le profil de
  /// l'autre n'est pas encore arrivé, on retombe sur le nom du groupe — c'est
  /// moins juste, mais c'est au moins quelque chose à toucher.
  final String title;

  final bool isDirect;

  /// L'effectif **actif**, compté par le serveur. Zéro pour un groupe
  /// institutionnel neuf, et ce n'est pas une erreur.
  final int memberCount;

  /// **La barre de saisie a-t-elle lieu d'être ?**
  ///
  /// Faux quand le groupe est en diffusion (`postPolicy == 'admins'`) ou sous
  /// verrou (`isWriteLocked`) et que je n'y suis pas animateur — les deux régimes
  /// sont indépendants et cumulatifs, et c'est exactement ce que le serveur
  /// vérifie à chaque envoi. On le lit ici pour **ne pas offrir** un champ dont
  /// chaque appui prendrait un 403 : un refus qu'on pouvait prévoir n'a pas à
  /// être découvert après avoir écrit.
  final bool canWrite;

  final String? avatarUrl;

  /// Le dernier message, **non tronqué** : c'est la tuile qui coupe, parce que
  /// c'est elle qui connaît sa largeur.
  ///
  /// `null` avec un [lastMessageAt] renseigné : le dernier message est un
  /// **média** (#140), et la tuile le dit.
  final String? lastMessagePreview;

  final DateTime? lastMessageAt;

  /// **Les messages non lus** de cette conversation (#140) — calculés par le
  /// client, le serveur n'en sert pas (contrat M1a §2). Zéro = pas de pastille.
  final int unreadCount;

  /// **Archivée par moi** (#146) : hors de la liste principale, dans la rangée
  /// « Archivées ». Elle y **reste** quand un message arrive.
  final bool archived;

  /// **Épinglée par moi** (#146), et depuis quand — `null` sinon. Les épingles
  /// tiennent la tête de la liste, la plus récente d'abord.
  final DateTime? pinnedAt;

  bool get pinned => pinnedAt != null;

  /// **En sourdine** (M5), jugé à l'instant où la liste a été lue : la tuile
  /// porte alors un haut-parleur barré. Une sourdine bornée échue n'en est plus
  /// une — elle disparaît à la prochaine émission du magasin.
  final bool isMuted;
}

/// **Le badge global** de l'onglet Échanges (#140) : la somme des non-lus de
/// mes conversations. Écrit une fois, lu par la barre du bas.
///
/// **Sans les discussions archivées** (#146) : comme WhatsApp, une discussion
/// rangée aux archives ne réclame plus l'attention de l'onglet — sa
/// notification, elle, reste.
int totalUnread(Iterable<ConversationView> conversations) => conversations
    .where((c) => !c.archived)
    .fold(0, (sum, c) => sum + c.unreadCount);

/// La fiche d'un groupe — en-tête, description, roster.
@immutable
class GroupDetailView {
  const GroupDetailView({
    required this.groupId,
    required this.title,
    required this.isDirect,
    required this.memberCount,
    required this.canWrite,
    this.description,
    this.hostName,
    this.members = const [],
    this.joinPolicy = 'invite_only',
    this.isActive = true,
    this.myRole,
  });

  final String groupId;
  final String title;
  final bool isDirect;
  final int memberCount;
  final bool canWrite;

  /// `open` | `request` | `invite_only` — ce qui décide « Rejoindre » ou
  /// « Demander à rejoindre » sur la fiche (#145).
  final String joinPolicy;

  final bool isActive;

  /// **Mon rôle** dans ce groupe, ou `null` si je n'en suis pas (ou plus)
  /// membre (#145). C'est lui qui décide des gestes offerts : voir
  /// `GroupRights` (`group_management.dart`).
  final String? myRole;

  /// `null` ou vide = pas de présentation déposée : la section ne se rend pas.
  final String? description;

  /// L'animateur, résolu depuis celle des trois collections que `ownerKind`
  /// désigne — `profiles`, `official_accounts` ou `contributors`.
  final String? hostName;

  final List<GroupMemberView> members;
}

/// Une personne du roster d'un groupe.
@immutable
class GroupMemberView {
  const GroupMemberView({
    required this.userId,
    required this.role,
    this.displayName,
    this.avatarUrl,
  });

  final String userId;

  /// `member` | `moderator` | `leader`, brut : c'est l'écran qui le traduit, et
  /// un rôle inconnu ne se rend simplement pas.
  final String role;

  /// `null` quand `profiles` ne l'a pas encore livré. La ligne se rend quand
  /// même — jamais un « Utilisateur inconnu », qui ressemblerait à une donnée.
  final String? displayName;

  final String? avatarUrl;
}

/// Une carte de la rangée « groupes à rejoindre ».
@immutable
class DiscoverGroupView {
  const DiscoverGroupView({
    required this.groupId,
    required this.title,
    required this.joinPolicy,
    required this.memberCount,
    this.hostName,
    this.requestStatus,
  });

  final String groupId;
  final String title;

  /// `open` | `request`. Brut : la carte en tire une phrase, et une politique
  /// inconnue n'arrive pas ici — le magasin ne propose que ces deux-là.
  final String joinPolicy;

  final int memberCount;

  /// L'animateur, ou `null`. La ligne ne se rend pas en son absence.
  final String? hostName;

  /// `pending` | `approved` | `rejected`, ou `null` si je n'ai jamais demandé.
  /// Une demande en attente se dit, plutôt que de proposer un geste déjà fait.
  final String? requestStatus;
}

/// La fiche d'un membre, ouverte depuis un roster ou depuis l'auteur d'un
/// message.
@immutable
class MemberProfileView {
  const MemberProfileView({
    required this.userId,
    this.displayName,
    this.avatarUrl,
    this.directGroupId,
  });

  final String userId;

  /// `null` quand `profiles` ne l'a pas livré, **ou** quand la personne n'a
  /// jamais rempli son nom. Les deux se rendent de la même façon : par l'absence.
  final String? displayName;

  final String? avatarUrl;

  /// **Le tête-à-tête que je partage déjà avec cette personne**, ou `null`.
  ///
  /// `null` veut dire « je ne lui ai jamais écrit » : « Message » ouvre alors
  /// l'écran du premier message (#145), dont l'envoi crée le tête-à-tête
  /// (`POST /groups/direct/:targetUserId/messages`, get-or-create côté serveur).
  final String? directGroupId;
}
