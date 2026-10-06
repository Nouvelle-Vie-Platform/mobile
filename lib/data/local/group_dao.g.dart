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
  $GroupMutesTable get groupMutes => attachedDatabase.groupMutes;
  $OfficialAccountsTable get officialAccounts =>
      attachedDatabase.officialAccounts;
  $ContributorsTable get contributors => attachedDatabase.contributors;
  $GroupArrangementsTable get groupArrangements =>
      attachedDatabase.groupArrangements;
  $PendingGroupArrangementsTable get pendingGroupArrangements =>
      attachedDatabase.pendingGroupArrangements;
  $GroupMessageReactionsTable get groupMessageReactions =>
      attachedDatabase.groupMessageReactions;
  $GroupMessageHidesTable get groupMessageHides =>
      attachedDatabase.groupMessageHides;
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
  $$GroupMutesTableTableManager get groupMutes =>
      $$GroupMutesTableTableManager(_db.attachedDatabase, _db.groupMutes);
  $$OfficialAccountsTableTableManager get officialAccounts =>
      $$OfficialAccountsTableTableManager(
          _db.attachedDatabase, _db.officialAccounts);
  $$ContributorsTableTableManager get contributors =>
      $$ContributorsTableTableManager(_db.attachedDatabase, _db.contributors);
  $$GroupArrangementsTableTableManager get groupArrangements =>
      $$GroupArrangementsTableTableManager(
          _db.attachedDatabase, _db.groupArrangements);
  $$PendingGroupArrangementsTableTableManager get pendingGroupArrangements =>
      $$PendingGroupArrangementsTableTableManager(
          _db.attachedDatabase, _db.pendingGroupArrangements);
  $$GroupMessageReactionsTableTableManager get groupMessageReactions =>
      $$GroupMessageReactionsTableTableManager(
          _db.attachedDatabase, _db.groupMessageReactions);
  $$GroupMessageHidesTableTableManager get groupMessageHides =>
      $$GroupMessageHidesTableTableManager(
          _db.attachedDatabase, _db.groupMessageHides);
}
