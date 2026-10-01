// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_settings_dao.dart';

// ignore_for_file: type=lint
mixin _$DeviceSettingsDaoMixin on DatabaseAccessor<AppDatabase> {
  $DeviceSettingsTable get deviceSettings => attachedDatabase.deviceSettings;
  DeviceSettingsDaoManager get managers => DeviceSettingsDaoManager(this);
}

class DeviceSettingsDaoManager {
  final _$DeviceSettingsDaoMixin _db;
  DeviceSettingsDaoManager(this._db);
  $$DeviceSettingsTableTableManager get deviceSettings =>
      $$DeviceSettingsTableTableManager(
          _db.attachedDatabase, _db.deviceSettings);
}
