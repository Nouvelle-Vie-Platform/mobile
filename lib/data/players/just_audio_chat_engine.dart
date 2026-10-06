import 'dart:async';

import 'package:just_audio/just_audio.dart';

import 'chat_audio_player.dart';

/// **Le moteur réel des vocaux du fil** (M4, #143) — l'un des trois fichiers
/// de `lib/` qui importent `just_audio` (garde-fou de source :
/// `test/data/content_player_test.dart`).
///
/// Un `AudioPlayer` **à part** de celui de la médiathèque : un vocal ne doit
/// ni prendre la notification du lecteur, ni écraser la position de reprise
/// d'un enseignement. Pas d'`audio_service` ici.
///
/// Les URL sont **nues** (présignées, ou `file://` pour un écho) : aucun
/// en-tête d'authentification ne part vers le magasin — voir `GroupMediaUrls`.
class JustAudioChatEngine implements ChatAudioEngine {
  JustAudioChatEngine({AudioPlayer? player})
      : _player = player ?? AudioPlayer(handleInterruptions: true);

  final AudioPlayer _player;

  @override
  Future<Duration?> load(String url) {
    final uri = url.startsWith('/') ? Uri.file(url) : Uri.parse(url);
    return _player.setAudioSource(AudioSource.uri(uri));
  }

  @override
  Future<void> play() async {
    // `play()` ne rend la main qu'à la fin de la lecture : on ne l'attend pas.
    unawaited(_player.play());
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  @override
  Future<void> stop() => _player.stop();

  @override
  Stream<Duration> positions() => _player.positionStream;

  @override
  Stream<void> completions() => _player.processingStateStream
      .where((state) => state == ProcessingState.completed);

  @override
  Future<void> dispose() => _player.dispose();
}
