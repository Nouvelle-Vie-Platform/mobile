/// **Rechercher dans ses discussions** (#146, tranche M8).
///
/// Deux sources, et l'ordre compte :
///
/// 1. **le magasin d'abord** ([ChatSearchRepository.searchLocal]) — instantané,
///    hors ligne : la synchronisation y a déjà rangé l'essentiel du fil ;
/// 2. **le serveur ensuite** ([ChatSearchRepository.searchRemote],
///    `GET /groups/messages/search?q=`) — pour l'historique que le magasin n'a
///    pas. Ses résultats ne sont **pas rangés** dans le magasin : un message
///    isolé y ferait un trou d'historique (la page suivante partirait de lui).
///    Ouvrir un résultat remonte le fil par pages jusqu'à lui
///    (`ThreadMessageLocator`).
///
/// La recherche sur les **noms** de discussions se fait sur la liste déjà lue
/// (`conversationsMatching`), sans requête.
library;

import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../../models/chat_organization.dart';
import '../local/chat_organization_dao.dart';

/// Contrat de la recherche dans les messages.
abstract interface class ChatSearchRepository {
  /// Les messages du magasin dont le texte contient [query], les plus récents
  /// d'abord.
  Future<List<MessageSearchHit>> searchLocal(String query);

  /// Une page de résultats du serveur, après [before] (l'`id` du dernier
  /// résultat de la page précédente). `null` = injoignable, ce qui n'est pas une
  /// erreur à montrer : les résultats locaux restent.
  Future<RemoteSearchPage?> searchRemote(String query, {String? before});
}

/// La recherche adossée au magasin, et au serveur si [remote] est fourni.
class StoreChatSearchRepository implements ChatSearchRepository {
  StoreChatSearchRepository(
    this._dao, {
    required this.userId,
    RemoteMessageSearch? remote,
  }) : _remote = remote;

  final ChatOrganizationDao _dao;
  final String userId;
  final RemoteMessageSearch? _remote;

  @override
  Future<List<MessageSearchHit>> searchLocal(String query) async {
    final q = query.trim();
    if (q.length < kMinSearchLength) return const [];
    final rows = await _dao.searchMessages(userId, q);
    return [
      for (final row in rows)
        MessageSearchHit(
          messageId: row.messageId,
          groupId: row.groupId,
          body: row.body,
          createdAt: row.createdAt,
          authorName: row.authorName,
        ),
    ];
  }

  @override
  Future<RemoteSearchPage?> searchRemote(String query, {String? before}) async {
    final remote = _remote;
    final q = query.trim();
    if (remote == null || q.length < kMinSearchLength) {
      return const RemoteSearchPage(hits: [], hasMore: false);
    }
    return remote.search(q, before: before);
  }
}

/// Double en mémoire : des résultats fixés, filtrés sur le texte.
class InMemoryChatSearchRepository implements ChatSearchRepository {
  InMemoryChatSearchRepository({
    List<MessageSearchHit> local = const [],
    List<MessageSearchHit> remote = const [],
  })  : _local = local,
        _remote = remote;

  final List<MessageSearchHit> _local;
  final List<MessageSearchHit> _remote;

  /// Les requêtes reçues par [searchRemote] — ce qu'un test relit.
  final List<String> remoteQueries = [];

  List<MessageSearchHit> _filter(List<MessageSearchHit> hits, String query) {
    final needle = foldForSearch(query.trim());
    if (needle.length < kMinSearchLength) return const [];
    return [
      for (final h in hits)
        if (foldForSearch(h.body).contains(needle)) h,
    ];
  }

  @override
  Future<List<MessageSearchHit>> searchLocal(String query) async =>
      _filter(_local, query);

  @override
  Future<RemoteSearchPage?> searchRemote(String query, {String? before}) async {
    remoteQueries.add(query);
    return RemoteSearchPage(hits: _filter(_remote, query), hasMore: false);
  }
}

/// La route serveur de recherche.
abstract interface class RemoteMessageSearch {
  Future<RemoteSearchPage?> search(String query, {String? before});
}

/// Implémentation HTTP de [RemoteMessageSearch].
///
/// ```
/// GET /groups/messages/search?q=<2..100>&before=<id>&limit=<1..50>   (garde api)
/// → 200 { data: [ <ligne group_messages>, … ] }
/// ```
class HttpRemoteMessageSearch implements RemoteMessageSearch {
  HttpRemoteMessageSearch({ApiClient? client, this.pageSize = 20})
      : _client = (client ?? ApiClient.instance).dio;

  final Dio _client;
  final int pageSize;

  @override
  Future<RemoteSearchPage?> search(String query, {String? before}) async {
    try {
      final response = await _client.get<Object?>(
        '/groups/messages/search',
        queryParameters: {
          'q': query,
          'limit': pageSize,
          if (before != null) 'before': before,
        },
      );
      final data = response.data;
      if (data is! List) {
        return const RemoteSearchPage(hits: [], hasMore: false);
      }
      final hits = <MessageSearchHit>[];
      for (final item in data) {
        if (item is! Map) continue;
        final id = item['id'];
        final groupId = item['groupId'];
        final body = item['body'];
        if (id is! String || groupId is! String || body is! String) continue;
        final created = item['createdAt'];
        hits.add(
          MessageSearchHit(
            messageId: id,
            groupId: groupId,
            body: body,
            createdAt: created is String ? DateTime.tryParse(created) : null,
          ),
        );
      }
      return RemoteSearchPage(hits: hits, hasMore: data.length >= pageSize);
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      // Une requête refusée (422 : trop courte, trop longue) ne deviendra pas
      // acceptable en insistant : rien de plus à montrer.
      if (status != null && status >= 400 && status < 500) {
        return const RemoteSearchPage(hits: [], hasMore: false);
      }
      return null;
    }
  }
}
