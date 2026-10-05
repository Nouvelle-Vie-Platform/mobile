// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'group_dao.dart';

// ignore_for_file: type=lint
mixin _$GroupDaoMixin on DatabaseAccessor<AppDatabase> {
  $GroupsTable get groups => attachedDatabase.groups;
  $GroupMembersTable get groupMembers => attachedDatabase.groupMembers;
  $GroupJoinRequestsTable get groupJoinRequests =>
      attachedDatabase.groupJoinRequests;
  $GroupMessagesTable get groupMessages => attachedDatabase.groupMessages;
  $ProfilesTable get profiles => attachedDatabase.profiles;
  $PendingGroupMessagesTable get pendingGroupMessages =>
      attachedDatabase.pendingGroupMessages;
  $GroupReadsTable get groupReads => attachedDatabase.groupReads;
  $PendingGroupReadsTable get pendingGroupReads =>
      attachedDatabase.pendingGroupReads;
  $OfficialAccountsTable get officialAccounts =>
      attachedDatabase.officialAccounts;
  $ContributorsTable get contributors => attachedDatabase.contributors;
  GroupDaoManager get managers => GroupDaoManager(this);
}

class GroupDaoManager {
  final _$GroupDaoMixin _db;
  GroupDaoManager(this._db);
  $$GroupsTableTableManager get groups =>
      $$GroupsTableTableManager(_db.attachedDatabase, _db.groups);
  $$GroupMembersTableTableManager get groupMembers =>
      $$GroupMembersTableTableManager(_db.attachedDatabase, _db.groupMembers);
  $$GroupJoinRequestsTableTableManager get groupJoinRequests =>
      $$GroupJoinRequestsTableTableManager(
          _db.attachedDatabase, _db.groupJoinRequests);
  $$GroupMessagesTableTableManager get groupMessages =>
      $$GroupMessagesTableTableManager(_db.attachedDatabase, _db.groupMessages);
  $$ProfilesTableTableManager get profiles =>
      $$ProfilesTableTableManager(_db.attachedDatabase, _db.profiles);
  $$PendingGroupMessagesTableTableManager get pendingGroupMessages =>
      $$PendingGroupMessagesTableTableManager(
          _db.attachedDatabase, _db.pendingGroupMessages);
  $$GroupReadsTableTableManager get groupReads =>
      $$GroupReadsTableTableManager(_db.attachedDatabase, _db.groupReads);
  $$PendingGroupReadsTableTableManager get pendingGroupReads =>
      $$PendingGroupReadsTableTableManager(
          _db.attachedDatabase, _db.pendingGroupReads);
  $$OfficialAccountsTableTableManager get officialAccounts =>
      $$OfficialAccountsTableTableManager(
          _db.attachedDatabase, _db.officialAccounts);
  $$ContributorsTableTableManager get contributors =>
      $$ContributorsTableTableManager(_db.attachedDatabase, _db.contributors);
}
