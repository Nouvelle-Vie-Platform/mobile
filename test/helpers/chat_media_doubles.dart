import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/messaging/media/chat_media_picker.dart';
import 'package:maison_du_miracle/data/messaging/media/group_media_composer.dart';
import 'package:maison_du_miracle/data/messaging/media/group_media_transport.dart';
import 'package:maison_du_miracle/data/messaging/media/group_media_urls.dart';
import 'package:maison_du_miracle/data/messaging/media/media_outbox.dart';
import 'package:maison_du_miracle/data/messaging/media/media_preparer.dart';
import 'package:maison_du_miracle/data/messaging/media/voice_recorder.dart';
import 'package:maison_du_miracle/data/players/chat_audio_player.dart';
import 'package:maison_du_miracle/data/players/chat_video_surface.dart';
import 'package:maison_du_miracle/state/chat_media_providers.dart';

/// **Les médias du fil, sans greffon ni réseau** (M4, #143).
///
/// `AppEnv.useBackend` est vrai hors surcharge : les providers des médias
/// construiraient alors l'enregistreur, le lecteur, le compresseur et le
/// chemin présigné **réels** — dont les canaux lèvent
/// `MissingPluginException` sous `flutter test`. `pumpScreen` pose ces doubles
/// pour tous les écrans ; les tests des médias montent les leurs.
List<Override> chatMediaTestOverrides(AppDatabase db) => [
      groupMediaTransportProvider
          .overrideWithValue(const InertGroupMediaTransport()),
      groupMediaUrlsProvider.overrideWithValue(const InertGroupMediaUrls()),
      chatMediaPickerProvider.overrideWithValue(const InertChatMediaPicker()),
      mediaOpenerProvider.overrideWithValue(const InertMediaOpener()),
      voiceRecorderProvider.overrideWith((ref) => FakeVoiceRecorder()),
      chatAudioControllerProvider.overrideWith((ref) {
        final controller = ChatAudioController(const InertChatAudioEngine());
        ref.onDispose(controller.dispose);
        return controller;
      }),
      chatVideoSurfaceProvider
          .overrideWithValue(const InertChatVideoSurfaceFactory()),
      mediaPreparerProvider.overrideWithValue(const UnusedMediaPreparer()),
      mediaOutboxProvider.overrideWithValue(
        MediaOutbox(root: () async => throw UnsupportedError('pas de disque')),
      ),
      groupMediaComposerProvider.overrideWith(
        (ref) => GroupMediaComposer(
          dao: db.groupDao,
          transport: const InertGroupMediaTransport(),
          preparer: const UnusedMediaPreparer(),
          outbox: ref.watch(mediaOutboxProvider),
          progress: ref.watch(mediaUploadProgressProvider),
          resynchronize: () async {},
        ),
      ),
    ];

/// Un préparateur qui ne prépare rien : un test d'écran n'envoie pas de
/// photo réelle.
class UnusedMediaPreparer implements MediaPreparer {
  const UnusedMediaPreparer();

  @override
  Future<PreparedImage> prepareImage(String sourcePath, String outPath) =>
      throw const MediaPreparationException('test');

  @override
  Future<VideoProbe> probeVideo(String sourcePath) =>
      throw const MediaPreparationException('test');

  @override
  Future<PreparedVideo> prepareVideo(
    String sourcePath, {
    void Function(double progress)? onProgress,
  }) =>
      throw const MediaPreparationException('test');
}
