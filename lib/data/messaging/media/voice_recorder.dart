import 'dart:async';

/// **L'enregistreur de vocaux**, derrière une couture (M4, #143 — reprend
/// #98).
///
/// Un seul fichier importe le greffon (`record_voice_recorder.dart`) ; les
/// tests posent [FakeVoiceRecorder] — sous `flutter test`, le canal du greffon
/// lève `MissingPluginException`.
///
/// La cible est celle de la règle d'Échanges : **AAC mono 32 kbit/s**, niveau
/// **normalisé** (gain automatique), **10 minutes** au plus — dix minutes à
/// 32 kbit/s pèsent ~2,4 Mo.
abstract interface class VoiceRecorder {
  /// **La permission du micro** — demandée au premier appui, pas avant.
  Future<bool> ensurePermission();

  /// Démarre l'enregistrement vers [path] (un `.m4a`).
  Future<void> start(String path);

  /// Le niveau, `0..1`, quelques fois par seconde pendant l'enregistrement —
  /// de quoi dessiner la forme d'onde en direct et la garder pour la bulle.
  Stream<double> levels();

  /// Arrête et rend le chemin du fichier, ou `null` s'il n'y en a pas.
  Future<String?> stop();

  /// Arrête et **jette** le fichier (glisser pour annuler).
  Future<void> cancel();

  Future<void> dispose();
}

/// Double de test : aucun micro, des niveaux que le test pousse lui-même.
class FakeVoiceRecorder implements VoiceRecorder {
  FakeVoiceRecorder({this.granted = true});

  bool granted;
  final StreamController<double> _levels = StreamController.broadcast();

  /// Le dernier chemin passé à [start], `null` hors enregistrement.
  String? recordingTo;
  final List<String> started = [];
  int stops = 0;
  int cancels = 0;

  /// Pousse un niveau, comme le ferait le micro.
  void emit(double level) => _levels.add(level);

  /// Retient [start] jusqu'à sa complétion — un micro réel met plusieurs
  /// centaines de millisecondes à démarrer (session audio, autorisation).
  Completer<void>? startGate;

  @override
  Future<bool> ensurePermission() async => granted;

  @override
  Future<void> start(String path) async {
    await startGate?.future;
    recordingTo = path;
    started.add(path);
  }

  @override
  Stream<double> levels() => _levels.stream;

  @override
  Future<String?> stop() async {
    stops++;
    final path = recordingTo;
    recordingTo = null;
    return path;
  }

  @override
  Future<void> cancel() async {
    cancels++;
    recordingTo = null;
  }

  @override
  Future<void> dispose() => _levels.close();
}
