// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mediatheque_dao.dart';

// ignore_for_file: type=lint
mixin _$MediathequeDaoMixin on DatabaseAccessor<AppDatabase> {
  $BranchesTable get branches => attachedDatabase.branches;
  $TeachingTypesTable get teachingTypes => attachedDatabase.teachingTypes;
  $ContributorsTable get contributors => attachedDatabase.contributors;
  $TeachingsTable get teachings => attachedDatabase.teachings;
  $TeachingGuestsTable get teachingGuests => attachedDatabase.teachingGuests;
  MediathequeDaoManager get managers => MediathequeDaoManager(this);
}

class MediathequeDaoManager {
  final _$MediathequeDaoMixin _db;
  MediathequeDaoManager(this._db);
  $$BranchesTableTableManager get branches =>
      $$BranchesTableTableManager(_db.attachedDatabase, _db.branches);
  $$TeachingTypesTableTableManager get teachingTypes =>
      $$TeachingTypesTableTableManager(_db.attachedDatabase, _db.teachingTypes);
  $$ContributorsTableTableManager get contributors =>
      $$ContributorsTableTableManager(_db.attachedDatabase, _db.contributors);
  $$TeachingsTableTableManager get teachings =>
      $$TeachingsTableTableManager(_db.attachedDatabase, _db.teachings);
  $$TeachingGuestsTableTableManager get teachingGuests =>
      $$TeachingGuestsTableTableManager(
          _db.attachedDatabase, _db.teachingGuests);
}
