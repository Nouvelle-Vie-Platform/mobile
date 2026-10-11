import 'package:drift/drift.dart';

import '../local/app_database.dart';

/// **L'outbox des pièces jointes de notes** (N4, mobile#192) : la table
/// `pending_note_media` de N2, et les deux lectures de contenu dont le
/// composeur a besoin.
///
/// Une classe simple sur [AppDatabase], **sans** `@DriftAccessor` : elle
/// n'ajoute ni table ni code généré, et la base n'a pas à la déclarer.
///
/// Les étapes d'une ligne se lisent sur ses colonnes :
///
/// | état | colonnes |
/// |---|---|
/// | en préparation | `mime` nul (image, vidéo pas encore dégradées) |
/// | en envoi | `mime` posé, `key` nulle |
/// | montée | `key` posée (et `thumbKey` pour une vidéo) |
/// | en échec | `error` posé (`MediaSendError.name`, ou `network`) |
///
/// Écritures : `pending_note_media`, et le seul `content` d'une ligne
/// `local_notes` ([patchLocalContent]) quand aucun éditeur n'est ouvert sur la
/// note. `spiritual_notes` n'est que **lue** (ADR-0026).
class NoteMediaDao {
  NoteMediaDao(this._db);

  final AppDatabase _db;

  $PendingNoteMediaTable get _t => _db.pendingNoteMedia;

  Future<void> insert(PendingNoteMediaCompanion row) =>
      _db.into(_t).insertOnConflictUpdate(row);

  Future<PendingNoteMediaRow?> byEmbedId(String embedId) => (_db.select(
        _t,
      )..where((r) => r.embedId.equals(embedId)))
          .getSingleOrNull();

  /// La ligne d'un embed — par `localId` tant qu'il n'est pas monté, par sa
  /// clé ensuite. Suivie par le bloc du fil.
  Stream<PendingNoteMediaRow?> watch({String? embedId, String? key}) {
    if (embedId == null && key == null) return Stream.value(null);
    return (_db.select(_t)
          ..where(
            (r) => embedId != null
                ? r.embedId.equals(embedId)
                : r.key.equals(key!),
          )
          ..limit(1))
        .watchSingleOrNull();
  }

  Future<PendingNoteMediaRow?> byKey(String key) => (_db.select(_t)
        ..where((r) => r.key.equals(key))
        ..limit(1))
      .getSingleOrNull();

  Future<List<PendingNoteMediaRow>> all() => _db.select(_t).get();

  Future<void> patch(String embedId, PendingNoteMediaCompanion patch) =>
      (_db.update(_t)..where((r) => r.embedId.equals(embedId))).write(patch);

  Future<void> markError(String embedId, String? error) =>
      patch(embedId, PendingNoteMediaCompanion(error: Value(error)));

  Future<void> remove(String embedId) =>
      (_db.delete(_t)..where((r) => r.embedId.equals(embedId))).go();

  /// Le brouillon (`local_notes.content`) de [noteId], `null` sans brouillon.
  Future<({String? content})?> localContent(String noteId) async {
    final row = await (_db.select(
      _db.localNotes,
    )..where((n) => n.id.equals(noteId)))
        .getSingleOrNull();
    return row == null ? null : (content: row.content);
  }

  /// Le contenu synchronisé (`spiritual_notes.content`) de [noteId].
  Future<String?> syncedContent(String noteId) async {
    final row = await (_db.select(
      _db.spiritualNotes,
    )..where((n) => n.id.equals(noteId)))
        .getSingleOrNull();
    return row?.content;
  }

  /// Réécrit le `content` du brouillon de [noteId] et le rend à envoyer.
  /// Rend `false` s'il n'y a pas de brouillon.
  Future<bool> patchLocalContent(
    String noteId,
    String content,
    DateTime now,
  ) async {
    final count = await (_db.update(
      _db.localNotes,
    )..where((n) => n.id.equals(noteId)))
        .write(
      LocalNotesCompanion(
        content: Value(content),
        clientUpdatedAt: Value(now),
        dirty: const Value(true),
      ),
    );
    return count > 0;
  }
}
