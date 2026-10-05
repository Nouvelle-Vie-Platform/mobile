/// **Faire avancer sa lecture** (#140) — `POST /groups/:id/read`, par une
/// outbox locale rejouable.
///
/// Trois temps, sur le patron de l'envoi d'un message :
///
/// 1. **poser la lecture locale** (`pending_group_reads`) — le compteur de
///    non-lus la lit aussitôt, la pastille s'éteint sans attendre le réseau ;
/// 2. **poster** ;
/// 3. confirmée → **ranger la ligne rendue** dans `group_reads` (la même
///    fonction que le tirage et le canal), **puis** retirer la lecture locale —
///    dans cet ordre, sinon la pastille se rallumerait le temps d'un battement.
///    Refusée (le groupe n'est plus le mien, le message a disparu) → retirer la
///    lecture locale : la rejouer ne changerait pas la réponse. Injoignable → la
///    garder, et la rejouer ([replay]) au prochain cycle réussi.
///
/// La route est **idempotente et monotone** (contrat M1a §2, piège 5 du plan) :
/// rejouer est toujours sûr, et une lecture antérieure à la courante n'écrit
/// rien côté serveur.
library;

import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../local/group_dao.dart';

/// Ce qu'a donné un envoi de lecture.
sealed class ReadOutcome {
  const ReadOutcome();
}

/// `200` : la position courante côté serveur, ligne `group_reads` (plus la clé
/// `advanced`, que le magasin ignore).
final class ReadConfirmed extends ReadOutcome {
  const ReadConfirmed(this.row);
  final Map<String, Object?> row;
}

/// `4xx` : rien à rejouer — non-membre, message inconnu dans ce groupe.
final class ReadRejected extends ReadOutcome {
  const ReadRejected();
}

/// Pas de réponse, ou `5xx` : à rejouer.
final class ReadUnreachable extends ReadOutcome {
  const ReadUnreachable();
}

/// Contrat d'envoi d'une lecture.
abstract interface class GroupReadSender {
  Future<ReadOutcome> send(
      {required String groupId, required String messageId});
}

/// Implémentation HTTP de [GroupReadSender].
///
/// ```
/// POST /groups/:id/read   (garde api)   { "messageId": "<uuidv7>" }
/// → 200 { id, groupId, lastReadMessageId, lastReadAt, advanced }
/// ```
class HttpGroupReadSender implements GroupReadSender {
  HttpGroupReadSender({ApiClient? client})
      : _client = (client ?? ApiClient.instance).dio;

  final Dio _client;

  @override
  Future<ReadOutcome> send({
    required String groupId,
    required String messageId,
  }) async {
    try {
      final response = await _client.post<Object?>(
        '/groups/$groupId/read',
        data: {'messageId': messageId},
      );
      final data = response.data;
      if (data is Map) {
        return ReadConfirmed({
          for (final e in data.entries) e.key.toString(): e.value,
        });
      }
      return const ReadRejected();
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status != null && status >= 400 && status < 500 && status != 429) {
        return const ReadRejected();
      }
      return const ReadUnreachable();
    }
  }
}

/// Double **inerte** : ne poste rien, ne confirme rien — la lecture locale reste
/// posée, ce qui est la seule chose honnête sans serveur. Défaut des tests.
class InertGroupReadSender implements GroupReadSender {
  const InertGroupReadSender();

  @override
  Future<ReadOutcome> send({
    required String groupId,
    required String messageId,
  }) async =>
      const ReadUnreachable();
}

/// L'outbox de la lecture.
class GroupReadAdvancer {
  GroupReadAdvancer({
    required GroupDao dao,
    required GroupReadSender sender,
    required Future<void> Function(Map<String, Object?> row) storeRead,
  })  : _dao = dao,
        _sender = sender,
        _storeRead = storeRead;

  final GroupDao _dao;
  final GroupReadSender _sender;

  /// Range la ligne confirmée dans `group_reads` — `MessagingStoreWriter`, qui
  /// ne la laisse jamais reculer.
  final Future<void> Function(Map<String, Object?> row) _storeRead;

  /// Les envois en cours, par groupe : un second appel pendant un aller-retour
  /// ne double pas la requête — la lecture plus récente, posée localement,
  /// partira au rejeu.
  final Set<String> _inFlight = {};

  /// **Le fil affiche [messageId]** : la lecture avance jusqu'à lui, si elle
  /// n'y est pas déjà.
  Future<void> advance({
    required String groupId,
    required String messageId,
    required DateTime messageCreatedAt,
  }) async {
    final advanced = await _dao.rememberRead(
      groupId: groupId,
      messageId: messageId,
      messageCreatedAt: messageCreatedAt,
    );
    if (!advanced) return;
    await _send(groupId, messageId);
  }

  /// **Rejoue** les lectures locales encore à confirmer. Appelé après chaque
  /// cycle de synchronisation réussi — donc au retour du réseau, au retour au
  /// premier plan, à la reconnexion du canal.
  Future<void> replay() async {
    for (final pending in await _dao.pendingReads()) {
      await _send(pending.groupId, pending.messageId);
    }
  }

  Future<void> _send(String groupId, String messageId) async {
    if (!_inFlight.add(groupId)) return;
    ReadOutcome outcome = const ReadUnreachable();
    try {
      outcome = await _sender.send(groupId: groupId, messageId: messageId);
      switch (outcome) {
        case ReadConfirmed(:final row):
          await _storeRead(row);
          await _dao.forgetRead(groupId: groupId, messageId: messageId);
        case ReadRejected():
          await _dao.forgetRead(groupId: groupId, messageId: messageId);
        case ReadUnreachable():
          break;
      }
    } finally {
      _inFlight.remove(groupId);
    }
    if (outcome is ReadUnreachable) return;

    // Une lecture plus récente a pu être posée pendant l'aller-retour (un
    // message arrivé fil ouvert) : elle part tout de suite, sans attendre le
    // rejeu. La récursion est bornée — chaque tour exige une lecture qui avance.
    for (final pending in await _dao.pendingReads()) {
      if (pending.groupId == groupId && pending.messageId != messageId) {
        await _send(groupId, pending.messageId);
      }
    }
  }
}
