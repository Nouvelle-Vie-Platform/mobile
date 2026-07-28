import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../models/models.dart';

/// Clé de stockage du `User` mis en cache.
const String _kUserKey = 'cached_user';

/// Cache local du [User] connecté — **la seule chose qui permet d'ouvrir
/// l'app sans réseau**.
///
/// Le splash lit ce cache et route immédiatement ; `GET /auth/me` revalide en
/// arrière-plan (voir `docs/auth-contract.md`, « Stockage local »). Sans lui,
/// chaque démarrage payait un aller-retour réseau avant de savoir quoi
/// afficher — visible sur une connexion lente, bloquant hors ligne.
///
/// **Le cache ne contient jamais le token** : [User.toJson] ne le porte pas, et
/// c'est délibéré. La règle du projet — *le coffre contient ce qu'on ne peut pas
/// re-télécharger ; le cache contient le reste* — veut que le token vive seul
/// dans `flutter_secure_storage` via `ApiClient`. Ici on stocke un objet
/// re-téléchargeable ; s'il disparaît, `/auth/me` le reconstruit.
///
/// **Pourquoi le coffre pour du non-secret ?** Uniquement parce que c'est le
/// seul stockage déjà présent (aucune dépendance en plus pour **un seul
/// objet**). Au jalon synchro ce cache passera à **ObjectBox**, avec la
/// douzaine d'entités qui justifieront le générateur de code. La bascule ne
/// touchera que cette classe : les écrans ne connaissent que `AuthRepository`.
///
/// Toute erreur de lecture est **avalée** : un coffre indisponible ou un JSON
/// devenu illisible (modèle qui a changé de forme entre deux versions de l'app)
/// doit dégrader vers « pas de cache », jamais faire échouer le démarrage.
class UserCache {
  UserCache({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  /// Utilisateur en cache, `null` si absent ou illisible. **Aucun réseau.**
  Future<User?> read() async {
    try {
      final raw = await _storage.read(key: _kUserKey);
      if (raw == null) return null;
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      return User.fromJson(json);
    } on Object catch (error) {
      // Cache illisible = pas de cache. On le purge pour ne pas retomber
      // dessus à chaque démarrage.
      debugPrint('[UserCache] lecture impossible, cache ignoré : $error');
      await clear();
      return null;
    }
  }

  /// Écrit l'utilisateur courant (après `verifyCode`, `updateProfile`, `me`).
  Future<void> write(User user) async {
    try {
      await _storage.write(key: _kUserKey, value: jsonEncode(user.toJson()));
    } on Object catch (error) {
      // Échec d'écriture : l'app fonctionne, seul le prochain démarrage
      // repassera par le réseau. Rien à remonter à l'utilisateur.
      debugPrint('[UserCache] écriture impossible : $error');
    }
  }

  /// Oublie l'utilisateur en cache (déconnexion, 401, token absent).
  Future<void> clear() async {
    try {
      await _storage.delete(key: _kUserKey);
    } on Object catch (error) {
      debugPrint('[UserCache] suppression impossible : $error');
    }
  }
}
