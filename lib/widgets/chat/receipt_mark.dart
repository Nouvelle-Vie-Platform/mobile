import 'package:flutter/material.dart';

import '../../l10n/l10n_extension.dart';
import '../../models/receipt_view.dart';

/// Le bleu des coches « lu ». Le même que WhatsApp, et pour la même raison :
/// c'est la seule couleur qui dit « lu » sans légende.
const Color kReceiptReadColor = Color(0xFF53BDEB);

/// **Les coches d'un message à moi, confirmé** (#142, tranche M3) — posées par
/// `ChatBubble` à la place de la coche simple d'envoi.
///
/// - **✓** : le serveur l'a ;
/// - **✓✓** : tous les destinataires l'ont reçu ;
/// - **✓✓ bleu** : tous l'ont lu — et la réciprocité permet de le voir (le
///   serveur ne sert jamais un « lu » interdit).
///
/// Chaque état porte une clé (`receipt_sent`, `receipt_delivered`,
/// `receipt_read`) et un libellé d'accessibilité : une coche bleue ne se voit
/// pas au lecteur d'écran.
class ReceiptMark extends StatelessWidget {
  const ReceiptMark({super.key, required this.status});

  final ReceiptStatus status;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final grey = Colors.white.withValues(alpha: 0.9);
    final (icon, color, label, key) = switch (status) {
      ReceiptStatus.sent => (
          Icons.check,
          grey,
          l.chatReceiptSent,
          const Key('receipt_sent'),
        ),
      ReceiptStatus.delivered => (
          Icons.done_all,
          grey,
          l.chatReceiptDelivered,
          const Key('receipt_delivered'),
        ),
      ReceiptStatus.read => (
          Icons.done_all,
          kReceiptReadColor,
          l.chatReceiptRead,
          const Key('receipt_read'),
        ),
    };
    return Semantics(
      label: label,
      child: Icon(icon, key: key, size: 15, color: color),
    );
  }
}
