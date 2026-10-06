// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'interaction_dao.dart';

// ignore_for_file: type=lint
mixin _$InteractionDaoMixin on DatabaseAccessor<AppDatabase> {
  $MyInteractionsTable get myInteractions => attachedDatabase.myInteractions;
  InteractionDaoManager get managers => InteractionDaoManager(this);
}

class InteractionDaoManager {
  final _$InteractionDaoMixin _db;
  InteractionDaoManager(this._db);
  $$MyInteractionsTableTableManager get myInteractions =>
      $$MyInteractionsTableTableManager(
          _db.attachedDatabase, _db.myInteractions);
}
