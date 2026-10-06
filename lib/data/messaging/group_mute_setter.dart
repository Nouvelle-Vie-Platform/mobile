/// **Mettre une discussion en sourdine, ou la réactiver** (tranche M5, décision
/// 10 du plan) — `PUT` / `DELETE /groups/:id/mute`.
///
/// ## Un geste en ligne, et c'est délibéré
///
/// Pas d'outbox, contrairement à l'envoi et à la lecture : la sourdine doit
/// être connue du **serveur** pour avoir son effet principal — c'est lui qui
/// choisit, à chaque message, entre le réveil sonore et le réveil muet. Une
/// sourdine posée hors ligne et seulement en local ferait croire à un silence
/// que les autres appareils, et le serveur, ignorent. Un refus se dit donc tout
/// de suite (« vérifiez votre connexion »), et la personne réessaie.
///
/// Rejouer est sûr (piège 5) : « toujours » et « réactiver » rejoués n'écrivent
/// rien côté serveur, et une durée bornée rejouée repart de maintenant.
///
/// ## Le serveur répond la ligne, et elle se range comme la synchro la rangerait
///
/// La réponse **est** la ligne `group_mutes` : elle passe par
/// `MessagingStoreWriter`, la même fonction que le canal (`mute.changed`) et
/// que le tirage. La tuile et le menu se repeignent du magasin.
library;

import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';

/// Les trois durées de la décision 10, et elles seules — la valeur est celle
/// que le serveur attend (`GROUP_MUTE_DURATIONS`).
enum MuteDuration {
  eightHours('8h'),
  oneWeek('1w'),
  forever('forever');

  const MuteDuration(this.wire);

  final String wire;
}

/// Contrat d'envoi d'un réglage de sourdine.
abstract interface class GroupMuteSender {
  /// Pose la sourdine ([duration]) ou la lève (`null`). Rend la ligne
  /// `group_mutes` servie, ou `null` si le réglage n'a pas abouti.
  Future<Map<String, Object?>?> send({
    required String groupId,
    required MuteDuration? duration,
  });
}

/// Implémentation HTTP de [GroupMuteSender].
///
/// ```
/// PUT    /groups/:id/mute   { "duration": "8h" | "1w" | "forever" }
/// DELETE /groups/:id/mute
/// → 200 { id, groupId, mutedUntil, mutedForever, muteChangedAt }
/// ```
class HttpGroupMuteSender implements GroupMuteSender {
  HttpGroupMuteSender({ApiClient? client})
      : _client = (client ?? ApiClient.instance).dio;

  final Dio _client;

  @override
  Future<Map<String, Object?>?> send({
    required String groupId,
    required MuteDuration? duration,
  }) async {
    try {
      final response = duration == null
          ? await _client.delete<Object?>('/groups/$groupId/mute')
          : await _client.put<Object?>(
              '/groups/$groupId/mute',
              data: {'duration': duration.wire},
            );
      final data = response.data;
      if (data is! Map) return null;
      return {for (final e in data.entries) e.key.toString(): e.value};
    } on DioException {
      // Réseau, 403 (plus membre), 404 : tous disent la même chose à l'écran —
      // « la sourdine n'a pas pu être réglée ».
      return null;
    }
  }
}

/// Double **inerte** : ne poste rien, ne confirme rien. Défaut des tests et de
/// `AppEnv.useBackend == false` — sans serveur, une sourdine n'aurait aucun
/// effet, et le dire vaut mieux que le simuler.
class InertGroupMuteSender implements GroupMuteSender {
  const InertGroupMuteSender();

  @override
  Future<Map<String, Object?>?> send({
    required String groupId,
    required MuteDuration? duration,
  }) async =>
      null;
}

/// Pose ou lève une sourdine, puis range la ligne confirmée.
class GroupMuteSetter {
  GroupMuteSetter({
    required GroupMuteSender sender,
    required Future<void> Function(Map<String, Object?> row) storeMute,
  })  : _sender = sender,
        _storeMute = storeMute;

  final GroupMuteSender _sender;
  final Future<void> Function(Map<String, Object?> row) _storeMute;

  /// `true` si le serveur a confirmé — la ligne est alors en magasin.
  Future<bool> set({
    required String groupId,
    required MuteDuration? duration,
  }) async {
    final row = await _sender.send(groupId: groupId, duration: duration);
    if (row == null) return false;
    await _storeMute(row);
    return true;
  }
}
