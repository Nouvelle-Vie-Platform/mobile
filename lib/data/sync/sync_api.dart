/// **Les deux routes du protocole delta**, et rien d'autre.
///
/// `GET /sync` (le manifeste) et `GET /sync/{collection}` (le tirage). Cette
/// couche ne décide de rien : elle parle HTTP, elle rend des formes de
/// protocole. Toute la discipline — l'ordre, le curseur, le resync, la version
/// de périmètre — vit dans `SyncEngine`.
library;

import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import 'sync_protocol.dart';

/// Taille de page demandée au serveur. Le maximum accepté est **200**, et c'est
/// aussi le défaut serveur.
///
/// Les tests la ramènent à **1** : à 200, une poignée de lignes ne produit
/// jamais de seconde page, donc la boucle de rattrapage ne serait **jamais**
/// exercée.
const int kSyncPageLimit = 200;

/// **La collection n'existe pas côté serveur** (`404`).
///
/// Ce n'est pas une panne : le mobile demandera un jour `gatherings`
/// (rassemblements, PRD §5 sexies) avant que le serveur ne l'enregistre. Un
/// `404` coûte une collection sautée, jamais une synchronisation échouée.
///
/// Le déclencheur est le **statut**, pas le code applicatif :
/// `RessourceNotExistsException` interpole le libellé de la ressource dans son
/// code (`E_COLLECTION_NOT_EXISTS`, et non l'`E_RESSOURCE_NOT_EXISTS` annoncé
/// par la documentation). Un libellé est une variable d'implémentation.
class UnknownSyncCollection implements Exception {
  const UnknownSyncCollection(this.collection);

  final String collection;

  @override
  String toString() =>
      'UnknownSyncCollection: le serveur ne connaît pas « $collection »';
}

/// Une réponse dont la forme n'est pas celle du protocole.
class MalformedSyncResponse implements Exception {
  const MalformedSyncResponse(this.path, this.body);

  final String path;
  final Object? body;

  @override
  String toString() => 'MalformedSyncResponse: « $path » a rendu $body';
}

/// Client des deux routes de synchronisation.
class SyncApi {
  /// [dio] par défaut est celui d'[ApiClient] : la requête traverse donc les
  /// intercepteurs de production — Bearer, déballage de l'enveloppe `data`,
  /// traitement du 401.
  SyncApi({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  final Dio _dio;

  /// `GET /sync` — l'état de **toutes** les collections du registre.
  ///
  /// Le client transmet ce qu'il sait : ses curseurs (`cursors[<collection>]`)
  /// et sa version de périmètre. Une valeur absente vaut « je ne sais pas », ce
  /// qui est différent de zéro.
  Future<SyncManifest> manifest({
    Map<String, String> cursors = const {},
    int? scopeVersion,
  }) async {
    final res = await _dio.get<dynamic>(
      '/sync',
      queryParameters: {
        for (final entry in cursors.entries)
          'cursors[${entry.key}]': entry.value,
        if (scopeVersion != null) 'scope_version': scopeVersion,
      },
    );
    return SyncManifest.fromJson(_body('/sync', res.data));
  }

  /// `GET /sync/{collection}` — une page de tirage.
  ///
  /// [since] est le curseur **rendu par le serveur**, rejoué tel quel. Le
  /// client n'en fabrique jamais et n'en décode jamais (ADR-0026) : absent, il
  /// signifie « depuis le début ».
  Future<DeltaPage> pull(
    String collection, {
    String? since,
    int limit = kSyncPageLimit,
  }) async {
    final path = '/sync/$collection';
    try {
      final res = await _dio.get<dynamic>(
        path,
        queryParameters: {
          if (since != null) 'since': since,
          'limit': limit,
        },
      );
      return DeltaPage.fromJson(_body(path, res.data));
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) {
        throw UnknownSyncCollection(collection);
      }
      rethrow;
    }
  }

  Map<String, Object?> _body(String path, Object? data) {
    if (data is Map) return data.cast<String, Object?>();
    throw MalformedSyncResponse(path, data);
  }
}
