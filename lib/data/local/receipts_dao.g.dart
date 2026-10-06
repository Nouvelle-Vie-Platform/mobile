// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'receipts_dao.dart';

// ignore_for_file: type=lint
mixin _$ReceiptsDaoMixin on DatabaseAccessor<AppDatabase> {
  $MessageReceiptsTable get messageReceipts => attachedDatabase.messageReceipts;
  $DeliveryAcksTable get deliveryAcks => attachedDatabase.deliveryAcks;
  $GroupMessagesTable get groupMessages => attachedDatabase.groupMessages;
  ReceiptsDaoManager get managers => ReceiptsDaoManager(this);
}

class ReceiptsDaoManager {
  final _$ReceiptsDaoMixin _db;
  ReceiptsDaoManager(this._db);
  $$MessageReceiptsTableTableManager get messageReceipts =>
      $$MessageReceiptsTableTableManager(
          _db.attachedDatabase, _db.messageReceipts);
  $$DeliveryAcksTableTableManager get deliveryAcks =>
      $$DeliveryAcksTableTableManager(_db.attachedDatabase, _db.deliveryAcks);
  $$GroupMessagesTableTableManager get groupMessages =>
      $$GroupMessagesTableTableManager(_db.attachedDatabase, _db.groupMessages);
}
