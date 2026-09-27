/// Doubles de la **reprise de lecture** (#43) et de la **mesure d'audience**
/// pour les tests d'écran.
///
/// Les deux vivent dans le même fichier de doubles mais restent **deux
/// familles** : rien n'y relie un rapport de progression à une remontée
/// d'écoute, et c'est exprès.
library;

import 'package:maison_du_miracle/data/measurement/play_reporter.dart';
import 'package:maison_du_miracle/data/measurement/play_spool.dart';
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

/// Rapporteur d'**écoute** qui n'envoie rien, et retient ce qu'on lui a confié.
///
/// À poser dans tout test qui monte l'écran de lecture, pour la raison exacte de
/// [FakePlaybackProgressReporter] : le défaut est l'implémentation **HTTP** dès
/// que `AppEnv.useBackend` est vrai — et il l'est hors surcharge.
///
/// Un double **séparé**, et non un champ de plus sur le précédent : c'est la
/// séparation des deux contrats que cette tranche doit garder vraie, et un
/// double unique la ferait disparaître des tests avant de la faire disparaître
/// du code.
class FakePlayReporter implements PlayReporter {
  /// Les contenus dont l'écoute serait partie, dans l'ordre.
  final List<String> reported = [];

  /// Ce que rend [report] — `false` simule un envoi qui n'est pas parti.
  bool delivered = true;

  @override
  Future<bool> report(String contentId) async {
    reported.add(contentId);
    return delivered;
  }
}

/// File d'attente **en mémoire** : ce qui a été classé, sans base de données.
class FakePlaySpool implements PlaySpool {
  final List<PendingPlay> entries = [];

  /// Nombre d'appels à [drain] — c'est ce qui prouve que l'ouverture d'un
  /// contenu vide bien la file.
  int drains = 0;

  @override
  Future<void> add(String contentId, {DateTime? at}) async {
    entries.add(
      PendingPlay(contentId: contentId, at: at ?? DateTime.utc(2026, 9, 27)),
    );
  }

  @override
  Future<int> drain(PlayReporter reporter, {DateTime? now}) async {
    drains++;
    var delivered = 0;
    while (entries.isNotEmpty) {
      if (!await reporter.report(entries.first.contentId)) break;
      entries.removeAt(0);
      delivered++;
    }
    return delivered;
  }

  @override
  Future<List<PendingPlay>> pending() async => List.unmodifiable(entries);
}
