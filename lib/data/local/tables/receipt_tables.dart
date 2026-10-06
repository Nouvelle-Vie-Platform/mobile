/// **Les accusés de mes messages, et ce que j'ai confirmé avoir reçu** (#142,
/// tranche M3 du plan `server-portal/docs/messagerie-whatsapp-plan.md`).
library;

import 'package:drift/drift.dart';

import 'mediatheque_tables.dart' show SyncedRow;

/// Collection `message_receipts` (partition `private`, **sans** tombstone) —
/// **l'accusé de chacun de mes messages**, tel que le serveur l'agrège :
/// `{ id, groupId, deliveredAt, readAt, updatedAt }`, `id` étant celui du
/// message.
///
/// - `deliveredAt` posé : **✓✓** — tous les destinataires l'ont rangé ;
/// - `readAt` posé : **✓✓ bleu** — tous l'ont lu, **et** la réciprocité permet
///   de le voir. Le serveur ne range jamais un « lu » interdit (piège 6 du
///   plan) : ce client n'a rien à filtrer, il affiche ce qu'il reçoit.
///
/// Servie par la synchronisation et par le canal (`receipt.updated`), rangée
/// par la même fonction (`messageReceiptRowOf`). Les deux instants ne reculent
/// jamais côté serveur. Pas de tombstone : un message purgé emporte son accusé,
/// et une coche sans message ne se peint nulle part.
@DataClassName('MessageReceiptRow')
class MessageReceipts extends Table with SyncedRow {
  @override
  String get tableName => 'message_receipts';

  /// L'identifiant **du message** (UUIDv7 serveur).
  TextColumn get id => text()();

  TextColumn get groupId => text()();

  DateTimeColumn get deliveredAt => dateTime().nullable()();

  DateTimeColumn get readAt => dateTime().nullable()();

  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// **Table locale seule** (#142) — les messages des autres dont **ce
/// téléphone** a confirmé la distribution (`POST /groups/messages/delivered`).
///
/// C'est l'outbox à l'envers : un message reçu **sans** ligne ici est à
/// confirmer. La route est idempotente (piège 5) : une ligne perdue ne coûte
/// qu'un renvoi sans effet. Dans aucun registre de synchronisation, sans
/// `sync_stamp`, et aucun cycle ne la touche.
@DataClassName('DeliveryAckRow')
class DeliveryAcks extends Table {
  @override
  String get tableName => 'delivery_acks';

  TextColumn get messageId => text()();

  @override
  Set<Column<Object>> get primaryKey => {messageId};
}
