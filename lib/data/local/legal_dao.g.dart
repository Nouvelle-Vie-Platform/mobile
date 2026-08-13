// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'legal_dao.dart';

// ignore_for_file: type=lint
mixin _$LegalDaoMixin on DatabaseAccessor<AppDatabase> {
  $LegalDocumentsTable get legalDocuments => attachedDatabase.legalDocuments;
  LegalDaoManager get managers => LegalDaoManager(this);
}

class LegalDaoManager {
  final _$LegalDaoMixin _db;
  LegalDaoManager(this._db);
  $$LegalDocumentsTableTableManager get legalDocuments =>
      $$LegalDocumentsTableTableManager(
          _db.attachedDatabase, _db.legalDocuments);
}
