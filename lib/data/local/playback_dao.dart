import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import 'app_database.dart';
import 'tables/playback_tables.dart';

part 'playback_dao.g.dart';

/// **Où reprendre**, une fois les deux sources départagées.
///
/// [source] n'a aucun effet sur le rendu : elle est là pour le diagnostic et
/// pour les tests, parce qu'une reprise qui vient de la mauvaise source est un
/// bug silencieux — le fidèle repart quelques minutes trop tôt et met ça sur le
/// compte de l'application.
@immutable
class PlaybackResume {
  const PlaybackResume({
    required this.contentId,
    required this.progressId,
    required this.positionSeconds,
    required this.completed,
    required this.source,
  });

  final String contentId;

  /// L'UUIDv7 sous lequel ce contenu se rapporte. Celui de la ligne répliquée
  /// dès qu'elle existe — c'est l'identité que le serveur connaît —, sinon
  /// celui que ce client a frappé.
  final String progressId;

  final int positionSeconds;

  /// Une fois vrai, on cesse de rapporter la position de ce contenu.
  final bool completed;

  final PlaybackResumeSource source;

  Duration get position => Duration(seconds: positionSeconds);
}

/// Laquelle des deux tables a fourni la position.
enum PlaybackResumeSource {
  /// La position à chaud, écrite par le lecteur de cet appareil.
  local,

  /// La ligne répliquée, arrivée par `GET /sync/playback_progress` — donc
  /// possiblement d'un autre appareil, ou d'avant une réinstallation.
  synced,
}

/// **Les deux tables de la reprise de lecture, et rien d'autre.**
///
/// Un DAO par domaine, comme `MediathequeDao`, `GatheringDao` et
/// `AnnouncementDao`. Celui-ci a une particularité que les trois autres n'ont
/// pas : il **écrit**. Il n'écrit cependant que dans
/// [LocalPlaybackPositions] — la table locale seule —, jamais dans
/// [PlaybackProgress], qui est une collection répliquée et n'appartient qu'à la
/// synchronisation.
///
/// **Aucune méthode de suppression n'existe ici, et c'est le garde-fou.** Le
/// client n'efface jamais de sa propre initiative une ligne d'une collection
/// répliquée (CLAUDE.md, § moteur de synchronisation, règle 4), et
/// `playback_progress` est le cas qui a motivé la règle : effacer une
/// progression la perd **sans recours**, le curseur étant déjà passé devant
/// elle — elle ne sera plus jamais livrée. Un enseignement rétracté, lui, se
/// republie couramment.
@DriftAccessor(tables: [PlaybackProgress, LocalPlaybackPositions])
class PlaybackDao extends DatabaseAccessor<AppDatabase>
    with _$PlaybackDaoMixin {
  PlaybackDao(super.db);

  /// **Où reprendre ce contenu**, ou `null` si personne n'en sait rien.
  ///
  /// Se lit **une fois, à l'ouverture** — en `Future` et non en `Stream`, seule
  /// entorse du dépôt à « un domaine adossé au magasin se lit en `Stream` ».
  /// La raison est propre à cette donnée : un flux ferait bouger la tête de
  /// lecture sous les pieds de quelqu'un qui écoute, à chaque cycle de
  /// synchronisation. Une reprise est une question qu'on pose au moment
  /// d'ouvrir, pas un état à observer.
  ///
  /// **La plus récente des deux gagne.** La locale est en général en avance —
  /// elle est écrite en continu, la répliquée a fait l'aller-retour serveur —,
  /// mais pas toujours : le fidèle qui a écouté trente minutes sur son second
  /// téléphone doit reprendre à trente minutes en rouvrant le premier, où la
  /// ligne locale s'est arrêtée à dix. Prendre systématiquement la plus grande
  /// **position** aurait cet effet-là aussi, mais renverrait quelqu'un qui
  /// réécoute un prêche depuis le début droit à la fin.
  ///
  /// Réserve assumée : les deux horloges ne sont pas la même — l'appareil pour
  /// la locale, le serveur pour la répliquée. Un téléphone dont l'horloge
  /// dérive de plusieurs minutes peut préférer la mauvaise source. Le prix
  /// d'une erreur est de reprendre au mauvais endroit d'un contenu qu'on a de
  /// toute façon commencé ; celui d'un identifiant de progression choisi de
  /// travers serait bien plus élevé, et c'est pourquoi [PlaybackResume.progressId]
  /// ne dépend **pas** de cette comparaison.
  Future<PlaybackResume?> resumeFor(String contentId) async {
    final synced = await _syncedRowFor(contentId);
    final local = await _localRowFor(contentId);

    if (synced == null && local == null) return null;

    // L'identité, elle, ne se départage pas à l'horloge : dès que le serveur
    // connaît une ligne pour ce contenu, c'est **son** `id` qu'il faut
    // rapporter. En frapper un second créerait une seconde ligne — ou un 409 le
    // jour où le rapprochement par `(userId, teachingId)` disparaîtrait.
    final progressId = synced?.id ?? local!.progressId;

    if (local == null) return _fromSynced(synced!, progressId);
    if (synced == null) return _fromLocal(local, progressId);

    // `updatedAt` est nullable côté serveur : une ligne répliquée qui n'en
    // porte pas ne peut pas prétendre être la plus fraîche.
    final syncedAt = synced.updatedAt;
    final localWins = syncedAt == null || !syncedAt.isAfter(local.updatedAt);

    return localWins
        ? _fromLocal(local, progressId)
        : _fromSynced(synced, progressId);
  }

  /// **Écrit la position à chaud.** L'unique écriture de ce DAO, et elle ne
  /// touche que la table locale seule.
  ///
  /// Gratuite et continue : c'est un remplacement d'une ligne unique, sans
  /// jeton d'écriture ni curseur à tenir. Seul l'appel **réseau** est espacé
  /// (`playback_progress_recorder.dart`) — pas celui-ci, qui est justement ce
  /// qui sauve la place d'un fidèle dont l'application est tuée par le système.
  Future<void> saveLocalPosition({
    required String contentId,
    required String progressId,
    required int positionSeconds,
    bool completed = false,
    DateTime? at,
  }) async {
    await into(localPlaybackPositions).insert(
      LocalPlaybackPositionsCompanion.insert(
        contentId: contentId,
        progressId: progressId,
        positionSeconds: positionSeconds,
        completed: Value(completed),
        updatedAt: at?.toUtc() ?? DateTime.now().toUtc(),
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  /// La ligne **répliquée** d'un contenu, telle que la synchronisation l'a
  /// laissée. Exposée pour les tests et le diagnostic ; la lecture normale
  /// passe par [resumeFor].
  @visibleForTesting
  Future<PlaybackProgressRow?> syncedProgressFor(String contentId) =>
      _syncedRowFor(contentId);

  // ───────────────────────────────────────────────────────────────────────────
  // Rouages
  // ───────────────────────────────────────────────────────────────────────────

  /// `limit(1)` plutôt que `getSingleOrNull` : la collection est `private` et
  /// unique par `(user_id, teaching_id)` côté serveur, donc une seule ligne est
  /// attendue — mais une seconde ligne arrivée on ne sait comment doit coûter
  /// une reprise imprécise, pas une exception en pleine ouverture d'écran.
  Future<PlaybackProgressRow?> _syncedRowFor(String contentId) {
    return (select(playbackProgress)
          ..where((t) => t.teachingId.equals(contentId))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<LocalPlaybackPositionRow?> _localRowFor(String contentId) {
    return (select(localPlaybackPositions)
          ..where((t) => t.contentId.equals(contentId)))
        .getSingleOrNull();
  }

  PlaybackResume _fromSynced(PlaybackProgressRow row, String progressId) {
    return PlaybackResume(
      contentId: row.teachingId,
      progressId: progressId,
      positionSeconds: row.positionSeconds,
      completed: row.completed,
      source: PlaybackResumeSource.synced,
    );
  }

  PlaybackResume _fromLocal(LocalPlaybackPositionRow row, String progressId) {
    return PlaybackResume(
      contentId: row.contentId,
      progressId: progressId,
      positionSeconds: row.positionSeconds,
      completed: row.completed,
      source: PlaybackResumeSource.local,
    );
  }
}
