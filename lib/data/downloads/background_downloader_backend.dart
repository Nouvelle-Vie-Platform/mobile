import 'dart:async';

import 'package:background_downloader/background_downloader.dart';

import 'download_backend.dart';

/// **La seule pièce du dépôt qui importe `background_downloader`** (#190) —
/// l'implémentation réelle de [DownloadBackend], derrière laquelle tout le reste
/// est aveugle, comme `JustAudioContentPlayer` l'est pour `just_audio`.
///
/// Elle ne prend **aucune décision** : elle transpose le vocabulaire du plugin
/// (`TaskStatus`, `TaskProgressUpdate`) vers celui de l'interface
/// ([DownloadBackendStatus], [DownloadProgressEvent]) et rien de plus. Les
/// décisions — quelle qualité, où, sous quelle contrainte, quel état écrire —
/// vivent dans `DownloadManager`. Ce mur de traduction évite qu'un renommage du
/// plugin traverse jusqu'à la table Drift.
///
/// **Ne s'instancie jamais sous `flutter test`** : ses canaux natifs lèvent. Le
/// harnais pose un `FakeDownloadBackend`.
class BackgroundDownloaderBackend implements DownloadBackend {
  BackgroundDownloaderBackend({FileDownloader? downloader})
      : _downloader = downloader ?? FileDownloader() {
    _statusSub = _downloader.updates.listen(_onUpdate);
  }

  /// Le sous-répertoire, sous les documents de l'application, où vivent les
  /// `.aac`. Le plugin résout le chemin absolu ; la lecture offline-first (#191)
  /// le lira dans `downloads.localPath`, écrit à la complétion.
  static const String _directory = 'teaching_downloads';

  final FileDownloader _downloader;
  final _events = StreamController<DownloadBackendEvent>.broadcast();
  StreamSubscription<TaskUpdate>? _statusSub;

  /// Les tâches connues, pour pouvoir les mettre en pause / reprendre (le plugin
  /// prend un `DownloadTask`, pas un identifiant). Alimenté à l'enqueue **et** à
  /// chaque rappel — ce qui les repeuple après un redémarrage de l'application.
  final _tasks = <String, DownloadTask>{};

  /// Active le suivi persistant et la notification de progression. À appeler une
  /// fois au démarrage, avant [DownloadBackend.activeTaskIds] et la
  /// réconciliation. Best-effort : un échec de configuration ne doit pas
  /// empêcher l'application de s'ouvrir.
  Future<void> initialize() async {
    try {
      await _downloader.trackTasks();
      _downloader.configureNotification(
        running: const TaskNotification(
          'Téléchargement',
          '{filename} — {progress}',
        ),
        complete:
            const TaskNotification('Téléchargement terminé', '{filename}'),
        progressBar: true,
      );
      await _downloader.resumeFromBackground();
    } on Object catch (_) {
      // Canal absent ou plateforme incomplète : on continue sans suivi natif.
    }
  }

  @override
  Future<bool> enqueue(DownloadTaskSpec spec) async {
    final task = DownloadTask(
      taskId: spec.taskId,
      url: spec.url,
      filename: spec.filename,
      directory: _directory,
      baseDirectory: BaseDirectory.applicationDocuments,
      updates: Updates.statusAndProgress,
      requiresWiFi: spec.requiresWifi,
      allowPause: true,
      retries: 3,
    );
    _tasks[spec.taskId] = task;
    return _downloader.enqueue(task);
  }

  @override
  Future<void> pause(String taskId) async {
    final task = await _taskFor(taskId);
    if (task != null) await _downloader.pause(task);
  }

  @override
  Future<bool> resume(String taskId) async {
    final task = await _taskFor(taskId);
    if (task == null) return false;
    return _downloader.resume(task);
  }

  @override
  Future<void> cancel(String taskId) async {
    await _downloader.cancelTaskWithId(taskId);
    _tasks.remove(taskId);
  }

  @override
  Stream<DownloadBackendEvent> get events => _events.stream;

  @override
  Future<Set<String>> activeTaskIds() async {
    final tasks = await _downloader.allTasks(includeTasksWaitingToRetry: true);
    return tasks.map((t) => t.taskId).toSet();
  }

  Future<void> dispose() async {
    await _statusSub?.cancel();
    await _events.close();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Traduction plugin → interface
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> _onUpdate(TaskUpdate update) async {
    final task = update.task;
    if (task is DownloadTask) _tasks[task.taskId] = task;

    switch (update) {
      case TaskProgressUpdate(:final progress, :final expectedFileSize):
        final total = expectedFileSize > 0 ? expectedFileSize : null;
        _events.add(
          DownloadProgressEvent(
            task.taskId,
            bytesReceived: total == null ? 0 : (progress * total).round(),
            bytesTotal: total,
          ),
        );
      case TaskStatusUpdate(:final status, :final exception):
        String? filePath;
        if (status == TaskStatus.complete && task is DownloadTask) {
          filePath = await task.filePath();
        }
        _events.add(
          DownloadStatusEvent(
            task.taskId,
            status: _mapStatus(status),
            filePath: filePath,
            reason: exception?.description,
          ),
        );
    }
  }

  DownloadBackendStatus _mapStatus(TaskStatus status) => switch (status) {
        TaskStatus.enqueued => DownloadBackendStatus.enqueued,
        TaskStatus.running => DownloadBackendStatus.running,
        TaskStatus.complete => DownloadBackendStatus.complete,
        TaskStatus.notFound => DownloadBackendStatus.notFound,
        TaskStatus.failed => DownloadBackendStatus.failed,
        TaskStatus.canceled => DownloadBackendStatus.canceled,
        TaskStatus.waitingToRetry => DownloadBackendStatus.waitingToRetry,
        TaskStatus.paused => DownloadBackendStatus.paused,
      };

  Future<DownloadTask?> _taskFor(String taskId) async {
    final known = _tasks[taskId];
    if (known != null) return known;
    final all = await _downloader.allTasks(includeTasksWaitingToRetry: true);
    for (final task in all) {
      if (task.taskId == taskId && task is DownloadTask) {
        _tasks[taskId] = task;
        return task;
      }
    }
    return null;
  }
}
