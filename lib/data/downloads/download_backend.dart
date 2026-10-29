import 'package:flutter/foundation.dart';

/// **L'abstraction du moteur de transfert en tâche de fond** — la porte unique
/// derrière laquelle vit `background_downloader` (#190).
///
/// Elle existe pour la même raison que `ContentPlayer` devant `just_audio` ou
/// `NetworkTransport` devant `connectivity_plus` : le plugin ouvre des canaux
/// natifs qui **lèvent sous `flutter test`**, et toute la logique du
/// `DownloadManager` (états, pré-check, réconciliation) doit se vérifier sur la
/// VM Dart. Un seul fichier du dépôt importe `background_downloader`
/// (`background_downloader_backend.dart`) ; tout le reste ne connaît que cette
/// interface, et les tests posent un [FakeDownloadBackend].
///
/// Elle est aussi le **contrat laissé aux issues suivantes** : #191–#194 ne
/// touchent jamais le plugin, elles passent par le `DownloadManager`, qui passe
/// par ici. Les décisions (wifi, disque, mapping d'état) vivent au-dessus, dans
/// le manager ; ce backend n'est qu'un transport — enqueue, pause, reprise,
/// annulation, et un flux d'événements bruts.
abstract interface class DownloadBackend {
  /// Met une tâche en file auprès du moteur natif. Rend `false` si le moteur
  /// refuse la tâche (le manager la marque alors en échec).
  Future<bool> enqueue(DownloadTaskSpec spec);

  /// Met en pause une tâche en cours. Sans effet si la tâche n'existe plus.
  Future<void> pause(String taskId);

  /// Reprend une tâche en pause **par `Range`** (le moteur natif rejoue depuis
  /// les octets déjà reçus). Rend `false` si la reprise est refusée.
  Future<bool> resume(String taskId);

  /// Annule une tâche. Le fichier partiel n'est pas garanti effacé par le
  /// moteur ; le manager s'en charge s'il le faut, par [deleteFile].
  Future<void> cancel(String taskId);

  /// **Efface les octets descendus**, désignés par le chemin que la complétion
  /// a rendu ([DownloadStatusEvent.filePath]). Sans effet s'il n'y a rien.
  ///
  /// Ici, et non dans le manager, parce qu'« un chemin » n'est un fichier que
  /// sur un appareil : dans un navigateur c'est une clé du `Cache`, et
  /// `dart:io` y lève dès le constructeur (#273). Le manager décide **quand**
  /// jeter les octets — annulation, purge après retrait, départ de zéro —, le
  /// transport qui les a écrits sait **comment**.
  Future<void> deleteFile(String path);

  /// Le flux **brut** des rappels du moteur : progression et changements
  /// d'état, tels qu'ils arrivent. Le manager les traduit et écrit dans Drift ;
  /// ce flux ne peint jamais un écran (ADR-0026).
  Stream<DownloadBackendEvent> get events;

  /// Les identifiants de tâches que le moteur natif **connaît encore**. Sert la
  /// réconciliation au démarrage : une ligne Drift `running` dont le `taskId`
  /// n'est plus là (application tuée, tâche oubliée) est à ré-enqueuer.
  Future<Set<String>> activeTaskIds();
}

/// Ce qu'il faut au moteur natif pour lancer un transfert.
///
/// Volontairement pauvre : ni qualité, ni contenu, ni politique. Le manager a
/// déjà tout décidé (quelle rendition, où, sous quelle contrainte) — ce spec
/// n'est que le résultat de ses décisions.
@immutable
class DownloadTaskSpec {
  const DownloadTaskSpec({
    required this.taskId,
    required this.url,
    required this.filename,
    this.requiresWifi = true,
  });

  /// L'identifiant que le manager a frappé et rangé dans la ligne Drift : c'est
  /// lui qui recolle les rappels à la ligne.
  final String taskId;

  /// L'URL absolue du fichier `.aac` (répond au `Range`, ADR-0038).
  final String url;

  /// Le nom de fichier sur l'appareil. Le moteur natif résout le répertoire de
  /// base (documents de l'application) ; le chemin absolu revient dans
  /// l'événement de complétion.
  final String filename;

  /// Contrainte **wifi par défaut** (F8). `true` = le moteur natif ne démarre
  /// pas sur cellulaire et rapporte l'attente ; le manager la reflète en
  /// [DownloadState.waitingWifi].
  final bool requiresWifi;

  @override
  bool operator ==(Object other) =>
      other is DownloadTaskSpec &&
      other.taskId == taskId &&
      other.url == url &&
      other.filename == filename &&
      other.requiresWifi == requiresWifi;

  @override
  int get hashCode => Object.hash(taskId, url, filename, requiresWifi);
}

/// Un rappel du moteur natif — progression **ou** changement d'état.
@immutable
sealed class DownloadBackendEvent {
  const DownloadBackendEvent(this.taskId);

  /// La tâche concernée. Le manager retrouve la ligne Drift par lui.
  final String taskId;
}

/// La tâche a avancé : [bytesReceived] sur [bytesTotal] (ce dernier `null` tant
/// que le moteur ne connaît pas la taille — mais le manager la connaît déjà par
/// `download.bytes`, il n'en dépend pas).
@immutable
class DownloadProgressEvent extends DownloadBackendEvent {
  const DownloadProgressEvent(
    super.taskId, {
    required this.bytesReceived,
    this.bytesTotal,
  });

  final int bytesReceived;
  final int? bytesTotal;

  @override
  bool operator ==(Object other) =>
      other is DownloadProgressEvent &&
      other.taskId == taskId &&
      other.bytesReceived == bytesReceived &&
      other.bytesTotal == bytesTotal;

  @override
  int get hashCode => Object.hash(taskId, bytesReceived, bytesTotal);
}

/// **Pourquoi la tâche a échoué**, en vocabulaire d'interface — jamais la
/// phrase brute du moteur natif.
///
/// Trois familles seulement, parce que le manager n'en tire que trois
/// **gestes** : repartir de zéro, conserver le partiel faute de place, ou
/// réessayer. Le mur de traduction range les exceptions du plugin ici ; le
/// manager n'a plus à lire une description en anglais pour décider.
enum DownloadBackendFailure {
  /// **La reprise est impossible** : le moteur a comparé l'`ETag` porté par le
  /// `206` à celui gardé au premier tir et il a changé (ou il est faible), ou
  /// le fichier temporaire a disparu. Le partiel ne vaut plus rien — la seule
  /// issue est de **repartir de zéro**.
  ///
  /// C'est **la** garde de reprise de cette origine, et elle ne peut pas passer
  /// par `If-Range` : mesuré en production le 2026-10-15, RustFS **ignore**
  /// `If-Range` et répond `206` même sur un validateur périmé (streaming
  /// ADR-0012, PRD §6 spike 3). Armer l'en-tête ne protégerait de rien ; la
  /// comparaison d'`ETag` est donc faite pour de bon, jamais déléguée au
  /// serveur.
  resume,

  /// **Plus de place sur le disque**, constaté par le moteur au moment d'écrire
  /// — le second filet derrière le pré-check de taille (F9). Partiel conservé.
  insufficientSpace,

  /// Tout le reste — réseau, HTTP, inconnu.
  other,
}

/// La tâche a changé d'état. [filePath] n'est renseigné qu'à la complétion (le
/// chemin absolu résolu par le moteur), [failure] qu'à l'échec.
@immutable
class DownloadStatusEvent extends DownloadBackendEvent {
  const DownloadStatusEvent(
    super.taskId, {
    required this.status,
    this.filePath,
    this.failure,
  });

  final DownloadBackendStatus status;
  final String? filePath;

  /// Le motif, **classé** (voir [DownloadBackendFailure]). Nul hors échec.
  final DownloadBackendFailure? failure;

  @override
  bool operator ==(Object other) =>
      other is DownloadStatusEvent &&
      other.taskId == taskId &&
      other.status == status &&
      other.filePath == filePath &&
      other.failure == failure;

  @override
  int get hashCode => Object.hash(taskId, status, filePath, failure);
}

/// Les états **bruts** du moteur natif, avant traduction en [DownloadState].
///
/// Ils recopient les états de `background_downloader` (`TaskStatus`) pour que le
/// backend réel n'ait aucune décision à prendre : il transpose un à un, le
/// manager traduit. Séparer les deux vocabulaires évite qu'un renommage du
/// plugin traverse jusqu'à la table.
enum DownloadBackendStatus {
  enqueued,
  running,
  paused,
  complete,
  failed,
  canceled,

  /// Le moteur attend un réseau autorisé (wifi requis, appareil sur cellulaire).
  waitingToRetry,

  /// Le moteur ne connaît pas (plus) cette tâche.
  notFound,
}
