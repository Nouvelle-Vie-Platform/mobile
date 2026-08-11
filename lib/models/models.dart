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

class ChatMessage {
  const ChatMessage({
    required this.author,
    required this.text,
    required this.time,
    required this.mine,
    this.system = false,
  });

  final String author;
  final String text;
  final String time;
  final bool mine;
  final bool system;
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
      };
}

/// Branche locale de l'église (liste statique en phase mock, référentiel servi
/// par `GET /sync/branches` en phase backend).
class Branch {
  const Branch({
    required this.id,
    required this.name,
    this.address,
    this.isMotherChurch = false,
  });

  /// SERIAL côté serveur : se compare directement à `User.branchId`.
  final int id;
  final String name;
  final String? address;

  /// Église mère (une seule dans le référentiel).
  final bool isMotherChurch;

  factory Branch.fromJson(Map<String, dynamic> json) => Branch(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String,
        address: json['address'] as String?,
        isMotherChurch: json['isMotherChurch'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
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
