import 'package:drift/drift.dart';

import 'app_database.dart';
import 'tables/download_tables.dart';

part 'downloads_dao.g.dart';

/// **Le magasin des téléchargements, en lecture et en écriture** (#190).
///
/// C'est lui qui peint le bouton (#192) et la page Téléchargements (#193) : les
/// écrans **observent** ses `Stream`, le `DownloadManager` y **écrit** l'état et
/// la progression que lui rapporte le moteur natif. Le réseau ne peint jamais
/// (ADR-0026).
///
/// **Il écrit ET supprime librement**, à la différence de `PlaybackDao` : la
/// table `downloads` est **locale seule**, jamais une collection répliquée. La
/// règle « le client n'efface jamais une ligne synchronisée » ne la concerne
/// pas — rien ici ne remonte au serveur, rien n'en redescend. Supprimer une
/// ligne (annulation, purge) est un geste normal et attendu.
///
/// Un DAO par domaine, comme les autres. Il ne joint rien : les métadonnées de
/// contenu (titre, image, `download.version` courant) vivent dans `teachings`,
/// et la jointure d'affichage se fait à la lecture, côté écran (#193).
@DriftAccessor(tables: [Downloads, DownloadTitles])
class DownloadsDao extends DatabaseAccessor<AppDatabase>
    with _$DownloadsDaoMixin {
  DownloadsDao(super.db);

  /// **Tous les téléchargements**, du plus récent au plus ancien. La page
  /// Téléchargements (#193) observe ce flux.
  Stream<List<DownloadRow>> watchAll() {
    return (select(downloads)..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  /// **Le téléchargement d'un contenu**, ou `null`. Le bouton 5 états (#192)
  /// observe ce flux pour un enseignement donné.
  Stream<DownloadRow?> watchForContent(String contentId) {
    return (select(downloads)..where((t) => t.contentId.equals(contentId)))
        .watchSingleOrNull();
  }

  /// **L'espace occupé sur le disque**, en octets — la somme des octets
  /// **reçus** (partiels compris, car ils occupent bien la place). La page
  /// Téléchargements (#193) affiche l'« espace total utilisé ».
  Stream<int> watchStorageUsage() {
    final total = downloads.bytesReceived.sum();
    final query = selectOnly(downloads)..addColumns([total]);
    return query.map((row) => row.read(total) ?? 0).watchSingle();
  }

  /// La ligne d'un contenu, en `Future` — pour le moteur (enqueue, réconcilie),
  /// pas pour un écran.
  Future<DownloadRow?> forContent(String contentId) {
    return (select(downloads)..where((t) => t.contentId.equals(contentId)))
        .getSingleOrNull();
  }

  /// La ligne portant cet identifiant de tâche natif — c'est ainsi qu'un rappel
  /// `background_downloader` (qui ne connaît que le `taskId`) retrouve sa ligne.
  Future<DownloadRow?> forTask(String taskId) {
    return (select(downloads)..where((t) => t.taskId.equals(taskId)))
        .getSingleOrNull();
  }

  /// Toutes les lignes, en `Future` — pour la réconciliation au démarrage.
  Future<List<DownloadRow>> all() => select(downloads).get();

  /// Écrit une ligne, en remplaçant celle du même contenu s'il y en avait une.
  Future<void> upsert(DownloadsCompanion row) {
    return into(downloads).insert(row, mode: InsertMode.insertOrReplace);
  }

  /// Met à jour les octets d'un contenu — l'écriture chaude, appelée à chaque
  /// rappel de progression.
  Future<void> updateProgress({
    required String contentId,
    required int bytesReceived,
    int? bytesTotal,
  }) {
    return (update(downloads)..where((t) => t.contentId.equals(contentId)))
        .write(
      DownloadsCompanion(
        bytesReceived: Value(bytesReceived),
        bytesTotal:
            bytesTotal == null ? const Value.absent() : Value(bytesTotal),
      ),
    );
  }

  /// Met à jour l'état d'un contenu, et ce qui l'accompagne. Les champs laissés
  /// à `null` **ne sont pas touchés** — un passage en `failed` conserve le
  /// `localPath` du partiel (F9).
  Future<void> setState({
    required String contentId,
    required DownloadState state,
    String? failureReason,
    bool clearFailureReason = false,
    String? taskId,
    String? localPath,
    int? bytesReceived,
  }) {
    return (update(downloads)..where((t) => t.contentId.equals(contentId)))
        .write(
      DownloadsCompanion(
        state: Value(state),
        failureReason: clearFailureReason
            ? const Value(null)
            : (failureReason == null
                ? const Value.absent()
                : Value(failureReason)),
        taskId: taskId == null ? const Value.absent() : Value(taskId),
        localPath: localPath == null ? const Value.absent() : Value(localPath),
        bytesReceived:
            bytesReceived == null ? const Value.absent() : Value(bytesReceived),
      ),
    );
  }

  /// Efface la ligne d'un contenu **et son titre dénormalisé**. Un geste
  /// **normal** ici (annulation, purge) : la table est locale seule. La
  /// suppression du fichier physique est du ressort du `DownloadManager`, qui
  /// l'appelle après avoir effacé les octets.
  Future<void> removeForContent(String contentId) async {
    await (delete(downloads)..where((t) => t.contentId.equals(contentId))).go();
    await (delete(downloadTitles)..where((t) => t.contentId.equals(contentId)))
        .go();
  }

  /// **Dénormalise le titre** d'un contenu au moment du téléchargement (#194) :
  /// il survivra à la disparition de l'enseignement (retrait) pour nommer la
  /// notification de purge. Remplace le titre précédent s'il y en avait un.
  Future<void> setTitle(String contentId, String? title) {
    return into(downloadTitles).insert(
      DownloadTitlesCompanion.insert(
        contentId: contentId,
        title: Value(title),
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  /// Le titre dénormalisé d'un contenu, ou `null` — lu par le cycle de vie au
  /// moment de purger, quand l'enseignement a déjà quitté le magasin.
  Future<String?> titleFor(String contentId) async {
    final row = await (select(downloadTitles)
          ..where((t) => t.contentId.equals(contentId)))
        .getSingleOrNull();
    return row?.title;
  }
}

/// **Le magasin des notifications de purge** (#194, F16) — locale seule.
///
/// Le cycle de vie (`DownloadLifecycle`) y **écrit** une entrée quand il purge
/// une copie locale à la suite d'un retrait serveur ; la page Téléchargements
/// l'**observe** et la rend dans son bandeau. Rejeter une notification, c'est
/// supprimer sa ligne — elle ne repassera pas (la rétractation qui l'a produite
/// concernait un `download` désormais purgé).
@DriftAccessor(tables: [DownloadNotifications])
class DownloadNotificationsDao extends DatabaseAccessor<AppDatabase>
    with _$DownloadNotificationsDaoMixin {
  DownloadNotificationsDao(super.db);

  /// **Toutes les notifications**, de la plus récente à la plus ancienne. Le
  /// bandeau de la page Téléchargements observe ce flux.
  Stream<List<DownloadNotificationRow>> watchAll() {
    return (select(downloadNotifications)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  /// Toutes les notifications en `Future` — pour les tests.
  Future<List<DownloadNotificationRow>> all() =>
      select(downloadNotifications).get();

  /// Dépose une notification de purge — le cycle de vie l'appelle **avant** de
  /// purger la ligne `downloads`, tant que son titre est encore lisible.
  Future<void> add({
    required String contentId,
    String? title,
    required DateTime createdAt,
  }) {
    return into(downloadNotifications).insert(
      DownloadNotificationsCompanion.insert(
        contentId: contentId,
        title: Value(title),
        createdAt: createdAt,
      ),
    );
  }

  /// **Rejette** une notification : le fidèle l'a vue. Elle ne repassera pas.
  Future<void> dismiss(int id) {
    return (delete(downloadNotifications)..where((t) => t.id.equals(id))).go();
  }
}
