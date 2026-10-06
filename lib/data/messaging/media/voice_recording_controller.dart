import 'dart:async';

import 'package:flutter/foundation.dart';

import 'voice_recorder.dart';

/// Le plafond d'un vocal, en secondes (règle d'Échanges : **10 minutes**). Le
/// serveur le sert aussi dans le ticket ; l'enregistreur s'arrête de lui-même
/// ici pour ne jamais produire un vocal qu'on refuserait.
const int kVoiceMaxSeconds = 10 * 60;

/// Le nombre de barres gardées pour la bulle (le serveur en accepte 64).
const int kVoiceWaveformBars = 48;

/// Un vocal enregistré, prêt à partir.
class RecordedVoice {
  const RecordedVoice({
    required this.path,
    required this.duration,
    required this.waveform,
  });

  final String path;
  final Duration duration;

  /// Hauteurs `0..100`, au plus [kVoiceWaveformBars].
  final List<int> waveform;
}

enum VoiceRecordingPhase {
  idle,

  /// Le doigt est posé : glisser à gauche annule, glisser vers le haut
  /// verrouille.
  recording,

  /// **Mains libres** : le doigt est levé, l'enregistrement continue ; on
  /// envoie ou on jette par un bouton.
  locked,
}

/// **L'enregistrement d'un vocal, comme WhatsApp** (M4, #143) : appui maintenu
/// sur le micro pour enregistrer, glisser pour annuler, verrouiller pour les
/// mains libres. L'état est ici, testable sans micro (un [VoiceRecorder]
/// double) ; le geste est dans `VoiceRecordButton`.
///
/// La durée se lit sur [clock] à chaque niveau reçu — pas de minuterie à soi :
/// le flux des niveaux bat déjà plusieurs fois par seconde.
class VoiceRecordingController extends ChangeNotifier {
  VoiceRecordingController({
    required VoiceRecorder recorder,
    required Future<String> Function() newPath,
    DateTime Function()? clock,
    this.maxSeconds = kVoiceMaxSeconds,
  })  : _recorder = recorder,
        _newPath = newPath,
        _clock = clock ?? DateTime.now;

  final VoiceRecorder _recorder;
  final Future<String> Function() _newPath;
  final DateTime Function() _clock;
  final int maxSeconds;

  VoiceRecordingPhase _phase = VoiceRecordingPhase.idle;
  VoiceRecordingPhase get phase => _phase;
  bool get isActive => _phase != VoiceRecordingPhase.idle;

  DateTime? _startedAt;
  Duration _elapsed = Duration.zero;
  Duration get elapsed => _elapsed;

  final List<double> _levels = [];

  /// Les derniers niveaux, pour la forme d'onde en direct (0..1).
  List<double> get recentLevels => _levels.length <= 40
      ? List.unmodifiable(_levels)
      : List.unmodifiable(_levels.sublist(_levels.length - 40));

  StreamSubscription<double>? _subscription;

  /// Rappelé quand le plafond arrête l'enregistrement de lui-même : le vocal
  /// part (il n'est pas perdu).
  void Function(RecordedVoice voice)? onAutoStop;

  /// **Commence** : permission (au premier appui, pas avant), puis
  /// enregistrement. Rend `false` si le micro est refusé.
  Future<bool> begin() async {
    if (isActive) return true;
    if (!await _recorder.ensurePermission()) return false;
    final path = await _newPath();
    await _recorder.start(path);
    _levels.clear();
    _startedAt = _clock();
    _elapsed = Duration.zero;
    _phase = VoiceRecordingPhase.recording;
    _subscription = _recorder.levels().listen(_onLevel);
    _notify();
    return true;
  }

  void _onLevel(double level) {
    if (!isActive) return;
    _levels.add(level.clamp(0.0, 1.0));
    final started = _startedAt;
    if (started != null) _elapsed = _clock().difference(started);
    _notify();
    if (_elapsed.inSeconds >= maxSeconds) {
      unawaited(_autoStop());
    }
  }

  Future<void> _autoStop() async {
    final voice = await finish();
    if (voice != null) onAutoStop?.call(voice);
  }

  /// **Verrouille** : mains libres.
  void lock() {
    if (_phase != VoiceRecordingPhase.recording) return;
    _phase = VoiceRecordingPhase.locked;
    _notify();
  }

  /// **Annule** : le fichier est jeté, rien ne part.
  Future<void> cancel() async {
    if (!isActive) return;
    await _end();
    await _recorder.cancel();
  }

  /// **Termine** et rend le vocal — ou `null` s'il est trop court pour être un
  /// vocal (moins d'une seconde : un appui de travers, pas un message).
  Future<RecordedVoice?> finish() async {
    if (!isActive) return null;
    final started = _startedAt;
    final duration = started == null ? _elapsed : _clock().difference(started);
    final levels = List<double>.of(_levels);
    await _end();
    final path = await _recorder.stop();
    if (path == null || duration < const Duration(seconds: 1)) return null;
    final capped = duration.inSeconds > maxSeconds
        ? Duration(seconds: maxSeconds)
        : duration;
    return RecordedVoice(
      path: path,
      duration: capped,
      waveform: waveformOf(levels),
    );
  }

  Future<void> _end() async {
    _phase = VoiceRecordingPhase.idle;
    await _subscription?.cancel();
    _subscription = null;
    _notify();
  }

  bool _disposed = false;

  /// Une fin asynchrone (annulation à la fermeture du fil) peut arriver après
  /// `dispose` : elle ne notifie plus personne.
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}

/// **La forme d'onde gardée pour la bulle** : les niveaux relevés, ramenés à
/// [bars] barres (moyenne par tranche), en hauteurs `0..100`.
@visibleForTesting
List<int> waveformOf(List<double> levels, {int bars = kVoiceWaveformBars}) {
  if (levels.isEmpty || bars <= 0) return const [];
  final count = levels.length < bars ? levels.length : bars;
  return List<int>.generate(count, (i) {
    final start = (i * levels.length) ~/ count;
    final end = ((i + 1) * levels.length) ~/ count;
    final slice = levels.sublist(start, end > start ? end : start + 1);
    final mean = slice.reduce((a, b) => a + b) / slice.length;
    return (mean * 100).round().clamp(0, 100);
  });
}
