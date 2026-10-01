// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vocabulary_dao.dart';

// ignore_for_file: type=lint
mixin _$VocabularyDaoMixin on DatabaseAccessor<AppDatabase> {
  $PresentationVocabularyTable get presentationVocabulary =>
      attachedDatabase.presentationVocabulary;
  VocabularyDaoManager get managers => VocabularyDaoManager(this);
}

class VocabularyDaoManager {
  final _$VocabularyDaoMixin _db;
  VocabularyDaoManager(this._db);
  $$PresentationVocabularyTableTableManager get presentationVocabulary =>
      $$PresentationVocabularyTableTableManager(
          _db.attachedDatabase, _db.presentationVocabulary);
}
