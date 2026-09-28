// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'season_dao.dart';

// ignore_for_file: type=lint
mixin _$SeasonDaoMixin on DatabaseAccessor<AppDatabase> {
  $SeasonsTable get seasons => attachedDatabase.seasons;
  $DecorTable get decor => attachedDatabase.decor;
  SeasonDaoManager get managers => SeasonDaoManager(this);
}

class SeasonDaoManager {
  final _$SeasonDaoMixin _db;
  SeasonDaoManager(this._db);
  $$SeasonsTableTableManager get seasons =>
      $$SeasonsTableTableManager(_db.attachedDatabase, _db.seasons);
  $$DecorTableTableManager get decor =>
      $$DecorTableTableManager(_db.attachedDatabase, _db.decor);
}
