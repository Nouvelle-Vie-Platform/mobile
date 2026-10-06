import 'dart:async';

import 'package:flutter/foundation.dart';

/// **La lecture des vocaux et des fichiers audio du fil** (M4, #143 — reprend
/// #98).
///
/// Ni `ContentPlayer` (la médiathèque : HLS, notification, écran verrouillé,
/// reprise de position) ni `StatusPlayer` (les statuts) : un vocal est un
/// fichier de quelques centaines de kilo-octets, lu sur place, sans
/// notification ni reprise. Un troisième contrat, minuscule.
///
/// Un seul fichier importe le moteur (`just_audio_chat_engine.dart`) ; les
/// tests posent [FakeChatAudioEngine].
abstract interface class ChatAudioEngine {
  /// Charge [url] ; rend la durée si le moteur la connaît.
  Future<Duration?> load(String url);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> setSpeed(double speed);
  Future<void> stop();

  /// La position de lecture, plusieurs fois par seconde.
  Stream<Duration> positions();

  /// Émis quand la lecture arrive au bout.
  Stream<void> completions();

  Future<void> dispose();
}

/// Ce que les bulles lisent : **un seul** son à la fois, et où il en est.
@immutable
class ChatAudioState {
  const ChatAudioState({
    this.activeId,
    this.playing = false,
    this.loading = false,
    this.failed = false,
    this.position = Duration.zero,
    this.duration,
    this.speed = 1.0,
  });

  /// Le message dont le son est chargé — `null` : rien.
  final String? activeId;
  final bool playing;
  final bool loading;

  /// Le dernier chargement a échoué (hors ligne, média retiré).
  final bool failed;
  final Duration position;
  final Duration? duration;

  /// 1×, 1,5× ou 2×.
  final double speed;

  ChatAudioState copyWith({
    String? activeId,
    bool? playing,
    bool? loading,
    bool? failed,
    Duration? position,
    Duration? duration,
    double? speed,
  }) =>
      ChatAudioState(
        activeId: activeId ?? this.activeId,
        playing: playing ?? this.playing,
        loading: loading ?? this.loading,
        failed: failed ?? this.failed,
        position: position ?? this.position,
        duration: duration ?? this.duration,
        speed: speed ?? this.speed,
      );
}

/// Les vitesses proposées, dans l'ordre du bouton.
const List<double> kChatAudioSpeeds = [1.0, 1.5, 2.0];

/// **Un vocal à la fois** : démarrer un second arrête le premier (#98).
class ChatAudioController extends ValueNotifier<ChatAudioState> {
  ChatAudioController(this._engine) : super(const ChatAudioState()) {
    _positions = _engine.positions().listen((position) {
      if (value.activeId != null) value = value.copyWith(position: position);
    });
    _completions = _engine.completions().listen((_) {
      if (value.activeId == null) return;
      value = value.copyWith(playing: false, position: Duration.zero);
      unawaited(_engine.pause().then((_) => _engine.seek(Duration.zero)));
    });
  }

  final ChatAudioEngine _engine;
  late final StreamSubscription<Duration> _positions;
  late final StreamSubscription<void> _completions;

  /// **Lit ou met en pause** le son du message [id]. [resolveUrl] n'est appelé
  /// qu'au premier chargement — l'URL présignée, ou le fichier local d'un écho.
  Future<void> toggle(
    String id, {
    required Future<String?> Function() resolveUrl,
    Duration? knownDuration,
  }) async {
    if (value.activeId == id && !value.failed) {
      if (value.loading) return;
      if (value.playing) {
        value = value.copyWith(playing: false);
        await _engine.pause();
      } else {
        value = value.copyWith(playing: true);
        await _engine.play();
      }
      return;
    }

    // Un autre son jouait : il s'arrête. Un seul vocal à la fois.
    if (value.activeId != null) await _engine.stop();
    value = ChatAudioState(
      activeId: id,
      loading: true,
      duration: knownDuration,
      speed: value.speed,
    );

    final url = await resolveUrl();
    if (value.activeId != id) return; // Un troisième a pris la place.
    if (url == null) {
      value = value.copyWith(loading: false, failed: true);
      return;
    }
    try {
      final duration = await _engine.load(url);
      if (value.activeId != id) return;
      await _engine.setSpeed(value.speed);
      value = value.copyWith(
        loading: false,
        playing: true,
        duration: duration ?? knownDuration,
      );
      await _engine.play();
    } on Object {
      if (value.activeId == id) {
        value = value.copyWith(loading: false, playing: false, failed: true);
      }
    }
  }

  /// **1× → 1,5× → 2× → 1×.** La vitesse vaut pour les vocaux suivants.
  Future<void> cycleSpeed() async {
    final index = kChatAudioSpeeds.indexOf(value.speed);
    final next = kChatAudioSpeeds[(index + 1) % kChatAudioSpeeds.length];
    value = value.copyWith(speed: next);
    await _engine.setSpeed(next);
  }

  /// Saute à [fraction] (`0..1`) du son **en cours** — sans effet sur un autre.
  Future<void> seekTo(String id, double fraction) async {
    final duration = value.duration;
    if (value.activeId != id || duration == null) return;
    final target = duration * fraction.clamp(0.0, 1.0);
    value = value.copyWith(position: target);
    await _engine.seek(target);
  }

  /// Arrête tout (l'écran du fil se ferme).
  Future<void> stopAll() async {
    if (value.activeId == null) return;
    value = ChatAudioState(speed: value.speed);
    await _engine.stop();
  }

  @override
  void dispose() {
    unawaited(_positions.cancel());
    unawaited(_completions.cancel());
    unawaited(_engine.dispose());
    super.dispose();
  }
}

/// Double de test : aucun son, un journal de ce qu'on lui a demandé.
class FakeChatAudioEngine implements ChatAudioEngine {
  final List<String> calls = [];
  final StreamController<Duration> _positions = StreamController.broadcast();
  final StreamController<void> _completions = StreamController.broadcast();

  Duration? durationToReport = const Duration(seconds: 12);

  void emitPosition(Duration position) => _positions.add(position);
  void complete() => _completions.add(null);

  @override
  Future<Duration?> load(String url) async {
    calls.add('load $url');
    return durationToReport;
  }

  @override
  Future<void> play() async => calls.add('play');

  @override
  Future<void> pause() async => calls.add('pause');

  @override
  Future<void> seek(Duration position) async =>
      calls.add('seek ${position.inMilliseconds}');

  @override
  Future<void> setSpeed(double speed) async => calls.add('speed $speed');

  @override
  Future<void> stop() async => calls.add('stop');

  @override
  Stream<Duration> positions() => _positions.stream;

  @override
  Stream<void> completions() => _completions.stream;

  @override
  Future<void> dispose() async {
    await _positions.close();
    await _completions.close();
  }
}

/// Moteur **inerte** : sans plugin, ne joue rien et ne lève pas.
class InertChatAudioEngine implements ChatAudioEngine {
  const InertChatAudioEngine();

  @override
  Future<Duration?> load(String url) async => null;
  @override
  Future<void> play() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> seek(Duration position) async {}
  @override
  Future<void> setSpeed(double speed) async {}
  @override
  Future<void> stop() async {}
  @override
  Stream<Duration> positions() => const Stream.empty();
  @override
  Stream<void> completions() => const Stream.empty();
  @override
  Future<void> dispose() async {}
}
