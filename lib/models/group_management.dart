/// **Discussions et groupes gérés depuis l'application** (#145, tranche M6 du
/// plan `server-portal/docs/messagerie-whatsapp-plan.md`, décisions 8 et 9) —
/// les modèles de lecture et **les droits**, écrits une fois.
///
/// Les droits d'un groupe ne sont pas une matrice RBAC : ils se lisent sur mon
/// **rôle dans ce groupe** (`leader` / `moderator` / `member`, ADR-0009), et le
/// serveur applique exactement la même règle à chaque appel. On la lit ici pour
/// **ne pas offrir** un geste dont chaque appui prendrait un 403 — l'absence,
/// jamais le grisage (la règle du sélecteur de canaux de connexion, #83).
library;

import 'package:flutter/foundation.dart';

/// **Une personne de mes groupes** — celle à qui je peux écrire en privé, ou
/// que je peux ajouter à un groupe.
///
/// « Mes groupes » exclut les tête-à-tête : c'est la règle du serveur
/// (`sharedGroupContacts`), et un sélecteur plus large proposerait des
/// personnes que le serveur refuserait.
@immutable
class ContactView {
  const ContactView({required this.userId, this.displayName, this.avatarUrl});

  final String userId;

  /// `null` quand la personne n'a jamais rempli son nom : la ligne se rend
  /// quand même, avec un avatar neutre — jamais un « Utilisateur inconnu ».
  final String? displayName;

  final String? avatarUrl;
}

/// **Filtre les contacts par nom** — la recherche du sélecteur.
///
/// Insensible à la casse et aux accents les plus courants : on cherche « Ama »
/// et on trouve « Amà », « Élodie » se trouve en tapant « elo ». Une requête
/// vide rend tout. Un contact **sans nom** ne correspond à aucune requête non
/// vide — il n'a rien sur quoi être trouvé.
List<ContactView> searchContacts(List<ContactView> contacts, String query) {
  final needle = foldForSearch(query.trim());
  if (needle.isEmpty) return contacts;
  return [
    for (final contact in contacts)
      if (foldForSearch(contact.displayName ?? '').contains(needle)) contact,
  ];
}

/// Minuscules, sans accents usuels (français, éwé) : la clé de comparaison de
/// [searchContacts].
String foldForSearch(String text) {
  const from = 'àâäáãåçéèêëíìîïñóòôöõúùûüýÿɖɛƒɣŋɔʋ';
  const to = 'aaaaaaceeeeiiiinooooouuuuyydefgnov';
  final lower = text.toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final char = String.fromCharCode(rune);
    final index = from.indexOf(char);
    buffer.write(index < 0 ? char : to[index]);
  }
  return buffer.toString();
}

/// **Ce que l'application peut offrir à l'acteur côté groupes** — lu sur
/// `GET /groups/capabilities`, la même policy que `POST /groups`.
@immutable
class GroupCapabilities {
  const GroupCapabilities({
    required this.canCreateGroup,
    this.createBranchIds = const [],
  });

  /// Rien d'offert : sans réseau, sans session, ou pour un fidèle qui n'est pas
  /// responsable. Le bouton « Nouveau groupe » n'existe pas.
  static const none = GroupCapabilities(canCreateGroup: false);

  /// **Responsable au RBAC** (décision 9) : seul lui voit « Nouveau groupe ».
  final bool canCreateGroup;

  /// Le ciblage à envoyer avec la création (`[]` = national).
  final List<int> createBranchIds;
}

/// Une demande d'adhésion **en attente**, vue par un admin du groupe.
@immutable
class PendingJoinRequestView {
  const PendingJoinRequestView({
    required this.id,
    required this.userId,
    this.displayName,
  });

  final int id;
  final String userId;

  /// Jamais un email ni un téléphone : le serveur ne les sert pas ici.
  final String? displayName;
}

/// Les rôles de groupe qui **administrent** (ADR-0009).
const Set<String> kGroupAdminRoles = {'leader', 'moderator'};

/// **Les droits de l'acteur sur un groupe** — la seule lecture de l'application
/// de la règle ADR-0009, miroir des gardes du serveur :
///
/// | geste | qui | garde serveur |
/// |---|---|---|
/// | rejoindre | non-membre, politique `open` | `JoinGroup` |
/// | demander à rejoindre | non-membre, politique `request` | `RequestGroupJoin` |
/// | quitter | membre, **pas un tête-à-tête** | `LeaveGroup` |
/// | ajouter, retirer, traiter les demandes | `leader` / `moderator` | `AssertCanModerate` |
/// | retirer quelqu'un | jamais le leader, jamais soi-même | `RemoveGroupMember` |
/// | nommer / retirer admin | `leader` seulement, jamais sur un leader | `UpdateGroupMemberRole` |
///
/// Un tête-à-tête n'a **aucune** administration : ses deux membres sont
/// `member`, et le serveur refuse qu'on le quitte.
@immutable
class GroupRights {
  const GroupRights({
    required this.myRole,
    required this.isDirect,
    required this.joinPolicy,
    this.isActive = true,
  });

  /// Mon rôle, ou `null` si je ne suis pas (ou plus) membre.
  final String? myRole;
  final bool isDirect;

  /// `open` | `request` | `invite_only`.
  final String joinPolicy;

  /// Un groupe désactivé ne s'administre plus et ne se rejoint plus.
  final bool isActive;

  bool get isMember => myRole != null;

  bool get isAdmin =>
      !isDirect && isActive && kGroupAdminRoles.contains(myRole);

  bool get isLeader => !isDirect && isActive && myRole == 'leader';

  bool get canJoin =>
      !isMember && !isDirect && isActive && joinPolicy == 'open';

  bool get canRequestToJoin =>
      !isMember && !isDirect && isActive && joinPolicy == 'request';

  bool get canLeave => isMember && !isDirect;

  bool get canAddMembers => isAdmin;

  bool get canDecideRequests => isAdmin;

  /// Retirer [targetRole] (dont l'identifiant est [targetIsMe]) du groupe.
  bool canRemove({required String targetRole, required bool targetIsMe}) =>
      isAdmin && !targetIsMe && targetRole != 'leader';

  /// Nommer ou retirer admin (`member` ⇄ `moderator`).
  bool canChangeRole({required String targetRole, required bool targetIsMe}) =>
      isLeader && !targetIsMe && targetRole != 'leader';
}
