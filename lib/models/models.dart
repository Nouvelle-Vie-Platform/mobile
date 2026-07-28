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

/// Forme dominante d'un statut.
///
/// Le type n'est jamais déclaré par le back : il se **déduit** de ce qui est
/// présent (cf. [Announcement.kind]). Il ne sert qu'aux rares cas à valeur
/// unique (icône de vignette, choix de fond) — le rendu, lui, empile ce qui
/// existe plutôt que de faire un `switch`.
enum StatusKind { text, image, audio, video }

/// Piste audio d'un statut (message vocal).
@immutable
class StatusAudio {
  const StatusAudio({
    required this.url,
    this.durationMs,
    this.waveform = const [],
  });

  final String url;

  /// Durée annoncée par le back, en millisecondes (`null` = inconnue).
  final int? durationMs;

  /// Hauteurs de barres précalculées (0–100).
  ///
  /// Peut être vide : l'UI replie alors sur une forme déterministe dérivée de
  /// l'identifiant du statut (jamais de `Random()`).
  final List<int> waveform;
}

/// Piste vidéo d'un statut.
@immutable
class StatusVideo {
  const StatusVideo({
    required this.url,
    required this.poster,
    this.durationMs,
  });

  final String url;

  /// Image d'aperçu — **requise** : elle porte tout l'affichage en phase 1 et
  /// couvre le temps de chargement en phase 2.
  final String poster;

  /// Durée annoncée par le back, en millisecondes (`null` = inconnue).
  final int? durationMs;
}

/// Annonce de l'église, publiée sous forme de **statut** (façon WhatsApp).
///
/// Statuts à plat : chacun porte son auteur, sa date de publication et les
/// médias qui le composent. Aucun champ n'est pré-formaté par le back —
/// notamment [publishedAt], que le client rend en relatif et localisé.
@immutable
class Announcement {
  /// Le constructeur reste déclaré `const` (tous les champs sont finaux), mais
  /// il n'est plus **invocable** en `const` : [DateTime] n'est pas constructible
  /// en constante. Les listes de `SampleData` passent donc en `static final`.
  const Announcement({
    required this.id,
    required this.publishedAt,
    this.title,
    this.body,
    this.author,
    this.tag,
    this.audio,
    this.video,
    this.backgroundImage,
    this.backgroundColor,
    this.durationMs,
    this.expiresAt,
    this.isPinned = false,
    this.actionLabel,
    this.actionRoute,
  });

  /// Identifiant stable : repli de waveform, couleur dérivée, clés de pager.
  final String id;

  /// Date de publication (UTC côté back), **formatée côté client**.
  final DateTime publishedAt;

  /// Absent ⇒ bloc de texte centré façon WhatsApp.
  final String? title;
  final String? body;

  /// Auteur affiché en en-tête du statut.
  final String? author;

  /// Pastille de catégorie affichée sous l'en-tête.
  final String? tag;

  /// Présence ⇒ waveform affichée (sous le texte s'il y en a un).
  final StatusAudio? audio;

  /// Présence ⇒ la vidéo sert de fond.
  final StatusVideo? video;

  /// Image de fond (`Image.network` + `errorBuilder` obligatoire).
  final String? backgroundImage;

  /// Couleur de fond (ARGB hexadécimal) ; `null` ⇒ palette dérivée de l'[id].
  final int? backgroundColor;

  /// Durée d'**affichage** du statut, en millisecondes.
  ///
  /// À ne pas confondre avec [publishedAt] ni avec la durée d'un média.
  final int? durationMs;

  /// `null` = n'expire jamais (défaut).
  final DateTime? expiresAt;

  /// Épinglé en tête de liste.
  final bool isPinned;

  /// Bouton d'action optionnel — prévu dans le modèle, inerte en phase 1.
  final String? actionLabel;
  final String? actionRoute;

  /// Forme dominante déduite de la composition.
  ///
  /// Priorité : vidéo, puis audio, puis image de fond **sans texte**, sinon
  /// texte.
  StatusKind get kind {
    if (video != null) return StatusKind.video;
    if (audio != null) return StatusKind.audio;
    final hasBody = body != null && body!.isNotEmpty;
    if (backgroundImage != null && !hasBody && title == null) {
      return StatusKind.image;
    }
    return StatusKind.text;
  }
}

/// Rubrique éditoriale d'un enseignement — pilote son classement sur l'accueil.
///
/// JSON : `"dimanche"` | `"etude"` | `"priere"` | `"libre"`.
/// `libre` = hors rubrique (série, invité, rediffusion…) : ces enseignements
/// alimentent « Derniers enseignements ».
enum TeachingRubric {
  /// Message porté au culte dominical.
  dimanche,

  /// Étude biblique de la semaine.
  etude,

  /// Enregistrement centré sur la prière (veillée, intercession) : peu
  /// d'enseignement, beaucoup de prière.
  priere,

  /// Aucune rubrique dédiée.
  libre,
}

class Teaching {
  const Teaching({
    required this.title,
    required this.author,
    required this.duration,
    this.seed = 0,
    this.color = 0xFF223B8C,
    this.image,
    this.description = '',
    this.verse,
    this.rubric = TeachingRubric.libre,
  });

  final String title;
  final String author;
  final String duration;
  final int seed;

  /// Rubrique d'accueil à laquelle l'enseignement appartient.
  final TeachingRubric rubric;

  /// Couleur d'habillage (ARGB hexadécimal) pilotant l'écran de détail.
  final int color;

  /// Image d'habillage optionnelle (chemin d'asset ou URL `http`).
  final String? image;

  /// Description longue (affichée dans la feuille de détail).
  final String description;

  /// Référence biblique associée (ex. « Matthieu 17:20 »), optionnelle.
  final String? verse;
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
