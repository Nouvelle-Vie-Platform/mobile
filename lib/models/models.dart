/// Modèles de données simples (immuables) servant à alimenter les écrans.
library;

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

/// Annonce de l'église (communications, événements importants).
class Announcement {
  const Announcement({
    required this.title,
    required this.body,
    required this.date,
    this.tag,
  });

  final String title;
  final String body;
  final String date;
  final String? tag;
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
