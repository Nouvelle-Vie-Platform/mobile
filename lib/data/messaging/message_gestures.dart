/// **Les gestes sur un message** (tranche M2, #141 ; plan
/// `server-portal/docs/messagerie-whatsapp-plan.md`, décisions 5 et 11) —
/// réagir, modifier, supprimer pour moi ou pour tous, transférer.
///
/// ## Le réseau d'abord, puis le magasin — et c'est la ligne serveur qui y entre
///
/// À la différence de l'envoi (écho optimiste, décision 2 d'Échanges), ces
/// gestes **attendent** la réponse : une modification refusée pour délai, une
/// suppression refusée faute de droit, ne doivent pas avoir paru acquises. Le
/// serveur rend la **ligne de synchronisation** de ce qu'il a écrit (contrat
/// M2, `docs/messagerie-temps-reel-contrat.md` §5) : elle se range aussitôt par
/// [MessagingStoreWriter] — la même fonction que le tirage et le canal —, et
/// l'écran se redessine parce qu'il observe le magasin. Le canal `users/{id}`
/// ramène la même ligne un instant plus tard ; la ranger deux fois est sans
/// effet.
///
/// ## Idempotents, donc rejouables
///
/// Chaque route l'est côté serveur (piège 5 du plan) : poser la même réaction,
/// renvoyer le même texte, masquer deux fois ne font rien de plus. Le transfert
/// porte une clé client **par cible**.
library;

import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../../core/network/api_client.dart';
import '../local/sync_dao.dart' show SyncCollectionKey;

/// Ce qu'a donné un geste — ce que l'écran peut en dire.
enum GestureOutcome {
  /// Fait (ou déjà fait : les routes sont idempotentes).
  done,

  /// Le délai est passé — 15 min pour modifier, 2 jours pour supprimer pour
  /// tous. Le magasin et l'horloge du téléphone pouvaient être en retard.
  windowClosed,

  /// Refusé : pas le droit (pas l'auteur, plus membre, discussion fermée à
  /// l'écriture), message supprimé entre-temps, ou contenu refusé.
  refused,

  /// Pas de réponse : réseau absent ou serveur injoignable. Rien n'a changé.
  unreachable,
}

/// Les deux codes de délai du serveur (contrat M2 §5).
const Set<String> kGestureWindowCodes = {
  'E_GROUP_MESSAGE_EDIT_WINDOW_CLOSED',
  'E_GROUP_MESSAGE_DELETE_WINDOW_CLOSED',
};

/// Une cible de transfert : la discussion, et la clé de la copie.
typedef ForwardTarget = ({String groupId, String clientMessageId});

/// La réponse d'un geste : son issue, et les lignes serveur à ranger.
typedef GestureReply = ({
  GestureOutcome outcome,
  List<Map<String, Object?>> rows,
});

/// **Le transport des gestes** — le seul endroit qui parle HTTP ici.
abstract interface class MessageGestureSender {
  Future<GestureReply> react(String groupId, String messageId, String emoji);
  Future<GestureReply> unreact(String groupId, String messageId);
  Future<GestureReply> edit(String groupId, String messageId, String body);
  Future<GestureReply> deleteForEveryone(String groupId, String messageId);
  Future<GestureReply> hideForMe(String groupId, String messageId);
  Future<GestureReply> forward(
    String groupId,
    String messageId,
    List<ForwardTarget> targets,
  );
}

/// Implémentation HTTP de [MessageGestureSender] — les six routes de M2, sous
/// la garde `api`. Les corps sont en `camelCase`, l'enveloppe `data` est
/// déballée par `ApiClient`.
class HttpMessageGestureSender implements MessageGestureSender {
  HttpMessageGestureSender({ApiClient? client})
      : _client = (client ?? ApiClient.instance).dio;

  final Dio _client;

  String _path(String groupId, String messageId) =>
      '/groups/$groupId/messages/$messageId';

  @override
  Future<GestureReply> react(String groupId, String messageId, String emoji) =>
      _call(() => _client.put<Object?>(
            '${_path(groupId, messageId)}/reaction',
            data: {'emoji': emoji},
          ));

  @override
  Future<GestureReply> unreact(String groupId, String messageId) =>
      _call(() => _client.delete<Object?>(
            '${_path(groupId, messageId)}/reaction',
          ));

  @override
  Future<GestureReply> edit(String groupId, String messageId, String body) =>
      _call(() => _client.patch<Object?>(
            _path(groupId, messageId),
            data: {'body': body},
          ));

  @override
  Future<GestureReply> deleteForEveryone(String groupId, String messageId) =>
      _call(() => _client.delete<Object?>(_path(groupId, messageId)));

  @override
  Future<GestureReply> hideForMe(String groupId, String messageId) =>
      _call(() => _client.post<Object?>('${_path(groupId, messageId)}/hide'));

  @override
  Future<GestureReply> forward(
    String groupId,
    String messageId,
    List<ForwardTarget> targets,
  ) =>
      _call(() => _client.post<Object?>(
            '${_path(groupId, messageId)}/forward',
            data: {
              'targets': [
                for (final target in targets)
                  {
                    'groupId': target.groupId,
                    'clientMessageId': target.clientMessageId,
                  },
              ],
            },
          ));

  Future<GestureReply> _call(
      Future<Response<Object?>> Function() request) async {
    try {
      final response = await request();
      return (outcome: GestureOutcome.done, rows: _rowsOf(response.data));
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status == null || status >= 500) {
        return (
          outcome: GestureOutcome.unreachable,
          rows: const <Map<String, Object?>>[]
        );
      }
      final body = error.response?.data;
      final code = body is Map ? body['code'] : null;
      return (
        outcome: kGestureWindowCodes.contains(code)
            ? GestureOutcome.windowClosed
            : GestureOutcome.refused,
        rows: const <Map<String, Object?>>[],
      );
    }
  }

  /// Une ligne, une liste de lignes (le transfert), ou rien (retirer une
  /// réaction jamais posée).
  static List<Map<String, Object?>> _rowsOf(Object? data) {
    Map<String, Object?> row(Map raw) =>
        {for (final e in raw.entries) e.key.toString(): e.value};
    if (data is Map) return [row(data)];
    if (data is List) {
      return [
        for (final item in data)
          if (item is Map) row(item)
      ];
    }
    return const [];
  }
}

/// Double **inerte** : ne poste rien, dit « fait », ne rend aucune ligne.
/// Défaut des tests et de `AppEnv.useBackend == false`.
class InertMessageGestureSender implements MessageGestureSender {
  const InertMessageGestureSender();

  static const GestureReply _done =
      (outcome: GestureOutcome.done, rows: <Map<String, Object?>>[]);

  @override
  Future<GestureReply> react(String g, String m, String e) async => _done;
  @override
  Future<GestureReply> unreact(String g, String m) async => _done;
  @override
  Future<GestureReply> edit(String g, String m, String b) async => _done;
  @override
  Future<GestureReply> deleteForEveryone(String g, String m) async => _done;
  @override
  Future<GestureReply> hideForMe(String g, String m) async => _done;
  @override
  Future<GestureReply> forward(
          String g, String m, List<ForwardTarget> t) async =>
      _done;
}

/// **Les gestes, rangés** : le transport, puis la ligne serveur au magasin.
class MessageGestures {
  MessageGestures({
    required MessageGestureSender sender,
    required Future<void> Function(String collection, Map<String, Object?> row)
        store,
    String Function()? mintId,
  })  : _sender = sender,
        _store = store,
        _mintId = mintId ?? (() => const Uuid().v7());

  final MessageGestureSender _sender;
  final Future<void> Function(String, Map<String, Object?>) _store;
  final String Function() _mintId;

  /// **Toucher un emoji** : le poser, le remplacer — ou, si c'est déjà **ma**
  /// réaction, la retirer (« la retoucher retire »).
  Future<GestureOutcome> toggleReaction({
    required String groupId,
    required String messageId,
    required String emoji,
    required String? current,
  }) {
    return current == emoji
        ? _apply(
            _sender.unreact(groupId, messageId),
            SyncCollectionKey.groupMessageReactions,
          )
        : _apply(
            _sender.react(groupId, messageId, emoji),
            SyncCollectionKey.groupMessageReactions,
          );
  }

  /// **Modifier** mon message (texte, 15 min).
  Future<GestureOutcome> edit({
    required String groupId,
    required String messageId,
    required String body,
  }) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return Future.value(GestureOutcome.refused);
    return _apply(
      _sender.edit(groupId, messageId, trimmed),
      SyncCollectionKey.groupMessages,
    );
  }

  /// **Supprimer pour tous** (auteur 2 jours, administrateur sans limite).
  Future<GestureOutcome> deleteForEveryone({
    required String groupId,
    required String messageId,
  }) =>
      _apply(
        _sender.deleteForEveryone(groupId, messageId),
        SyncCollectionKey.groupMessages,
      );

  /// **Supprimer pour moi** — toujours.
  Future<GestureOutcome> hideForMe({
    required String groupId,
    required String messageId,
  }) =>
      _apply(
        _sender.hideForMe(groupId, messageId),
        SyncCollectionKey.groupMessageHides,
      );

  /// **Transférer** dans une ou plusieurs de mes discussions — une clé par
  /// copie, frappée ici.
  Future<GestureOutcome> forward({
    required String groupId,
    required String messageId,
    required List<String> targetGroupIds,
  }) {
    if (targetGroupIds.isEmpty) return Future.value(GestureOutcome.done);
    return _apply(
      _sender.forward(groupId, messageId, [
        for (final target in targetGroupIds)
          (groupId: target, clientMessageId: _mintId()),
      ]),
      SyncCollectionKey.groupMessages,
    );
  }

  Future<GestureOutcome> _apply(
    Future<GestureReply> request,
    String collection,
  ) async {
    final reply = await request;
    if (reply.outcome == GestureOutcome.done) {
      for (final row in reply.rows) {
        await _store(collection, row);
      }
    }
    return reply.outcome;
  }
}
