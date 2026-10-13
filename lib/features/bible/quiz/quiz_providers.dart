/// **Les données des quiz** (M6, mobile#204) : quiz publiés, profil d'âge,
/// scores, badges, quiz de la semaine, file d'envoi et voix.
///
/// Les quiz se lisent dans le miroir `bible_quizzes` — un quiz dépublié arrive
/// en rétractation `{ id, deletedAt }` et la synchronisation retire sa ligne.
/// Les scores s'écrivent **seulement** dans `local_bible_quiz_results`
/// (ADR-0026) : brouillon de l'invité (versé par la fusion à la connexion, M2),
/// file d'envoi du membre (`POST /bible/quiz-results` après chaque cycle,
/// purgée quand le miroir `bible_quiz_results` ramène la ligne).
library;

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/api_client.dart';
import '../../../data/local/app_database.dart';
import '../../../state/sync_providers.dart';
import '../data/bible_providers.dart';
import 'quiz.dart';

// ─────────────────────────────────────────────────────────────────────────────
// La voix
// ─────────────────────────────────────────────────────────────────────────────

/// **La lecture à voix haute** du profil enfant. Muette tant que la synthèse
/// vocale (M4, `flutter_tts`) n'est pas branchée : M4 surcharge
/// [quizSpeakerProvider] par son implémentation.
abstract interface class QuizSpeaker {
  Future<void> speak(String text);
  Future<void> stop();
}

final class SilentQuizSpeaker implements QuizSpeaker {
  const SilentQuizSpeaker();

  @override
  Future<void> speak(String text) async {}

  @override
  Future<void> stop() async {}
}

final quizSpeakerProvider =
    Provider<QuizSpeaker>((ref) => const SilentQuizSpeaker());

// ─────────────────────────────────────────────────────────────────────────────
// Le magasin
// ─────────────────────────────────────────────────────────────────────────────

/// Un score joué, local ou synchronisé.
typedef QuizScore = ({String id, int quizId, int score, int total});

enum QuizBadge { firstQuiz, perfect, tenQuizzes }

class QuizStore {
  QuizStore(this.db);

  final AppDatabase db;

  /// Clé stable de `app_settings` : la renommer oublierait le profil choisi.
  static const ageBandKey = 'bible_quiz_age_band';

  Stream<List<Quiz>> watchQuizzes() {
    final q = db.select(db.bibleQuizzes)
      ..where((t) => t.publishedAt.isNotNull())
      ..orderBy([(t) => OrderingTerm.desc(t.publishedAt)]);
    return q
        .watch()
        .map((rows) => rows.map(Quiz.fromRow).whereType<Quiz>().toList());
  }

  Stream<QuizAgeBand?> watchAgeBand() {
    final q = db.select(db.appSettings)..where((s) => s.key.equals(ageBandKey));
    return q.watchSingleOrNull().map((r) => QuizAgeBand.parse(r?.value));
  }

  Future<void> setAgeBand(QuizAgeBand band) =>
      db.into(db.appSettings).insertOnConflictUpdate(
            AppSettingsCompanion.insert(key: ageBandKey, value: band.name),
          );

  /// Mes scores. Un invité ne lit **jamais** le miroir : il pourrait porter
  /// le compte d'une session précédente.
  Stream<List<QuizScore>> watchScores({required bool member}) {
    const local =
        'SELECT id, quiz_id, score, total FROM local_bible_quiz_results';
    const synced = 'SELECT id, quiz_id, score, total FROM bible_quiz_results';
    return db
        .customSelect(
          member ? '$local UNION $synced' : local,
          readsFrom: {db.localBibleQuizResults, db.bibleQuizResults},
        )
        .watch()
        .map(
          (rows) => [
            for (final r in rows)
              (
                id: r.read<String>('id'),
                quizId: r.read<int>('quiz_id'),
                score: r.read<int>('score'),
                total: r.read<int>('total'),
              ),
          ],
        );
  }

  /// Retient une partie finie, à envoyer.
  Future<void> record({
    required int quizId,
    required int score,
    required int total,
    required int durationSeconds,
    DateTime? now,
  }) {
    final at = (now ?? DateTime.now()).toUtc();
    return db.into(db.localBibleQuizResults).insert(
          LocalBibleQuizResultsCompanion.insert(
            id: const Uuid().v7(),
            quizId: quizId,
            score: Value(score),
            total: Value(total),
            durationSeconds: Value(durationSeconds),
            playedAt: at,
            clientUpdatedAt: at,
          ),
        );
  }

  /// **La file d'envoi du membre** : purge ce que le miroir a ramené, puis
  /// envoie le reste. Un refus du serveur (4xx) n'est pas rejoué ; une panne
  /// réseau l'est au cycle suivant (l'envoi est idempotent par `id`).
  Future<void> sendPending(Dio dio) async {
    await db.customStatement(
      'DELETE FROM local_bible_quiz_results '
      'WHERE id IN (SELECT id FROM bible_quiz_results)',
    );
    // `customStatement` ne prévient pas les flux.
    db.notifyUpdates({
      TableUpdate.onTable(db.localBibleQuizResults, kind: UpdateKind.delete),
    });
    final pending = await (db.select(db.localBibleQuizResults)
          ..where((t) => t.dirty.equals(true)))
        .get();
    for (final r in pending) {
      String? error;
      var retry = false;
      try {
        await dio.post<void>('/bible/quiz-results', data: {
          'id': r.id,
          'quizId': r.quizId,
          'score': r.score,
          'total': r.total,
          'durationSeconds': r.durationSeconds ?? 0,
          'playedAt': r.playedAt.toUtc().toIso8601String(),
        });
      } on DioException catch (e) {
        final status = e.response?.statusCode;
        error = '${status ?? e.type.name}: ${e.message}';
        retry = status == null || status >= 500 || status == 429;
      }
      await (db.update(db.localBibleQuizResults)
            ..where((t) => t.id.equals(r.id)))
          .write(
        LocalBibleQuizResultsCompanion(
          dirty: Value(retry),
          lastError: Value(error),
        ),
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Les providers
// ─────────────────────────────────────────────────────────────────────────────

final quizStoreProvider =
    Provider<QuizStore>((ref) => QuizStore(ref.watch(appDatabaseProvider)));

/// Les quiz publiés et jouables, les plus récents d'abord.
final quizzesProvider = StreamProvider<List<Quiz>>(
  (ref) => ref.watch(quizStoreProvider).watchQuizzes(),
);

/// Le profil d'âge du joueur ; `null` tant qu'il n'a pas été choisi.
final quizAgeProfileProvider = StreamProvider<QuizAgeBand?>(
  (ref) => ref.watch(quizStoreProvider).watchAgeBand(),
);

final quizScoresProvider = StreamProvider<List<QuizScore>>(
  (ref) => ref
      .watch(quizStoreProvider)
      .watchScores(member: ref.watch(bibleIsMemberProvider)),
);

/// Le meilleur score de chaque quiz joué.
final quizBestScoresProvider = Provider<Map<int, QuizScore>>((ref) {
  final best = <int, QuizScore>{};
  for (final s in ref.watch(quizScoresProvider).value ?? const []) {
    final b = best[s.quizId];
    if (b == null || s.score * b.total > b.score * s.total) best[s.quizId] = s;
  }
  return best;
});

/// Les badges de quiz gagnés : premier quiz, sans faute, dix quiz différents.
final quizBadgesProvider = Provider<Set<QuizBadge>>((ref) {
  final scores = ref.watch(quizScoresProvider).value ?? const [];
  return {
    if (scores.isNotEmpty) QuizBadge.firstQuiz,
    if (scores.any((s) => s.total > 0 && s.score >= s.total)) QuizBadge.perfect,
    if ({for (final s in scores) s.quizId}.length >= 10) QuizBadge.tenQuizzes,
  };
});

/// **Le quiz de la semaine** (carte de l'accueil, M7) : celui dont la fenêtre
/// de mise en avant contient aujourd'hui, dans le profil d'âge choisi (tous
/// les profils s'il ne l'est pas). Plusieurs : la mise en avant la plus
/// récente.
final featuredQuizProvider = Provider<Quiz?>((ref) {
  final band = ref.watch(quizAgeProfileProvider).value;
  final today = quizDay(DateTime.now());
  final candidates = [
    for (final q in ref.watch(quizzesProvider).value ?? const <Quiz>[])
      if (q.featuredOn(today) && (band == null || q.ageBand == band)) q,
  ]..sort((a, b) => (b.featuredFrom ?? '').compareTo(a.featuredFrom ?? ''));
  return candidates.firstOrNull;
});

/// L'envoi des scores du membre, appelé après chaque cycle réussi
/// (`lib/app.dart`). Rien pour un invité : la fusion à la connexion (M2)
/// versera ses scores.
final quizOutboxProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    if (!ref.read(bibleIsMemberProvider)) return;
    await ref.read(quizStoreProvider).sendPending(ApiClient.instance.dio);
  };
});
