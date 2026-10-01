import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/network/api_client.dart';
import 'device_identity.dart';
import 'device_repository.dart';

/// Plancher entre deux tentatives d'ouverture de session **après un échec**.
///
/// Ce n'est pas un backoff : c'est une borne au nombre d'appels que
/// l'application peut lancer quand ça va mal. Sans elle, un `deviceId` refusé en
/// 422 ferait demander un jeton à *chaque* requête du moteur de synchronisation,
/// et ça se verrait dans le plafond journalier du serveur. **Valeur à
/// confirmer.**
const Duration kDeviceSessionRetryFloor = Duration(seconds: 30);

/// Implémentation HTTP du [DeviceRepository], **et** le garde que l'intercepteur
/// 401 interroge ([DeviceSessionGuard]).
///
/// Les deux rôles vivent dans le même objet **exprès** : le renouvellement en vol
/// est un état d'instance, et il doit être le *même* pour les deux portes
/// d'entrée. Sinon `ensureSession()` au démarrage et un 401 arrivé dans la même
/// seconde demanderaient deux jetons pour un appareil.
///
/// Corollaire : **un seul exemplaire pour toute l'application**. C'est ce que
/// [wire] installe.
class HttpDeviceRepository implements DeviceRepository, DeviceSessionGuard {
  HttpDeviceRepository({
    ApiClient? client,
    DeviceIdentity? identity,
    Duration retryFloor = kDeviceSessionRetryFloor,
    DateTime Function()? now,
  })  : _api = client ?? ApiClient.instance,
        _dio = (client ?? ApiClient.instance).dio,
        // **La même identité que l'en-tête `X-Device-Id`**, et non une seconde :
        // deux instances pourraient, à la première ouverture, fabriquer deux
        // identifiants dont un seul serait rangé.
        _identity = identity ?? (client ?? ApiClient.instance).deviceIdentity,
        _retryFloor = retryFloor,
        _now = now ?? DateTime.now;

  /// Construit le repository **et le câble** sur le client HTTP, pour que
  /// l'intercepteur 401 sache renouveler en silence.
  ///
  /// À appeler **une fois**, au démarrage (`main`), avant la première requête.
  /// Tant que ce câblage n'est pas fait, un 401 se comporte comme avant le mode
  /// invité : purge du jeton et retour à `/auth`.
  static HttpDeviceRepository wire({
    ApiClient? client,
    DeviceIdentity? identity,
  }) {
    final api = client ?? ApiClient.instance;
    final repository = HttpDeviceRepository(client: api, identity: identity);
    api.deviceSession = repository;
    return repository;
  }

  final ApiClient _api;
  final Dio _dio;
  final DeviceIdentity _identity;
  final Duration _retryFloor;
  final DateTime Function() _now;

  /// **Le** renouvellement en vol, s'il y en a un. C'est toute la sérialisation :
  /// les requêtes suivantes attendent celui-ci au lieu d'en lancer un autre.
  Future<bool>? _inFlight;

  /// Instant du dernier échec, pour tenir [kDeviceSessionRetryFloor].
  DateTime? _lastFailure;

  @override
  Future<String> deviceId() => _identity.current();

  @override
  Future<DeviceSession> openSession() async {
    final id = await _identity.current();
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/devices/anonymous',
        data: {'deviceId': id},
        // La requête part **nue** et ne peut rien relancer : voir
        // `kDeviceSessionRequestExtra`.
        options: Options(extra: {kDeviceSessionRequestExtra: true}),
      );
      final session = DeviceSession.fromJson(res.data!);
      // Même emplacement que le jeton de membre, marqué « appareil » : un seul
      // jeton à la fois dans le coffre, jamais deux.
      await _api.saveToken(session.token, kind: AuthTokenKind.device);
      return session;
    } on DioException catch (e) {
      throw mapDeviceSessionError(e);
    } on TypeError catch (_) {
      // Réponse d'une forme inattendue (champ `token` absent) : surtout ne rien
      // ranger, l'application ne doit pas croire avoir un jeton.
      throw const DeviceSessionException(DeviceSessionErrorCode.unknown);
    }
  }

  @override
  Future<bool> ensureSession() async {
    if (await _api.readToken() != null) return true;
    return renew();
  }

  @override
  Future<bool> resume() async {
    // Le coffre **attend** désormais un jeton d'appareil, même si la reprise
    // échoue : c'est ce qui fait qu'un 401 ultérieur se renouvellera en silence
    // au lieu d'éjecter vers l'écran de connexion.
    await _api.expectDeviceSession();
    return renew();
  }

  @override
  Future<bool> renew() {
    final pending = _inFlight;
    // Cinq 401 simultanés au démarrage attendent **le même** renouvellement.
    if (pending != null) return pending;

    final started = _renewOnce();
    _inFlight = started;
    return started.whenComplete(() {
      if (identical(_inFlight, started)) _inFlight = null;
    });
  }

  Future<bool> _renewOnce() async {
    // Garde-fou de course : une connexion peut avoir abouti pendant qu'une
    // requête d'invité était en vol. Écraser le jeton de membre tout juste rangé
    // déconnecterait quelqu'un en silence — le pire des deux échecs possibles.
    if (await _api.readTokenKind() == AuthTokenKind.member &&
        await _api.readToken() != null) {
      return false;
    }

    final lastFailure = _lastFailure;
    if (lastFailure != null && _now().difference(lastFailure) < _retryFloor) {
      return false;
    }

    try {
      await openSession();
      _lastFailure = null;
      return true;
    } on Object catch (error) {
      // Muet, comme le rapport de progression : un invité ne doit rien voir. La
      // trace n'existe qu'en debug.
      _lastFailure = _now();
      assert(() {
        debugPrint('[appareil] renouvellement impossible : $error');
        return true;
      }());
      return false;
    }
  }

  @override
  Future<Response<dynamic>> replay(RequestOptions options) {
    final data = options.data;
    if (data is FormData) {
      // Le flux d'un multipart ne se relit pas : le rejouer tel quel enverrait
      // un corps vide.
      options.data = data.clone();
    }
    // `fetch` retraverse la chaîne d'intercepteurs : c'est `_AuthInterceptor` qui
    // posera le jeton frais, et la marque de rejeu qui empêche un second tour.
    return _dio.fetch<dynamic>(options);
  }
}

/// Traduit l'échec d'une ouverture de session.
///
/// Le **422** est le seul statut nommé : c'est le refus du `deviceId`, et le seul
/// qui dise quelque chose sur nous plutôt que sur le réseau. Tout le reste est du
/// réseau ou du serveur, et se retentera.
///
/// Fonction de niveau bibliothèque, comme `mapAuthError` : testable sans réseau.
@visibleForTesting
DeviceSessionException mapDeviceSessionError(DioException e) {
  final response = e.response;
  if (response == null && e.type != DioExceptionType.cancel) {
    return DeviceSessionException(
      DeviceSessionErrorCode.network,
      'Impossible de joindre le serveur (${e.message})',
    );
  }
  final body = response?.data;
  final message = body is Map ? body['message'] as String? : null;
  if (response?.statusCode == 422) {
    return DeviceSessionException(
      DeviceSessionErrorCode.rejectedDeviceId,
      message,
    );
  }
  return DeviceSessionException(DeviceSessionErrorCode.unknown, message);
}
