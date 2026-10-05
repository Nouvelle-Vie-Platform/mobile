import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:just_audio/just_audio.dart' show AudioPlayer, ProcessingState;
import 'package:video_player/video_player.dart'
    show VideoFormat, VideoPlayer, VideoPlayerController, VideoPlayerValue;

import 'status_player.dart';

/// Ce qui fait avancer le statut chargé.
enum _Engine {
  /// L'horloge seule : un statut texte ou image — ou un média qui n'a pas pu
  /// s'ouvrir, et qui défile alors comme une affiche plutôt que de bloquer le
  /// mur.
  clock,

  /// `just_audio`, pour un statut vocal.
  audio,

  /// `video_player`, pour un statut vidéo — qui porte son son.
  video,
}

/// **Le lecteur réel des statuts** (#130) : `just_audio` pour l'audio,
/// `video_player` pour la vidéo, une horloge pour le reste — derrière
/// [StatusPlayer], **sans qu'aucun écran ne sache lequel tourne**.
///
/// Branché par `main.dart` sur mobile, et là seulement : sous `flutter test`
/// les deux greffons lèvent `MissingPluginException` (les tests gardent
/// `FakeStatusPlayer` / `InertStatusPlayer`), et sur le web `just_audio` ne joue
/// pas le HLS hors Safari (#46).
///
/// **Le seul fichier de `lib/` qui importe `video_player`**, et l'un des deux
/// seuls qui importent `just_audio` — des tests de source le vérifient
/// (`test/data/content_player_test.dart`).
///
/// Cinq règles, et chacune se raterait en silence :
///
/// 1. **L'horloge et l'auto-avance restent au lecteur.** Le widget écoute une
///    position et une fin ; il ne sait pas si elles viennent d'un minuteur,
///    d'ExoPlayer ou d'AVPlayer.
/// 2. **La durée réelle prime** dès que le média la dit
///    ([effectiveStatusDuration]) ; la durée de repli passée à [load] tient
///    jusque-là, et pour toujours si le média ne la dit jamais.
/// 3. **Un média qui ne s'ouvre pas ne bloque pas le mur.** Hors ligne, ou sur
///    une playlist refusée, le statut retombe sur l'horloge avec sa durée de
///    repli : il défile, affiche et texte compris, comme un statut sans média.
///    Un statut figé sur un tampon vide obligerait à taper pour sortir.
/// 4. **Un lecteur par chargement**, jeté au suivant. Réutiliser le même
///    `AudioPlayer` laisserait passer un « terminé » du statut précédent après
///    le chargement du suivant — et le mur sauterait un statut. Chaque
///    abonnement est daté par une génération, et une génération périmée se tait.
/// 5. **Il ne touche pas au lecteur de la médiathèque.** C'est un second
///    moteur, sans `audio_service` ni notification : la mise en pause de la
///    radio ou d'un enseignement pendant un statut à son est décidée par
///    l'écran, au travers du contrôleur global (`PlaybackController.interrupt`).
final class MediaStatusPlayer extends ValueNotifier<StatusPlayback>
    implements StatusPlayer {
  MediaStatusPlayer({this.tick = const Duration(milliseconds: 100)})
      : super(const StatusPlayback());

  /// Pas de l'horloge des statuts sans média.
  final Duration tick;

  bool _disposed = false;
  bool _muted = false;

  /// La lecture est demandée — elle commencera dès que le média sera prêt.
  bool _wantsPlay = false;

  _Engine _engine = _Engine.clock;

  /// Date chaque chargement : un rappel d'une génération passée se tait.
  int _generation = 0;

  /// La durée de repli du statut chargé (transcodeur, sinon défaut par type).
  Duration _fallback = Duration.zero;

  Timer? _clock;
  AudioPlayer? _audio;
  final List<StreamSubscription<Object?>> _audioSubscriptions = [];
  VideoPlayerController? _video;
  VoidCallback? _videoListener;

  @override
  bool get isMuted => _muted;

  @override
  void setMuted(bool muted) {
    if (_disposed) return;
    _muted = muted;
    final volume = muted ? 0.0 : 1.0;
    _guard(_audio?.setVolume(volume), 'volume audio');
    _guard(_video?.setVolume(volume), 'volume vidéo');
  }

  @override
  void load({
    required String statusId,
    String? mediaUrl,
    StatusMediaKind? mediaKind,
    required Duration fallbackDuration,
  }) {
    if (_disposed) return;
    final generation = ++_generation;
    _releaseMedia();
    _wantsPlay = false;
    _fallback = fallbackDuration;
    // Valeur **neuve** : c'est le seul moyen d'effacer une fin atteinte, des
    // dimensions et une première image héritées du statut précédent.
    value = StatusPlayback(statusId: statusId, duration: fallbackDuration);

    final url = mediaUrl;
    if (url == null || url.isEmpty || mediaKind == null) {
      _engine = _Engine.clock;
      return;
    }
    switch (mediaKind) {
      case StatusMediaKind.audio:
        _engine = _Engine.audio;
        unawaited(_openAudio(url, generation));
      case StatusMediaKind.video:
        _engine = _Engine.video;
        unawaited(_openVideo(url, generation));
    }
  }

  @override
  void play() {
    if (_disposed) return;
    final current = value;
    if (current.statusId == null || current.isPlaying || current.isCompleted) {
      return;
    }
    _wantsPlay = true;
    value = current.copyWith(isPlaying: true);
    switch (_engine) {
      case _Engine.clock:
        _startClock();
      case _Engine.audio:
        // Avant la fin de `setUrl`, l'appel est retenu par `just_audio` et la
        // lecture part dès que la source est prête ; `_openAudio` le redemande
        // de toute façon.
        _startAudio();
      case _Engine.video:
        final video = _video;
        if (video != null && video.value.isInitialized) {
          _guard(video.play(), 'lecture vidéo');
        }
    }
  }

  @override
  void pause() {
    if (_disposed) return;
    _wantsPlay = false;
    _stopClock();
    _guard(_audio?.pause(), 'pause audio');
    _guard(_video?.pause(), 'pause vidéo');
    if (value.isPlaying) value = value.copyWith(isPlaying: false);
  }

  @override
  void seek(Duration position) {
    if (_disposed) return;
    final current = value;
    final clamped = position < Duration.zero
        ? Duration.zero
        : (position > current.duration ? current.duration : position);
    if (current.duration > Duration.zero && clamped >= current.duration) {
      _complete();
      return;
    }
    switch (_engine) {
      case _Engine.clock:
        break;
      case _Engine.audio:
        _guard(_audio?.seek(clamped), 'déplacement audio');
      case _Engine.video:
        _guard(_video?.seekTo(clamped), 'déplacement vidéo');
    }
    value = current.copyWith(position: clamped, isCompleted: false);
  }

  @override
  Widget? videoSurface() {
    final video = _video;
    if (_engine != _Engine.video || video == null) return null;
    if (!video.value.isInitialized) return null;
    return VideoPlayer(video);
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    _releaseMedia();
    super.dispose();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Audio
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> _openAudio(String url, int generation) async {
    final player = AudioPlayer();
    _audio = player;
    _audioSubscriptions
      ..add(player.durationStream.listen((duration) {
        if (_isCurrent(generation)) _applyRealDuration(duration);
      }))
      ..add(player.positionStream.listen((position) {
        if (_isCurrent(generation)) _applyPosition(position);
      }))
      ..add(player.playerStateStream.listen(
        (state) {
          if (!_isCurrent(generation)) return;
          if (state.processingState == ProcessingState.completed) _complete();
        },
        onError: (Object error) {
          if (_isCurrent(generation)) _fallBackToClock('audio', error);
        },
      ))
      // Les pannes de la plateforme arrivent en erreur sur le flux
      // d'événements : une playlist refusée, un réseau coupé.
      ..add(player.playbackEventStream.listen(
        (_) {},
        onError: (Object error) {
          if (_isCurrent(generation)) _fallBackToClock('audio', error);
        },
      ));
    try {
      await player.setVolume(_muted ? 0 : 1);
      final duration = await player.setUrl(url);
      if (!_isCurrent(generation)) return;
      _applyRealDuration(duration);
      if (_wantsPlay) _startAudio();
    } catch (error) {
      if (_isCurrent(generation)) _fallBackToClock('audio', error);
    }
  }

  void _startAudio() {
    final player = _audio;
    if (player == null) return;
    // `play()` ne se résout qu'à la pause ou à la fin : on ne l'attend pas,
    // mais une panne qu'il porterait ne doit pas sortir non rattrapée.
    _guard(player.play(), 'lecture audio');
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Vidéo
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> _openVideo(String url, int generation) async {
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(url),
      // Le profil `sparks` ne sert que du HLS : le dire évite à ExoPlayer de
      // deviner le format sur l'extension.
      formatHint: VideoFormat.hls,
    );
    _video = controller;
    void listener() {
      if (_isCurrent(generation)) _onVideo(controller.value);
    }

    _videoListener = listener;
    controller.addListener(listener);
    try {
      await controller.initialize();
      if (!_isCurrent(generation)) return;
      await controller.setVolume(_muted ? 0 : 1);
      if (!_isCurrent(generation)) return;
      _onVideo(controller.value);
      if (_wantsPlay) await controller.play();
    } catch (error) {
      if (_isCurrent(generation)) _fallBackToClock('vidéo', error);
    }
  }

  void _onVideo(VideoPlayerValue video) {
    if (video.hasError) {
      _fallBackToClock('vidéo', video.errorDescription ?? 'erreur');
      return;
    }
    if (!video.isInitialized) return;
    if (video.isCompleted) {
      _complete();
      return;
    }
    final current = value;
    if (current.isCompleted) return;
    final size = video.size;
    value = current.copyWith(
      videoSize: size.isEmpty ? null : size,
      // `video_player` n'annonce pas sa première image : une position qui a
      // quitté zéro en tient lieu. Une fois vraie, elle le reste pour ce
      // statut — l'affiche ne revient pas sur un hoquet de tampon.
      hasVideoFrame: current.hasVideoFrame || video.position > Duration.zero,
    );
    _applyRealDuration(video.duration);
    _applyPosition(video.position);
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Horloge et état commun
  // ───────────────────────────────────────────────────────────────────────────

  void _startClock() {
    _clock?.cancel();
    _clock = Timer.periodic(tick, (_) => _advanceClock());
  }

  void _stopClock() {
    _clock?.cancel();
    _clock = null;
  }

  void _advanceClock() {
    final current = value;
    if (!current.isPlaying) {
      _stopClock();
      return;
    }
    final next = current.position + tick;
    if (next >= current.duration) {
      _complete();
      return;
    }
    value = current.copyWith(position: next);
  }

  /// La durée lue dans le média **remplace** celle de repli — la chaîne
  /// [effectiveStatusDuration], au maillon que seul le lecteur connaît.
  void _applyRealDuration(Duration? real) {
    final effective = effectiveStatusDuration(
      real: real,
      announcedMs: _fallback.inMilliseconds,
      hasMedia: true,
    );
    final current = value;
    if (current.isCompleted || effective == current.duration) return;
    value = current.copyWith(duration: effective);
  }

  void _applyPosition(Duration position) {
    final current = value;
    if (current.isCompleted) return;
    // Une durée de repli plus courte que le média ne coupe pas le son : la
    // barre se remplit, et c'est le média qui dit sa fin.
    final shown = position > current.duration ? current.duration : position;
    if (shown == current.position) return;
    value = current.copyWith(position: shown);
  }

  /// Le statut est terminé : barre pleine, plus rien ne joue.
  void _complete() {
    final current = value;
    if (current.isCompleted) return;
    _wantsPlay = false;
    _stopClock();
    _guard(_audio?.pause(), 'fin audio');
    _guard(_video?.pause(), 'fin vidéo');
    value = current.copyWith(
      position: current.duration,
      isPlaying: false,
      isCompleted: true,
    );
  }

  /// **Le média ne s'ouvre pas** : le statut défile sur l'horloge, avec sa
  /// durée de repli, depuis où il en était.
  void _fallBackToClock(String what, Object error) {
    if (_engine == _Engine.clock) return;
    debugPrint('[statut] $what indisponible, repli sur l\'horloge : $error');
    // La génération avance : les rappels du média abandonné se taisent.
    _generation++;
    _releaseMedia();
    _engine = _Engine.clock;
    final current = value;
    value = current.copyWith(
      duration: _fallback,
      position: current.position > _fallback ? Duration.zero : current.position,
      hasVideoFrame: false,
    );
    if (_wantsPlay && !value.isCompleted) _startClock();
  }

  /// Arrête l'horloge et **jette** les deux moteurs du chargement courant.
  void _releaseMedia() {
    _stopClock();
    for (final subscription in _audioSubscriptions) {
      unawaited(subscription.cancel());
    }
    _audioSubscriptions.clear();
    final audio = _audio;
    _audio = null;
    if (audio != null) _guard(audio.dispose(), 'libération audio');

    final video = _video;
    final listener = _videoListener;
    _video = null;
    _videoListener = null;
    if (video != null) {
      if (listener != null) video.removeListener(listener);
      _guard(video.dispose(), 'libération vidéo');
    }
  }

  bool _isCurrent(int generation) => !_disposed && generation == _generation;

  /// Un appel au greffon qu'on n'attend pas — mais dont une panne ne doit pas
  /// remonter en erreur asynchrone non rattrapée.
  static void _guard(Future<void>? work, String label) {
    if (work == null) return;
    unawaited(work.catchError((Object error) {
      debugPrint('[statut] $label : $error');
    }));
  }
}
