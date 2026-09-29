// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_dao.dart';

// ignore_for_file: type=lint
mixin _$SyncDaoMixin on DatabaseAccessor<AppDatabase> {
  $SyncCursorsTable get syncCursors => attachedDatabase.syncCursors;
  $SyncStateTable get syncState => attachedDatabase.syncState;
  $ResyncTokensTable get resyncTokens => attachedDatabase.resyncTokens;
  $BranchesTable get branches => attachedDatabase.branches;
  $TeachingTypesTable get teachingTypes => attachedDatabase.teachingTypes;
  $ContributorsTable get contributors => attachedDatabase.contributors;
  $TeachingsTable get teachings => attachedDatabase.teachings;
  $TeachingGuestsTable get teachingGuests => attachedDatabase.teachingGuests;
  $GatheringTypesTable get gatheringTypes => attachedDatabase.gatheringTypes;
  $GatheringsTable get gatherings => attachedDatabase.gatherings;
  $StatusBackgroundsTable get statusBackgrounds =>
      attachedDatabase.statusBackgrounds;
  $OfficialAccountsTable get officialAccounts =>
      attachedDatabase.officialAccounts;
  $OfficialAccountMembershipsTable get officialAccountMemberships =>
      attachedDatabase.officialAccountMemberships;
  $AnnouncementsTable get announcements => attachedDatabase.announcements;
  $PlaybackProgressTable get playbackProgress =>
      attachedDatabase.playbackProgress;
  $LegalDocumentsTable get legalDocuments => attachedDatabase.legalDocuments;
  $SeasonsTable get seasons => attachedDatabase.seasons;
  $DecorTable get decor => attachedDatabase.decor;
  SyncDaoManager get managers => SyncDaoManager(this);
}

class SyncDaoManager {
  final _$SyncDaoMixin _db;
  SyncDaoManager(this._db);
  $$SyncCursorsTableTableManager get syncCursors =>
      $$SyncCursorsTableTableManager(_db.attachedDatabase, _db.syncCursors);
  $$SyncStateTableTableManager get syncState =>
      $$SyncStateTableTableManager(_db.attachedDatabase, _db.syncState);
  $$ResyncTokensTableTableManager get resyncTokens =>
      $$ResyncTokensTableTableManager(_db.attachedDatabase, _db.resyncTokens);
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
  $$GatheringTypesTableTableManager get gatheringTypes =>
      $$GatheringTypesTableTableManager(
          _db.attachedDatabase, _db.gatheringTypes);
  $$GatheringsTableTableManager get gatherings =>
      $$GatheringsTableTableManager(_db.attachedDatabase, _db.gatherings);
  $$StatusBackgroundsTableTableManager get statusBackgrounds =>
      $$StatusBackgroundsTableTableManager(
          _db.attachedDatabase, _db.statusBackgrounds);
  $$OfficialAccountsTableTableManager get officialAccounts =>
      $$OfficialAccountsTableTableManager(
          _db.attachedDatabase, _db.officialAccounts);
  $$OfficialAccountMembershipsTableTableManager
      get officialAccountMemberships =>
          $$OfficialAccountMembershipsTableTableManager(
              _db.attachedDatabase, _db.officialAccountMemberships);
  $$AnnouncementsTableTableManager get announcements =>
      $$AnnouncementsTableTableManager(_db.attachedDatabase, _db.announcements);
  $$PlaybackProgressTableTableManager get playbackProgress =>
      $$PlaybackProgressTableTableManager(
          _db.attachedDatabase, _db.playbackProgress);
  $$LegalDocumentsTableTableManager get legalDocuments =>
      $$LegalDocumentsTableTableManager(
          _db.attachedDatabase, _db.legalDocuments);
  $$SeasonsTableTableManager get seasons =>
      $$SeasonsTableTableManager(_db.attachedDatabase, _db.seasons);
  $$DecorTableTableManager get decor =>
      $$DecorTableTableManager(_db.attachedDatabase, _db.decor);
}
