// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_channels_dao.dart';

// ignore_for_file: type=lint
mixin _$AuthChannelsDaoMixin on DatabaseAccessor<AppDatabase> {
  $AuthChannelsTable get authChannels => attachedDatabase.authChannels;
  AuthChannelsDaoManager get managers => AuthChannelsDaoManager(this);
}

class AuthChannelsDaoManager {
  final _$AuthChannelsDaoMixin _db;
  AuthChannelsDaoManager(this._db);
  $$AuthChannelsTableTableManager get authChannels =>
      $$AuthChannelsTableTableManager(_db.attachedDatabase, _db.authChannels);
}
