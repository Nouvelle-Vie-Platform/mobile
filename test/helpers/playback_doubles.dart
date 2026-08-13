/// Doubles de la **reprise de lecture** (#43) pour les tests d'écran.
library;

import 'package:maison_du_miracle/data/repositories/playback_progress_reporter.dart';

/// Rapporteur de progression **qui n'envoie rien**, et retient ce qu'on lui a
/// confié.
///
/// À poser dans tout test qui monte l'écran de lecture, pour la même raison que
/// les repositories en mémoire de `pumpScreen` : le rapporteur par défaut est
/// l'implémentation **HTTP** dès que `AppEnv.useBackend` est vrai — et il l'est
/// hors surcharge. Un écran de lecture ouvert dans un test posterait donc sa
/// progression sur une socket que `flutter test` refuse, et laisserait derrière
/// lui la minuterie de Dio : « A Timer is still pending even after the widget
/// tree was disposed ».
class FakePlaybackProgressReporter implements PlaybackProgressReporter {
  /// Ce qui serait parti, dans l'ordre.
  final List<PlaybackProgressReport> reports = [];

  /// Ce que rend [report] — `false` simule un envoi qui n'est pas parti.
  bool delivered = true;

  @override
  Future<bool> report(PlaybackProgressReport report) async {
    reports.add(report);
    return delivered;
  }
}
