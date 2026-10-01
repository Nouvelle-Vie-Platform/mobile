// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'menu_dao.dart';

// ignore_for_file: type=lint
mixin _$MenuDaoMixin on DatabaseAccessor<AppDatabase> {
  $MenuEntriesTable get menuEntries => attachedDatabase.menuEntries;
  $TeachingTypesTable get teachingTypes => attachedDatabase.teachingTypes;
  $GatheringTypesTable get gatheringTypes => attachedDatabase.gatheringTypes;
  $TeachingsTable get teachings => attachedDatabase.teachings;
  $GatheringsTable get gatherings => attachedDatabase.gatherings;
  MenuDaoManager get managers => MenuDaoManager(this);
}

class MenuDaoManager {
  final _$MenuDaoMixin _db;
  MenuDaoManager(this._db);
  $$MenuEntriesTableTableManager get menuEntries =>
      $$MenuEntriesTableTableManager(_db.attachedDatabase, _db.menuEntries);
  $$TeachingTypesTableTableManager get teachingTypes =>
      $$TeachingTypesTableTableManager(_db.attachedDatabase, _db.teachingTypes);
  $$GatheringTypesTableTableManager get gatheringTypes =>
      $$GatheringTypesTableTableManager(
          _db.attachedDatabase, _db.gatheringTypes);
  $$TeachingsTableTableManager get teachings =>
      $$TeachingsTableTableManager(_db.attachedDatabase, _db.teachings);
  $$GatheringsTableTableManager get gatherings =>
      $$GatheringsTableTableManager(_db.attachedDatabase, _db.gatherings);
}
