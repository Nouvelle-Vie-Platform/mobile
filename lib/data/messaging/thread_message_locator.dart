/// **Retrouver un message dans son fil** (#146, tranche M8) — pour ouvrir une
/// discussion sur le résultat d'une recherche.
///
/// Le fil s'affiche par fenêtre (les N messages les plus récents, #140). Pour
/// montrer un message, il faut une fenêtre qui le contienne — donc savoir à
/// quelle distance du bas il se trouve. S'il n'est pas dans le magasin (trouvé
/// par le serveur, au-delà de ce qui est chargé), on **remonte l'historique par
/// pages** (`GET /groups/:id/messages?before=`), rangées dans le magasin comme
/// d'habitude — contiguës, donc sans trou —, jusqu'à le rencontrer.
library;

import '../local/chat_organization_dao.dart';
import 'group_history.dart';

/// Remonte le fil jusqu'à un message.
class ThreadMessageLocator {
  ThreadMessageLocator({
    required ChatOrganizationDao dao,
    required GroupHistory history,
    this.maxPages = 20,
  })  : _dao = dao,
        _history = history;

  final ChatOrganizationDao _dao;
  final GroupHistory _history;

  /// La borne du nombre de pages demandées pour un seul message : au-delà, on
  /// ouvre le fil sans lui plutôt que de vider le forfait d'un fidèle.
  final int maxPages;

  /// **La fenêtre qui contient [messageId]** (sa place depuis le plus récent),
  /// ou `null` si on ne l'a pas trouvé — supprimé, hors d'atteinte, réseau
  /// absent. Le fil s'ouvre alors normalement.
  Future<int?> windowFor(String groupId, String messageId) async {
    for (var page = 0; page < maxPages; page++) {
      final position = await _dao.positionFromNewest(groupId, messageId);
      if (position != null) return position;

      final oldest = await _dao.oldestMessageIdOf(groupId);
      if (oldest == null) return null;
      final outcome =
          await _history.loadBefore(groupId: groupId, beforeId: oldest);
      if (outcome != HistoryOutcome.more) {
        return _dao.positionFromNewest(groupId, messageId);
      }
    }
    return _dao.positionFromNewest(groupId, messageId);
  }
}
