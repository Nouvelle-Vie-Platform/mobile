/// **Confirmer la distribution — le ✓✓ des autres** (#142, tranche M3).
///
/// WhatsApp passe un message à ✓✓ quand il est **sur le téléphone** du
/// destinataire. Ici, c'est l'instant où ce téléphone l'a **rangé** dans son
/// magasin — par le tirage ou par le canal. Ce fichier dit au serveur, par lot,
/// « ceux-là sont arrivés » (`POST /groups/messages/delivered`).
///
/// ## Quand
///
/// - après **chaque cycle de synchronisation réussi** (le renvoi de la
///   messagerie, `messagingOutboxProvider`) ;
/// - à chaque **`message.created` d'un autre** reçu par le canal.
///
/// ## Jamais deux fois, et sans rien perdre
///
/// Ce qui est confirmé est noté dans `delivery_acks` (locale seule) **après**
/// la réponse du serveur ; ce qui ne l'est pas repart au prochain passage. La
/// route est idempotente (piège 5) : un lot rejoué n'écrit rien de plus. Un
/// `4xx` (le lot ne passera jamais tel quel) est noté aussi, pour ne pas
/// tourner en boucle ; une panne ne note rien.
///
/// Seuls les messages des [kDeliveryHorizon] derniers jours sont confirmés : à
/// la première ouverture d'une version qui confirme, l'historique entier ne
/// part pas — une coche ne se regarde que sur des messages récents.
library;

import '../local/receipts_dao.dart';
import 'messaging_signals_api.dart';

/// La fenêtre des messages qu'on confirme encore.
const Duration kDeliveryHorizon = Duration(days: 3);

/// La taille d'un lot — la borne serveur.
const int kDeliveryBatchSize = 200;

class DeliveryAcknowledger {
  DeliveryAcknowledger({
    required this.me,
    required ReceiptsDao dao,
    required MessagingSignalsApi api,
    DateTime Function()? now,
  })  : _dao = dao,
        _api = api,
        _now = now ?? DateTime.now;

  /// Moi : mes propres messages ne s'accusent pas.
  final String me;

  final ReceiptsDao _dao;
  final MessagingSignalsApi _api;
  final DateTime Function() _now;

  bool _running = false;
  bool _again = false;

  /// **Confirme tout ce qui attend**, lot après lot. Un appel pendant un
  /// passage en cours ne double pas les requêtes : il relance un tour à la fin.
  Future<void> flush() async {
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    try {
      do {
        _again = false;
        await _drain();
      } while (_again);
    } finally {
      _running = false;
    }
  }

  Future<void> _drain() async {
    // Borné : au plus quelques lots par passage, le cycle suivant reprend.
    for (var round = 0; round < 10; round++) {
      final ids = await _dao.unacknowledgedFrom(
        me: me,
        since: _now().toUtc().subtract(kDeliveryHorizon),
        limit: kDeliveryBatchSize,
      );
      if (ids.isEmpty) return;

      final outcome = await _api.confirmDeliveries(ids);
      if (outcome == DeliveryOutcome.unreachable) return;
      await _dao.acknowledge(ids);
      if (ids.length < kDeliveryBatchSize) return;
    }
  }
}
