/// **Les providers des médias du fil** (M4, #143 — reprend #98).
///
/// Un fichier à part d'`echanges_providers.dart`, pour que les tranches de la
/// messagerie qui avancent en parallèle n'écrivent pas dans le même. Chaque
/// greffon est derrière une couture, et **sans backend** (`AppEnv.useBackend`
/// faux, donc dans tous les tests) chaque couture est inerte : aucun canal de
/// greffon n'est touché sous `flutter test`.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_env.dart';
import '../data/messaging/media/chat_media_picker.dart';
import '../data/messaging/media/device_chat_media.dart';
import '../data/messaging/media/group_media_composer.dart';
import '../data/messaging/media/group_media_transport.dart';
import '../data/messaging/media/group_media_urls.dart';
import '../data/messaging/media/media_outbox.dart';
import '../data/messaging/media/media_preparer.dart';
import '../data/messaging/media/message_media_store.dart';
import '../data/messaging/media/media_upload_progress.dart';
import '../data/messaging/media/record_voice_recorder.dart';
import '../data/messaging/media/v_video_compressor_engine.dart';
import '../data/messaging/media/voice_recorder.dart';
import '../data/players/chat_audio_player.dart';
import '../data/players/chat_video_surface.dart';
import '../data/players/just_audio_chat_engine.dart';
import 'sync_providers.dart';

/// Le chemin présigné : HTTP avec backend, inerte sinon.
final groupMediaTransportProvider = Provider<GroupMediaTransport>(
  (ref) => AppEnv.useBackend
      ? HttpGroupMediaTransport()
      : const InertGroupMediaTransport(),
);

/// Le magasin durable des médias reçus (T1, #223).
final messageMediaStoreProvider =
    Provider<MessageMediaStore>((ref) => MessageMediaStore());

/// Les URL de lecture (clé → URL présignée nue), et le **fichier local**
/// quand il est déjà là : le disque avant le réseau (#223).
final groupMediaUrlsProvider = Provider<GroupMediaUrls>(
  (ref) => AppEnv.useBackend
      ? HttpGroupMediaUrls(
          store: ref.watch(messageMediaStoreProvider),
          dao: ref.watch(groupDaoProvider),
        )
      : const InertGroupMediaUrls(),
);

/// La progression des montées, par écho.
final mediaUploadProgressProvider = Provider<MediaUploadProgress>((ref) {
  final progress = MediaUploadProgress();
  ref.onDispose(progress.dispose);
  return progress;
});

final mediaOutboxProvider = Provider<MediaOutbox>((ref) => MediaOutbox());

final mediaPreparerProvider = Provider<MediaPreparer>(
  (ref) => DeviceMediaPreparer(video: VVideoCompressionEngine()),
);

/// **L'envoi d'un média.** Même rappel de synchronisation que le composeur de
/// texte : un envoi réussi rejoint le cycle en cours.
final groupMediaComposerProvider = Provider<GroupMediaComposer>(
  (ref) => GroupMediaComposer(
    dao: ref.watch(groupDaoProvider),
    transport: ref.watch(groupMediaTransportProvider),
    preparer: ref.watch(mediaPreparerProvider),
    outbox: ref.watch(mediaOutboxProvider),
    store: ref.watch(messageMediaStoreProvider),
    progress: ref.watch(mediaUploadProgressProvider),
    resynchronize: ref.watch(pullToRefreshProvider),
  ),
);

/// Les sources d'une pièce jointe.
final chatMediaPickerProvider = Provider<ChatMediaPicker>(
  (ref) => AppEnv.useBackend
      ? DeviceChatMediaPicker()
      : const InertChatMediaPicker(),
);

/// Ouvrir une carte, un document, un numéro.
final mediaOpenerProvider = Provider<MediaOpener>(
  (ref) =>
      AppEnv.useBackend ? const DeviceMediaOpener() : const InertMediaOpener(),
);

/// L'enregistreur de vocaux. Sans backend : un double qui n'enregistre rien.
final voiceRecorderProvider = Provider<VoiceRecorder>((ref) {
  final recorder =
      AppEnv.useBackend ? RecordVoiceRecorder() : FakeVoiceRecorder();
  ref.onDispose(recorder.dispose);
  return recorder;
});

/// **Un vocal à la fois**, pour toute l'application.
final chatAudioControllerProvider = Provider<ChatAudioController>((ref) {
  final controller = ChatAudioController(
    AppEnv.useBackend ? JustAudioChatEngine() : const InertChatAudioEngine(),
  );
  ref.onDispose(controller.dispose);
  return controller;
});

/// La surface de lecture d'une vidéo.
final chatVideoSurfaceProvider = Provider<ChatVideoSurfaceFactory>(
  (ref) => AppEnv.useBackend
      ? const VideoPlayerChatSurfaceFactory()
      : const InertChatVideoSurfaceFactory(),
);
