// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_pages_dao.dart';

// ignore_for_file: type=lint
mixin _$MediaPagesDaoMixin on DatabaseAccessor<AppDatabase> {
  $MediaPagesTable get mediaPages => attachedDatabase.mediaPages;
  $MediaPageChipsTable get mediaPageChips => attachedDatabase.mediaPageChips;
  $MediaPageSectionsTable get mediaPageSections =>
      attachedDatabase.mediaPageSections;
  $TeachingTypesTable get teachingTypes => attachedDatabase.teachingTypes;
  $GatheringTypesTable get gatheringTypes => attachedDatabase.gatheringTypes;
  MediaPagesDaoManager get managers => MediaPagesDaoManager(this);
}

class MediaPagesDaoManager {
  final _$MediaPagesDaoMixin _db;
  MediaPagesDaoManager(this._db);
  $$MediaPagesTableTableManager get mediaPages =>
      $$MediaPagesTableTableManager(_db.attachedDatabase, _db.mediaPages);
  $$MediaPageChipsTableTableManager get mediaPageChips =>
      $$MediaPageChipsTableTableManager(
          _db.attachedDatabase, _db.mediaPageChips);
  $$MediaPageSectionsTableTableManager get mediaPageSections =>
      $$MediaPageSectionsTableTableManager(
          _db.attachedDatabase, _db.mediaPageSections);
  $$TeachingTypesTableTableManager get teachingTypes =>
      $$TeachingTypesTableTableManager(_db.attachedDatabase, _db.teachingTypes);
  $$GatheringTypesTableTableManager get gatheringTypes =>
      $$GatheringTypesTableTableManager(
          _db.attachedDatabase, _db.gatheringTypes);
}
