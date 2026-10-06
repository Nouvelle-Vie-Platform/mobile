import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/messaging/media/chat_media_picker.dart';
import '../../../data/messaging/media/group_media_composer.dart';
import '../../../data/messaging/media/media_mime.dart';
import '../../../data/messaging/media/voice_recording_controller.dart';
import '../../../data/players/chat_audio_player.dart';
import '../../../data/repositories/group_message_sender.dart'
    show mintClientMessageId;
import '../../../l10n/l10n_extension.dart';
import '../../../state/chat_media_providers.dart';
import '../../../theme/app_palette.dart';
import '../message_input_bar.dart';
import 'attachment_sheet.dart';
import 'media_caption_screen.dart';
import 'voice_record_button.dart';

/// **La barre de saisie avec ses médias** (M4, #143 — reprend #98).
///
/// Elle enveloppe `MessageInputBar` (texte, envoi) et lui donne ce que M1b
/// lui avait retiré parce que c'était inerte : le **trombone** (la feuille des
/// pièces jointes), l'**appareil photo**, et le **micro** — qui prend la place
/// du bouton d'envoi tant que le champ est vide, comme WhatsApp.
///
/// Chaque média part par `GroupMediaComposer` **sans bloquer l'écran** :
/// l'écho paraît au fil, la montée suit.
class ChatComposer extends ConsumerStatefulWidget {
  const ChatComposer({
    super.key,
    required this.groupId,
    required this.hintText,
    required this.controller,
    required this.onSend,
    this.focusNode,
  });

  final String groupId;
  final String hintText;
  final TextEditingController controller;
  final ValueChanged<String> onSend;

  /// Le focus du champ (M2) : glisser pour répondre y place le curseur.
  final FocusNode? focusNode;

  @override
  ConsumerState<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends ConsumerState<ChatComposer> {
  // Créés dans `initState`, jamais paresseusement : `dispose` les touche.
  late final VoiceRecordingController _recording;
  late final ChatAudioController _audio;

  @override
  void initState() {
    super.initState();
    _audio = ref.read(chatAudioControllerProvider);
    final outbox = ref.read(mediaOutboxProvider);
    _recording = VoiceRecordingController(
      recorder: ref.read(voiceRecorderProvider),
      newPath: () => outbox.pathFor('voice-${mintClientMessageId()}.m4a'),
    )..onAutoStop = _sendVoice;
  }

  @override
  void dispose() {
    // Quitter le fil arrête le son en cours et jette un vocal inachevé.
    unawaited(_audio.stopAll());
    unawaited(_recording.cancel());
    _recording.dispose();
    super.dispose();
  }

  GroupMediaComposer get _composer => ref.read(groupMediaComposerProvider);

  void _send(OutgoingMedia media) {
    unawaited(_composer.send(groupId: widget.groupId, media: media));
  }

  void _sendVoice(RecordedVoice voice) {
    // Pendant qu'on enregistrait, un vocal du fil a pu jouer : il s'arrête.
    unawaited(_audio.stopAll());
    _send(
      OutgoingMedia.voice(
        path: voice.path,
        durationSeconds: (voice.duration.inMilliseconds / 1000).ceil(),
        waveform: voice.waveform,
      ),
    );
  }

  void _say(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  ChatMediaPicker get _picker => ref.read(chatMediaPickerProvider);

  Future<void> _photo(Future<String?> Function() pick) async {
    final path = await pick();
    if (path == null || !mounted) return;
    final caption = await MediaCaptionScreen.open(context, path: path);
    if (caption == null) return;
    _send(OutgoingMedia.image(path: path, caption: caption));
  }

  Future<void> _video(Future<String?> Function() pick) async {
    final path = await pick();
    if (path == null || !mounted) return;
    final caption =
        await MediaCaptionScreen.open(context, path: path, video: true);
    if (caption == null) return;
    _send(OutgoingMedia.video(path: path, caption: caption));
  }

  Future<void> _attach() async {
    final choice = await showAttachmentSheet(context);
    if (choice == null || !mounted) return;
    final l = context.l10n;
    switch (choice) {
      case AttachmentChoice.gallery:
        await _photo(_picker.pickPhoto);
      case AttachmentChoice.video:
        await _video(_picker.pickVideo);
      case AttachmentChoice.recordVideo:
        await _video(_picker.recordVideo);
      case AttachmentChoice.document:
        final file = await _picker.pickDocument();
        if (file == null || !mounted) return;
        final mime = documentMimeOf(file.name);
        if (mime == null) {
          _say(l.m4DocumentUnsupported);
          return;
        }
        _send(
          OutgoingMedia.document(
            path: file.path,
            name: file.name,
            mime: mime,
            sizeBytes: file.sizeBytes,
          ),
        );
      case AttachmentChoice.audio:
        final file = await _picker.pickAudioFile();
        if (file == null || !mounted) return;
        final mime = audioFileMimeOf(file.name);
        if (mime == null) {
          _say(l.m4DocumentUnsupported);
          return;
        }
        _send(
          OutgoingMedia.audioFile(
            path: file.path,
            name: file.name,
            mime: mime,
            sizeBytes: file.sizeBytes,
          ),
        );
      case AttachmentChoice.location:
        await _location();
      case AttachmentChoice.contact:
        final contact = await _picker.pickContact();
        if (contact == null) return;
        _send(
          OutgoingMedia.contact(name: contact.name, phones: contact.phones),
        );
    }
  }

  Future<void> _location() async {
    final l = context.l10n;
    final outcome = await _picker.currentLocation();
    if (outcome == null || !mounted) return;
    switch (outcome) {
      case LocationUnavailable(:final serviceDisabled):
        _say(serviceDisabled ? l.m4LocationDisabled : l.m4LocationDenied);
      case LocationFound(:final latitude, :final longitude):
        final label = await _confirmLocation();
        if (label == null) return;
        _send(
          OutgoingMedia.location(
            latitude: latitude,
            longitude: longitude,
            label: label.isEmpty ? null : label,
          ),
        );
    }
  }

  /// « Envoyer ma position ? » — avec un libellé facultatif. Rend le libellé
  /// (éventuellement vide), ou `null` si l'on renonce.
  Future<String?> _confirmLocation() => showDialog<String>(
        context: context,
        builder: (_) => const _LocationDialog(),
      );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final palette = context.palette;

    return ListenableBuilder(
      listenable: _recording,
      builder: (context, _) {
        final recording = _recording.isActive;
        return MessageInputBar(
          hintText: widget.hintText,
          controller: widget.controller,
          focusNode: widget.focusNode,
          onSend: widget.onSend,
          // Pendant l'enregistrement, le champ cède la place à la bande du
          // vocal ; le micro, lui, ne bouge pas — c'est lui qui porte le geste.
          replacement:
              recording ? VoiceRecordingStrip(controller: _recording) : null,
          attachments: recording
              ? null
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      key: const Key('m4_attach_button'),
                      tooltip: l.m4ChatAttach,
                      visualDensity: VisualDensity.compact,
                      icon:
                          Icon(Icons.attach_file, color: palette.textSecondary),
                      onPressed: _attach,
                    ),
                    IconButton(
                      key: const Key('m4_camera_button'),
                      tooltip: l.m4ChatCamera,
                      visualDensity: VisualDensity.compact,
                      icon: Icon(Icons.photo_camera_outlined,
                          color: palette.textSecondary),
                      onPressed: () => _photo(_picker.takePhoto),
                    ),
                  ],
                ),
          voiceButton: VoiceRecordButton(
            controller: _recording,
            onRecorded: _sendVoice,
            onDenied: () => _say(l.m4VoiceMicDenied),
            onTooShort: () => _say(l.m4VoiceTooShort),
          ),
        );
      },
    );
  }
}

/// « Envoyer ma position ? », avec un libellé facultatif. Le champ appartient
/// au dialogue : il vit et meurt avec lui (sortie animée comprise).
class _LocationDialog extends StatefulWidget {
  const _LocationDialog();

  @override
  State<_LocationDialog> createState() => _LocationDialogState();
}

class _LocationDialogState extends State<_LocationDialog> {
  final TextEditingController _label = TextEditingController();

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.m4LocationTitle),
      content: TextField(
        key: const Key('m4_location_label'),
        controller: _label,
        maxLength: 200,
        decoration: InputDecoration(hintText: l.m4LocationLabelHint),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.m4Cancel),
        ),
        FilledButton(
          key: const Key('m4_location_send'),
          onPressed: () => Navigator.of(context).pop(_label.text.trim()),
          child: Text(l.m4Send),
        ),
      ],
    );
  }
}
