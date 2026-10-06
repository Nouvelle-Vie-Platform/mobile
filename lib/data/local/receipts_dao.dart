import 'package:drift/drift.dart';

import 'app_database.dart';
import 'tables/group_tables.dart';
import 'tables/receipt_tables.dart';

part 'receipts_dao.g.dart';

/// **Les accusés, côté magasin** (#142, tranche M3).
///
/// Deux choses, et seulement deux :
///
/// - **lire** l'accusé de mes messages d'un fil (`message_receipts`, que la
///   synchronisation et le canal écrivent) — les coches ✓✓ et ✓✓ bleu ;
/// - tenir **ce que ce téléphone a déjà confirmé avoir reçu**
///   (`delivery_acks`, locale seule) — pour ne confirmer chaque message qu'une
///   fois.
///
/// La table répliquée n'est **jamais** écrite ici : c'est le travail de
/// `SyncDao`, par le registre (la règle du magasin).
@DriftAccessor(tables: [MessageReceipts, DeliveryAcks, GroupMessages])
class ReceiptsDao extends DatabaseAccessor<AppDatabase>
    with _$ReceiptsDaoMixin {
  ReceiptsDao(super.db);

  /// **Les accusés des messages d'un groupe**, par identifiant de message.
  ///
  /// Un message absent de la carte n'a pas d'accusé : il est **✓** s'il est
  /// confirmé par le serveur — personne ne l'a encore reçu.
  Stream<Map<String, MessageReceiptRow>> watchReceiptsOf(String groupId) {
    final query = select(messageReceipts)
      ..where((r) => r.groupId.equals(groupId));
    return query.watch().map((rows) => {for (final row in rows) row.id: row});
  }

  /// **Les messages des autres que ce téléphone n'a pas encore confirmés.**
  ///
  /// Ni les miens, ni ceux du serveur, ni ceux d'un auteur retiré (`authorId`
  /// nul : personne à prévenir). Seulement ceux arrivés après [since] : à la
  /// première ouverture d'une version qui confirme, l'historique entier ne
  /// part pas — seuls les récents comptent pour une coche qui se regarde.
  /// Les plus anciens d'abord, au plus [limit] (la borne du lot serveur).
  Future<List<String>> unacknowledgedFrom({
    required String me,
    required DateTime since,
    int limit = 200,
  }) async {
    final query = select(groupMessages)
      ..where(
        (m) =>
            m.isSystem.equals(false) &
            m.authorId.isNotNull() &
            m.authorId.equals(me).not() &
            m.createdAt.isBiggerThanValue(since) &
            notExistsQuery(
              select(deliveryAcks)..where((a) => a.messageId.equalsExp(m.id)),
            ),
      )
      ..orderBy([(m) => OrderingTerm.asc(m.createdAt)])
      ..limit(limit);
    final rows = await query.get();
    return [for (final row in rows) row.id];
  }

  /// **Ces messages sont confirmés** — ils ne repartiront plus. Idempotent.
  Future<void> acknowledge(Iterable<String> messageIds) async {
    await batch((b) {
      b.insertAll(
        deliveryAcks,
        [
          for (final id in messageIds)
            DeliveryAcksCompanion.insert(messageId: id),
        ],
        mode: InsertMode.insertOrIgnore,
      );
    });
  }
}
