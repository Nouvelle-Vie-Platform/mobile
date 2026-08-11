// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'announcement_dao.dart';

// ignore_for_file: type=lint
mixin _$AnnouncementDaoMixin on DatabaseAccessor<AppDatabase> {
  $AnnouncementsTable get announcements => attachedDatabase.announcements;
  $OfficialAccountsTable get officialAccounts =>
      attachedDatabase.officialAccounts;
  $OfficialAccountMembershipsTable get officialAccountMemberships =>
      attachedDatabase.officialAccountMemberships;
  $StatusBackgroundsTable get statusBackgrounds =>
      attachedDatabase.statusBackgrounds;
  AnnouncementDaoManager get managers => AnnouncementDaoManager(this);
}

class AnnouncementDaoManager {
  final _$AnnouncementDaoMixin _db;
  AnnouncementDaoManager(this._db);
  $$AnnouncementsTableTableManager get announcements =>
      $$AnnouncementsTableTableManager(_db.attachedDatabase, _db.announcements);
  $$OfficialAccountsTableTableManager get officialAccounts =>
      $$OfficialAccountsTableTableManager(
          _db.attachedDatabase, _db.officialAccounts);
  $$OfficialAccountMembershipsTableTableManager
      get officialAccountMemberships =>
          $$OfficialAccountMembershipsTableTableManager(
              _db.attachedDatabase, _db.officialAccountMemberships);
  $$StatusBackgroundsTableTableManager get statusBackgrounds =>
      $$StatusBackgroundsTableTableManager(
          _db.attachedDatabase, _db.statusBackgrounds);
}
