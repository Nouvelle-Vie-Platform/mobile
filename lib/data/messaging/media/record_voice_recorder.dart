import 'dart:io';
import 'dart:math' as math;

import 'package:record/record.dart';

import 'voice_recorder.dart';

/// **Le seul fichier du dépôt qui importe `record`** (M4, #143).
///
/// `record` 7 : maintenu, **Swift Package**, encodeur AAC natif des deux côtés
/// (`MediaRecorder` / `AVAudioRecorder`) — le vocal sort à la cible sans
/// transcodage. `autoGain` est le geste de **normalisation** du cadrage : deux
/// vocaux consécutifs ne doivent pas faire sursauter l'auditeur.
///
/// Permission : `RECORD_AUDIO` (Android, déclarée au manifeste) et
/// `NSMicrophoneUsageDescription` (iOS), demandées **au premier appui** sur le
/// micro, jamais au démarrage de l'application.
class RecordVoiceRecorder implements VoiceRecorder {
  RecordVoiceRecorder({AudioRecorder? recorder})
      : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;

  /// La cible de la règle d'Échanges.
  static const RecordConfig config = RecordConfig(
    encoder: AudioEncoder.aacLc,
    bitRate: 32000,
    sampleRate: 22050,
    numChannels: 1,
    autoGain: true,
    noiseSuppress: true,
  );

  @override
  Future<bool> ensurePermission() async {
    try {
      return await _recorder.hasPermission();
    } on Object {
      return false;
    }
  }

  @override
  Future<void> start(String path) => _recorder.start(config, path: path);

  @override
  Stream<double> levels() => _recorder
      .onAmplitudeChanged(const Duration(milliseconds: 120))
      // `current` est en dBFS (de -160 à 0) : ramené à 0..1 sur les 50 dB
      // utiles d'une voix — en deçà, c'est du silence.
      .map((amplitude) => ((amplitude.current + 50) / 50).clamp(0.0, 1.0))
      .map((level) => math.sqrt(level));

  @override
  Future<String?> stop() => _recorder.stop();

  @override
  Future<void> cancel() async {
    // `cancel` arrête **et** efface le fichier.
    try {
      await _recorder.cancel();
    } on FileSystemException {
      // Déjà parti.
    }
  }

  @override
  Future<void> dispose() => _recorder.dispose();
}
