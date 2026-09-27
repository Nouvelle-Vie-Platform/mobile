/// Le **porteur d'appareil anonyme** : ce qui permet de lire le catalogue sans
/// compte.
///
/// Un repository dédié et asynchrone, hors de `ChurchRepository`, comme tous les
/// domaines servis par le back (CLAUDE.md, « Brancher un vrai backend »).
///
/// Contrat serveur (déployé en v1.11.0) :
/// ```
/// POST /devices/anonymous   → 200 { token, type, expiresAt, lastSeenAt }
/// ```
/// **Publique** : aucune authentification. Corps `{ "deviceId": "<opaque>" }`.
/// Rejouée avec le **même** `deviceId`, elle rend un nouveau jeton sans dupliquer
/// l'appareil, et **les jetons précédents restent valides**. Un `deviceId` trop
/// court rend **422**.
///
/// Le jeton porte ensuite toutes les requêtes exactement comme un jeton de
/// membre (`/sync`, `/sync/:collection`, `/events`…), et son expiration est
/// **glissante** : le serveur la repousse à chaque appel. Rien à rafraîchir, ni
/// rotation ni refresh token — comme pour un membre (`docs/auth-contract.md`).
abstract interface class DeviceRepository {
  /// L'identifiant de cet appareil, généré à la première ouverture. Stable, et
  /// il **survit à une déconnexion**.
  Future<String> deviceId();

  /// Ouvre une session d'appareil : obtient un jeton et le range dans le coffre,
  /// **à la place** de celui qui s'y trouvait (un seul jeton à la fois).
  ///
  /// Lève une [DeviceSessionException] en cas de refus ou de panne réseau. Rien
  /// n'est alors rangé : l'application ne croit pas avoir un jeton.
  Future<DeviceSession> openSession();

  /// Ouvre une session d'appareil **seulement s'il n'y a pas déjà un jeton** dans
  /// le coffre, de l'une ou l'autre nature. À appeler au démarrage.
  ///
  /// Ne lève jamais ; rend `true` si le coffre porte un jeton utilisable.
  Future<bool> ensureSession();

  /// Reprend une session d'appareil après une **déconnexion**, avec le même
  /// identifiant. Ne lève jamais.
  Future<bool> resume();
}

/// Ce que rend `POST /devices/anonymous`.
///
/// Le jeton est **opaque** (`oat_…`) : stocké tel quel, jamais décodé. Les deux
/// dates ne sont là que pour le journal et le débogage — **aucune décision de
/// l'application ne s'y appuie**, l'expiration étant glissante et le serveur seul
/// à la connaître vraiment. Lire `expiresAt` pour décider d'un renouvellement
/// serait une horloge de client contre une horloge de serveur ; le 401 est la
/// seule source de vérité.
class DeviceSession {
  const DeviceSession({
    required this.token,
    this.type,
    this.expiresAt,
    this.lastSeenAt,
  });

  factory DeviceSession.fromJson(Map<String, dynamic> json) => DeviceSession(
        token: json['token'] as String,
        type: json['type'] as String?,
        expiresAt: _instant(json['expiresAt']),
        lastSeenAt: _instant(json['lastSeenAt']),
      );

  final String token;

  /// Le type de porteur annoncé par le serveur, gardé **tel quel** et jamais
  /// comparé : c'est le serveur qui décide de ce qu'un jeton ouvre.
  final String? type;

  final DateTime? expiresAt;
  final DateTime? lastSeenAt;

  /// Une date illisible ne casse pas l'ouverture de session : elle ne sert à
  /// aucune décision.
  static DateTime? _instant(Object? raw) =>
      raw is String ? DateTime.tryParse(raw) : null;
}

/// Pourquoi une session d'appareil n'a pas pu s'ouvrir.
enum DeviceSessionErrorCode {
  /// Le serveur n'a pas répondu (avion, DNS, TLS, coupure).
  network,

  /// **422** — le serveur a refusé le `deviceId`.
  rejectedDeviceId,

  /// Tout le reste (500, réponse inattendue).
  unknown,
}

class DeviceSessionException implements Exception {
  const DeviceSessionException(this.code, [this.message]);

  final DeviceSessionErrorCode code;
  final String? message;

  @override
  String toString() => 'DeviceSessionException($code, $message)';
}
