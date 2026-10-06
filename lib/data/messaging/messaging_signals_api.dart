/// **Les routes des accusés, de la frappe, de la présence et de la
/// confidentialité** (#142, tranche M3 ; contrat serveur
/// `docs/messagerie-temps-reel-contrat.md` §5).
///
/// Une seule couture pour les six routes, et c'est délibéré : ce sont six
/// petits appels sans état, et les tests n'ont qu'un double à poser
/// ([InertMessagingSignalsApi], le défaut de `pumpScreen`). L'implémentation
/// réelle est HTTP dès que `AppEnv.useBackend` est vrai — dans un test, elle
/// ouvrirait une socket que `flutter test` refuse.
///
/// ```
/// POST /groups/messages/delivered                 { messageIds }   (lot ≤ 200)
/// POST /groups/:id/typing                                          → 204
/// GET  /groups/:id/presence                                        → présence | null
/// GET  /groups/:id/messages/:messageId/receipts                    → Infos du message
/// GET  /messaging/privacy                                          → réglages
/// PUT  /messaging/privacy   { readReceipts?, presence? }           → réglages
/// ```
library;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/network/api_client.dart';
import 'messaging_channel.dart' show MessagingPresenceEvent;

/// Ce qu'a donné une confirmation de distribution.
enum DeliveryOutcome {
  /// `200` : confirmé (y compris les identifiants que le serveur a ignorés).
  confirmed,

  /// `4xx` : rien à rejouer — le lot ne passera jamais tel quel.
  rejected,

  /// Pas de réponse, ou `5xx` : à rejouer au prochain cycle.
  unreachable,
}

/// **Mes réglages de confidentialité** (`GET|PUT /messaging/privacy`).
@immutable
class MessagingPrivacy {
  const MessagingPrivacy({required this.readReceipts, required this.presence});

  /// Le défaut serveur (et WhatsApp) : tout est visible.
  static const MessagingPrivacy defaults =
      MessagingPrivacy(readReceipts: true, presence: true);

  /// « Accusés de lecture ». Coupé : les autres ne voient plus mes « lu », et
  /// je ne vois plus les leurs.
  final bool readReceipts;

  /// « Vu à / en ligne ». Même réciprocité.
  final bool presence;

  MessagingPrivacy copyWith({bool? readReceipts, bool? presence}) =>
      MessagingPrivacy(
        readReceipts: readReceipts ?? this.readReceipts,
        presence: presence ?? this.presence,
      );

  static MessagingPrivacy? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final read = raw['readReceipts'];
    final presence = raw['presence'];
    if (read is! bool || presence is! bool) return null;
    return MessagingPrivacy(readReceipts: read, presence: presence);
  }

  @override
  bool operator ==(Object other) =>
      other is MessagingPrivacy &&
      other.readReceipts == readReceipts &&
      other.presence == presence;

  @override
  int get hashCode => Object.hash(readReceipts, presence);
}

/// Un destinataire d'un de mes messages, dans « Infos du message ».
@immutable
class MessageRecipientReceipt {
  const MessageRecipientReceipt({
    required this.userId,
    this.deliveredAt,
    this.readAt,
  });

  final String userId;

  /// Quand son téléphone l'a reçu ; `null` = pas encore.
  final DateTime? deliveredAt;

  /// Quand il l'a lu ; `null` = pas lu, **ou** la réciprocité le cache — le
  /// serveur ne distingue pas les deux, l'écran non plus.
  final DateTime? readAt;
}

/// **Les six routes de M3.**
abstract interface class MessagingSignalsApi {
  Future<DeliveryOutcome> confirmDeliveries(List<String> messageIds);

  /// « J'écris » — best-effort : un échec est avalé (le signal suivant le
  /// remplacera).
  Future<void> signalTyping(String groupId);

  /// La présence de l'autre dans un tête-à-tête ; `null` pour un groupe, ou
  /// sans réponse.
  Future<MessagingPresenceEvent?> presenceIn(String groupId);

  /// « Infos du message » — **lève** sur une panne : l'écran le dit.
  Future<List<MessageRecipientReceipt>> messageReceipts({
    required String groupId,
    required String messageId,
  });

  /// **Lève** sur une panne.
  Future<MessagingPrivacy> readPrivacy();

  /// **Lève** sur une panne ; rend les réglages tels que le serveur les tient.
  Future<MessagingPrivacy> updatePrivacy({bool? readReceipts, bool? presence});
}

/// Implémentation HTTP.
class HttpMessagingSignalsApi implements MessagingSignalsApi {
  HttpMessagingSignalsApi({ApiClient? client})
      : _client = (client ?? ApiClient.instance).dio;

  final Dio _client;

  @override
  Future<DeliveryOutcome> confirmDeliveries(List<String> messageIds) async {
    try {
      await _client.post<Object?>(
        '/groups/messages/delivered',
        data: {'messageIds': messageIds},
      );
      return DeliveryOutcome.confirmed;
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status != null && status >= 400 && status < 500 && status != 429) {
        return DeliveryOutcome.rejected;
      }
      return DeliveryOutcome.unreachable;
    }
  }

  @override
  Future<void> signalTyping(String groupId) async {
    try {
      await _client.post<Object?>('/groups/$groupId/typing');
    } on DioException {
      // Éphémère : un signal perdu ne se rattrape pas, le suivant suffit.
    }
  }

  @override
  Future<MessagingPresenceEvent?> presenceIn(String groupId) async {
    try {
      final response = await _client.get<Object?>('/groups/$groupId/presence');
      return MessagingPresenceEvent.fromJson(_unwrap(response.data));
    } on DioException {
      return null;
    }
  }

  @override
  Future<List<MessageRecipientReceipt>> messageReceipts({
    required String groupId,
    required String messageId,
  }) async {
    final response = await _client
        .get<Object?>('/groups/$groupId/messages/$messageId/receipts');
    final data = response.data;
    final recipients = data is Map ? data['recipients'] : null;
    if (recipients is! List) return const [];
    return [
      for (final raw in recipients)
        if (raw is Map && raw['userId'] is String)
          MessageRecipientReceipt(
            userId: raw['userId'] as String,
            deliveredAt: _instant(raw['deliveredAt']),
            readAt: _instant(raw['readAt']),
          ),
    ];
  }

  @override
  Future<MessagingPrivacy> readPrivacy() async {
    final response = await _client.get<Object?>('/messaging/privacy');
    return MessagingPrivacy.fromJson(response.data) ??
        MessagingPrivacy.defaults;
  }

  @override
  Future<MessagingPrivacy> updatePrivacy({
    bool? readReceipts,
    bool? presence,
  }) async {
    final response = await _client.put<Object?>(
      '/messaging/privacy',
      data: {
        if (readReceipts != null) 'readReceipts': readReceipts,
        if (presence != null) 'presence': presence,
      },
    );
    return MessagingPrivacy.fromJson(response.data) ??
        MessagingPrivacy.defaults;
  }

  /// `{"data": null}` n'est pas déballé par l'intercepteur (il ne déballe
  /// qu'une carte d'une clé dont la valeur existe) : on le fait ici.
  static Object? _unwrap(Object? body) =>
      body is Map && body.length == 1 && body.containsKey('data')
          ? body['data']
          : body;

  static DateTime? _instant(Object? raw) =>
      raw is String ? DateTime.tryParse(raw)?.toUtc() : null;
}

/// **Double inerte** — le défaut des tests et d'une application sans backend :
/// rien ne part, la présence est inconnue, les réglages sont ceux par défaut.
class InertMessagingSignalsApi implements MessagingSignalsApi {
  const InertMessagingSignalsApi();

  @override
  Future<DeliveryOutcome> confirmDeliveries(List<String> messageIds) async =>
      DeliveryOutcome.unreachable;

  @override
  Future<void> signalTyping(String groupId) async {}

  @override
  Future<MessagingPresenceEvent?> presenceIn(String groupId) async => null;

  @override
  Future<List<MessageRecipientReceipt>> messageReceipts({
    required String groupId,
    required String messageId,
  }) async =>
      const [];

  @override
  Future<MessagingPrivacy> readPrivacy() async => MessagingPrivacy.defaults;

  @override
  Future<MessagingPrivacy> updatePrivacy({
    bool? readReceipts,
    bool? presence,
  }) async =>
      MessagingPrivacy.defaults.copyWith(
        readReceipts: readReceipts,
        presence: presence,
      );
}
