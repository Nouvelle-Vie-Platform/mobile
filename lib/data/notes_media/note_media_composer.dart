/// **Joindre un média à une note** (N4, mobile#192) — le patron de
/// `GroupMediaComposer`, sans le temps 3 : la clé part dans l'embed, et c'est
/// le `POST /notes` de la note qui la cite.
///
/// 1. **l'embed tout de suite**, au curseur, avec `localId` et sans clé
///    (voir `note_attachment_content.dart`) ;
/// 2. la source **recopiée** dans l'outbox `note_outbox/` et la ligne
///    `pending_note_media` écrite ;
/// 3. **préparer** : image ≤ 1600 px JPEG q80 EXIF retiré ; vidéo 720p +
///    vignette, durée **sondée avant** la compression et refusée au-delà du
///    plafond servi ; audio et document tels quels ;
/// 4. **le ticket**, et `size ≤ maxBytes` vérifié **avant** le `PUT` ;
/// 5. le `PUT` (et celui de la vignette) ;
/// 6. `key` / `thumbKey` posées dans l'embed, puis l'enregistrement du
///    brouillon.
///
/// Chaque étape franchie est écrite dans la ligne (fichier préparé, clé
/// montée) : [resendPending], appelé après chaque cycle de synchronisation
/// réussi, reprend où l'on s'était arrêté. Une cause **définitive** (trop
/// lourd, trop long, type refusé, illisible) reste affichée sur le bloc et
/// n'est pas rejouée — seul « Réessayer » ([retry]) le fait.
library;

import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/widgets.dart' show TextSelection;
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:uuid/uuid.dart';

import '../../features/notes_editor/note_content.dart' show noteAttachmentEmbed;
import '../../models/message_media.dart' show MediaSendError;
import '../local/app_database.dart';
import '../messaging/media/group_media_transport.dart';
import '../messaging/media/media_mime.dart' show fileExtension;
import '../messaging/media/media_outbox.dart';
import '../messaging/media/media_preparer.dart';
import 'note_attachment_content.dart';
import 'note_media_dao.dart';
import 'note_media_transport.dart';

/// La cause enregistrée d'une panne **réseau** : elle se rejoue.
const String kNoteMediaNetworkError = 'network';

/// Ce que l'utilisateur a choisi.
class NoteMediaSource {
  const NoteMediaSource({
    required this.kind,
    required this.path,
    required this.name,
    this.mime,
    this.sizeBytes,
    this.durationSeconds,
  });

  /// `image | video | audio | document`.
  final String kind;
  final String path;
  final String name;

  /// Connu pour un audio ou un document ; fixé à la préparation sinon.
  final String? mime;
  final int? sizeBytes;
  final int? durationSeconds;

  /// Audio et document partent tels quels : leur type est déjà le bon.
  bool get readyAsIs => kind == 'audio' || kind == 'document';
}

class NoteMediaComposer {
  NoteMediaComposer({
    required NoteMediaDao dao,
    required NoteMediaTransport transport,
    required MediaPreparer preparer,
    required MediaOutbox outbox,
    required Future<void> Function() resendNotes,
    DateTime Function()? now,
    String Function()? mintId,
  })  : _dao = dao,
        _transport = transport,
        _preparer = preparer,
        _outbox = outbox,
        _resendNotes = resendNotes,
        _now = now ?? DateTime.now,
        _mintId = mintId ?? (() => const Uuid().v7());

  final NoteMediaDao _dao;
  final NoteMediaTransport _transport;
  final MediaPreparer _preparer;
  final MediaOutbox _outbox;
  final Future<void> Function() _resendNotes;
  final DateTime Function() _now;
  final String Function() _mintId;

  /// Les éditeurs ouverts, par note : un embed s'y patche dans le contrôleur
  /// (l'écran enregistre lui-même), sinon dans `local_notes`.
  final Map<String, QuillController> _editors = {};
  final Set<String> _inFlight = {};

  /// L'écran d'édition de [noteId] s'ouvre (`initState`).
  void attachEditor(String noteId, QuillController controller) =>
      _editors[noteId] = controller;

  /// … et se ferme (`dispose`).
  void detachEditor(String noteId, QuillController controller) {
    if (identical(_editors[noteId], controller)) _editors.remove(noteId);
  }

  /// **Joint [source] à la note [noteId]**, au curseur de [controller]. Rend
  /// l'identifiant de l'embed. L'embed paraît avant le premier `await` :
  /// l'appelant peut ne pas attendre la fin (`unawaited`).
  Future<String> attach({
    required String noteId,
    required QuillController controller,
    required NoteMediaSource source,
  }) async {
    final id = _mintId();
    _editors[noteId] = controller;
    insertAttachmentEmbed(controller, {
      'kind': source.kind,
      'name': source.name,
      if (source.mime != null) 'mime': source.mime,
      if (source.sizeBytes != null) 'size': source.sizeBytes,
      if (source.durationSeconds != null) 'duration': source.durationSeconds,
      kNoteAttachmentLocalId: id,
    });

    var path = source.path;
    try {
      final ext = fileExtension(path);
      path = await _outbox.adopt(path, '$id-src.${ext.isEmpty ? 'bin' : ext}');
    } on Object {
      // Pas de copie possible : on monte depuis la source, tant qu'elle vit.
    }
    int? size = source.sizeBytes;
    if (size == null) {
      try {
        size = await File(path).length();
      } on FileSystemException {
        size = null;
      }
    }
    await _dao.insert(
      PendingNoteMediaCompanion.insert(
        noteId: noteId,
        embedId: id,
        kind: source.kind,
        localPath: path,
        mime: Value(source.readyAsIs ? source.mime : null),
        size: Value(size),
        duration: Value(source.durationSeconds),
      ),
    );
    await deliver(id, manual: true);
    return id;
  }

  /// « Réessayer » sur le bloc : rejoue même une cause définitive.
  Future<bool> retry(String embedId) => deliver(embedId, manual: true);

  /// **Envoie l'embed [embedId]**, en reprenant à l'étape atteinte. Rend
  /// `true` si la clé est posée dans l'embed (ou l'était déjà).
  Future<bool> deliver(String embedId, {bool manual = false}) async {
    if (!_inFlight.add(embedId)) return false;
    try {
      var row = await _dao.byEmbedId(embedId);
      if (row == null) return false;
      if (!manual && (MediaSendError.parse(row.error)?.isPermanent ?? false)) {
        return false;
      }
      if (row.error != null) await _dao.markError(embedId, null);

      row = await _prepare(row);
      row = await _upload(row);
      final patched = await _patchEmbed(row.noteId, embedId, {
        'key': row.key,
        'thumbKey': row.thumbKey,
        'mime': row.mime,
        'size': row.size,
      });
      if (patched) await _resendNotes();
      return true;
    } on _Refused catch (refusal) {
      await _dao.markError(embedId, refusal.error.name);
      return false;
    } on GroupMediaTransportException catch (error) {
      await _dao.markError(
        embedId,
        _causeOf(error.code)?.name ?? kNoteMediaNetworkError,
      );
      return false;
    } on MediaPreparationException {
      await _dao.markError(embedId, MediaSendError.unreadable.name);
      return false;
    } on FileSystemException {
      await _dao.markError(embedId, MediaSendError.missingFile.name);
      return false;
    } finally {
      _inFlight.remove(embedId);
    }
  }

  /// **Après chaque cycle de synchronisation réussi** : oublie ce que le
  /// serveur a ramené et ce que l'utilisateur a effacé, reprend le reste,
  /// puis vide l'outbox de ce qu'aucune ligne ne cite.
  Future<void> resendPending() async {
    for (final row in await _dao.all()) {
      if (_inFlight.contains(row.embedId)) continue;
      final local = await _dao.localContent(row.noteId);
      final synced = await _dao.syncedContent(row.noteId);
      final key = row.key;

      // Livrée : la note synchronisée cite la clé, aucun brouillon n'attend.
      if (key != null &&
          contentCites(synced, key: key) &&
          !contentCites(local?.content, embedId: row.embedId)) {
        await _dao.remove(row.embedId);
        continue;
      }
      // Effacée : le contenu courant ne la cite plus. Pas quand un éditeur
      // est ouvert — son brouillon peut avoir 300 ms de retard.
      final current = local?.content ?? synced;
      if (!_editors.containsKey(row.noteId) &&
          current != null &&
          !contentCites(current, embedId: row.embedId, key: key)) {
        await _dao.remove(row.embedId);
        continue;
      }
      await deliver(row.embedId);
    }
    await _outbox.sweep({
      for (final row in await _dao.all()) ...[
        row.localPath,
        if (row.thumbPath != null) row.thumbPath!,
      ],
    });
  }

  /// Dégrade une image ou une vidéo, une fois : le type posé dit « prêt ».
  Future<PendingNoteMediaRow> _prepare(PendingNoteMediaRow row) async {
    if (row.mime != null) return row;
    final source = row.localPath;
    if (!File(source).existsSync()) {
      throw const FileSystemException('source absente');
    }
    final id = row.embedId;

    if (row.kind == 'image') {
      final prepared = await _preparer.prepareImage(
        source,
        await _outbox.pathFor('$id.jpg'),
      );
      // L'embed d'abord : si l'application meurt entre les deux, la ligne
      // sans type refait la préparation, qui est idempotente.
      await _patchEmbed(row.noteId, id, {
        'mime': 'image/jpeg',
        'size': prepared.sizeBytes,
        'width': prepared.width,
        'height': prepared.height,
      });
      await _dao.patch(
        id,
        PendingNoteMediaCompanion(
          localPath: Value(prepared.path),
          mime: const Value('image/jpeg'),
          size: Value(prepared.sizeBytes),
        ),
      );
    } else if (row.kind == 'video') {
      // Le plafond de durée est **servi** : lu avant de compresser, pour ne
      // pas dépenser la batterie sur une vidéo qu'on refuserait.
      final limits = await _transport.openUpload(
        kind: 'video',
        contentType: 'video/mp4',
      );
      final probe = await _preparer.probeVideo(source);
      final max = limits.maxDurationSeconds;
      if (max != null && probe.durationSeconds > max) {
        throw const _Refused(MediaSendError.tooLong);
      }
      final prepared = await _preparer.prepareVideo(source);
      final path = await _outbox.adopt(prepared.path, '$id.mp4');
      final thumb = prepared.thumbPath == null
          ? null
          : await _outbox.adopt(prepared.thumbPath!, '$id-thumb.jpg');
      await _patchEmbed(row.noteId, id, {
        'mime': 'video/mp4',
        'size': prepared.sizeBytes,
        'duration': prepared.durationSeconds,
        'width': prepared.width,
        'height': prepared.height,
      });
      await _dao.patch(
        id,
        PendingNoteMediaCompanion(
          localPath: Value(path),
          thumbPath: Value(thumb),
          mime: const Value('video/mp4'),
          size: Value(prepared.sizeBytes),
          duration: Value(prepared.durationSeconds),
        ),
      );
    }
    return (await _dao.byEmbedId(id))!;
  }

  /// Monte le fichier (et la vignette d'une vidéo), une fois : la clé posée
  /// dit « monté ».
  Future<PendingNoteMediaRow> _upload(PendingNoteMediaRow row) async {
    final id = row.embedId;
    final video = row.kind == 'video';

    if (row.key == null) {
      final path = row.localPath;
      if (!File(path).existsSync()) {
        throw const FileSystemException('fichier absent');
      }
      final ticket = await _transport.openUpload(
        kind: row.kind,
        // Le type d'un audio ou d'un document est **déclaré** ; celui d'une
        // image est le premier de la politique (JPEG).
        contentType:
            video ? 'video/mp4' : (row.kind == 'image' ? null : row.mime),
      );

      // **Les bornes, avant la montée** : refusé ici, sans dépenser les données.
      final size = await File(path).length();
      if (size > ticket.maxBytes) throw const _Refused(MediaSendError.tooLarge);
      final max = ticket.maxDurationSeconds;
      final duration = row.duration;
      if (max != null && duration != null && duration > max) {
        throw const _Refused(MediaSendError.tooLong);
      }

      await _transport.upload(ticket, path);
      await _dao.patch(
        id,
        PendingNoteMediaCompanion(key: Value(ticket.key), size: Value(size)),
      );
    }

    final thumbPath = row.thumbPath;
    if (video &&
        thumbPath != null &&
        row.thumbKey == null &&
        File(thumbPath).existsSync()) {
      final ticket = await _transport.openUpload(kind: 'thumbnail');
      // Une vignette trop lourde est omise, pas bloquante.
      if (await File(thumbPath).length() <= ticket.maxBytes) {
        await _transport.upload(ticket, thumbPath);
        await _dao.patch(
          id,
          PendingNoteMediaCompanion(thumbKey: Value(ticket.key)),
        );
      }
    }
    return (await _dao.byEmbedId(id))!;
  }

  /// Patche l'embed : dans l'éditeur ouvert s'il y en a un, sinon dans le
  /// brouillon. Rend `false` si l'embed n'existe plus (effacé, déjà patché).
  Future<bool> _patchEmbed(
    String noteId,
    String embedId,
    Map<String, Object?> fields,
  ) async {
    final editor = _editors[noteId];
    if (editor != null) {
      try {
        return patchEmbedInController(editor, embedId, fields);
      } on Object {
        // Contrôleur détruit sans `detachEditor` : on passe au brouillon.
        _editors.remove(noteId);
      }
    }
    final local = await _dao.localContent(noteId);
    if (local == null) return false;
    final patched = patchAttachmentJson(local.content, embedId, fields);
    if (patched == null) return false;
    return _dao.patchLocalContent(noteId, patched, _now());
  }

  static MediaSendError? _causeOf(String? code) => switch (code) {
        'E_NOTE_MEDIA_TOO_LARGE' => MediaSendError.tooLarge,
        'E_NOTE_MEDIA_TOO_LONG' => MediaSendError.tooLong,
        'E_NOTE_MEDIA_TYPE_NOT_ALLOWED' => MediaSendError.typeNotAllowed,
        _ => null,
      };
}

/// **Insère l'embed** `nvAttachment` [data] au curseur de [controller], seul
/// sur sa ligne, et place le curseur sur la ligne suivante.
void insertAttachmentEmbed(
  QuillController controller,
  Map<String, Object?> data,
) {
  final selection = controller.selection;
  final end = controller.document.length - 1;
  final index = selection.isValid ? selection.start.clamp(0, end) : end;
  final length = selection.isValid ? (selection.end.clamp(0, end) - index) : 0;
  final plain = controller.document.toPlainText();
  final atLineStart = index == 0 || plain[index - 1] == '\n';

  final delta = Delta();
  if (index > 0) delta.retain(index);
  if (length > 0) delta.delete(length);
  if (!atLineStart) delta.insert('\n');
  delta
    ..insert({noteAttachmentEmbed: data})
    ..insert('\n');
  controller.compose(delta, controller.selection, ChangeSource.local);
  controller.updateSelection(
    TextSelection.collapsed(offset: index + (atLineStart ? 2 : 3)),
    ChangeSource.local,
  );
}

/// **Patche l'embed [embedId]** dans le document de [controller] (remplacé à
/// la même place). Rend `false` s'il n'y est plus.
bool patchEmbedInController(
  QuillController controller,
  String embedId,
  Map<String, Object?> fields,
) {
  var offset = 0;
  for (final op in controller.document.toDelta().toList()) {
    final data = attachmentOf({'insert': op.data});
    if (data != null && data[kNoteAttachmentLocalId] == embedId) {
      final delta = Delta();
      if (offset > 0) delta.retain(offset);
      delta
        ..delete(1)
        ..insert({noteAttachmentEmbed: mergeAttachment(data, fields)});
      controller.compose(delta, controller.selection, ChangeSource.local);
      return true;
    }
    offset += op.length ?? 0;
  }
  return false;
}

/// Un refus **côté téléphone**, avant toute montée.
class _Refused implements Exception {
  const _Refused(this.error);

  final MediaSendError error;
}
