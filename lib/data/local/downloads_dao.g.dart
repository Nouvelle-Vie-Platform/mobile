// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'downloads_dao.dart';

// ignore_for_file: type=lint
mixin _$DownloadsDaoMixin on DatabaseAccessor<AppDatabase> {
  $DownloadsTable get downloads => attachedDatabase.downloads;
  $DownloadTitlesTable get downloadTitles => attachedDatabase.downloadTitles;
  DownloadsDaoManager get managers => DownloadsDaoManager(this);
}

class DownloadsDaoManager {
  final _$DownloadsDaoMixin _db;
  DownloadsDaoManager(this._db);
  $$DownloadsTableTableManager get downloads =>
      $$DownloadsTableTableManager(_db.attachedDatabase, _db.downloads);
  $$DownloadTitlesTableTableManager get downloadTitles =>
      $$DownloadTitlesTableTableManager(
          _db.attachedDatabase, _db.downloadTitles);
}

mixin _$DownloadNotificationsDaoMixin on DatabaseAccessor<AppDatabase> {
  $DownloadNotificationsTable get downloadNotifications =>
      attachedDatabase.downloadNotifications;
  DownloadNotificationsDaoManager get managers =>
      DownloadNotificationsDaoManager(this);
}

class DownloadNotificationsDaoManager {
  final _$DownloadNotificationsDaoMixin _db;
  DownloadNotificationsDaoManager(this._db);
  $$DownloadNotificationsTableTableManager get downloadNotifications =>
      $$DownloadNotificationsTableTableManager(
          _db.attachedDatabase, _db.downloadNotifications);
}
