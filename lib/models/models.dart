/// Modèles de données simples (immuables) servant à alimenter les écrans.
library;

import 'package:flutter/foundation.dart';

class ChurchEvent {
  const ChurchEvent({
    required this.title,
    required this.weekday,
    required this.day,
    required this.month,
    required this.time,
    required this.place,
    this.tag,
  });

  final String title;

  /// Nom du jour de la semaine (ex. « Dimanche »).
  final String weekday;
  final String day;
  final String month;
  final String time;
  final String place;
  final String? tag;
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
  });

  final String title;
  final String author;
  final String duration;
  final int seed;

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

/// Canal d'envoi du code de vérification. JSON : `"sms"` | `"email"`.
enum IdentifierChannel { sms, email }

/// Civilité de l'utilisateur. JSON : `"frere"` | `"soeur"`.
enum UserTitle { frere, soeur }

/// Statut d'appartenance. JSON : `"membre"` | `"nouveau"`.
///
/// `nouveau` = pas encore rattaché à une branche.
enum UserStatus { membre, nouveau }

/// Utilisateur connecté (immuable). `title` + `fullName` sont stockés
/// **séparément** et recomposés à l'affichage (voir [displayName]).
class User {
  const User({
    required this.id,
    this.phone,
    this.email,
    this.title,
    this.fullName,
    this.branchId,
    this.status = UserStatus.nouveau,
    this.avatarUrl,
    this.profileComplete = false,
  });

  final String id;

  /// Téléphone au format E.164 (ex. « +22890123456 »).
  final String? phone;
  final String? email;

  /// Civilité, `null` tant que le profil n'est pas complété.
  final UserTitle? title;

  /// Nom seul, **sans** préfixe Frère/Sœur.
  final String? fullName;

  /// Branche rattachée, `null` si « Je suis nouveau » / non rattaché.
  final String? branchId;
  final UserStatus status;
  final String? avatarUrl;

  /// Calculé côté back (title + fullName + (branchId | status nouveau)).
  /// Ne bloque jamais : pilote seulement une bannière douce.
  final bool profileComplete;

  /// Nom d'affichage recomposé : « Frère/Sœur + nom ».
  ///
  /// Repli sur le nom seul si [title] est `null`, chaîne vide si aucun nom.
  String get displayName {
    final name = fullName?.trim() ?? '';
    if (name.isEmpty) return '';
    final prefix = switch (title) {
      UserTitle.frere => 'Frère',
      UserTitle.soeur => 'Sœur',
      null => null,
    };
    return prefix == null ? name : '$prefix $name';
  }

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String,
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        title: json['title'] == null
            ? null
            : UserTitle.values.byName(json['title'] as String),
        fullName: json['fullName'] as String?,
        branchId: json['branchId'] as String?,
        status: json['status'] == null
            ? UserStatus.nouveau
            : UserStatus.values.byName(json['status'] as String),
        avatarUrl: json['avatarUrl'] as String?,
        profileComplete: json['profileComplete'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'phone': phone,
        'email': email,
        'title': title?.name,
        'fullName': fullName,
        'branchId': branchId,
        'status': status.name,
        'avatarUrl': avatarUrl,
        'profileComplete': profileComplete,
      };
}

/// Branche locale de l'église (liste statique en phase mock, `GET /branches`
/// en phase backend).
class Branch {
  const Branch({required this.id, required this.name, this.city});

  final String id;
  final String name;
  final String? city;

  factory Branch.fromJson(Map<String, dynamic> json) => Branch(
        id: json['id'] as String,
        name: json['name'] as String,
        city: json['city'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'city': city,
      };
}

/// Session authentifiée : jeton JWT, utilisateur et indicateur « nouveau ».
class Session {
  const Session({
    required this.token,
    required this.user,
    required this.isNewUser,
  });

  /// Jeton JWT (en-tête `Authorization: Bearer <token>`).
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
