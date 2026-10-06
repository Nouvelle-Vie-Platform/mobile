/// **Les coches d'un message à moi** (#142, tranche M3) — ✓, ✓✓, ✓✓ bleu.
library;

/// Où en est un message **à moi, confirmé par le serveur**.
///
/// Le « en cours d'envoi » et l'« échec » restent ceux de `MessageDelivery` :
/// ces trois états-ci ne commencent qu'une fois le message accepté.
enum ReceiptStatus {
  /// **✓** — le serveur l'a ; personne (ou pas tout le monde) ne l'a reçu.
  sent,

  /// **✓✓** — tous les destinataires l'ont reçu sur leur téléphone.
  delivered,

  /// **✓✓ bleu** — tous l'ont lu, et la réciprocité permet de le voir. Le
  /// serveur ne sert jamais un « lu » interdit : ce client n'a rien à filtrer.
  read,
}

/// L'état tiré d'une ligne `message_receipts` : `readAt` l'emporte (lu implique
/// reçu), puis `deliveredAt`. Aucune ligne : **✓**.
ReceiptStatus receiptStatusOf({DateTime? deliveredAt, DateTime? readAt}) {
  if (readAt != null) return ReceiptStatus.read;
  if (deliveredAt != null) return ReceiptStatus.delivered;
  return ReceiptStatus.sent;
}
