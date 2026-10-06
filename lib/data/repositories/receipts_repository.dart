/// **Les coches de mes messages, lues dans le magasin** (#142, tranche M3).
///
/// Un repository à part plutôt qu'une méthode de plus sur `EchangesRepository`
/// : les coches ne concernent que mes messages, elles arrivent par leur propre
/// collection (`message_receipts`), et un écran qui ne les montre pas n'a pas à
/// les connaître. Même découpage que partout : un double vide (le défaut sans
/// backend, sans session, et dans `pumpScreen` — un flux Drift attendu sous
/// l'horloge factice du harnais fige le montage), et l'implémentation
/// adossée au magasin.
library;

import '../../models/receipt_view.dart';
import '../local/receipts_dao.dart';

abstract interface class ReceiptsRepository {
  /// Les coches des messages de [groupId], par identifiant de message. Un
  /// message absent de la carte est **✓** s'il est confirmé.
  Stream<Map<String, ReceiptStatus>> receiptsOf(String groupId);
}

/// **Aucune coche connue** — tout message confirmé reste ✓.
class EmptyReceiptsRepository implements ReceiptsRepository {
  const EmptyReceiptsRepository();

  @override
  Stream<Map<String, ReceiptStatus>> receiptsOf(String groupId) =>
      Stream.value(const {});
}

/// Double de test : des coches données d'avance, par groupe.
class InMemoryReceiptsRepository implements ReceiptsRepository {
  const InMemoryReceiptsRepository(this._byGroup);

  final Map<String, Map<String, ReceiptStatus>> _byGroup;

  @override
  Stream<Map<String, ReceiptStatus>> receiptsOf(String groupId) =>
      Stream.value(_byGroup[groupId] ?? const {});
}

/// Le magasin : la collection `message_receipts`, que la synchronisation et le
/// canal (`receipt.updated`) remplissent.
class StoreReceiptsRepository implements ReceiptsRepository {
  StoreReceiptsRepository(this._dao);

  final ReceiptsDao _dao;

  @override
  Stream<Map<String, ReceiptStatus>> receiptsOf(String groupId) =>
      _dao.watchReceiptsOf(groupId).map(
            (rows) => {
              for (final entry in rows.entries)
                entry.key: receiptStatusOf(
                  deliveredAt: entry.value.deliveredAt,
                  readAt: entry.value.readAt,
                ),
            },
          );
}
