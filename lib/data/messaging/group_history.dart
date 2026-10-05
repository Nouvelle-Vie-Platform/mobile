/// **L'historique d'un fil, par pages, en remontant** (#140) —
/// `GET /groups/:id/messages?before=<messageId>&limit=<n>`.
///
/// Une lecture d'**affichage** : le fil s'ouvre sur ce que le magasin possède,
/// et ne demande au serveur que ce qui précède le plus ancien message local,
/// quand on remonte jusqu'à lui. Les lignes rendues ont la forme exacte de
/// `group_messages` (tombstones compris) et se **rangent dans le magasin** par
/// la même fonction que le tirage (`MessagingStoreWriter.storeMessages`) : le
/// fil les affiche ensuite comme les autres — le réseau ne peint jamais.
library;

import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';

/// La taille d'une page, nommée une fois : le défaut du serveur (`1..100`).
const int kHistoryPageSize = 30;

/// Ce qu'a donné une demande de page.
enum HistoryOutcome {
  /// Une page pleine est arrivée : il y en a peut-être d'autres avant.
  more,

  /// Une page courte (ou vide) : **il n'y a plus rien avant**. Aussi le cas d'un
  /// `404` — le message de référence n'existe pas (plus) dans ce groupe.
  exhausted,

  /// Pas de réponse : à retenter au prochain défilement.
  unreachable,
}

/// Contrat de lecture de l'historique.
abstract interface class GroupHistory {
  /// Demande les messages strictement antérieurs à [beforeId], et les range.
  Future<HistoryOutcome> loadBefore({
    required String groupId,
    required String beforeId,
  });
}

/// Implémentation HTTP de [GroupHistory].
class HttpGroupHistory implements GroupHistory {
  HttpGroupHistory({
    required Future<void> Function(List<Map<String, Object?>> rows) store,
    ApiClient? client,
    int pageSize = kHistoryPageSize,
  })  : _store = store,
        _client = (client ?? ApiClient.instance).dio,
        _pageSize = pageSize;

  final Future<void> Function(List<Map<String, Object?>> rows) _store;
  final Dio _client;
  final int _pageSize;

  @override
  Future<HistoryOutcome> loadBefore({
    required String groupId,
    required String beforeId,
  }) async {
    try {
      final response = await _client.get<Object?>(
        '/groups/$groupId/messages',
        queryParameters: {'before': beforeId, 'limit': _pageSize},
      );
      final data = response.data;
      if (data is! List) return HistoryOutcome.exhausted;
      final rows = [
        for (final item in data)
          if (item is Map)
            {for (final e in item.entries) e.key.toString(): e.value},
      ];
      await _store(rows);
      return rows.length < _pageSize
          ? HistoryOutcome.exhausted
          : HistoryOutcome.more;
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      // 403/404 : ce fil n'a rien de plus à me donner. 422 : un curseur que le
      // serveur refuse ne deviendra pas acceptable en insistant.
      if (status != null && status >= 400 && status < 500) {
        return HistoryOutcome.exhausted;
      }
      return HistoryOutcome.unreachable;
    }
  }
}

/// Double **inerte** : aucun historique au-delà du magasin. Défaut des tests.
class NoGroupHistory implements GroupHistory {
  const NoGroupHistory();

  @override
  Future<HistoryOutcome> loadBefore({
    required String groupId,
    required String beforeId,
  }) async =>
      HistoryOutcome.exhausted;
}
