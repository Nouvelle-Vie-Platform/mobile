// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notes_dao.dart';

// ignore_for_file: type=lint
mixin _$NotesDaoMixin on DatabaseAccessor<AppDatabase> {
  $SpiritualNotesTable get spiritualNotes => attachedDatabase.spiritualNotes;
  $NoteCategoriesTable get noteCategories => attachedDatabase.noteCategories;
  $LocalNotesTable get localNotes => attachedDatabase.localNotes;
  NotesDaoManager get managers => NotesDaoManager(this);
}

class NotesDaoManager {
  final _$NotesDaoMixin _db;
  NotesDaoManager(this._db);
  $$SpiritualNotesTableTableManager get spiritualNotes =>
      $$SpiritualNotesTableTableManager(
          _db.attachedDatabase, _db.spiritualNotes);
  $$NoteCategoriesTableTableManager get noteCategories =>
      $$NoteCategoriesTableTableManager(
          _db.attachedDatabase, _db.noteCategories);
  $$LocalNotesTableTableManager get localNotes =>
      $$LocalNotesTableTableManager(_db.attachedDatabase, _db.localNotes);
}
