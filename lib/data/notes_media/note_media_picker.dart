import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart' hide PickedFile;

import '../messaging/media/chat_media_picker.dart';
import '../messaging/media/device_chat_media.dart';
import '../messaging/media/media_mime.dart';
import 'note_media_composer.dart';

/// **Les sources d'une pièce jointe de note** (N4, mobile#192), derrière une
/// couture — les greffons lèvent `MissingPluginException` sous `flutter test`.
///
/// Adaptateur sur [ChatMediaPicker] (l'appareil photo est le sien, inchangé) :
/// il n'offre ni « photo **ou** vidéo de la galerie » en un seul sélecteur, ni
/// « document **ou** audio » en un seul fichier, ce que veut le menu façon
/// Apple. Toutes les méthodes rendent `null` quand la personne annule.
abstract interface class NoteMediaPicker {
  Future<NoteMediaSource?> chooseMedia();
  Future<NoteMediaSource?> takePhoto();
  Future<NoteMediaSource?> recordVideo();
  Future<NoteMediaSource?> pickFile();
}

class InertNoteMediaPicker implements NoteMediaPicker {
  const InertNoteMediaPicker();

  @override
  Future<NoteMediaSource?> chooseMedia() async => null;
  @override
  Future<NoteMediaSource?> takePhoto() async => null;
  @override
  Future<NoteMediaSource?> recordVideo() async => null;
  @override
  Future<NoteMediaSource?> pickFile() async => null;
}

const Set<String> _videoExtensions = {
  'mp4',
  'mov',
  'm4v',
  '3gp',
  'webm',
  'mkv',
};

/// La source d'une photo ou d'une vidéo, d'après l'extension de [path].
NoteMediaSource mediaSourceOf(String path, {String? name}) {
  final fileName = name ?? path.split('/').last;
  final video = _videoExtensions.contains(fileExtension(fileName));
  return NoteMediaSource(
    kind: video ? 'video' : 'image',
    path: path,
    name: fileName,
  );
}

/// La source d'un fichier choisi : audio s'il en a l'extension, document
/// sinon. `null` pour un type que le serveur refuserait.
NoteMediaSource? fileSourceOf(String path, String name, int? sizeBytes) {
  final audio = audioFileMimeOf(name);
  final mime = audio ?? documentMimeOf(name);
  if (mime == null) return null;
  return NoteMediaSource(
    kind: audio != null ? 'audio' : 'document',
    path: path,
    name: name,
    mime: mime,
    sizeBytes: sizeBytes,
  );
}

class DeviceNoteMediaPicker implements NoteMediaPicker {
  DeviceNoteMediaPicker({ImagePicker? images, ChatMediaPicker? camera})
      : _images = images ?? ImagePicker(),
        _camera = camera ?? DeviceChatMediaPicker();

  final ImagePicker _images;
  final ChatMediaPicker _camera;

  @override
  Future<NoteMediaSource?> chooseMedia() async {
    final file = await _images.pickMedia();
    return file == null ? null : mediaSourceOf(file.path, name: file.name);
  }

  @override
  Future<NoteMediaSource?> takePhoto() async {
    final path = await _camera.takePhoto();
    return path == null ? null : mediaSourceOf(path);
  }

  @override
  Future<NoteMediaSource?> recordVideo() async {
    final path = await _camera.recordVideo();
    return path == null ? null : mediaSourceOf(path);
  }

  @override
  Future<NoteMediaSource?> pickFile() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: [
          ...kDocumentMimeByExtension.keys,
          ...kAudioFileMimeByExtension.keys,
        ],
      );
      final path = file?.path;
      if (file == null || path == null) return null;
      return fileSourceOf(path, file.name, await File(path).length());
    } on Object {
      return null;
    }
  }
}
