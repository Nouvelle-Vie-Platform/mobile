import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../../models/models.dart';

/// Référentiel des branches de l'église.
///
/// Une seule abstraction, surchargée via `branchRepositoryProvider` — même
/// principe que `churchRepositoryProvider` et `authRepositoryProvider` : aucun
/// écran ne change quand l'implémentation change.
abstract interface class BranchRepository {
  /// Liste des branches sélectionnables. Peut être **vide** : le référentiel
  /// n'en compte qu'une aujourd'hui, il pourrait n'en compter aucune sur un
  /// environnement fraîchement installé.
  Future<List<Branch>> branches();
}

/// Implémentation HTTP : `GET /sync/branches` (guard `api`, donc **après** le
/// token — l'écran profil étant post-connexion, l'ordre est acquis).
///
/// **Il n'y a pas de `GET /branches`** et il ne faut pas en créer un : les
/// branches sont un référentiel servi par le module de synchronisation. Un
/// endpoint doublon, ce serait deux chemins vers la même donnée à garder
/// cohérents.
///
/// Réponse (après déballage de l'enveloppe `data` par `ApiClient`) :
/// `{ items, next_cursor, has_more, full_resync }`, page de **200** par défaut.
///
/// **Pour ce jalon** : un seul appel, **sans `since`**, curseur **ignoré**. Le
/// vrai protocole delta (curseur persisté, `full_resync`, pagination) viendra
/// avec la synchro complète ; l'ouvrir ici coûterait un état à persister pour
/// une liste qui tient en une ligne.
class HttpBranchRepository implements BranchRepository {
  HttpBranchRepository({ApiClient? client})
      : _client = (client ?? ApiClient.instance).dio;

  final Dio _client;

  @override
  Future<List<Branch>> branches() async {
    final res = await _client.get<Map<String, dynamic>>('/sync/branches');
    final items = res.data?['items'];
    // Une charge utile inattendue vaut « aucune branche » : l'écran profil
    // reste utilisable (« Je suis nouveau » ne dépend d'aucun référentiel).
    if (items is! List) return const [];
    return items
        .whereType<Map>()
        .map((item) => Branch.fromJson(item.cast<String, dynamic>()))
        .toList(growable: false);
  }
}

/// Implémentation de démonstration, servie **uniquement** quand
/// `AppEnv.useBackend` est faux (mode maquette, sans backend).
///
/// Sa liste imite l'état réel du serveur — une seule branche, l'église mère —
/// pour que la maquette ne promette pas une UI que la production n'a pas.
class InMemoryBranchRepository implements BranchRepository {
  const InMemoryBranchRepository();

  static const List<Branch> _branches = [
    Branch(
      id: 1,
      name: 'Eglise Evangélique Nouvelle Vie Lomé',
      address: 'Lomé',
      isMotherChurch: true,
    ),
  ];

  @override
  Future<List<Branch>> branches() async => _branches;
}
