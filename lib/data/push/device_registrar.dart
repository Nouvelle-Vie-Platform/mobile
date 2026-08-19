/// **L'envoi de l'inscription push au serveur — derrière une abstraction.**
///
/// Le maillon qui **rend l'appareil joignable** : il prend la [PushRegistration]
/// produite par le [PushTransport] (jeton FCM ou endpoint UnifiedPush, décisions
/// **D1/D3** du PRD `notifications-push.md`) et la POSTe au serveur ; à la
/// déconnexion il la **purge**. Il ne connaît **ni `firebase_messaging` ni
/// `unifiedpush`** — il ne manipule que la valeur plate que le transport lui
/// tend —, donc il se teste intégralement sur la VM avec un `Dio` factice, et le
/// vrai câblage natif s'ajoutera plus tard sans qu'un appelant change.
///
/// **Best-effort, et c'est un choix, pas un relâchement.** Le push est un
/// *confort* : il double le SSE (app ouverte) pour réveiller l'app **fermée**.
/// Un échec d'enregistrement ne doit donc **jamais** casser un démarrage, une
/// connexion ou une déconnexion. Les deux méthodes **avalent** l'échec réseau,
/// le traduisent en un [DeviceRegistrarRefusal] **typé** et le **journalisent**
/// (jamais le [PushRegistration.token] — décision **D5**), puis rendent la main.
/// Elles ne lèvent pas. Le serveur est idempotent : le prochain démarrage
/// réenregistrera de toute façon.
///
/// ## Le contrat serveur, tel qu'il est *réellement* (lu dans le code serveur)
///
/// - **Enregistrer** : `POST /devices/tokens`, corps **camelCase**
///   `{ token, platform, transport }` (issue #109,
///   `app/devices/controllers/register_device_token_controller.ts`). `transport`
///   est optionnel côté serveur (défaut `fcm`) ; on l'envoie **toujours**, la
///   valeur étant déjà portée, non nulle, par la [PushRegistration]. Le compte
///   propriétaire vient du Bearer, jamais du corps.
///
/// - **Purger** : il **n'existe pas** de `DELETE /devices/tokens`, et c'est
///   **délibéré** (commentaire de `app/devices/routes.ts`, issue #109). Le
///   désenregistrement est **soudé à la déconnexion** : `POST /auth/sign-out`
///   avec un champ optionnel `{ deviceToken }` (camelCase,
///   `app/auth/controllers/sign_out_controller.ts`). Le sortir dans un `DELETE`
///   séparé aurait autorisé un *sign-out qui laisse l'appareil abonné* —
///   précisément le trou à éviter sur un téléphone partagé ou revendu.
///
///   Conséquence assumée à connaître : sur ce serveur, **purger l'inscription
///   push, c'est révoquer la session courante** — les deux sont la même
///   opération. [unregister] n'est donc à appeler **qu'à la déconnexion**, et le
///   `sign-out` qu'il émet est **le** sign-out de l'appareil (il ne s'ajoute pas
///   à un autre : le câblage — hors de ce maillon — doit veiller à ne pas
///   déconnecter deux fois). Un second sign-out sur un token déjà révoqué
///   retombe en `401`, avalé comme le reste.
///
/// > Note de réconciliation : l'en-tête de `push_transport.dart` évoque un
/// > « `DELETE /devices` » — c'était l'hypothèse au moment de son écriture. Le
/// > contrat serveur effectif est celui décrit ci-dessus (sign-out + `deviceToken`),
/// > vérifié dans le code du serveur.
///
/// Le défaut hors backend et en test est [InertDeviceRegistrar] (no-op).
library;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/network/api_client.dart';
import 'push_transport.dart';

/// **Enregistre / purge l'inscription push d'un appareil auprès du serveur.**
///
/// Deux implémentations vivent derrière ce contrat et **aucun appelant ne sait
/// laquelle tourne** : [HttpDeviceRegistrar] (la réelle, sur le `Dio`
/// d'`ApiClient`) et [InertDeviceRegistrar] (le no-op des tests et du mode
/// maquette). Ni l'une ni l'autre ne lève : l'échec est un non-événement.
abstract interface class DeviceRegistrar {
  /// Poste l'inscription au serveur (`POST /devices/tokens`). Idempotent côté
  /// serveur ; à rappeler au démarrage, à la connexion et à chaque rotation.
  Future<void> register(PushRegistration registration);

  /// Purge l'inscription **à la déconnexion** (`POST /auth/sign-out` +
  /// `deviceToken`). Voir l'en-tête du fichier : sur ce serveur, purger l'appareil
  /// et révoquer la session sont une seule opération.
  Future<void> unregister(PushRegistration registration);
}

/// Implémentation HTTP, sur le `Dio` partagé d'[ApiClient] (Bearer injecté, 401
/// traité globalement). **Best-effort** : voir l'en-tête du fichier.
class HttpDeviceRegistrar implements DeviceRegistrar {
  HttpDeviceRegistrar({ApiClient? client})
      : _dio = (client ?? ApiClient.instance).dio;

  final Dio _dio;

  @override
  Future<void> register(PushRegistration registration) async {
    try {
      // Corps **camelCase** — la convention des corps de cette API REST (le
      // `snake_case` est réservé aux query strings et à l'enveloppe `/sync`).
      // `transport` est toujours envoyé : la valeur est déjà portée par
      // l'inscription (`fcm` | `unifiedpush`).
      await _dio.post<void>(
        '/devices/tokens',
        data: <String, Object?>{
          'token': registration.token,
          'platform': registration.platform,
          'transport': registration.transport,
        },
      );
    } on DioException catch (e) {
      _swallow('register', mapDeviceRegistrarError(e));
    }
  }

  @override
  Future<void> unregister(PushRegistration registration) async {
    try {
      // Pas de `DELETE /devices/tokens` (choix serveur délibéré) : la purge
      // passe par le sign-out, qui accepte le `deviceToken` de l'appareil
      // courant et le désabonne. Voir l'en-tête du fichier.
      await _dio.post<void>(
        '/auth/sign-out',
        data: <String, Object?>{'deviceToken': registration.token},
      );
    } on DioException catch (e) {
      _swallow('unregister', mapDeviceRegistrarError(e));
    }
  }

  /// Journalise un refus **sans jamais lever** — le push est un confort. Ne
  /// journalise **pas** le token (décision **D5**) : seul le code typé sort.
  void _swallow(String operation, DeviceRegistrarRefusal refusal) {
    final detail = refusal.detail == null ? '' : ' (${refusal.detail})';
    debugPrint('[push] $operation ignoré — ${refusal.code.name}$detail');
  }
}

/// Double **inerte** : ne parle à personne. Défaut hors backend et en test, à
/// l'image d'[InertPushTransport] et d'`InertContentPlayer`.
class InertDeviceRegistrar implements DeviceRegistrar {
  const InertDeviceRegistrar();

  @override
  Future<void> register(PushRegistration registration) async {}

  @override
  Future<void> unregister(PushRegistration registration) async {}
}

/// Nature d'un refus d'enregistrement, pour la **journalisation** (jamais pour
/// bloquer un écran : rien de tout ceci ne remonte à l'UI).
enum DeviceRegistrarRefusalCode {
  /// Aucune réponse : timeout, DNS, coupure, TLS.
  network,

  /// **401** : plus de session valide (typique d'un sign-out déjà consommé).
  unauthorized,

  /// **422** : corps refusé par le validateur (plateforme/transport hors du jeu).
  rejected,

  /// Toute autre réponse HTTP (5xx…).
  server,

  /// Requête annulée, ou cas inclassable.
  unknown,
}

/// Un refus typé, avec un détail **facultatif** (message serveur ou cause
/// réseau) — de quoi journaliser, jamais de quoi composer une phrase à l'écran.
@immutable
class DeviceRegistrarRefusal {
  const DeviceRegistrarRefusal(this.code, [this.detail]);

  final DeviceRegistrarRefusalCode code;
  final String? detail;
}

/// Traduit une [DioException] en [DeviceRegistrarRefusal].
///
/// Fonction de niveau bibliothèque (et non méthode privée) pour rester testable
/// sans réseau — même motif que `mapGroupWriteError`. `flutter test` répond
/// `400` à tout accès réel.
@visibleForTesting
DeviceRegistrarRefusal mapDeviceRegistrarError(DioException e) {
  if (e.type == DioExceptionType.cancel) {
    return const DeviceRegistrarRefusal(DeviceRegistrarRefusalCode.unknown);
  }

  final response = e.response;
  if (response == null) {
    return DeviceRegistrarRefusal(DeviceRegistrarRefusalCode.network, e.message);
  }

  final body = response.data;
  final message = body is Map ? body['message'] as String? : null;

  return switch (response.statusCode) {
    401 => DeviceRegistrarRefusal(
        DeviceRegistrarRefusalCode.unauthorized,
        message,
      ),
    422 => DeviceRegistrarRefusal(DeviceRegistrarRefusalCode.rejected, message),
    _ => DeviceRegistrarRefusal(
        DeviceRegistrarRefusalCode.server,
        message ?? e.message,
      ),
  };
}
