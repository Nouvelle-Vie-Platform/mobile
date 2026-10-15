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
import '../data/messaging/media/message_media_queue.dart';
import '../data/messaging/media/message_media_store.dart';
import '../data/messaging/media/media_upload_progress.dart';
import '../data/messaging/media/record_voice_recorder.dart';
import '../data/messaging/media/v_video_compressor_engine.dart';
import '../data/messaging/media/voice_recorder.dart';
import '../data/players/chat_audio_player.dart';
import '../data/players/chat_video_surface.dart';
import '../data/players/just_audio_chat_engine.dart';
import 'downloads_providers.dart';
import 'media_settings_providers.dart';
import 'sync_providers.dart';
import 'theme_provider.dart';

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

/// **La descente automatique des médias reçus** (T3, #225).
///
/// Pas `autoDispose` : la file vit aussi longtemps que l'application — elle
/// garde en mémoire les médias qu'une bulle a affichés et qui attendent le
/// wifi, et un écran fermé n'a pas à les perdre. Son déclencheur d'arrivée est
/// `app.dart`, après chaque cycle de synchronisation réussi.
final messageMediaQueueProvider = Provider<MessageMediaQueue>((ref) {
  return MessageMediaQueue(
    urls: ref.watch(groupMediaUrlsProvider),
    network: ref.watch(networkTransportProvider),
    // Lus **à la demande**, jamais observés : la file consulte l'état courant
    // au moment de descendre (même raison que `DownloadManager`). Le flux
    // Drift est refermé aussitôt (`.first`) : la file n'observe pas le magasin,
    // elle le consulte.
    arrived: () async {
      final since = await ref.read(settingsDaoProvider).chatMediaDescentSince();
      return ref.read(groupDaoProvider).watchMediaToDescend(since).first;
    },
    descent: () => ref.read(settingsDaoProvider).chatMediaDescent(),
    diskSpace: ref.watch(diskSpaceProvider),
  );
});

/// **La frontière « arrivé / historique »**, lue une fois (T3, #225). Un
/// `Future` et non un flux : elle est posée au premier appel et ne bouge plus.
final _chatMediaSinceProvider = FutureProvider<DateTime>(
  (ref) => ref.read(settingsDaoProvider).chatMediaDescentSince(),
);

/// **Ce qui attend de descendre** : combien de médias, et combien d'octets.
///
/// Les octets sont la somme des `media_size` **mesurés par le serveur**, lus au
/// magasin : c'est le chiffre que l'onglet MESSAGERIE affiche, et il ne
/// s'invente pas. `null` tant que la frontière n'est pas lue.
///
/// **Surtout pas un `async*` avec `yield*`** sur le flux Drift : voir
/// l'avertissement d'`onCellularProvider`. Le `since` passe donc par un
/// provider à lui, et celui-ci ne fait que transformer un flux.
final chatMediaWaitingProvider = StreamProvider<({int count, int bytes})>(
  (ref) {
    final since = ref.watch(_chatMediaSinceProvider).value;
    if (since == null) return const Stream<({int count, int bytes})>.empty();
    return ref.watch(groupDaoProvider).watchMediaToDescend(since).map(
          (media) => (
            count: media.length,
            bytes: media.fold<int>(0, (sum, m) => sum + (m.sizeBytes ?? 0)),
          ),
        );
  },
  // Même raison que les autres lectures de magasin : une lecture locale qui
  // échoue ne réussira pas mieux à la seconde tentative.
  retry: (_, __) => null,
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
