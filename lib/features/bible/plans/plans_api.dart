/// **Le réseau des plans et des défis** (M5, #203) — membres seulement
/// (guard `api`). Les plans publiés et les défis arrivent par le delta ; ces
/// routes-ci sont celles qu'il ne peut pas porter :
///
/// ```
/// POST   /bible/plan-enrollments          upsert idempotent (S1)
/// DELETE /bible/plan-enrollments/:id      abandon (S1)
/// GET    /bible/challenges/:id/pseudonyms {pseudonyms: [..]}           (S3)
/// POST   /bible/challenges/:id/join       {pseudonym} → 201 | 409      (S3)
/// GET    /bible/challenges/:id/leaderboard {entries, participants, me} (S3)
/// ```
///
/// L'enveloppe `data` est déballée par l'intercepteur d'`ApiClient`. Aucune
/// réponse ne porte de vrai nom : rien ici n'en lit un.
library;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Une ligne du classement : un pseudonyme, jamais un nom.
@immutable
final class LeaderboardEntry {
  const LeaderboardEntry({
    required this.pseudonym,
    required this.onTime,
    required this.streak,
    required this.rank,
  });

  final String pseudonym;
  final int onTime;
  final int streak;
  final int rank;

  static LeaderboardEntry? fromJson(Object? json) {
    if (json is! Map) return null;
    final pseudonym = json['pseudonym'];
    if (pseudonym is! String) return null;
    int n(String k) => (json[k] as num?)?.toInt() ?? 0;
    return LeaderboardEntry(
      pseudonym: pseudonym,
      onTime: n('onTime'),
      streak: n('streak'),
      rank: n('rank'),
    );
  }
}

@immutable
final class Leaderboard {
  const Leaderboard({
    required this.entries,
    required this.participants,
    this.me,
  });

  final List<LeaderboardEntry> entries;
  final int participants;

  /// Ma ligne, `null` si je ne participe pas.
  final LeaderboardEntry? me;
}

/// L'issue d'un `join`.
enum JoinOutcome {
  joined,

  /// 409 `E_BIBLE_PSEUDONYM_TAKEN` : le nom vient d'être pris.
  nameTaken,

  /// 409 `E_BIBLE_CHALLENGE_ALREADY_JOINED`.
  alreadyJoined,
}

class BiblePlansApi {
  BiblePlansApi(this._dio);

  final Dio _dio;

  /// Le dernier échec avalé par la file, pour les tests.
  @visibleForTesting
  Object? lastFailure;

  Future<bool> upsertEnrollment(Map<String, Object?> body) =>
      _send(() => _dio.post<void>('/bible/plan-enrollments', data: body));

  Future<bool> deleteEnrollment(String id) =>
      _send(() => _dio.delete<void>('/bible/plan-enrollments/$id'));

  Future<List<String>> pseudonyms(String challengeId) async {
    final res = await _dio.get<Object?>(
      '/bible/challenges/$challengeId/pseudonyms',
    );
    final data = res.data;
    final list = data is Map ? data['pseudonyms'] : null;
    return list is List ? list.whereType<String>().toList() : const [];
  }

  /// Rejoint [challengeId] sous [pseudonym]. Tout autre échec que les deux
  /// 409 connus remonte en `DioException`.
  Future<JoinOutcome> join(String challengeId, String pseudonym) async {
    try {
      await _dio.post<Object?>(
        '/bible/challenges/$challengeId/join',
        data: {'pseudonym': pseudonym},
      );
      return JoinOutcome.joined;
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        final data = e.response?.data;
        final code = data is Map ? data['code'] : null;
        return code == 'E_BIBLE_CHALLENGE_ALREADY_JOINED'
            ? JoinOutcome.alreadyJoined
            : JoinOutcome.nameTaken;
      }
      rethrow;
    }
  }

  Future<Leaderboard> leaderboard(String challengeId) async {
    final res = await _dio.get<Object?>(
      '/bible/challenges/$challengeId/leaderboard',
    );
    final data = res.data;
    if (data is! Map) return const Leaderboard(entries: [], participants: 0);
    final entries = data['entries'];
    return Leaderboard(
      entries: entries is List
          ? entries.map(LeaderboardEntry.fromJson).nonNulls.toList()
          : const [],
      participants: (data['participants'] as num?)?.toInt() ?? 0,
      me: LeaderboardEntry.fromJson(data['me']),
    );
  }

  Future<bool> _send(Future<void> Function() call) async {
    try {
      await call();
      lastFailure = null;
      return true;
    } on DioException catch (e) {
      // Un 404 sur un DELETE est un succès : la ligne est déjà partie.
      if (e.response?.statusCode == 404 &&
          e.requestOptions.method == 'DELETE') {
        lastFailure = null;
        return true;
      }
      lastFailure = e;
      return false;
    }
  }
}
