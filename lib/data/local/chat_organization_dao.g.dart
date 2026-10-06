// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_organization_dao.dart';

// ignore_for_file: type=lint
mixin _$ChatOrganizationDaoMixin on DatabaseAccessor<AppDatabase> {
  $GroupsTable get groups => attachedDatabase.groups;
  $GroupMembersTable get groupMembers => attachedDatabase.groupMembers;
  $GroupMessagesTable get groupMessages => attachedDatabase.groupMessages;
  $PendingGroupMessagesTable get pendingGroupMessages =>
      attachedDatabase.pendingGroupMessages;
  $ProfilesTable get profiles => attachedDatabase.profiles;
  $GroupArrangementsTable get groupArrangements =>
      attachedDatabase.groupArrangements;
  $PendingGroupArrangementsTable get pendingGroupArrangements =>
      attachedDatabase.pendingGroupArrangements;
  ChatOrganizationDaoManager get managers => ChatOrganizationDaoManager(this);
}

class ChatOrganizationDaoManager {
  final _$ChatOrganizationDaoMixin _db;
  ChatOrganizationDaoManager(this._db);
  $$GroupsTableTableManager get groups =>
      $$GroupsTableTableManager(_db.attachedDatabase, _db.groups);
  $$GroupMembersTableTableManager get groupMembers =>
      $$GroupMembersTableTableManager(_db.attachedDatabase, _db.groupMembers);
  $$GroupMessagesTableTableManager get groupMessages =>
      $$GroupMessagesTableTableManager(_db.attachedDatabase, _db.groupMessages);
  $$PendingGroupMessagesTableTableManager get pendingGroupMessages =>
      $$PendingGroupMessagesTableTableManager(
          _db.attachedDatabase, _db.pendingGroupMessages);
  $$ProfilesTableTableManager get profiles =>
      $$ProfilesTableTableManager(_db.attachedDatabase, _db.profiles);
  $$GroupArrangementsTableTableManager get groupArrangements =>
      $$GroupArrangementsTableTableManager(
          _db.attachedDatabase, _db.groupArrangements);
  $$PendingGroupArrangementsTableTableManager get pendingGroupArrangements =>
      $$PendingGroupArrangementsTableTableManager(
          _db.attachedDatabase, _db.pendingGroupArrangements);
}
