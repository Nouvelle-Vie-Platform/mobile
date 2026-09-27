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

/// **La branche demandée n'existe pas côté serveur** (`422`).
///
/// `branch_id` est un **filtre d'affichage, jamais une autorisation** : une
/// branche inconnue rend **422**, jamais 403. C'est donc un désaccord de
/// **référentiel** — une assemblée fermée, un identifiant recopié d'un autre
/// environnement, une base de démonstration —, pas un refus d'accès.
///
/// Elle ne remonte que si le client a **réellement envoyé** un `branch_id` :
/// c'est ce dont [branchId] témoigne, et c'est la garde qui empêche de prendre
/// n'importe quel 422 de `/sync` pour celui-ci. Sans elle, une validation
/// serveur quelconque ferait perdre au fidèle sa préférence, en silence, sans
/// que rien ne l'explique.
///
/// Le repli est écrit dans `SyncEngine` : oublier la préférence, puis rejouer le
/// cycle **sans filtre**. S'obstiner ferait échouer *tous* les cycles, donc
/// toutes les collections — la panne la plus muette du moteur.
class UnknownSyncBranch implements Exception {
  const UnknownSyncBranch(this.branchId, this.path);

  /// La branche que le serveur refuse.
  final int branchId;

  /// La route qui a refusé (`/sync`, ou `/sync/{collection}`).
  final String path;

  @override
  String toString() =>
      'UnknownSyncBranch: « $path » ne connaît pas la branche $branchId';
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
  ///
  /// [branchId] est la **préférence de branche**, `null` = toutes. Sur le
  /// manifeste, elle change ce que le serveur déclare avoir de neuf pour les
  /// quatre collections filtrées (`kBranchScopedCollections`) : sans elle, une
  /// collection annoncerait `has_changes` pour des lignes que le tirage filtré
  /// ne rendrait pas. C'est un **filtre d'affichage, jamais une autorisation**.
  Future<SyncManifest> manifest({
    Map<String, String> cursors = const {},
    int? scopeVersion,
    int? branchId,
  }) async {
    try {
      final res = await _dio.get<dynamic>(
        '/sync',
        queryParameters: {
          for (final entry in cursors.entries)
            'cursors[${entry.key}]': entry.value,
          if (scopeVersion != null) 'scope_version': scopeVersion,
          if (branchId != null) 'branch_id': branchId,
        },
      );
      return SyncManifest.fromJson(_body('/sync', res.data));
    } on DioException catch (error) {
      throw _branchRefusal(error, '/sync', branchId) ?? error;
    }
  }

  /// `GET /sync/{collection}` — une page de tirage.
  ///
  /// [since] est le curseur **rendu par le serveur**, rejoué tel quel. Le
  /// client n'en fabrique jamais et n'en décode jamais (ADR-0026) : absent, il
  /// signifie « depuis le début ».
  ///
  /// [branchId] est la **préférence de branche**, `null` = toutes (aucun
  /// paramètre sur le fil). C'est l'appelant — `SyncEngine` — qui décide de la
  /// passer ou non : cette couche ne sait pas quelles collections sont filtrées,
  /// et elle ne doit pas le savoir. La liste vit dans `branch_filter.dart`, en un
  /// seul endroit.
  Future<DeltaPage> pull(
    String collection, {
    String? since,
    int limit = kSyncPageLimit,
    int? branchId,
  }) async {
    final path = '/sync/$collection';
    try {
      final res = await _dio.get<dynamic>(
        path,
        queryParameters: {
          if (since != null) 'since': since,
          'limit': limit,
          if (branchId != null) 'branch_id': branchId,
        },
      );
      return DeltaPage.fromJson(_body(path, res.data));
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) {
        throw UnknownSyncCollection(collection);
      }
      throw _branchRefusal(error, path, branchId) ?? error;
    }
  }

  Map<String, Object?> _body(String path, Object? data) {
    if (data is Map) return data.cast<String, Object?>();
    throw MalformedSyncResponse(path, data);
  }

  /// Ce 422 est-il un refus de **branche** ?
  ///
  /// Deux conditions, et la seconde est la garde : le statut est 422, **et** le
  /// client a effectivement envoyé un `branch_id`. Tout autre 422 — un paramètre
  /// mal formé, une validation que le serveur ajoutera demain — repart tel quel
  /// et coupe le cycle, ce qui est le bon comportement : on ne devine pas une
  /// cause pour retomber sur un repli qui effacerait un réglage du fidèle.
  UnknownSyncBranch? _branchRefusal(
    DioException error,
    String path,
    int? branchId,
  ) {
    if (branchId == null) return null;
    if (error.response?.statusCode != 422) return null;
    return UnknownSyncBranch(branchId, path);
  }
}
