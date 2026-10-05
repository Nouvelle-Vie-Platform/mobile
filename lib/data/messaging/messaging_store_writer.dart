/// **Range dans le magasin une ligne arrivée hors du tirage** (#140) — par le
/// canal `users/{id}`, par l'historique par pages, par la réponse de
/// `POST /groups/:id/read`.
///
/// Une seule règle, celle du contrat serveur (« une ligne, trois chemins ») : la
/// ligne se range **par le descripteur du registre**, exactement comme le
/// moteur la rangerait — même désérialisation (`sync_rows.dart`), même tri
/// « rétractation ou ligne », même `insertOrReplace`. Seul le curseur n'avance
/// pas : il ne couvre que ce que le tirage a livré.
///
/// Trois ajouts, et ce sont eux que ce fichier existe pour porter :
///
/// 1. **La lecture ne recule jamais.** `read.advanced` peut arriver dans le
///    désordre (deux appareils, un événement en double) ; une ligne qui
///    n'avance pas sur la locale est ignorée. La route serveur n'écrit que vers
///    l'avant ; l'ordre se juge sur l'identifiant du message lu (un UUIDv7).
/// 2. **L'écho optimiste se réconcilie** : l'appareil qui envoie reçoit lui
///    aussi `message.created`. La ligne serveur porte le même `clientMessageId`
///    que l'écho, que `GroupDao.threadOf` cesse aussitôt d'afficher ; la table
///    des échos est ensuite ramassée.
/// 3. **Un groupe inconnu se signale** : la ligne est rangée, et l'appelant
///    apprend qu'il faut synchroniser pour recevoir le reste (profils, roster).
library;

import '../local/app_database.dart';
import '../local/sync_dao.dart' show SyncCollectionKey;
import '../sync/synced_collection.dart';

/// Écrit les lignes de messagerie reçues hors du tirage.
class MessagingStoreWriter {
  MessagingStoreWriter(this._db);

  final AppDatabase _db;

  /// Range [row] dans la collection [collection]. Rend **`false` si le groupe
  /// cité était inconnu** du magasin avant ce rangement — l'appelant doit alors
  /// déclencher une synchronisation.
  ///
  /// Une collection que ce client ne réplique pas est ignorée (et rend `true` :
  /// il n'y a rien à rattraper qu'on saurait ranger).
  Future<bool> store(String collection, Map<String, Object?> row) async {
    final descriptor = syncedCollectionFor(collection);
    if (descriptor == null) return true;

    final groupId = collection == SyncCollectionKey.groups
        ? row['id']
        : row['groupId'];
    final known =
        groupId is! String || await _db.groupDao.knowsGroup(groupId);

    if (collection == SyncCollectionKey.groupReads &&
        groupId is String &&
        !await _advances(groupId, row)) {
      return known;
    }

    await descriptor.applyLive(_db.syncDao, [row]);

    if (collection == SyncCollectionKey.groupMessages &&
        row['clientMessageId'] is String) {
      await _db.groupDao.purgeReconciled();
    }
    return known;
  }

  /// Range une page d'historique (`GET /groups/:id/messages?before=`) — des
  /// lignes `group_messages`, tombstones compris.
  Future<void> storeMessages(List<Map<String, Object?>> rows) async {
    if (rows.isEmpty) return;
    await syncedCollectionFor(SyncCollectionKey.groupMessages)!
        .applyLive(_db.syncDao, rows);
  }

  /// La ligne de lecture reçue avance-t-elle sur la locale ?
  ///
  /// Jugé sur l'**identifiant du message lu**, et non sur `lastReadAt` : un
  /// identifiant de message est un UUIDv7 frappé par le serveur à l'écriture,
  /// donc son ordre lexicographique est l'ordre du fil — et il ne perd rien au
  /// stockage, là où un instant est arrondi à la seconde par le magasin (deux
  /// lectures dans la même seconde ne se départageraient plus).
  Future<bool> _advances(String groupId, Map<String, Object?> row) async {
    final local = (await _db.groupDao.readOf(groupId))?.lastReadMessageId;
    if (local == null) return true;
    final incoming = row['lastReadMessageId'];
    if (incoming is! String) return false;
    return incoming.compareTo(local) > 0;
  }
}
