// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bible_dao.dart';

// ignore_for_file: type=lint
mixin _$BibleDaoMixin on DatabaseAccessor<AppDatabase> {
  $BibleReadingStatesTable get bibleReadingStates =>
      attachedDatabase.bibleReadingStates;
  $LocalBibleReadingStateTable get localBibleReadingState =>
      attachedDatabase.localBibleReadingState;
  BibleDaoManager get managers => BibleDaoManager(this);
}

class BibleDaoManager {
  final _$BibleDaoMixin _db;
  BibleDaoManager(this._db);
  $$BibleReadingStatesTableTableManager get bibleReadingStates =>
      $$BibleReadingStatesTableTableManager(
          _db.attachedDatabase, _db.bibleReadingStates);
  $$LocalBibleReadingStateTableTableManager get localBibleReadingState =>
      $$LocalBibleReadingStateTableTableManager(
          _db.attachedDatabase, _db.localBibleReadingState);
}
