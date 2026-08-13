// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'playback_dao.dart';

// ignore_for_file: type=lint
mixin _$PlaybackDaoMixin on DatabaseAccessor<AppDatabase> {
  $PlaybackProgressTable get playbackProgress =>
      attachedDatabase.playbackProgress;
  $LocalPlaybackPositionsTable get localPlaybackPositions =>
      attachedDatabase.localPlaybackPositions;
  PlaybackDaoManager get managers => PlaybackDaoManager(this);
}

class PlaybackDaoManager {
  final _$PlaybackDaoMixin _db;
  PlaybackDaoManager(this._db);
  $$PlaybackProgressTableTableManager get playbackProgress =>
      $$PlaybackProgressTableTableManager(
          _db.attachedDatabase, _db.playbackProgress);
  $$LocalPlaybackPositionsTableTableManager get localPlaybackPositions =>
      $$LocalPlaybackPositionsTableTableManager(
          _db.attachedDatabase, _db.localPlaybackPositions);
}
