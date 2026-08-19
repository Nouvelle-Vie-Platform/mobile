/// **Le vrai serveur, piloté en HTTP** — de quoi monter un scénario dans une
/// base de développement, sans double ni fixture.
///
/// Rien ici n'est du client mobile : ce sont les gestes d'un opérateur (se
/// connecter, publier un enseignement, changer sa Home Branch) faits par les
/// mêmes routes que l'app. Le moteur de synchronisation, lui, est exercé tel
/// quel dans le test — c'est tout l'objet de l'exercice.
///
/// **Aucun double d'`HttpClientAdapter`** n'a sa place dans ce répertoire : un
/// test qui remplacerait l'adaptateur ne parlerait plus au serveur, et ne
/// vérifierait rien de ce que ces fichiers prétendent vérifier.
library;

import 'package:dio/dio.dart';
import 'package:maison_du_miracle/core/network/api_client.dart';

/// URL du serveur de développement.
///
/// ```sh
/// flutter test --run-skipped --dart-define=LIVE_SERVER_URL=http://localhost:3333 test/integration/
/// ```
const String kLiveServerUrl = String.fromEnvironment(
  'LIVE_SERVER_URL',
  defaultValue: 'http://localhost:3333',
);

/// Identifiant de l'**opérateur** — celui qui publie les enseignements du
/// scénario. Le `super_admin` amorcé par `node ace db:seed` (`SUPER_ADMIN_PHONE`
/// dans le `.env` du serveur) a une affectation **globale** : il publie dans
/// n'importe quelle branche.
const String kLiveOperatorIdentifier = String.fromEnvironment(
  'LIVE_OPERATOR_IDENTIFIER',
  defaultValue: '+22890000000',
);

/// Identifiant du **fidèle** dont on déplace le périmètre. Un compte ordinaire,
/// sans affectation : c'est sa Home Branch, et elle seule, qui décide de ce
/// qu'il voit. Inconnu du serveur, il est créé à la volée par `verify-code`
/// (ADR-0020) ; connu, il est réutilisé — le scénario est rejouable.
const String kLiveMemberIdentifier = String.fromEnvironment(
  'LIVE_MEMBER_IDENTIFIER',
  defaultValue: '+22899000031',
);

/// Ce que le serveur a répondu, remonté lisiblement.
///
/// Une `DioException` brute ne montre ni le corps ni la route : sur un scénario
/// en douze appels, elle coûte une demi-heure de tâtonnement.
class LiveServerRefused implements Exception {
  LiveServerRefused(this.method, this.path, this.status, this.body);

  final String method;
  final String path;
  final int? status;
  final Object? body;

  @override
  String toString() => 'LiveServerRefused: $method $path → $status\n$body';
}

/// Le serveur n'a pas été joint du tout.
class LiveServerUnreachable implements Exception {
  LiveServerUnreachable(this.url, this.cause);

  final String url;
  final Object? cause;

  @override
  String toString() => '''
LiveServerUnreachable: aucun serveur sur $url ($cause).

Le monter, depuis le dépôt `new-life-server` :

    node ace migration:run && node ace db:seed
    OTP_PHONE_DRIVER=log OTP_DEV_ECHO_CODE=true npm run dev
''';
}

/// Pilote HTTP du serveur de développement.
class LiveServer {
  LiveServer({String baseUrl = kLiveServerUrl})
      : _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 20),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          ),
        )..interceptors.add(unwrapEnvelopeInterceptor),
        url = baseUrl;

  final Dio _dio;

  /// URL de base, telle qu'un `Dio` client doit la recevoir.
  final String url;

  void close() => _dio.close(force: true);

  // ── Authentification (ADR-0020 : OTP, jamais de mot de passe) ─────────────

  /// `POST /auth/request-code` puis `POST /auth/verify-code`, et rend le token
  /// `api`.
  ///
  /// Le code est lu dans `debugCode`, que la réponse `202` ne porte **que** si
  /// le serveur tourne avec `OTP_DEV_ECHO_CODE=true`. C'est le même code que
  /// celui que le canal `phone` journalise en `OTP_PHONE_DRIVER=log` — le lire
  /// dans la réponse plutôt que dans la sortie du serveur ne change que la
  /// façon de le récupérer, et rend le scénario rejouable sans surveiller un
  /// fichier de log.
  Future<String> signIn(String identifier) async {
    final requested = await _post('/auth/request-code', {
      'channel': identifier.contains('@') ? 'email' : 'phone',
      'identifier': identifier,
    });

    final code = (requested as Map)['debugCode'];
    if (code is! String) {
      throw StateError(
        'Le serveur n\'a pas rendu de `debugCode` pour « $identifier ». '
        'Le relancer avec OTP_DEV_ECHO_CODE=true, ou lire le code dans sa '
        'sortie (ligne « [OTP] fake sender ») et le passer à la main.',
      );
    }

    final verified = await _post('/auth/verify-code', {
      'identifier': identifier,
      'code': code,
    });
    return (verified as Map)['token'] as String;
  }

  /// `GET /auth/me` — l'identité de l'acteur, dont son `id` (uuid), cible d'un DM.
  Future<String> me(String token) async {
    final body = await _get('/auth/me', token);
    final user = (body as Map)['user'] ?? body;
    return (user as Map)['id'] as String;
  }

  /// `PUT /auth/profile` — pose un nom, pour que la collection `profiles` porte un
  /// `displayName` (« Prénom Nom ») plutôt qu'un nul.
  Future<void> setName(
    String token, {
    required String firstName,
    required String lastName,
  }) async {
    await _put('/auth/profile', {
      'firstName': firstName,
      'lastName': lastName,
    }, token);
  }

  /// `POST /groups/direct/:targetUserId/messages` — envoi direct (DM 1-à-1),
  /// création paresseuse du fil. Rend le message autoritaire du serveur.
  Future<Map<String, Object?>> sendDirect(
    String token,
    String targetUserId,
    String body, {
    String? clientMessageId,
  }) async {
    final sent = await _post(
      '/groups/direct/$targetUserId/messages',
      {
        'body': body,
        if (clientMessageId != null) 'clientMessageId': clientMessageId,
      },
      token,
    );
    return (sent as Map).cast<String, Object?>();
  }

  // ── Le geste qui déplace le périmètre ────────────────────────────────────

  /// `PUT /auth/profile` — la réponse à la question de la Home Branch.
  ///
  /// C'est **le** chemin HTTP qui incrémente `users.scope_version` sans toucher
  /// à la base : `UpdateProfile` appelle `CompleteOnboarding` dès que
  /// `branchId` est présent, et `CompleteOnboarding` appelle `BumpScopeVersion`.
  /// Renvoyer la **même** branche bumpe aussi — l'action ne compare pas.
  Future<void> setHomeBranch(String token, int branchId) async {
    await _put('/auth/profile', {'branchId': branchId}, token);
  }

  // ── Amorçage du contenu ──────────────────────────────────────────────────

  /// `POST /teachings` — publie un enseignement, immédiatement visible, et rend
  /// son identifiant.
  Future<String> publishTeaching({
    required String token,
    required String title,
    required int? branchId,
    required int contributorId,
    required int teachingTypeId,
  }) async {
    final created = await _post(
      '/teachings',
      {
        'title': title,
        'contributorId': contributorId,
        'teachingTypeId': teachingTypeId,
        'branchId': branchId,
      },
      token,
    );
    return (created as Map)['id'] as String;
  }

  // ── Lectures de reconnaissance ───────────────────────────────────────────

  /// Les lignes d'une collection, tirées **depuis zéro** par le protocole delta.
  ///
  /// Sert à découvrir le terrain (branches, intervenants, rubriques) plutôt
  /// qu'à coder en dur des identifiants qui dépendent de l'ordre des seeders.
  Future<List<Map<String, Object?>>> collection(
    String token,
    String key, {
    String? since,
  }) async {
    final page = await _get(
      '/sync/$key',
      token,
      query: {if (since != null) 'since': since, 'limit': 200},
    );
    return ((page as Map)['items'] as List)
        .cast<Map<String, Object?>>()
        .toList(growable: false);
  }

  /// Le manifeste brut, tel que le serveur le sert.
  Future<Map<String, Object?>> manifest(
    String token, {
    int? scopeVersion,
    Map<String, String> cursors = const {},
  }) async {
    final body = await _get(
      '/sync',
      token,
      query: {
        for (final entry in cursors.entries)
          'cursors[${entry.key}]': entry.value,
        if (scopeVersion != null) 'scope_version': scopeVersion,
      },
    );
    return (body as Map).cast<String, Object?>();
  }

  // ── Plomberie ────────────────────────────────────────────────────────────

  Future<Object?> _get(
    String path,
    String token, {
    Map<String, Object?> query = const {},
  }) =>
      _send(
        'GET',
        path,
        () => _dio.get<dynamic>(
          path,
          queryParameters: query,
          options: _bearer(token),
        ),
      );

  Future<Object?> _post(String path, Object body, [String? token]) => _send(
        'POST',
        path,
        () => _dio.post<dynamic>(path, data: body, options: _bearer(token)),
      );

  Future<Object?> _put(String path, Object body, String token) => _send(
        'PUT',
        path,
        () => _dio.put<dynamic>(path, data: body, options: _bearer(token)),
      );

  Options? _bearer(String? token) => token == null
      ? null
      : Options(headers: {'Authorization': 'Bearer $token'});

  Future<Object?> _send(
    String method,
    String path,
    Future<Response<dynamic>> Function() call,
  ) async {
    try {
      return (await call()).data;
    } on DioException catch (error) {
      final response = error.response;
      if (response == null) throw LiveServerUnreachable(url, error.message);
      throw LiveServerRefused(method, path, response.statusCode, response.data);
    }
  }
}

/// **La coupure**, posée sur le `Dio` du client.
///
/// Le serveur ne sait pas provoquer une synchronisation interrompue : c'est le
/// téléphone qui perd le réseau, pas lui. L'intercepteur rejette la n-ième
/// requête vers [path] exactement comme le ferait une perte de connexion —
/// après quoi le moteur voit une `DioException`, ce qu'il verrait sur le
/// terrain.
///
/// Ce n'est **pas** un double de serveur : les requêtes précédentes sont
/// réellement parties, et leurs réponses viennent du serveur.
class ConnectionCut extends Interceptor {
  ConnectionCut({required this.path, required this.afterRequests});

  /// Chemin surveillé, tel que le client le passe à `Dio` (`/sync/teachings`).
  final String path;

  /// Nombre de requêtes laissées passer avant la coupure.
  final int afterRequests;

  /// Désarmé, l'intercepteur laisse tout passer — le cycle suivant rejoue.
  bool armed = true;

  int _seen = 0;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (armed && options.path == path) {
      _seen++;
      if (_seen > afterRequests) {
        handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
            error: 'coupure simulée en plein resync de périmètre',
          ),
        );
        return;
      }
    }
    handler.next(options);
  }
}

/// Ce que le client a **réellement** envoyé au manifeste, requête par requête.
///
/// La règle d'ADR-0027 côté client — retenir la version *après* application —
/// ne se lit pas seulement dans le magasin : elle se lit sur le fil. Un client
/// qui aurait persisté trop tôt rejouerait la version neuve au tour suivant.
class ManifestWireLog extends Interceptor {
  final List<Object?> scopeVersionsSent = [];

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.path == '/sync') {
      scopeVersionsSent.add(options.queryParameters['scope_version']);
    }
    handler.next(options);
  }
}
