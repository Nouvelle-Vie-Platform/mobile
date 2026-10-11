/// **L'auto-sauvegarde d'une note** (#190) : chaque changement écrit le
/// brouillon dans `local_notes`, l'envoi (`POST /notes`) part **2 s après le
/// dernier changement** et à la sortie de l'écran, et ce qui est resté `dirty`
/// repart après chaque cycle de synchronisation réussi ([resendDirty], câblé
/// comme `resendUnconfirmed`).
///
/// Pas de bouton Enregistrer : la coche de la maquette ferme le clavier.
library;

import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../local/app_database.dart';
import '../local/notes_dao.dart';
import 'notes_repository.dart';

/// L'état courant d'un brouillon, tel que l'éditeur le tient.
@immutable
class NoteDraft {
  const NoteDraft({
    required this.id,
    this.title,
    this.body = '',
    this.content,
    this.categoryId,
    this.pinned = false,
    this.teachingId,
    required this.clientCreatedAt,
  });

  final String id;
  final String? title;
  final String body;
  final String? content;
  final String? categoryId;
  final bool pinned;
  final String? teachingId;
  final DateTime clientCreatedAt;

  bool get isEmpty => (title ?? '').trim().isEmpty && body.trim().isEmpty;

  NoteDraft copyWith({
    String? title,
    String? body,
    String? content,
    String? categoryId,
    bool clearCategory = false,
    bool? pinned,
  }) =>
      NoteDraft(
        id: id,
        title: title ?? this.title,
        body: body ?? this.body,
        content: content ?? this.content,
        categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
        pinned: pinned ?? this.pinned,
        teachingId: teachingId,
        clientCreatedAt: clientCreatedAt,
      );
}

/// Un enregistreur **par écran d'édition** : il connaît un seul brouillon.
class NoteDraftSaver {
  NoteDraftSaver({
    required NotesDao dao,
    required NotesRepository repository,
    this.debounce = const Duration(seconds: 2),
    DateTime Function()? now,
  })  : _dao = dao,
        _repository = repository,
        _now = now ?? DateTime.now;

  final NotesDao _dao;
  final NotesRepository _repository;
  final Duration debounce;
  final DateTime Function() _now;

  Timer? _timer;
  NoteDraft? _draft;
  Future<void>? _inFlight;

  /// Un changement : la ligne locale tout de suite, l'envoi dans [debounce].
  ///
  /// Un brouillon **vide** n'est jamais envoyé (piège 6 : `body.minLength`
  /// donne un 422, et une tombstone n'est pas une solution) — mais il est
  /// écrit, pour que la frappe suivante reparte d'une ligne existante.
  Future<void> update(NoteDraft draft) async {
    _draft = draft;
    await _dao.saveDraft(_companion(draft, _now()));
    _timer?.cancel();
    _timer = draft.isEmpty ? null : Timer(debounce, () => unawaited(flush()));
  }

  /// Envoie maintenant ce qui est en attente. Rend *parti* / *pas parti*
  /// (ou vrai quand il n'y avait rien à envoyer).
  Future<bool> flush() async {
    _timer?.cancel();
    _timer = null;
    final draft = _draft;
    if (draft == null || draft.isEmpty) return true;
    final sent = _send(draft.id);
    _inFlight = sent.then((_) {});
    return sent;
  }

  /// **La sortie de l'écran** : un brouillon vide s'efface sans partir, les
  /// autres partent tout de suite.
  Future<void> close() async {
    _timer?.cancel();
    _timer = null;
    final draft = _draft;
    if (draft == null) return;
    if (draft.isEmpty) {
      await _dao.deleteLocal(draft.id);
      return;
    }
    await flush();
    await _inFlight;
  }

  /// **Le renvoi après un cycle réussi** : tout ce qui est resté `dirty`, dans
  /// l'ordre des frappes, puis la purge de ce que le delta a ramené. Statique
  /// parce qu'aucun écran n'est ouvert à ce moment-là.
  static Future<void> resendDirty(
    NotesDao dao,
    NotesRepository repository,
  ) async {
    await dao.purgeReconciled();
    for (final row in await dao.dirtyNotes()) {
      if (row.body.trim().isEmpty && (row.title ?? '').trim().isEmpty) {
        continue;
      }
      await _post(dao, repository, row);
    }
  }

  Future<bool> _send(String id) async {
    final row = await _dao.localNote(id);
    if (row == null || !row.dirty) return true;
    return _post(_dao, _repository, row);
  }

  static Future<bool> _post(
    NotesDao dao,
    NotesRepository repository,
    LocalNoteRow row,
  ) async {
    final sent = await repository.upsertNote(NoteUpsert(
      id: row.id,
      title: row.title,
      content: row.content,
      body: row.body,
      categoryId: row.categoryId,
      pinned: row.pinned,
      teachingId: row.teachingId,
      clientCreatedAt: row.clientCreatedAt,
      clientUpdatedAt: row.clientUpdatedAt,
    ));
    if (sent) {
      await dao.markSent(row.id, row.clientUpdatedAt);
    } else {
      await dao.markFailed(row.id, 'send failed');
    }
    return sent;
  }

  static LocalNotesCompanion _companion(NoteDraft draft, DateTime now) =>
      LocalNotesCompanion.insert(
        id: draft.id,
        teachingId: Value(draft.teachingId),
        title: Value(draft.title),
        content: Value(draft.content),
        body: Value(draft.body),
        categoryId: Value(draft.categoryId),
        pinned: Value(draft.pinned),
        clientCreatedAt: draft.clientCreatedAt,
        clientUpdatedAt: now,
        dirty: const Value(true),
        lastError: const Value(null),
      );
}
