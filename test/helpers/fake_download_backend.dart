import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/downloads/download_backend.dart';

/// **Le double de test de `background_downloader`.**
///
/// Aucun canal natif : le `DownloadManager` se vérifie entièrement sur la VM
/// Dart. On pilote ce que le moteur natif « ferait » — accepter ou refuser un
/// enqueue, quelles tâches il connaît encore — et on **émet** à la main les
/// rappels de progression et d'état pour observer ce que le manager écrit dans
/// Drift.
class FakeDownloadBackend implements DownloadBackend {
  final _events = StreamController<DownloadBackendEvent>.broadcast();

  /// Les specs passés à [enqueue], dans l'ordre — pour vérifier url, filename,
  /// contrainte wifi.
  final List<DownloadTaskSpec> enqueued = [];
  final List<String> paused = [];
  final List<String> resumed = [];
  final List<String> canceled = [];

  /// Ce que rend le prochain [enqueue]. `false` simule un refus du moteur.
  bool enqueueResult = true;

  /// Ce que rend le prochain [resume].
  bool resumeResult = true;

  /// Les tâches que le moteur natif « connaît encore » (réconciliation).
  Set<String> active = {};

  @override
  Future<bool> enqueue(DownloadTaskSpec spec) async {
    enqueued.add(spec);
    if (enqueueResult) active.add(spec.taskId);
    return enqueueResult;
  }

  @override
  Future<void> pause(String taskId) async => paused.add(taskId);

  @override
  Future<bool> resume(String taskId) async {
    resumed.add(taskId);
    return resumeResult;
  }

  @override
  Future<void> cancel(String taskId) async {
    canceled.add(taskId);
    active.remove(taskId);
  }

  @override
  Stream<DownloadBackendEvent> get events => _events.stream;

  @override
  Future<Set<String>> activeTaskIds() async => active;

  /// Émet un rappel comme le ferait le moteur natif, et laisse le manager le
  /// traiter (le `DownloadManager` écoute par un abonnement asynchrone).
  ///
  /// **Vide la file d'événements au lieu de compter les tours de boucle.** Deux
  /// `Future.delayed(Duration.zero)` suffisaient aux chemins courts et pas au
  /// plus long — le départ de zéro, qui enchaîne plusieurs écritures Drift. Le
  /// test lisait alors la ligne avant que le manager ait fini : il voyait
  /// `running` au lieu de `queued`, et le `_reEnqueue` resté en vol écrivait
  /// dans une base déjà fermée (« Can't re-open a database after closing it »).
  /// Vert sur le Flutter de la machine, rouge en CI — un nombre de tours ne
  /// décrit pas une attente, il la devine.
  Future<void> emit(DownloadBackendEvent event) async {
    _events.add(event);
    // Laisse l'abonnement recevoir, puis attend que le manager ait **fini**.
    await pumpEventQueue();
    await settle?.call();
  }

  /// Branché par le test sur `DownloadManager.settled` : la seule attente qui
  /// ne devine rien. Nul quand aucun manager n'écoute.
  Future<void> Function()? settle;

  Future<void> dispose() => _events.close();
}
