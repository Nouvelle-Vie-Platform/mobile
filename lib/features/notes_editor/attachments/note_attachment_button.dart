/// **Le trombone de la pilule** (N4, mobile#192) : un [PillButton] à passer
/// dans `RichNoteEditor.attachmentSlot`, qui ouvre le menu façon Apple —
/// prendre, choisir, enregistrer, joindre. Pas de scan.
///
/// La pilule disparaît quand l'éditeur perd le focus, ce que fait l'ouverture
/// du menu : tout ce dont le geste a besoin (providers, navigateur, textes) est
/// donc lu **avant** le premier `await`.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../data/messaging/media/media_outbox.dart';
import '../../../data/messaging/media/voice_recorder.dart';
import '../../../data/notes_media/note_media_composer.dart';
import '../../../data/notes_media/note_media_providers.dart';
import '../../../l10n/l10n_extension.dart';
import '../../../models/message_media.dart' show formatMediaDuration;
import '../../../state/chat_media_providers.dart' show voiceRecorderProvider;
import '../../../theme/app_palette.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_typography.dart';
import '../format_pill.dart';

enum _Choice { take, choose, record, file }

class NoteAttachmentButton extends ConsumerWidget {
  const NoteAttachmentButton({
    super.key,
    required this.noteId,
    required this.controller,
    this.focusNode,
  });

  static const Key buttonKey = Key('note_pill_attachment');
  static const Key takeKey = Key('note_attachment_take');
  static const Key chooseKey = Key('note_attachment_choose');
  static const Key recordKey = Key('note_attachment_record');
  static const Key fileKey = Key('note_attachment_file');
  static const Key photoKey = Key('note_attachment_photo');
  static const Key videoKey = Key('note_attachment_video');

  final String noteId;
  final QuillController controller;

  /// Rendu à l'éditeur après le choix, pour que la pilule revienne.
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PillButton(
      key: buttonKey,
      label: context.l10n.noteAttachmentButton,
      onTap: () => _open(context, ref),
      child: const Icon(Icons.attach_file),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final navigator = Navigator.of(context);
    // Le navigateur survit à la pilule, qui disparaît avec le focus.
    final host = navigator.context;
    final composer = ref.read(noteMediaComposerProvider);
    final picker = ref.read(noteMediaPickerProvider);
    final recorder = ref.read(voiceRecorderProvider);
    final outbox = ref.read(noteMediaOutboxProvider);
    final overlay = navigator.overlay!.context.findRenderObject()! as RenderBox;
    final box = context.findRenderObject()! as RenderBox;
    final position = RelativeRect.fromRect(
      box.localToGlobal(Offset.zero, ancestor: overlay) & box.size,
      Offset.zero & overlay.size,
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.xl),
    );

    PopupMenuItem<T> item<T>(Key key, T value, IconData icon, String label) =>
        PopupMenuItem<T>(
          key: key,
          value: value,
          child: Row(
            children: [
              Icon(icon, size: 22),
              const SizedBox(width: AppSpacing.md),
              Flexible(child: Text(label)),
            ],
          ),
        );

    final choice = await showMenu<_Choice>(
      context: host,
      position: position,
      shape: shape,
      items: [
        item(
          takeKey,
          _Choice.take,
          Icons.photo_camera_outlined,
          l.noteAttachmentTakeMedia,
        ),
        item(
          chooseKey,
          _Choice.choose,
          Icons.photo_library_outlined,
          l.noteAttachmentChooseMedia,
        ),
        const PopupMenuDivider(),
        item(
          recordKey,
          _Choice.record,
          Icons.graphic_eq,
          l.noteAttachmentRecordAudio,
        ),
        item(
          fileKey,
          _Choice.file,
          Icons.insert_drive_file_outlined,
          l.noteAttachmentAttachFile,
        ),
      ],
    );

    if (choice == null || !host.mounted) {
      focusNode?.requestFocus();
      return;
    }
    final NoteMediaSource? source;
    switch (choice) {
      case _Choice.choose:
        source = await picker.chooseMedia();
      case _Choice.file:
        source = await picker.pickFile();
      case _Choice.record:
        source = await showModalBottomSheet<NoteMediaSource>(
          context: host,
          isDismissible: false,
          enableDrag: false,
          builder: (_) => NoteAudioRecordSheet(
            recorder: recorder,
            outbox: outbox,
            name: l.noteAttachmentRecordingName,
          ),
        );
      case _Choice.take:
        // L'appareil photo du système ne fait qu'un des deux : on demande
        // lequel.
        final video = await showMenu<bool>(
          context: host,
          position: position,
          shape: shape,
          items: [
            item(photoKey, false, Icons.photo_camera_outlined,
                l.noteAttachmentTakePhoto),
            item(videoKey, true, Icons.videocam_outlined,
                l.noteAttachmentTakeVideo),
          ],
        );
        source = switch (video) {
          true => await picker.recordVideo(),
          false => await picker.takePhoto(),
          null => null,
        };
    }

    focusNode?.requestFocus();
    if (source == null) return;
    unawaited(
      composer.attach(noteId: noteId, controller: controller, source: source),
    );
  }
}

/// **L'enregistrement d'un audio** : il démarre à l'ouverture (la permission
/// du micro est demandée à ce geste, jamais avant), compte le temps, et rend
/// la source à « Terminer » — ou rien à « Annuler ».
///
/// L'enregistreur est celui des vocaux (`VoiceRecorder`, AAC mono) ; le
/// fichier part en `kind: audio`, `audio/mp4` — un fichier pour le serveur,
/// pas un vocal.
class NoteAudioRecordSheet extends StatefulWidget {
  const NoteAudioRecordSheet({
    super.key,
    required this.recorder,
    required this.outbox,
    required this.name,
  });

  static const Key stopKey = Key('note_record_stop');
  static const Key cancelKey = Key('note_record_cancel');

  final VoiceRecorder recorder;
  final MediaOutbox outbox;
  final String name;

  @override
  State<NoteAudioRecordSheet> createState() => _NoteAudioRecordSheetState();
}

class _NoteAudioRecordSheetState extends State<NoteAudioRecordSheet> {
  final Stopwatch _clock = Stopwatch();
  Timer? _ticker;
  bool _denied = false;
  bool _recording = false;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    if (!await widget.recorder.ensurePermission()) {
      if (mounted) setState(() => _denied = true);
      return;
    }
    final path = await widget.outbox.pathFor('${const Uuid().v7()}.m4a');
    await widget.recorder.start(path);
    if (!mounted) {
      await widget.recorder.cancel();
      return;
    }
    _clock.start();
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() {}),
    );
    setState(() => _recording = true);
  }

  Future<void> _finish() async {
    _ticker?.cancel();
    _clock.stop();
    _recording = false;
    final path = await widget.recorder.stop();
    if (!mounted) return;
    Navigator.of(context).pop(
      path == null
          ? null
          : NoteMediaSource(
              kind: 'audio',
              path: path,
              name: widget.name,
              mime: 'audio/mp4',
              durationSeconds: _clock.elapsed.inSeconds.clamp(1, 1 << 30),
            ),
    );
  }

  Future<void> _cancel() async {
    _ticker?.cancel();
    if (_recording) {
      _recording = false;
      await widget.recorder.cancel();
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    if (_recording) unawaited(widget.recorder.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final palette = context.palette;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.graphic_eq, size: 40, color: palette.primary),
            const SizedBox(height: AppSpacing.md),
            Text(
              _denied
                  ? l.noteAttachmentMicDenied
                  : '${l.noteAttachmentRecording}  '
                      '${formatMediaDuration(_clock.elapsed)}',
              textAlign: TextAlign.center,
              style: AppTypography.bodyLarge.copyWith(
                color: palette.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  key: NoteAudioRecordSheet.cancelKey,
                  onPressed: _cancel,
                  child: Text(l.noteAttachmentRecordCancel),
                ),
                const SizedBox(width: AppSpacing.lg),
                FilledButton(
                  key: NoteAudioRecordSheet.stopKey,
                  onPressed: _recording ? _finish : null,
                  child: Text(l.noteAttachmentRecordStop),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
