// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'group_dao.dart';

// ignore_for_file: type=lint
mixin _$GroupDaoMixin on DatabaseAccessor<AppDatabase> {
  $GroupsTable get groups => attachedDatabase.groups;
  $GroupMembersTable get groupMembers => attachedDatabase.groupMembers;
  $GroupMessagesTable get groupMessages => attachedDatabase.groupMessages;
  $GroupJoinRequestsTable get groupJoinRequests =>
      attachedDatabase.groupJoinRequests;
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
  $$GroupMessagesTableTableManager get groupMessages =>
      $$GroupMessagesTableTableManager(_db.attachedDatabase, _db.groupMessages);
  $$GroupJoinRequestsTableTableManager get groupJoinRequests =>
      $$GroupJoinRequestsTableTableManager(
          _db.attachedDatabase, _db.groupJoinRequests);
  $$OfficialAccountsTableTableManager get officialAccounts =>
      $$OfficialAccountsTableTableManager(
          _db.attachedDatabase, _db.officialAccounts);
  $$ContributorsTableTableManager get contributors =>
      $$ContributorsTableTableManager(_db.attachedDatabase, _db.contributors);
}
