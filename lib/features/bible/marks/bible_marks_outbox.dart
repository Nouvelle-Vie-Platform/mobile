/// **La file d'envoi et la fusion à la connexion** (M2, #200, décision 5).
///
/// - **Membre** : après chaque cycle de synchronisation réussi (`app.dart`),
///   [BibleMarksOutbox.run] purge ce que le delta a déjà ramené, puis envoie ce
///   qui reste `dirty` : `POST /bible/marks`, `DELETE /bible/marks/:id`,
///   `PUT /bible/reading-state`, chacun avec `clientUpdatedAt`.
/// - **Invité** : rien ne part, tout reste dans les `local_bible_*`.
/// - **Invité → membre** : tout ce que l'invité a fait part **en un lot**
///   (`POST /bible/import`, 204) — marques, état de lecture, plans, scores —,
///   puis est marqué envoyé ; le delta ramène la fusion.
/// - **Membre → invité** : les `local_bible_*` sont vidées — les données du
///   compte quittent l'appareil (le miroir, lui, n'est jamais lu par un invité).
///
/// **La purge** : une ligne marquée envoyée l'a été pendant une exécution
/// précédente, donc avant le cycle qui vient de réussir — le delta l'a ramenée
/// (ou l'a fondue dans une marque du compte, sous un autre `id`). Elle quitte
/// donc le magasin sans comparaison d'horloge. Les plans et les scores (M5,
/// M6) ne sont **pas** purgés ici : leur file s'en charge.
///
/// Muet sur l'échec : hors ligne, la ligne reste `dirty` et repart au cycle
/// suivant.
library;

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../data/local/app_database.dart';
import '../../../state/auth_providers.dart';
import '../../../state/sync_providers.dart';
import '../data/bible_providers.dart';

class BibleMarksOutbox {
  BibleMarksOutbox(this._db, this._dio, {required this.isMember});

  final AppDatabase _db;
  final Dio _dio;

  /// Lu à chaque exécution : la session peut changer entre deux cycles.
  final bool Function() isMember;

  /// Une fusion d'invité reste à envoyer (posé à l'ouverture de session).
  bool importPending = false;

  Future<void> _queue = Future.value();

  /// Une exécution à la fois : un cycle et une ouverture de session peuvent
  /// tomber ensemble.
  Future<void> run() => _serial(_run);

  Future<void> _serial(Future<void> Function() job) =>
      _queue = _queue.then((_) => job()).catchError((Object e) {
        debugPrint('[bible] file d\'envoi : $e');
      });

  Future<void> _run() async {
    if (!isMember()) return;
    await _purgeSent();
    if (importPending) {
      importPending = !await _import();
      if (importPending) return;
    }
    await _sendMarks();
    await _sendReadingState();
  }

  Future<void> _purgeSent() async {
    await (_db.delete(
      _db.localBibleMarks,
    )..where((r) => r.dirty.equals(false)))
        .go();
    await (_db.delete(
      _db.localBibleReadingState,
    )..where((r) => r.dirty.equals(false)))
        .go();
  }

  Future<void> _sendMarks() async {
    final t = _db.localBibleMarks;
    final rows = await (_db.select(t)
          ..where((r) => r.dirty.equals(true))
          ..orderBy([(r) => OrderingTerm.asc(r.clientUpdatedAt)]))
        .get();
    for (final row in rows) {
      final sent = await _send(
        row.deletedAt != null
            ? _dio.delete<void>('/bible/marks/${row.id}')
            : _dio.post<void>('/bible/marks', data: markPayload(row)),
      );
      if (!sent) continue;
      // Un geste arrivé entre-temps a avancé l'horloge : la ligne repart.
      await (_db.update(t)
            ..where(
              (r) =>
                  r.id.equals(row.id) &
                  r.clientUpdatedAt.equals(row.clientUpdatedAt),
            ))
          .write(const LocalBibleMarksCompanion(dirty: Value(false)));
    }
  }

  Future<void> _sendReadingState() async {
    final t = _db.localBibleReadingState;
    final row = await (_db.select(t)
          ..where((r) => r.dirty.equals(true))
          ..limit(1))
        .getSingleOrNull();
    final payload = row == null ? null : readingStatePayload(row);
    if (row == null || payload == null) return;
    if (await _send(_dio.put<void>('/bible/reading-state', data: payload))) {
      await (_db.update(t)
            ..where(
              (r) =>
                  r.id.equals(row.id) &
                  r.clientUpdatedAt.equals(row.clientUpdatedAt),
            ))
          .write(const LocalBibleReadingStateCompanion(dirty: Value(false)));
    }
  }

  /// `POST /bible/import` : rend vrai quand le lot est parti (ou était vide).
  Future<bool> _import() async {
    final marks = await (_db.select(
      _db.localBibleMarks,
    )..where((r) => r.deletedAt.isNull()))
        .get();
    final state = await (_db.select(
      _db.localBibleReadingState,
    )..limit(1))
        .getSingleOrNull();
    final plans = await (_db.select(
      _db.localBiblePlanEnrollments,
    )..where((r) => r.deletedAt.isNull()))
        .get();
    final quiz = await _db.select(_db.localBibleQuizResults).get();
    final readingState = state == null ? null : readingStatePayload(state);
    final planPayloads = [
      for (final p in plans)
        if (planPayload(p) case final body?) body,
    ];
    if (marks.isEmpty &&
        readingState == null &&
        planPayloads.isEmpty &&
        quiz.isEmpty) {
      return true;
    }
    final sent = await _send(
      _dio.post<void>(
        '/bible/import',
        data: {
          'marks': [for (final m in marks) markPayload(m)],
          'readingState': readingState,
          'planEnrollments': planPayloads,
          'quizResults': [for (final q in quiz) quizPayload(q)],
        },
      ),
    );
    if (!sent) return false;
    await _db.transaction(() async {
      await _db
          .update(_db.localBibleMarks)
          .write(const LocalBibleMarksCompanion(dirty: Value(false)));
      await _db
          .update(_db.localBibleReadingState)
          .write(const LocalBibleReadingStateCompanion(dirty: Value(false)));
      await _db
          .update(_db.localBiblePlanEnrollments)
          .write(const LocalBiblePlanEnrollmentsCompanion(dirty: Value(false)));
      await _db
          .update(_db.localBibleQuizResults)
          .write(const LocalBibleQuizResultsCompanion(dirty: Value(false)));
    });
    return true;
  }

  /// La session est fermée : tout ce que le compte avait sur l'appareil part.
  Future<void> forgetAccount() => _serial(
        () => _db.transaction(() async {
          importPending = false;
          await _db.delete(_db.localBibleMarks).go();
          await _db.delete(_db.localBibleReadingState).go();
          await _db.delete(_db.localBiblePlanEnrollments).go();
          await _db.delete(_db.localBibleQuizResults).go();
        }),
      );

  static Future<bool> _send(Future<void> call) async {
    try {
      await call;
      return true;
    } on DioException catch (e) {
      // Un DELETE en 404 : la marque n'existe déjà plus.
      return e.response?.statusCode == 404 &&
          e.requestOptions.method == 'DELETE';
    }
  }
}

String _utc(DateTime d) => d.toUtc().toIso8601String();

Object? _json(String? raw) {
  if (raw == null) return null;
  try {
    return jsonDecode(raw);
  } on FormatException {
    return null;
  }
}

@visibleForTesting
Map<String, Object?> markPayload(LocalBibleMarkRow m) => {
      'id': m.id,
      'kind': m.kind,
      'book': m.book,
      'chapter': m.chapter,
      'verseFrom': m.verseFrom,
      'verseTo': m.verseTo,
      'color': m.color,
      // #252 : le serveur refuse un décalage sans `versionCode` (422
      // `E_BIBLE_PAYLOAD_INVALID`), et la marque au mot ne vaut que pour sa
      // traduction. Les trois voyagent donc ensemble, ou pas du tout.
      'versionCode': m.versionCode,
      'charFrom': m.charFrom,
      'charTo': m.charTo,
      'clientCreatedAt': _utc(m.clientCreatedAt),
      'clientUpdatedAt': _utc(m.clientUpdatedAt),
    };

/// `null` tant que la position est incomplète (le serveur l'exige).
@visibleForTesting
Map<String, Object?>? readingStatePayload(LocalBibleReadingStateRow s) {
  if (s.versionCode == null || s.book == null || s.chapter == null) return null;
  return {
    'id': s.id,
    'versionCode': s.versionCode,
    'book': s.book,
    'chapter': s.chapter,
    'verse': s.verse,
    'readChapters': _json(s.readChapters) ?? const {},
    'streakDays': s.streakDays,
    'lastReadOn': s.lastReadOn,
    'clientUpdatedAt': _utc(s.clientUpdatedAt),
  };
}

@visibleForTesting
Map<String, Object?>? planPayload(LocalBiblePlanEnrollmentRow p) {
  if (p.startedOn == null) return null;
  return {
    'id': p.id,
    'source': p.source,
    'planCode': p.planCode,
    'planId': p.planId,
    'custom': _json(p.custom),
    'startedOn': p.startedOn,
    'completedDays': _json(p.completedDays) ?? const [],
    'challengeId': p.challengeId,
    'clientCreatedAt': _utc(p.clientCreatedAt),
    'clientUpdatedAt': _utc(p.clientUpdatedAt),
  };
}

@visibleForTesting
Map<String, Object?> quizPayload(LocalBibleQuizResultRow q) => {
      'id': q.id,
      'quizId': q.quizId,
      'score': q.score,
      'total': q.total,
      'durationSeconds': q.durationSeconds ?? 0,
      'playedAt': _utc(q.playedAt),
    };

/// **La file, et l'observateur de session** : `app.dart` le tient vivant
/// (`listenManual`) et appelle `run` après chaque cycle réussi.
final bibleMarksOutboxProvider = Provider<BibleMarksOutbox>((ref) {
  final outbox = BibleMarksOutbox(
    ref.watch(appDatabaseProvider),
    ApiClient.instance.dio,
    isMember: () => ref.read(authProvider).isAuthenticated,
  );
  ref.listen<AuthState>(authProvider, (previous, next) {
    if ((previous?.isGuest ?? false) && next.isAuthenticated) {
      outbox.importPending = true;
      unawaited(outbox.run());
    } else if ((previous?.isAuthenticated ?? false) && next.isGuest) {
      unawaited(outbox.forgetAccount());
    }
  });
  // **Tenu à jour hors du `build`.** Pendant la connexion à la demande (Note
  // sur un verset), le lecteur reste monté sous le parcours de connexion et ses
  // abonnements sont en pause (Riverpod 3, `TickerMode`) : sans auditeur actif,
  // la version active ne se recalculerait qu'au `build` suivant du lecteur, et
  // ce recalcul y planifierait un rafraîchissement — « setState() during
  // build ». L'écouter ici le recalcule au changement de session.
  ref.listen(activeBibleVersionProvider, (_, __) {});
  return outbox;
});
