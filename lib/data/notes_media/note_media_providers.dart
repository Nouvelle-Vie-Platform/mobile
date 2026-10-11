/// **Les providers des pièces jointes de notes** (N4, mobile#192). Sans
/// backend (`AppEnv.useBackend` faux, donc dans tous les tests), le transport,
/// les URL et le sélecteur sont inertes : aucun canal de greffon n'est touché
/// sous `flutter test`.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/config/app_env.dart';
import '../../state/chat_media_providers.dart' show mediaPreparerProvider;
import '../../state/notes_providers.dart' show notesOutboxProvider;
import '../../state/sync_providers.dart' show appDatabaseProvider;
import '../local/app_database.dart';
import '../messaging/media/media_outbox.dart';
import 'load_image_for_pdf.dart';
import 'note_media_composer.dart';
import 'note_media_dao.dart';
import 'note_media_picker.dart';
import 'note_media_transport.dart';
import 'note_media_urls.dart';

final noteMediaDaoProvider = Provider<NoteMediaDao>(
  (ref) => NoteMediaDao(ref.watch(appDatabaseProvider)),
);

final noteMediaTransportProvider = Provider<NoteMediaTransport>(
  (ref) => AppEnv.useBackend
      ? HttpNoteMediaTransport()
      : const InertNoteMediaTransport(),
);

/// Clé → URL présignée nue, gardée 50 min en mémoire : **une** instance pour
/// toute l'application, sinon le cache ne sert à rien.
final noteMediaUrlsProvider = Provider<NoteMediaUrls>(
  (ref) => AppEnv.useBackend ? HttpNoteMediaUrls() : const InertNoteMediaUrls(),
);

/// L'outbox des notes : `<support>/note_outbox/message_outbox/`. `MediaOutbox`
/// est réutilisé tel quel (son sous-dossier est fixe) ; seule sa racine change,
/// et son `sweep` ne voit donc jamais les fichiers de la messagerie.
final noteMediaOutboxProvider = Provider<MediaOutbox>(
  (ref) => MediaOutbox(
    root: () async => Directory(
      '${(await getApplicationSupportDirectory()).path}/note_outbox',
    ),
  ),
);

final noteMediaPickerProvider = Provider<NoteMediaPicker>(
  (ref) => AppEnv.useBackend
      ? DeviceNoteMediaPicker()
      : const InertNoteMediaPicker(),
);

final noteMediaComposerProvider = Provider<NoteMediaComposer>(
  (ref) => NoteMediaComposer(
    dao: ref.watch(noteMediaDaoProvider),
    transport: ref.watch(noteMediaTransportProvider),
    preparer: ref.watch(mediaPreparerProvider),
    outbox: ref.watch(noteMediaOutboxProvider),
    resendNotes: () => ref.read(notesOutboxProvider)(),
  ),
);

/// La ligne en attente d'un embed (par `localId`, ou par clé une fois monté).
final pendingNoteMediaProvider = StreamProvider.family<PendingNoteMediaRow?,
    ({String? embedId, String? key})>(
  (ref, id) =>
      ref.watch(noteMediaDaoProvider).watch(embedId: id.embedId, key: id.key),
);

/// Le `loadImage` du PDF : `exporter.build(…, loadImage: ref.read(noteImageLoaderProvider))`.
final noteImageLoaderProvider =
    Provider<Future<Uint8List?> Function(String key)>((ref) {
  final dao = ref.watch(noteMediaDaoProvider);
  final urls = ref.watch(noteMediaUrlsProvider);
  return (key) => loadImageForPdf(key, dao: dao, urls: urls);
});
