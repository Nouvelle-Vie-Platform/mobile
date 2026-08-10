// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gathering_dao.dart';

// ignore_for_file: type=lint
mixin _$GatheringDaoMixin on DatabaseAccessor<AppDatabase> {
  $GatheringTypesTable get gatheringTypes => attachedDatabase.gatheringTypes;
  $GatheringsTable get gatherings => attachedDatabase.gatherings;
  $ContributorsTable get contributors => attachedDatabase.contributors;
  GatheringDaoManager get managers => GatheringDaoManager(this);
}

class GatheringDaoManager {
  final _$GatheringDaoMixin _db;
  GatheringDaoManager(this._db);
  $$GatheringTypesTableTableManager get gatheringTypes =>
      $$GatheringTypesTableTableManager(
          _db.attachedDatabase, _db.gatheringTypes);
  $$GatheringsTableTableManager get gatherings =>
      $$GatheringsTableTableManager(_db.attachedDatabase, _db.gatherings);
  $$ContributorsTableTableManager get contributors =>
      $$ContributorsTableTableManager(_db.attachedDatabase, _db.contributors);
}
