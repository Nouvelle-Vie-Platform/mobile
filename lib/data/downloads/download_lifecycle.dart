import '../local/downloads_dao.dart';
import '../local/mediatheque_dao.dart';
import '../local/tables/download_tables.dart';
import 'download_manager.dart';

/// **Le cycle de vie d'une copie téléchargée face aux évolutions serveur**
/// (#194, PRD §3.5 F15/F16, ADR-0039/0025).
///
/// Une fois un `.aac` sur le téléphone, deux événements serveur le touchent, et
/// ils demandent des gestes **opposés** :
///
/// - **révision** (le média a été re-transcodé) : `download.version` a changé
///   vs la version stockée sur la ligne `downloads`. La copie est *périmée*,
///   pas *invalide* → on la marque [DownloadState.outdated] (« mise à jour
///   disponible ») et on **garde le fichier**. Re-télécharger la remet à jour.
/// - **retrait** (dépublication) : l'enseignement a **quitté le magasin**
///   (rétractation `{id, deletedAt}`, ADR-0025) → on **purge** la copie (fichier
///   + tâche + ligne) et on dépose une **notification** que la page
///   Téléchargements affiche.
///
/// **Le magasin local est autoritaire** (ADR-0026) : [reconcile] se lit sur
/// l'état du store **après** une sync, jamais sur le delta brut. Un retrait se
/// lit à l'**absence** de la ligne `teachings` ; une révision à sa version.
///
/// [reconcile] est une **méthode explicite**, appelée après une sync réussie et
/// au démarrage / retour au premier plan (voir le câblage dans `app.dart`).
/// Elle ne monte aucun flux réactif : ce sont des lectures ponctuelles, donc
/// testables sans se heurter à l'horloge factice de `flutter test`.
class DownloadLifecycle {
  DownloadLifecycle({
    required DownloadsDao dao,
    required DownloadNotificationsDao notifications,
    required DownloadManager manager,
    required Future<TeachingSyncState?> Function(String contentId) syncStateFor,
    DateTime Function()? now,
  })  : _dao = dao,
        _notifications = notifications,
        _manager = manager,
        _syncStateFor = syncStateFor,
        _now = now ?? (() => DateTime.now().toUtc());

  final DownloadsDao _dao;
  final DownloadNotificationsDao _notifications;
  final DownloadManager _manager;
  final Future<TeachingSyncState?> Function(String contentId) _syncStateFor;
  final DateTime Function() _now;

  /// Confronte chaque téléchargement à l'état du magasin après une sync.
  Future<void> reconcile() async {
    final rows = await _dao.all();
    for (final row in rows) {
      final state = await _syncStateFor(row.contentId);

      if (state == null) {
        // **RETRAIT** — l'enseignement a quitté le magasin. On nomme la copie
        // **avant** de la purger : le titre a été dénormalisé au téléchargement
        // (`download_titles`), il survit à la disparition de la source. La purge
        // efface ensuite la ligne, le titre et le fichier.
        final title = await _dao.titleFor(row.contentId);
        await _notifications.add(
          contentId: row.contentId,
          title: title,
          createdAt: _now(),
        );
        await _manager.purge(row.contentId);
        continue;
      }

      // **RÉVISION** — version courante ≠ version téléchargée. Seul un
      // **complété** se marque périmé : la copie est entière et écoutable. Un
      // téléchargement en cours, en pause ou en échec n'est pas concerné —
      // il finira sur la version qu'il tirait, et sa reprise est le rôle du
      // `DownloadManager`, pas du cycle de vie.
      final current = state.downloadVersion;
      final stored = row.versionId;
      final revised = stored != null && current != null && current != stored;
      if (revised && row.state == DownloadState.complete) {
        await _dao.setState(
          contentId: row.contentId,
          state: DownloadState.outdated,
        );
      }
    }
  }
}
