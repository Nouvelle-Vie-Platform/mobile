/// Modèles de données simples (immuables) servant à alimenter les écrans.
library;

import 'package:flutter/foundation.dart';

/// Catégorie d'un évènement d'agenda (« Culte », « Prière »…).
///
/// [label] est **multilingue** : le back sert toutes les langues disponibles,
/// l'app choisit la sienne via `pick` (voir `utils/i18n_text.dart`). [tone]
/// est une **clé d'habillage** (ex. `culte`, `info`), pas une couleur : la
/// palette reste côté thème.
@immutable
class EventCategory {
  const EventCategory({
    required this.id,
    required this.label,
    required this.tone,
  });

  /// SERIAL côté serveur.
  final int id;

  /// Libellé par code de langue : `{fr: 'Culte', en: 'Service'}`.
  final Map<String, String> label;

  /// Clé d'habillage résolue par l'UI (repli si inconnue).
  final String tone;

  /// `{ "id": 2, "label": {"fr": "Prière"}, "tone": "culte" }`
  factory EventCategory.fromJson(Map<String, dynamic> json) => EventCategory(
        id: (json['id'] as num).toInt(),
        label: parseI18nMap(json['label']) ?? const {},
        tone: json['tone'] as String? ?? '',
      );
}

/// Lit un champ **multilingue** servi par le back (`{fr: '…', en: '…'}`).
///
/// Trois tolérances délibérées, parce qu'un champ de contenu ne doit jamais
/// faire échouer le chargement d'un agenda entier :
/// - une **langue inconnue** de l'app (`ee`, `yo`, n'importe quoi) est
///   conservée telle quelle : c'est `pick` (voir `utils/i18n_text.dart`) qui
///   choisit et qui se replie, pas le parsing ;
/// - une valeur non textuelle est **ignorée** plutôt que castée de force ;
/// - un champ absent ou d'une autre forme rend `null`.
///
/// La map rendue est **non modifiable** : les modèles sont immuables, et rien
/// ne doit pouvoir réécrire un intitulé après coup.
Map<String, String>? parseI18nMap(Object? raw) {
  if (raw is! Map) return null;
  final values = <String, String>{};
  for (final entry in raw.entries) {
    final value = entry.value;
    if (value is String) values[entry.key.toString()] = value;
  }
  return Map<String, String>.unmodifiable(values);
}

/// Lit un instant servi par le back et le rend **toujours en UTC**.
///
/// `DateTime.parse` d'une chaîne suffixée `Z` rend déjà de l'UTC ; le
/// `.toUtc()` couvre les deux autres formes possibles — un décalage explicite
/// (`+01:00`) et, en dernier recours, une chaîne sans fuseau, que Dart lit en
/// heure **locale de l'appareil**. Sans lui, l'agenda glisserait de plusieurs
/// heures selon le téléphone du lecteur, et `wallClockAt` recalculerait l'heure
/// de la branche à partir d'une base fausse.
DateTime parseInstant(Object? raw) => DateTime.parse(raw as String).toUtc();

/// Lit une **date de calendrier** servie par le back (`YYYY-MM-DD`).
///
/// À ne pas confondre avec [parseInstant] : ce que le back sert ici n'est pas
/// un moment mais un **jour**, et il n'y a donc aucun fuseau à appliquer. Le
/// résultat est ancré à minuit **UTC** non pour désigner un instant, mais pour
/// qu'aucun appareil ne puisse le déplacer : `DateTime.parse('2026-04-12')`
/// seul rend minuit en heure **locale**, et un téléphone à l'est du serveur
/// afficherait alors « samedi 11 » un enseignement du dimanche 12.
///
/// Le résultat ne se compare donc **jamais** à un instant ni à un `now()` :
/// ce sont deux grandeurs différentes.
DateTime parseCalendarDay(Object? raw) {
  final parsed = DateTime.parse(raw as String);
  return DateTime.utc(parsed.year, parsed.month, parsed.day);
}

/// Évènement de l'agenda — **un rassemblement physique, à un lieu**.
///
/// Aucun champ n'est pré-formaté : le back sert un **instant** (UTC) et le
/// fuseau de la branche, jamais « Dimanche 26 Mai ». Tout le formatage vit
/// dans la vue (voir `utils/event_time.dart`).
///
/// L'heure se lit **dans le fuseau de la branche** et n'est jamais convertie
/// dans celui du lecteur : « prière de zone lundi 17h30 » veut dire « sois là
/// à 17h30 », ce qui n'est vrai que sur place. Un membre en transit serait
/// induit en erreur par une conversion ; le suffixe de décalage lève
/// l'ambiguïté sans déplacer l'heure.
@immutable
class ChurchEvent {
  /// Constructeur déclaré `const` (tous les champs sont finaux) mais **non
  /// invocable** en `const` : [DateTime] n'est pas constructible en constante.
  const ChurchEvent({
    required this.id,
    required this.startsAt,
    required this.timezone,
    required this.title,
    this.endsAt,
    this.branchId,
    this.body,
    this.place,
    this.category,
  });

  /// Identifiant stable (clés de liste, navigation, cache).
  final String id;

  /// Début de l'évènement, **en UTC**.
  final DateTime startsAt;

  /// Fin de l'évènement, `null` = durée non annoncée.
  final DateTime? endsAt;

  /// Fuseau **IANA de la branche** (ex. `Africa/Lome`), pas celui du lecteur.
  final String timezone;

  /// Branche organisatrice ; `null` = portée **nationale**.
  final int? branchId;

  /// Intitulé par code de langue : `{fr: '…', en?: '…', ee?: '…'}`.
  final Map<String, String> title;

  /// Description longue, multilingue elle aussi.
  final Map<String, String>? body;

  /// Lieu du rassemblement, tel qu'écrit par l'organisateur.
  final String? place;

  final EventCategory? category;

  /// Item de `GET /events` — **clés en `snake_case`**, comme le sérialiseur du
  /// module agenda (à la différence de `/auth`, qui sert du `camelCase`).
  ///
  /// Seuls `id`, `starts_at`, `timezone` et `title` sont exigés : le contrat
  /// annonce tout le reste comme nullable, et un item **minimal** (un intitulé
  /// français, aucune description, aucun lieu, aucune catégorie, portée
  /// nationale) est un item parfaitement valide qui doit s'afficher.
  ///
  /// Ne cherche **pas** `occurrence_date`, `series_id`, `is_overridden` ni
  /// `audience_id` : le serveur ne les sert pas. La matérialisation des séries
  /// est son affaire ; l'app ne voit que des occurrences déjà à plat.
  factory ChurchEvent.fromJson(Map<String, dynamic> json) => ChurchEvent(
        id: json['id'] as String,
        startsAt: parseInstant(json['starts_at']),
        endsAt: json['ends_at'] == null ? null : parseInstant(json['ends_at']),
        timezone: json['timezone'] as String,
        branchId: (json['branch_id'] as num?)?.toInt(),
        title: parseI18nMap(json['title']) ?? const {},
        body: parseI18nMap(json['body']),
        place: json['place'] as String?,
        category: json['category'] == null
            ? null
            : EventCategory.fromJson(
                (json['category'] as Map).cast<String, dynamic>(),
              ),
      );
}

/// Rubrique éditoriale d'un enseignement — pilote son classement sur l'accueil.
///
/// **Ce n'est plus un enum, et ça ne peut pas en être un.** Côté serveur la
/// rubrique est une table SERIAL éditable depuis le portail : la première
/// rubrique créée par un administrateur n'aurait aucune valeur d'enum où aller.
/// La raison de fond est plus forte que ce cas limite — un enum est une
/// **décision figée à l'écriture** : il oblige à traduire une rubrique serveur
/// en valeur locale au moment de désérialiser, et cette traduction ne peut que
/// se périmer. [Teaching.teachingTypeId] porte donc l'identifiant nu, et la
/// rubrique se **joint** (ADR-0026, décision 3).
///
/// Miroir de `teaching_types` : [label] est la carte de traduction **entière**
/// (`pick` choisit à la lecture), [color] est le maillon dont hérite un
/// enseignement sans couleur propre, et [position] / [layout] / [visibleOnHome]
/// décrivent la composition de l'accueil voulue par le serveur.
@immutable
class TeachingType {
  const TeachingType({
    required this.id,
    required this.label,
    required this.slug,
    this.color,
    this.position = 0,
    this.visibleOnHome = true,
    this.layout,
  });

  /// SERIAL côté serveur.
  final int id;

  /// Libellé par code de langue : `{fr: '…', en: '…', ee: '…'}`.
  final Map<String, String> label;

  /// Clé stable que le mobile reconnaît : elle survit au renommage du libellé.
  final String slug;

  /// Couleur de la rubrique (ARGB), `null` = aucune. Dont hérite un
  /// enseignement dont la couleur propre est nulle — l'héritage se calcule
  /// **à la lecture**, jamais à l'écriture.
  final int? color;

  /// Rang voulu par le serveur sur l'accueil.
  final int position;

  /// `false` = la rubrique a quitté l'accueil, mais ses enseignements restent.
  final bool visibleOnHome;

  /// `hero` | `carousel` | `list`. Chaîne libre, jamais un enum : le
  /// référentiel est administrable, une valeur inconnue se replie à
  /// l'affichage.
  final String? layout;
}

/// Enseignement de la médiathèque — miroir du `TeachingTransformer` du back,
/// réduit à ce que les écrans savent afficher aujourd'hui.
///
/// **La famille n'y figure pas.** Le serveur range désormais les contenus de
/// médiathèque en deux familles (`teaching` / `gathering`, PRD §5 sexies), mais
/// il ne sert **pas** le discriminant : ni `TeachingTransformer` ni
/// `TeachingTypeTransformer` ne l'exposent, et quatre filtres `family =
/// 'teaching'` cachent les rassemblements au parc installé. Rien à lire ici
/// tant qu'ils n'auront pas leur propre collection de synchronisation.
///
/// **Trois champs en sont sortis, et ne reviendront pas par l'affichage**
/// (cadrage D5) : aucun des trois n'a de source serveur, et un modèle qui porte
/// ce que le back ne sert pas fabrique de la donnée en mode maquette — donc un
/// écran qui marche sur les fixtures et se vide en production.
///
/// - `duration` : le serveur n'en sert **aucune**, et ADR-0005 dit pourquoi —
///   la durée est dans la playlist HLS, que le lecteur lit de toute façon. La
///   faire servir par l'API obligerait le serveur à connaître le média, ce
///   qu'ADR-0005 lui refuse. **Le temps total vient du lecteur.**
/// - `verse` : aucun équivalent serveur ; [description] existe. S'il faut un
///   jour l'afficher, ce sera une colonne à ajouter et une décision d'édition,
///   pas une variable d'affichage.
/// - `seed` : graine du vignettage de remplacement, sans objet depuis qu'un
///   enseignement porte deux URL d'image et une couleur de repli.
@immutable
class Teaching {
  /// Constructeur déclaré `const` (tous les champs sont finaux) mais **non
  /// invocable** en `const` : [DateTime] n'est pas constructible en constante —
  /// même contrainte que [ChurchEvent].
  const Teaching({
    required this.id,
    required this.title,
    required this.author,
    required this.recordedAt,
    required this.publishedAt,
    this.teachingTypeId,
    this.color,
    this.isFullService = false,
    this.imageLandscapeUrl,
    this.imagePortraitUrl,
    this.playlistUrl,
    this.description = '',
  });

  /// Identité de l'enseignement — **UUIDv7 servi par le serveur**, en chaîne.
  ///
  /// C'est ce qui circule dans l'application, et non l'objet : la route de
  /// détail porte cet identifiant (`/teaching/:id`) et l'écran relit la donnée
  /// dans la source de vérité à chaque build. Deux conséquences voulues :
  /// - une **rétractation** (dépublication ou reprogrammation dans le futur,
  ///   `{ id, deletedAt }` du flux delta, cf. ADR-0025) retire le contenu de
  ///   l'écran ouvert au lieu de le laisser afficher une copie périmée ;
  /// - un enseignement devient **désignable de l'extérieur** — notification
  ///   FCM, lien partagé — ce qu'aucun objet passé de main en main ne permet.
  final String id;

  final String title;
  final String author;

  /// Rubrique à laquelle l'enseignement appartient — un **entier nu**, celui
  /// de [TeachingType.id]. `null` = l'enseignement n'en porte pas (encore).
  ///
  /// Aucune contrainte ne garantit que la cible existe localement, et c'est
  /// voulu : les deux collections se synchronisent séparément, la jointure est
  /// tolérante et l'enseignement s'affiche quand même.
  final int? teachingTypeId;

  /// **Jour** de l'enregistrement — la date propre de l'enseignement, celle du
  /// culte (`recordedAt`, servi en `YYYY-MM-DD` ; voir [parseCalendarDay]).
  ///
  /// Ce n'est **pas** un horodatage : aucun fuseau ne s'y applique et rien ne
  /// doit la comparer à un `now()`. C'est la seule des trois dates du serveur
  /// qu'un fidèle reconnaît (« le message du dimanche 12 avril »), la seule qui
  /// ne bouge pas si l'on republie, et celle sur laquelle le catalogue se
  /// classe.
  final DateTime recordedAt;

  /// Instant de **mise à disposition** (`publishedAt`), en UTC.
  ///
  /// Toujours dans le passé : les chemins de lecture mobile ne servent jamais
  /// le non-publié. Il ne sert donc pas à re-tester la visibilité, mais à dater
  /// « publié le … » et à départager deux enseignements enregistrés le même
  /// jour.
  final DateTime publishedAt;

  /// **Culte entier** : l'enregistrement porte le service complet, et non un
  /// extrait de prédication.
  ///
  /// C'est un **marqueur**, pas une rubrique — un message du dimanche peut
  /// l'être, une étude biblique non : les deux axes sont indépendants. Écarté
  /// de « Derniers enseignements » (voir `latestTeachingsProvider`).
  final bool isFullService;

  /// Couleur d'habillage **brute** (ARGB), telle que la sert le serveur.
  ///
  /// `null` ne veut pas dire « pas de couleur » mais **« hérite de ma
  /// rubrique »** : le serveur ne résout plus rien (issue serveur #130), il
  /// sert la colonne. S'il l'avait résolue, changer la couleur d'une rubrique
  /// aurait laissé les téléphones sur l'ancienne teinte indéfiniment et en
  /// silence — ça ne bouscule l'`updated_at` d'aucun enseignement, donc aucune
  /// ligne ne repasserait par le flux delta pour corriger la valeur figée.
  ///
  /// La cascade se termine **à la lecture**, dans `TeachingView.resolve`.
  final int? color;

  /// Visuel **paysage** (1,7:1), recadré au dépôt pour la mise en avant de
  /// l'accueil (320 × 188). `null` = aucune photo déposée → c'est [color] qui
  /// habille la tuile.
  ///
  /// URL **relative** au serveur d'API côté back (`/uploads/teachings/…`) :
  /// l'hôte change d'un environnement à l'autre, c'est au client de la
  /// résoudre (voir `utils/media_url.dart`).
  final String? imageLandscapeUrl;

  /// Visuel **portrait** (0,6:1), recadré au dépôt pour le carrousel de
  /// l'accueil (104 × 172). Le même enseignement porte les deux : une image
  /// unique serait amputée dans l'un des deux cadres.
  final String? imagePortraitUrl;

  /// **URL HLS publique** du média, telle que le serveur la sert
  /// (`playlist_url`), ou `null`.
  ///
  /// Le champ n'est pas une entorse à la règle « rien que le serveur ne serve
  /// pas » qui a sorti `duration`, `verse` et `seed` de ce modèle : la colonne
  /// existe côté serveur, le magasin la réplique (`teachings.playlist_url`) et
  /// `StoreMediathequeRepository` la lit déjà. C'est le double en mémoire qui
  /// ne savait pas la porter — donc, depuis #40 où le lecteur en exige une, le
  /// seul mode dans lequel rien ne pouvait jouer.
  ///
  /// `null` ne veut pas dire « erreur » : le contenu est publié, son fichier
  /// n'est pas (encore) attaché. C'est une absence à dessiner
  /// (`ContentAbsence.noMedia`).
  final String? playlistUrl;

  /// Description longue (affichée dans la feuille de détail).
  final String description;
}

class CommunityGroup {
  const CommunityGroup({
    required this.name,
    required this.members,
    this.role,
  });

  final String name;
  final int members;
  final String? role;
}

/// Nature d'une [Conversation] du hub « Échanges ».
///
/// [group] = discussion à plusieurs (un groupe communautaire) ; [direct] = tête
/// à tête (message privé). Le hub mélange les deux dans une **seule liste à
/// plat**, sans les séparer — le discriminant ne sert qu'à l'habillage de la
/// tuile (avatar de groupe vs. de personne) et jamais à trier.
enum ConversationKind { group, direct }

/// **Nature du propriétaire d'un groupe** (décision D3, propriétaire polymorphe).
///
/// Un groupe appartient à **exactement un** parmi `{ user, compte officiel,
/// intervenant }`. [user] = groupe d'un fidèle (le cas historique) ;
/// [officialAccount] / [contributor] = groupe **institutionnel**, sans chef
/// humain (décision D4). Stocké en chaîne côté magasin, replié ici.
enum GroupOwnerKind {
  user,
  officialAccount,
  contributor;

  /// `user` | `official_account` | `contributor` → l'enum ; toute autre valeur
  /// (ou l'absence) se replie sur [user], le cas le plus bénin.
  static GroupOwnerKind parse(String? raw) => switch (raw) {
        'official_account' => GroupOwnerKind.officialAccount,
        'contributor' => GroupOwnerKind.contributor,
        _ => GroupOwnerKind.user,
      };

  bool get isInstitution => this != GroupOwnerKind.user;
}

/// Slug d'URL d'une institution (segment de la route `/institution/:kind/:id`).
String institutionKindSlug(GroupOwnerKind kind) =>
    kind == GroupOwnerKind.contributor ? 'contributor' : 'official_account';

/// Lit le slug d'URL en [GroupOwnerKind] institutionnel ; `null` si inconnu.
GroupOwnerKind? parseInstitutionKind(String? slug) => switch (slug) {
      'official_account' => GroupOwnerKind.officialAccount,
      'contributor' => GroupOwnerKind.contributor,
      _ => null,
    };

/// **Politique d'accès d'un groupe** (décision D11, `join_policy` à trois états).
///
/// [open] = public, entrée libre ; [request] = public, sur validation (valeur
/// **nouvelle**) ; [inviteOnly] = privé, caché. La découverte ne liste que
/// `open` ∪ `request` ; `invite_only` n'est jamais listé.
enum GroupJoinPolicy {
  open,
  request,
  inviteOnly;

  static GroupJoinPolicy parse(String? raw) => switch (raw) {
        'open' => GroupJoinPolicy.open,
        'request' => GroupJoinPolicy.request,
        _ => GroupJoinPolicy.inviteOnly,
      };
}

/// **Régime d'écriture d'un groupe** (décision D14, `post_policy`).
///
/// [all] = discussion (tout membre écrit) ; [admins] = **diffusion** (seuls
/// leaders/modérateurs publient, les membres lisent).
enum GroupPostPolicy {
  all,
  admins;

  static GroupPostPolicy parse(String? raw) =>
      raw == 'admins' ? GroupPostPolicy.admins : GroupPostPolicy.all;
}

/// **Rôle d'un membre dans un groupe** (`group_members.role`).
enum GroupRole {
  leader,
  moderator,
  member;

  static GroupRole? parse(String? raw) => switch (raw) {
        'leader' => GroupRole.leader,
        'moderator' => GroupRole.moderator,
        'member' => GroupRole.member,
        _ => null,
      };

  /// Leaders et modérateurs modèrent : ils écrivent en diffusion et sous verrou,
  /// et valident les demandes d'adhésion.
  bool get canModerate =>
      this == GroupRole.leader || this == GroupRole.moderator;
}

/// Une **demande d'adhésion** à valider par les admins d'un groupe (décision
/// D12). Le mobile n'a pas de source de nom de fidèle (ADR-0029) : la validation
/// s'affiche par identifiant, à réconcilier quand un nom voyagera.
@immutable
class GroupJoinRequest {
  const GroupJoinRequest({
    required this.id,
    required this.userId,
    this.createdAt,
  });

  /// SERIAL côté serveur — passé aux endpoints approve/reject.
  final int id;
  final String userId;
  final DateTime? createdAt;
}

/// **Pourquoi un groupe est en lecture seule pour moi** — choisit le bandeau.
///
/// [broadcast] = diffusion (`post_policy = admins`), je ne suis pas admin ;
/// [writeLocked] = verrou d'écriture temporaire (décision D15) ; [deactivated] =
/// groupe désactivé (décision D18, archive) ; [notMember] = je n'en suis pas
/// membre (fiche consultée avant de rejoindre).
enum GroupReadOnlyReason { broadcast, writeLocked, deactivated, notMember }

/// **L'identité d'une institution** propriétaire d'un groupe (compte officiel ou
/// intervenant) — la fiche dédiée (décision D23), alimentée par les collections
/// déjà répliquées `official_accounts` / `contributors`.
///
/// Distincte de la fiche **membre** : une institution a un logo, une description
/// et **ses** groupes/annonces, pas un statut de fidèle. [avatarUrl] est
/// **relative** au serveur d'API (à résoudre par `utils/media_url.dart`).
@immutable
class InstitutionProfile {
  const InstitutionProfile({
    required this.kind,
    required this.id,
    required this.name,
    this.description,
    this.avatarUrl,
  });

  /// [GroupOwnerKind.officialAccount] ou [GroupOwnerKind.contributor] — jamais
  /// [GroupOwnerKind.user] (un fidèle a une fiche membre).
  final GroupOwnerKind kind;

  /// SERIAL de l'institution (`official_accounts.id` ou `contributors.id`).
  final int id;

  final String name;
  final String? description;
  final String? avatarUrl;
}

/// Une conversation du hub « Échanges » — **modèle de maquette**, fictif et
/// synchrone (alimenté par `SampleData`, comme [ChatMessage]).
///
/// C'est l'unité de la liste d'inbox : groupes et messages privés y sont
/// mélangés et triés par récence. [lastMessagePreview] et [time] sont **déjà
/// résolus** (le serveur ne sert pas de texte pré-formaté ; ici il n'y a pas de
/// serveur), à l'image de `ChatMessage.time`.
///
/// Au branchement, ce modèle recevra l'origine réelle de la conversation et un
/// identifiant serveur ; aujourd'hui l'[id] est une chaîne écrite en dur dans la
/// fixture, stable d'un lancement à l'autre.
@immutable
class Conversation {
  const Conversation({
    required this.id,
    required this.kind,
    required this.name,
    required this.lastMessagePreview,
    required this.time,
    this.avatarUrl,
    this.members = const [],
    this.description,
    this.sharedMedia = const [],
    this.role,
    this.joinPolicy,
    this.postPolicy = GroupPostPolicy.all,
    this.isWriteLocked = false,
    this.isActive = true,
    this.ownerKind = GroupOwnerKind.user,
    this.institution,
    this.memberCount,
    this.peerUserId,
  });

  final String id;
  final ConversationKind kind;
  final String name;

  /// L'`userId` du correspondant d'un **DM** ([ConversationKind.direct]) — ce qui
  /// permet de rouvrir le fil depuis la liste et d'ouvrir sa fiche membre. `null`
  /// pour un groupe.
  final String? peerUserId;

  /// **Mon rôle** dans le groupe, `null` si c'est une discussion directe ou si
  /// je n'en suis pas membre. Décide de l'accès au composeur en diffusion / sous
  /// verrou, et à l'UI de validation des demandes.
  final GroupRole? role;

  /// Politique d'accès du groupe (`null` pour une discussion directe).
  final GroupJoinPolicy? joinPolicy;

  /// Régime d'écriture (décision D14).
  final GroupPostPolicy postPolicy;

  /// Verrou d'écriture temporaire (décision D15).
  final bool isWriteLocked;

  /// `false` = groupe désactivé — lecture seule (décision D18).
  final bool isActive;

  /// Nature du propriétaire (décision D3).
  final GroupOwnerKind ownerKind;

  /// L'identité de l'**institution** propriétaire, `null` pour un groupe `user`
  /// ou tant que la collection d'institution ne l'a pas encore livrée. Sert
  /// l'en-tête propriétaire du détail de groupe (décision D23 → tap = fiche).
  final InstitutionProfile? institution;

  /// Effectif servi par le serveur, `null` si inconnu.
  final int? memberCount;

  /// **Puis-je écrire dans ce groupe ?** Un membre écrit toujours en régime
  /// `all` sans verrou ; en diffusion (`admins`) **ou** sous verrou, seuls les
  /// admins écrivent. Un groupe désactivé est en lecture seule pour tous.
  ///
  /// **Un confort d'affichage, jamais une autorisation** : le serveur revérifie
  /// à chaque envoi (un membre rétrogradé verra encore le composeur et recevra
  /// un 403).
  bool get canPost {
    if (kind == ConversationKind.direct) return true;
    if (!isActive) return false;
    final admin = role?.canModerate ?? false;
    if (isWriteLocked) return admin;
    if (postPolicy == GroupPostPolicy.admins) return admin;
    return role != null;
  }

  /// La raison, s'il y en a une, pour laquelle le composeur est masqué — pour
  /// choisir le bon bandeau de lecture seule. `null` = je peux écrire.
  GroupReadOnlyReason? get readOnlyReason {
    if (canPost) return null;
    if (kind == ConversationKind.direct) return null;
    if (!isActive) return GroupReadOnlyReason.deactivated;
    if (isWriteLocked) return GroupReadOnlyReason.writeLocked;
    if (postPolicy == GroupPostPolicy.admins) {
      return GroupReadOnlyReason.broadcast;
    }
    return GroupReadOnlyReason.notMember;
  }

  /// URL d'avatar, `null` = repli sur les initiales ([AppAvatar]).
  final String? avatarUrl;

  /// Aperçu déjà tronqué du dernier message échangé.
  final String lastMessagePreview;

  /// Horodatage **déjà formaté** du dernier message (ex. « 10:38 »).
  final String time;

  /// Noms des membres — renseigné pour un [ConversationKind.group], vide pour un
  /// message direct. **Modèle de maquette** : au branchement, le mobile n'aura
  /// aucune collection d'utilisateurs (ADR-0029) et cette liste viendra d'une
  /// autre source. Sert à peupler la liste des membres ouverte depuis le titre.
  final List<String> members;

  /// Description du groupe, affichée dans la fiche (façon Telegram). `null` pour
  /// un message direct ou un groupe sans présentation.
  final String? description;

  /// URLs des médias partagés, aperçus dans la fiche du groupe. **Maquette**.
  final List<String> sharedMedia;
}

/// Un **membre d'un groupe** — la ligne de la liste des membres (PRD
/// `messagerie-directe.md` D12). Porte le **vrai `userId`** (d'où part un DM),
/// le nom résolu (`profiles`) et le rôle. Au réel, plus rien de fictif.
@immutable
class GroupMemberView {
  const GroupMemberView({
    required this.userId,
    required this.name,
    this.avatarUrl,
    this.role,
  });

  /// L'identité de l'utilisateur (`users.id`) — la cible d'un DM.
  final String userId;

  /// Nom d'affichage (`profiles.displayName`), vide si le profil n'est pas
  /// encore synchronisé → repli initiales par [AppAvatar].
  final String name;

  /// URL d'avatar déjà résolue, `null` = repli initiales.
  final String? avatarUrl;

  /// Rôle dans le groupe (`leader` | `moderator` | `member`), `null` hors
  /// contexte de groupe (ex. le pair d'un DM, dont la fiche n'affiche pas de
  /// rôle).
  final GroupRole? role;
}

/// Un groupe **à rejoindre** proposé dans la rangée de découverte du hub
/// « Échanges » — **modèle de maquette**, distinct des [Conversation].
///
/// Il ne porte que ce que la carte de découverte affiche : un visuel, un nom et
/// l'animateur. Volontairement séparé de [Conversation] : découvrir un groupe et
/// discuter dedans sont deux gestes, et la maquette les range en deux rangées.
@immutable
class DiscoverGroup {
  const DiscoverGroup({
    required this.id,
    required this.name,
    required this.host,
    this.imageUrl,
    this.joinPolicy = GroupJoinPolicy.open,
    this.pendingRequest = false,
  });

  final String id;
  final String name;

  /// Nom de l'animateur du groupe. **Modèle de maquette** : au réel, le mobile
  /// n'a pas de collection d'utilisateurs (ADR-0029) ; pour un groupe
  /// institutionnel c'est le nom de l'institution, sinon vide.
  final String host;

  /// Visuel de couverture, `null` = repli coloré.
  final String? imageUrl;

  /// [GroupJoinPolicy.open] → « Rejoindre » (immédiat) ;
  /// [GroupJoinPolicy.request] → « Demander à rejoindre » (validation).
  final GroupJoinPolicy joinPolicy;

  /// `true` = j'ai déjà une demande en attente sur ce groupe `request` → l'UI
  /// affiche « En attente » au lieu du bouton.
  final bool pendingRequest;
}

class PrayerRequest {
  const PrayerRequest({
    required this.title,
    required this.body,
    required this.status,
    required this.prayingCount,
    required this.age,
    this.confidential = true,
  });

  final String title;
  final String body;
  final String status;
  final int prayingCount;
  final String age;
  final bool confidential;
}

class SpiritualNote {
  const SpiritualNote({required this.title, required this.preview});
  final String title;
  final String preview;
}

/// Message d'une discussion de groupe — **modèle de maquette**, alimenté par
/// `SampleData` (voir `docs/messagerie-groupe.md`, qui tient le contrat de
/// branchement).
///
/// Il porte des valeurs déjà résolues que le serveur ne sert pas : [author] est
/// un nom d'affichage (aucune identité de membre ne circule — il n'existe pas
/// de collection de synchronisation `users`, ADR-0029), [time] une chaîne déjà
/// formatée, [mine] une comparaison déjà faite.
///
/// **La règle à ne pas rater au branchement.** Le serveur sert `authorId`
/// (uuid nullable) et `isSystem`, et l'origine d'un message se lit sur le
/// **couple**, jamais sur `authorId` seul :
///
/// | `authorId` | `isSystem` | origine |
/// | --- | --- | --- |
/// | uuid | `false` | un membre |
/// | `null` | `true` | message **système**, émis par le serveur |
/// | `null` | `false` | **auteur retiré** — compte supprimé (ADR-0032) |
///
/// Le nul avait un seul sens jusqu'à la suppression de compte
/// (`miracle-house-server#128`) : `null` = message système. Il en a deux
/// depuis. Un client qui teste `authorId == null` pour décider « c'est un
/// message système » affiche les messages d'un membre parti comme des annonces
/// du serveur — centrés, en gris, sans bulle. Rien ne plante, aucun test ne
/// rougit.
///
/// [system] est donc le futur `isSystem` — il ne se déduit pas d'un auteur
/// absent — et il n'a **pas** de champ jumeau ici : la maquette n'a pas de cas
/// « auteur retiré », et en fabriquer un sans donnée serveur derrière donnerait
/// un écran qui marche sur les fixtures et se vide en production.
class ChatMessage {
  const ChatMessage({
    required this.author,
    required this.text,
    required this.time,
    required this.mine,
    this.system = false,
    this.authorRemoved = false,
  });

  final String author;
  final String text;
  final String time;
  final bool mine;

  /// `true` = **message système** (`isSystem` serveur) : bannière centrée, pas
  /// de bulle. Décidé sur le couple `(authorId, isSystem)`, jamais sur
  /// `authorId` seul (ADR-0032).
  final bool system;

  /// `true` = **auteur retiré** (`authorId == null && isSystem == false`) :
  /// compte supprimé, le message reste mais n'est **pas** un message système.
  /// Une bulle, sans nom d'auteur — jamais centrée en gris comme une annonce.
  final bool authorRemoved;
}

// ─────────────────────────────────────────────────────────────────────────────
// Authentification (voir docs/auth-contract.md)
// ─────────────────────────────────────────────────────────────────────────────

/// Type d'identifiant saisi à la connexion. JSON : `"phone"` | `"email"`.
///
/// Désigne un **type d'identifiant**, pas un transport : le code peut partir
/// par SMS, WhatsApp ou autre sans que le contrat change.
enum IdentifierChannel { phone, email }

/// Civilité de l'utilisateur. JSON : `"brother"` | `"sister"`.
///
/// Ce sont des **clés de donnée**, pas des libellés : le rendu passe par
/// `context.l10n` (voir `l10n/l10n_extension.dart`).
enum UserTitle { brother, sister }

/// Statut d'appartenance. JSON : `"affiliated"` | `"newcomer"`.
///
/// `newcomer` = pas encore rattaché à une branche. On ne dit pas « member » :
/// côté serveur c'est déjà le rôle RBAC implicite de **tout** utilisateur —
/// un `newcomer` **est** un membre.
enum UserStatus { affiliated, newcomer }

/// Utilisateur connecté (immuable). `title`, `firstName` et `lastName` sont
/// stockés **séparément** et recomposés à l'affichage (voir [displayName]).
class User {
  const User({
    required this.id,
    this.phone,
    this.email,
    this.title,
    this.firstName,
    this.lastName,
    this.branchId,
    this.status = UserStatus.newcomer,
    this.avatarUrl,
    this.profileComplete = false,
    this.acceptedLegal = const {},
  });

  final String id;

  /// Téléphone au format E.164 (ex. « +22890123456 »).
  final String? phone;
  final String? email;

  /// Civilité, `null` tant que le profil n'est pas complété.
  final UserTitle? title;

  /// Prénom — le champ saisi à la complétion du profil.
  final String? firstName;

  /// Nom de famille — renseigné plus tard depuis le profil, souvent `null`.
  final String? lastName;

  /// Branche rattachée, `null` si « Je suis nouveau » / non rattaché.
  final int? branchId;
  final UserStatus status;
  final String? avatarUrl;

  /// Calculé côté serveur. Ne bloque jamais : pilote seulement une bannière
  /// douce d'invitation à compléter le profil.
  final bool profileComplete;

  /// **Le résumé des versions légales acceptées**, par genre :
  /// `{ 'cgu': 3, 'privacy': 2 }` (ADR-0036, `GET /auth/me` et
  /// `POST /legal/accept` servent le même objet sous le même nom).
  ///
  /// Il voyage avec la **session**, et non dans le magasin, parce que la garde
  /// de route qui le lit est **synchrone** : elle ne peut ni attendre une
  /// requête ni attendre un cycle de synchronisation.
  ///
  /// **Un genre jamais accepté est ABSENT de la carte, jamais à `0`.** Le
  /// serveur l'omet délibérément — il n'existe pas de « version 0 » à
  /// accepter, et l'absence se lit « jamais accepté ». Un client qui garnirait
  /// les trous à zéro n'y gagnerait rien et perdrait la distinction.
  ///
  /// La carte est **vide** quand le serveur n'a rien servi : un `User` reconstruit
  /// d'un JSON sans la clé (le portail admin en sert un, ADR-0036) se lit donc
  /// « rien d'accepté ». C'est le pire cas, et c'est le bon : la barrière se
  /// lève, elle ne se saute pas.
  final Map<String, int> acceptedLegal;

  /// Le même utilisateur, avec un **nouveau résumé d'acceptation**.
  ///
  /// La réponse de `POST /legal/accept` porte le résumé à jour : l'appliquer
  /// ici évite un `GET /auth/me` de plus entre le bouton « Continuer » et
  /// l'application (ADR-0036).
  User withAcceptedLegal(Map<String, int> accepted) => User(
        id: id,
        phone: phone,
        email: email,
        title: title,
        firstName: firstName,
        lastName: lastName,
        branchId: branchId,
        status: status,
        avatarUrl: avatarUrl,
        profileComplete: profileComplete,
        acceptedLegal: Map<String, int>.unmodifiable(accepted),
      );

  /// Nom d'affichage recomposé : « civilité + prénom + nom ».
  ///
  /// [titleLabel] est le libellé **déjà localisé** de [title] — le modèle ne
  /// produit aucun texte utilisateur (voir CLAUDE.md, « toujours via l10n »).
  /// Les parties vides sont ignorées : « Frère Jean » avec un prénom seul,
  /// « Frère Jean Kossi » quand le nom existe, chaîne vide si aucun nom.
  String displayName([String? titleLabel]) => [
        titleLabel,
        firstName,
        lastName,
      ]
          .map((part) => part?.trim() ?? '')
          .where((part) => part.isNotEmpty)
          .join(' ');

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String,
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        title: json['title'] == null
            ? null
            : UserTitle.values.byName(json['title'] as String),
        firstName: json['firstName'] as String?,
        lastName: json['lastName'] as String?,
        branchId: (json['branchId'] as num?)?.toInt(),
        status: json['status'] == null
            ? UserStatus.newcomer
            : UserStatus.values.byName(json['status'] as String),
        avatarUrl: json['avatarUrl'] as String?,
        profileComplete: json['profileComplete'] as bool? ?? false,
        acceptedLegal: _acceptedLegalFromJson(json['acceptedLegal']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'phone': phone,
        'email': email,
        'title': title?.name,
        'firstName': firstName,
        'lastName': lastName,
        'branchId': branchId,
        'status': status.name,
        'avatarUrl': avatarUrl,
        'profileComplete': profileComplete,
        // **Le cache local le porte aussi**, et ce n'est pas un détail : sans
        // lui, un démarrage hors ligne rouvrirait la barrière à quelqu'un qui a
        // déjà accepté — et il ne pourrait pas la refermer, l'accord exigeant
        // le réseau (ADR-0036, décision 2).
        'acceptedLegal': acceptedLegal,
      };
}

/// Le résumé d'acceptation tel qu'il arrive du serveur (ou du cache local).
///
/// **Clé absente ou nulle → carte vide**, jamais une carte garnie de zéros.
/// Les valeurs sont relues en `int` : le JSON les rend en `num`, et le cache
/// local repasse par la même porte.
Map<String, int> _acceptedLegalFromJson(Object? raw) {
  if (raw is! Map) return const {};
  return {
    for (final entry in raw.entries)
      if (entry.key is String && entry.value is num)
        entry.key as String: (entry.value as num).toInt(),
  };
}

/// Branche locale de l'église (liste statique en phase mock, référentiel servi
/// par `GET /sync/branches` en phase backend).
class Branch {
  const Branch({
    required this.id,
    required this.name,
    this.city,
    this.address,
    this.isMotherChurch = false,
  });

  /// SERIAL côté serveur : se compare directement à `User.branchId`.
  final int id;

  /// Le nom **composé** — l'église plus la ville, « Eglise Evangélique Nouvelle
  /// Vie Lomé ». C'est le serveur qui le compose ([branchDisplayName]) : la
  /// colonne `name` ne porte plus que l'église, la même valeur pour toutes les
  /// branches.
  final String name;

  /// La ville seule, « Lomé » — servie **en plus** de [name] par
  /// `GET /sync/branches`.
  ///
  /// `null` = la branche n'en a pas ; [name] retombe alors sur l'église seule.
  /// L'affichage court se compose par `branchSelectionLabel`
  /// (`utils/branch_label.dart`), jamais en découpant [name].
  final String? city;

  final String? address;

  /// Église mère (une seule dans le référentiel).
  final bool isMotherChurch;

  factory Branch.fromJson(Map<String, dynamic> json) => Branch(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String,
        city: json['city'] as String?,
        address: json['address'] as String?,
        isMotherChurch: json['isMotherChurch'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'city': city,
        'address': address,
        'isMotherChurch': isMotherChurch,
      };
}

/// Session authentifiée : jeton opaque, utilisateur et indicateur « nouveau ».
class Session {
  const Session({
    required this.token,
    required this.user,
    required this.isNewUser,
  });

  /// Jeton **opaque** `oat_…` (en-tête `Authorization: Bearer <token>`).
  /// Il ne contient aucune information : ne jamais tenter de le décoder.
  final String token;
  final User user;

  /// `true` = première connexion de cette identité (→ écran profil skippable).
  final bool isNewUser;

  factory Session.fromJson(Map<String, dynamic> json) => Session(
        token: json['token'] as String,
        user: User.fromJson(json['user'] as Map<String, dynamic>),
        isNewUser: json['isNewUser'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'token': token,
        'user': user.toJson(),
        'isNewUser': isNewUser,
      };
}
