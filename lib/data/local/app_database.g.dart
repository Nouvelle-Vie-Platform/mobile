// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $SyncCursorsTable extends SyncCursors
    with TableInfo<$SyncCursorsTable, SyncCursorRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncCursorsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _collectionMeta =
      const VerificationMeta('collection');
  @override
  late final GeneratedColumn<String> collection = GeneratedColumn<String>(
      'collection', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _cursorMeta = const VerificationMeta('cursor');
  @override
  late final GeneratedColumn<String> cursor = GeneratedColumn<String>(
      'cursor', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _syncedAtMeta =
      const VerificationMeta('syncedAt');
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
      'synced_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [collection, cursor, syncedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_cursors';
  @override
  VerificationContext validateIntegrity(Insertable<SyncCursorRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('collection')) {
      context.handle(
          _collectionMeta,
          collection.isAcceptableOrUnknown(
              data['collection']!, _collectionMeta));
    } else if (isInserting) {
      context.missing(_collectionMeta);
    }
    if (data.containsKey('cursor')) {
      context.handle(_cursorMeta,
          cursor.isAcceptableOrUnknown(data['cursor']!, _cursorMeta));
    }
    if (data.containsKey('synced_at')) {
      context.handle(_syncedAtMeta,
          syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta));
    } else if (isInserting) {
      context.missing(_syncedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {collection};
  @override
  SyncCursorRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncCursorRow(
      collection: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}collection'])!,
      cursor: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}cursor']),
      syncedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}synced_at'])!,
    );
  }

  @override
  $SyncCursorsTable createAlias(String alias) {
    return $SyncCursorsTable(attachedDatabase, alias);
  }
}

class SyncCursorRow extends DataClass implements Insertable<SyncCursorRow> {
  /// Clé de collection du protocole (`teachings`, `teaching_types`, …). C'est
  /// **le seul discriminant** du rangement : une ligne se range d'après le
  /// canal par lequel elle est arrivée, jamais d'après un champ qu'elle porte
  /// (ADR-0026, décision 1).
  final String collection;

  /// Curseur opaque de la dernière page appliquée. `null` = « depuis zéro ».
  final String? cursor;

  /// Instant de la dernière page **effectivement appliquée**.
  final DateTime syncedAt;
  const SyncCursorRow(
      {required this.collection, this.cursor, required this.syncedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['collection'] = Variable<String>(collection);
    if (!nullToAbsent || cursor != null) {
      map['cursor'] = Variable<String>(cursor);
    }
    map['synced_at'] = Variable<DateTime>(syncedAt);
    return map;
  }

  SyncCursorsCompanion toCompanion(bool nullToAbsent) {
    return SyncCursorsCompanion(
      collection: Value(collection),
      cursor:
          cursor == null && nullToAbsent ? const Value.absent() : Value(cursor),
      syncedAt: Value(syncedAt),
    );
  }

  factory SyncCursorRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncCursorRow(
      collection: serializer.fromJson<String>(json['collection']),
      cursor: serializer.fromJson<String?>(json['cursor']),
      syncedAt: serializer.fromJson<DateTime>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'collection': serializer.toJson<String>(collection),
      'cursor': serializer.toJson<String?>(cursor),
      'syncedAt': serializer.toJson<DateTime>(syncedAt),
    };
  }

  SyncCursorRow copyWith(
          {String? collection,
          Value<String?> cursor = const Value.absent(),
          DateTime? syncedAt}) =>
      SyncCursorRow(
        collection: collection ?? this.collection,
        cursor: cursor.present ? cursor.value : this.cursor,
        syncedAt: syncedAt ?? this.syncedAt,
      );
  SyncCursorRow copyWithCompanion(SyncCursorsCompanion data) {
    return SyncCursorRow(
      collection:
          data.collection.present ? data.collection.value : this.collection,
      cursor: data.cursor.present ? data.cursor.value : this.cursor,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncCursorRow(')
          ..write('collection: $collection, ')
          ..write('cursor: $cursor, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(collection, cursor, syncedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncCursorRow &&
          other.collection == this.collection &&
          other.cursor == this.cursor &&
          other.syncedAt == this.syncedAt);
}

class SyncCursorsCompanion extends UpdateCompanion<SyncCursorRow> {
  final Value<String> collection;
  final Value<String?> cursor;
  final Value<DateTime> syncedAt;
  final Value<int> rowid;
  const SyncCursorsCompanion({
    this.collection = const Value.absent(),
    this.cursor = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncCursorsCompanion.insert({
    required String collection,
    this.cursor = const Value.absent(),
    required DateTime syncedAt,
    this.rowid = const Value.absent(),
  })  : collection = Value(collection),
        syncedAt = Value(syncedAt);
  static Insertable<SyncCursorRow> custom({
    Expression<String>? collection,
    Expression<String>? cursor,
    Expression<DateTime>? syncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (collection != null) 'collection': collection,
      if (cursor != null) 'cursor': cursor,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncCursorsCompanion copyWith(
      {Value<String>? collection,
      Value<String?>? cursor,
      Value<DateTime>? syncedAt,
      Value<int>? rowid}) {
    return SyncCursorsCompanion(
      collection: collection ?? this.collection,
      cursor: cursor ?? this.cursor,
      syncedAt: syncedAt ?? this.syncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (collection.present) {
      map['collection'] = Variable<String>(collection.value);
    }
    if (cursor.present) {
      map['cursor'] = Variable<String>(cursor.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncCursorsCompanion(')
          ..write('collection: $collection, ')
          ..write('cursor: $cursor, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncStateTable extends SyncState
    with TableInfo<$SyncStateTable, SyncStateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncStateTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      check: () => const CustomExpression<bool>('id = 1'),
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(kSyncStateRowId));
  static const VerificationMeta _scopeVersionMeta =
      const VerificationMeta('scopeVersion');
  @override
  late final GeneratedColumn<int> scopeVersion = GeneratedColumn<int>(
      'scope_version', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _nextStampMeta =
      const VerificationMeta('nextStamp');
  @override
  late final GeneratedColumn<int> nextStamp = GeneratedColumn<int>(
      'next_stamp', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  @override
  List<GeneratedColumn> get $columns => [id, scopeVersion, nextStamp];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_state';
  @override
  VerificationContext validateIntegrity(Insertable<SyncStateRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('scope_version')) {
      context.handle(
          _scopeVersionMeta,
          scopeVersion.isAcceptableOrUnknown(
              data['scope_version']!, _scopeVersionMeta));
    }
    if (data.containsKey('next_stamp')) {
      context.handle(_nextStampMeta,
          nextStamp.isAcceptableOrUnknown(data['next_stamp']!, _nextStampMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncStateRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncStateRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      scopeVersion: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}scope_version']),
      nextStamp: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}next_stamp'])!,
    );
  }

  @override
  $SyncStateTable createAlias(String alias) {
    return $SyncStateTable(attachedDatabase, alias);
  }
}

class SyncStateRow extends DataClass implements Insertable<SyncStateRow> {
  /// Toujours [kSyncStateRowId] — l'unicité de la ligne est une contrainte de
  /// base, pas une convention qu'un appelant pourrait oublier.
  final int id;

  /// Version de périmètre connue. `null` = jamais synchronisé.
  final int? scopeVersion;

  /// Prochain jeton d'écriture à distribuer.
  ///
  /// C'est un **compteur monotone local**, pas une date : le balayage de fin de
  /// resync compare des jetons, et une horloge d'appareil qui recule pendant un
  /// cycle ferait supprimer des lignes fraîchement écrites — silencieusement.
  /// Il n'a aucun sens hors de l'appareil et ne voyage jamais.
  final int nextStamp;
  const SyncStateRow(
      {required this.id, this.scopeVersion, required this.nextStamp});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || scopeVersion != null) {
      map['scope_version'] = Variable<int>(scopeVersion);
    }
    map['next_stamp'] = Variable<int>(nextStamp);
    return map;
  }

  SyncStateCompanion toCompanion(bool nullToAbsent) {
    return SyncStateCompanion(
      id: Value(id),
      scopeVersion: scopeVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(scopeVersion),
      nextStamp: Value(nextStamp),
    );
  }

  factory SyncStateRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncStateRow(
      id: serializer.fromJson<int>(json['id']),
      scopeVersion: serializer.fromJson<int?>(json['scopeVersion']),
      nextStamp: serializer.fromJson<int>(json['nextStamp']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'scopeVersion': serializer.toJson<int?>(scopeVersion),
      'nextStamp': serializer.toJson<int>(nextStamp),
    };
  }

  SyncStateRow copyWith(
          {int? id,
          Value<int?> scopeVersion = const Value.absent(),
          int? nextStamp}) =>
      SyncStateRow(
        id: id ?? this.id,
        scopeVersion:
            scopeVersion.present ? scopeVersion.value : this.scopeVersion,
        nextStamp: nextStamp ?? this.nextStamp,
      );
  SyncStateRow copyWithCompanion(SyncStateCompanion data) {
    return SyncStateRow(
      id: data.id.present ? data.id.value : this.id,
      scopeVersion: data.scopeVersion.present
          ? data.scopeVersion.value
          : this.scopeVersion,
      nextStamp: data.nextStamp.present ? data.nextStamp.value : this.nextStamp,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateRow(')
          ..write('id: $id, ')
          ..write('scopeVersion: $scopeVersion, ')
          ..write('nextStamp: $nextStamp')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, scopeVersion, nextStamp);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncStateRow &&
          other.id == this.id &&
          other.scopeVersion == this.scopeVersion &&
          other.nextStamp == this.nextStamp);
}

class SyncStateCompanion extends UpdateCompanion<SyncStateRow> {
  final Value<int> id;
  final Value<int?> scopeVersion;
  final Value<int> nextStamp;
  const SyncStateCompanion({
    this.id = const Value.absent(),
    this.scopeVersion = const Value.absent(),
    this.nextStamp = const Value.absent(),
  });
  SyncStateCompanion.insert({
    this.id = const Value.absent(),
    this.scopeVersion = const Value.absent(),
    this.nextStamp = const Value.absent(),
  });
  static Insertable<SyncStateRow> custom({
    Expression<int>? id,
    Expression<int>? scopeVersion,
    Expression<int>? nextStamp,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (scopeVersion != null) 'scope_version': scopeVersion,
      if (nextStamp != null) 'next_stamp': nextStamp,
    });
  }

  SyncStateCompanion copyWith(
      {Value<int>? id, Value<int?>? scopeVersion, Value<int>? nextStamp}) {
    return SyncStateCompanion(
      id: id ?? this.id,
      scopeVersion: scopeVersion ?? this.scopeVersion,
      nextStamp: nextStamp ?? this.nextStamp,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (scopeVersion.present) {
      map['scope_version'] = Variable<int>(scopeVersion.value);
    }
    if (nextStamp.present) {
      map['next_stamp'] = Variable<int>(nextStamp.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateCompanion(')
          ..write('id: $id, ')
          ..write('scopeVersion: $scopeVersion, ')
          ..write('nextStamp: $nextStamp')
          ..write(')'))
        .toString();
  }
}

class $ResyncTokensTable extends ResyncTokens
    with TableInfo<$ResyncTokensTable, ResyncTokenRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ResyncTokensTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _collectionMeta =
      const VerificationMeta('collection');
  @override
  late final GeneratedColumn<String> collection = GeneratedColumn<String>(
      'collection', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _stampMeta = const VerificationMeta('stamp');
  @override
  late final GeneratedColumn<int> stamp = GeneratedColumn<int>(
      'stamp', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _startedAtMeta =
      const VerificationMeta('startedAt');
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
      'started_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [collection, stamp, startedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'resync_tokens';
  @override
  VerificationContext validateIntegrity(Insertable<ResyncTokenRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('collection')) {
      context.handle(
          _collectionMeta,
          collection.isAcceptableOrUnknown(
              data['collection']!, _collectionMeta));
    } else if (isInserting) {
      context.missing(_collectionMeta);
    }
    if (data.containsKey('stamp')) {
      context.handle(
          _stampMeta, stamp.isAcceptableOrUnknown(data['stamp']!, _stampMeta));
    } else if (isInserting) {
      context.missing(_stampMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(_startedAtMeta,
          startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta));
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {collection};
  @override
  ResyncTokenRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ResyncTokenRow(
      collection: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}collection'])!,
      stamp: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}stamp'])!,
      startedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}started_at'])!,
    );
  }

  @override
  $ResyncTokensTable createAlias(String alias) {
    return $ResyncTokensTable(attachedDatabase, alias);
  }
}

class ResyncTokenRow extends DataClass implements Insertable<ResyncTokenRow> {
  /// Clé de collection du protocole.
  final String collection;

  /// Jeton d'écriture alloué à l'ouverture du cycle.
  final int stamp;

  /// Instant d'ouverture du cycle — diagnostic seulement, jamais comparé.
  final DateTime startedAt;
  const ResyncTokenRow(
      {required this.collection, required this.stamp, required this.startedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['collection'] = Variable<String>(collection);
    map['stamp'] = Variable<int>(stamp);
    map['started_at'] = Variable<DateTime>(startedAt);
    return map;
  }

  ResyncTokensCompanion toCompanion(bool nullToAbsent) {
    return ResyncTokensCompanion(
      collection: Value(collection),
      stamp: Value(stamp),
      startedAt: Value(startedAt),
    );
  }

  factory ResyncTokenRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ResyncTokenRow(
      collection: serializer.fromJson<String>(json['collection']),
      stamp: serializer.fromJson<int>(json['stamp']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'collection': serializer.toJson<String>(collection),
      'stamp': serializer.toJson<int>(stamp),
      'startedAt': serializer.toJson<DateTime>(startedAt),
    };
  }

  ResyncTokenRow copyWith(
          {String? collection, int? stamp, DateTime? startedAt}) =>
      ResyncTokenRow(
        collection: collection ?? this.collection,
        stamp: stamp ?? this.stamp,
        startedAt: startedAt ?? this.startedAt,
      );
  ResyncTokenRow copyWithCompanion(ResyncTokensCompanion data) {
    return ResyncTokenRow(
      collection:
          data.collection.present ? data.collection.value : this.collection,
      stamp: data.stamp.present ? data.stamp.value : this.stamp,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ResyncTokenRow(')
          ..write('collection: $collection, ')
          ..write('stamp: $stamp, ')
          ..write('startedAt: $startedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(collection, stamp, startedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ResyncTokenRow &&
          other.collection == this.collection &&
          other.stamp == this.stamp &&
          other.startedAt == this.startedAt);
}

class ResyncTokensCompanion extends UpdateCompanion<ResyncTokenRow> {
  final Value<String> collection;
  final Value<int> stamp;
  final Value<DateTime> startedAt;
  final Value<int> rowid;
  const ResyncTokensCompanion({
    this.collection = const Value.absent(),
    this.stamp = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ResyncTokensCompanion.insert({
    required String collection,
    required int stamp,
    required DateTime startedAt,
    this.rowid = const Value.absent(),
  })  : collection = Value(collection),
        stamp = Value(stamp),
        startedAt = Value(startedAt);
  static Insertable<ResyncTokenRow> custom({
    Expression<String>? collection,
    Expression<int>? stamp,
    Expression<DateTime>? startedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (collection != null) 'collection': collection,
      if (stamp != null) 'stamp': stamp,
      if (startedAt != null) 'started_at': startedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ResyncTokensCompanion copyWith(
      {Value<String>? collection,
      Value<int>? stamp,
      Value<DateTime>? startedAt,
      Value<int>? rowid}) {
    return ResyncTokensCompanion(
      collection: collection ?? this.collection,
      stamp: stamp ?? this.stamp,
      startedAt: startedAt ?? this.startedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (collection.present) {
      map['collection'] = Variable<String>(collection.value);
    }
    if (stamp.present) {
      map['stamp'] = Variable<int>(stamp.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ResyncTokensCompanion(')
          ..write('collection: $collection, ')
          ..write('stamp: $stamp, ')
          ..write('startedAt: $startedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BranchesTable extends Branches
    with TableInfo<$BranchesTable, BranchRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BranchesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _syncStampMeta =
      const VerificationMeta('syncStamp');
  @override
  late final GeneratedColumn<int> syncStamp = GeneratedColumn<int>(
      'sync_stamp', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _isMotherChurchMeta =
      const VerificationMeta('isMotherChurch');
  @override
  late final GeneratedColumn<bool> isMotherChurch = GeneratedColumn<bool>(
      'is_mother_church', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_mother_church" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _addressMeta =
      const VerificationMeta('address');
  @override
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
      'address', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
      'email', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
      'phone', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _postalBoxMeta =
      const VerificationMeta('postalBox');
  @override
  late final GeneratedColumn<String> postalBox = GeneratedColumn<String>(
      'postal_box', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        syncStamp,
        id,
        name,
        isMotherChurch,
        address,
        email,
        phone,
        postalBox,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'branches';
  @override
  VerificationContext validateIntegrity(Insertable<BranchRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('sync_stamp')) {
      context.handle(_syncStampMeta,
          syncStamp.isAcceptableOrUnknown(data['sync_stamp']!, _syncStampMeta));
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('is_mother_church')) {
      context.handle(
          _isMotherChurchMeta,
          isMotherChurch.isAcceptableOrUnknown(
              data['is_mother_church']!, _isMotherChurchMeta));
    }
    if (data.containsKey('address')) {
      context.handle(_addressMeta,
          address.isAcceptableOrUnknown(data['address']!, _addressMeta));
    }
    if (data.containsKey('email')) {
      context.handle(
          _emailMeta, email.isAcceptableOrUnknown(data['email']!, _emailMeta));
    }
    if (data.containsKey('phone')) {
      context.handle(
          _phoneMeta, phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta));
    }
    if (data.containsKey('postal_box')) {
      context.handle(_postalBoxMeta,
          postalBox.isAcceptableOrUnknown(data['postal_box']!, _postalBoxMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BranchRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BranchRow(
      syncStamp: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sync_stamp'])!,
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      isMotherChurch: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_mother_church'])!,
      address: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}address']),
      email: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}email']),
      phone: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}phone']),
      postalBox: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}postal_box']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at']),
    );
  }

  @override
  $BranchesTable createAlias(String alias) {
    return $BranchesTable(attachedDatabase, alias);
  }
}

class BranchRow extends DataClass implements Insertable<BranchRow> {
  /// Jeton de la transaction qui a écrit cette ligne pour la dernière fois.
  ///
  /// Le défaut existe pour que l'appelant n'ait **pas** à le renseigner : le
  /// jeton est une mécanique du magasin, posée par `SyncDao`, pas une donnée du
  /// serveur. Une ligne qui arriverait ici sans jeton porterait `0`, donc
  /// serait traitée comme jamais revue — la panne va dans le sens sûr.
  final int syncStamp;
  final int id;
  final String name;
  final bool isMotherChurch;
  final String? address;
  final String? email;
  final String? phone;
  final String? postalBox;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  const BranchRow(
      {required this.syncStamp,
      required this.id,
      required this.name,
      required this.isMotherChurch,
      this.address,
      this.email,
      this.phone,
      this.postalBox,
      this.createdAt,
      this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['sync_stamp'] = Variable<int>(syncStamp);
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['is_mother_church'] = Variable<bool>(isMotherChurch);
    if (!nullToAbsent || address != null) {
      map['address'] = Variable<String>(address);
    }
    if (!nullToAbsent || email != null) {
      map['email'] = Variable<String>(email);
    }
    if (!nullToAbsent || phone != null) {
      map['phone'] = Variable<String>(phone);
    }
    if (!nullToAbsent || postalBox != null) {
      map['postal_box'] = Variable<String>(postalBox);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    return map;
  }

  BranchesCompanion toCompanion(bool nullToAbsent) {
    return BranchesCompanion(
      syncStamp: Value(syncStamp),
      id: Value(id),
      name: Value(name),
      isMotherChurch: Value(isMotherChurch),
      address: address == null && nullToAbsent
          ? const Value.absent()
          : Value(address),
      email:
          email == null && nullToAbsent ? const Value.absent() : Value(email),
      phone:
          phone == null && nullToAbsent ? const Value.absent() : Value(phone),
      postalBox: postalBox == null && nullToAbsent
          ? const Value.absent()
          : Value(postalBox),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory BranchRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BranchRow(
      syncStamp: serializer.fromJson<int>(json['syncStamp']),
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      isMotherChurch: serializer.fromJson<bool>(json['isMotherChurch']),
      address: serializer.fromJson<String?>(json['address']),
      email: serializer.fromJson<String?>(json['email']),
      phone: serializer.fromJson<String?>(json['phone']),
      postalBox: serializer.fromJson<String?>(json['postalBox']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'syncStamp': serializer.toJson<int>(syncStamp),
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'isMotherChurch': serializer.toJson<bool>(isMotherChurch),
      'address': serializer.toJson<String?>(address),
      'email': serializer.toJson<String?>(email),
      'phone': serializer.toJson<String?>(phone),
      'postalBox': serializer.toJson<String?>(postalBox),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
    };
  }

  BranchRow copyWith(
          {int? syncStamp,
          int? id,
          String? name,
          bool? isMotherChurch,
          Value<String?> address = const Value.absent(),
          Value<String?> email = const Value.absent(),
          Value<String?> phone = const Value.absent(),
          Value<String?> postalBox = const Value.absent(),
          Value<DateTime?> createdAt = const Value.absent(),
          Value<DateTime?> updatedAt = const Value.absent()}) =>
      BranchRow(
        syncStamp: syncStamp ?? this.syncStamp,
        id: id ?? this.id,
        name: name ?? this.name,
        isMotherChurch: isMotherChurch ?? this.isMotherChurch,
        address: address.present ? address.value : this.address,
        email: email.present ? email.value : this.email,
        phone: phone.present ? phone.value : this.phone,
        postalBox: postalBox.present ? postalBox.value : this.postalBox,
        createdAt: createdAt.present ? createdAt.value : this.createdAt,
        updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
      );
  BranchRow copyWithCompanion(BranchesCompanion data) {
    return BranchRow(
      syncStamp: data.syncStamp.present ? data.syncStamp.value : this.syncStamp,
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      isMotherChurch: data.isMotherChurch.present
          ? data.isMotherChurch.value
          : this.isMotherChurch,
      address: data.address.present ? data.address.value : this.address,
      email: data.email.present ? data.email.value : this.email,
      phone: data.phone.present ? data.phone.value : this.phone,
      postalBox: data.postalBox.present ? data.postalBox.value : this.postalBox,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BranchRow(')
          ..write('syncStamp: $syncStamp, ')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('isMotherChurch: $isMotherChurch, ')
          ..write('address: $address, ')
          ..write('email: $email, ')
          ..write('phone: $phone, ')
          ..write('postalBox: $postalBox, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(syncStamp, id, name, isMotherChurch, address,
      email, phone, postalBox, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BranchRow &&
          other.syncStamp == this.syncStamp &&
          other.id == this.id &&
          other.name == this.name &&
          other.isMotherChurch == this.isMotherChurch &&
          other.address == this.address &&
          other.email == this.email &&
          other.phone == this.phone &&
          other.postalBox == this.postalBox &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class BranchesCompanion extends UpdateCompanion<BranchRow> {
  final Value<int> syncStamp;
  final Value<int> id;
  final Value<String> name;
  final Value<bool> isMotherChurch;
  final Value<String?> address;
  final Value<String?> email;
  final Value<String?> phone;
  final Value<String?> postalBox;
  final Value<DateTime?> createdAt;
  final Value<DateTime?> updatedAt;
  const BranchesCompanion({
    this.syncStamp = const Value.absent(),
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.isMotherChurch = const Value.absent(),
    this.address = const Value.absent(),
    this.email = const Value.absent(),
    this.phone = const Value.absent(),
    this.postalBox = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  BranchesCompanion.insert({
    this.syncStamp = const Value.absent(),
    this.id = const Value.absent(),
    required String name,
    this.isMotherChurch = const Value.absent(),
    this.address = const Value.absent(),
    this.email = const Value.absent(),
    this.phone = const Value.absent(),
    this.postalBox = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : name = Value(name);
  static Insertable<BranchRow> custom({
    Expression<int>? syncStamp,
    Expression<int>? id,
    Expression<String>? name,
    Expression<bool>? isMotherChurch,
    Expression<String>? address,
    Expression<String>? email,
    Expression<String>? phone,
    Expression<String>? postalBox,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (syncStamp != null) 'sync_stamp': syncStamp,
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (isMotherChurch != null) 'is_mother_church': isMotherChurch,
      if (address != null) 'address': address,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      if (postalBox != null) 'postal_box': postalBox,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  BranchesCompanion copyWith(
      {Value<int>? syncStamp,
      Value<int>? id,
      Value<String>? name,
      Value<bool>? isMotherChurch,
      Value<String?>? address,
      Value<String?>? email,
      Value<String?>? phone,
      Value<String?>? postalBox,
      Value<DateTime?>? createdAt,
      Value<DateTime?>? updatedAt}) {
    return BranchesCompanion(
      syncStamp: syncStamp ?? this.syncStamp,
      id: id ?? this.id,
      name: name ?? this.name,
      isMotherChurch: isMotherChurch ?? this.isMotherChurch,
      address: address ?? this.address,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      postalBox: postalBox ?? this.postalBox,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (syncStamp.present) {
      map['sync_stamp'] = Variable<int>(syncStamp.value);
    }
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (isMotherChurch.present) {
      map['is_mother_church'] = Variable<bool>(isMotherChurch.value);
    }
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (postalBox.present) {
      map['postal_box'] = Variable<String>(postalBox.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BranchesCompanion(')
          ..write('syncStamp: $syncStamp, ')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('isMotherChurch: $isMotherChurch, ')
          ..write('address: $address, ')
          ..write('email: $email, ')
          ..write('phone: $phone, ')
          ..write('postalBox: $postalBox, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $TeachingTypesTable extends TeachingTypes
    with TableInfo<$TeachingTypesTable, TeachingTypeRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TeachingTypesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _syncStampMeta =
      const VerificationMeta('syncStamp');
  @override
  late final GeneratedColumn<int> syncStamp = GeneratedColumn<int>(
      'sync_stamp', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  @override
  late final GeneratedColumnWithTypeConverter<Map<String, String>, String>
      label = GeneratedColumn<String>('label', aliasedName, false,
              type: DriftSqlType.string, requiredDuringInsert: true)
          .withConverter<Map<String, String>>(
              $TeachingTypesTable.$converterlabel);
  static const VerificationMeta _slugMeta = const VerificationMeta('slug');
  @override
  late final GeneratedColumn<String> slug = GeneratedColumn<String>(
      'slug', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
      'icon', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
      'color', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _positionMeta =
      const VerificationMeta('position');
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
      'position', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _visibleOnHomeMeta =
      const VerificationMeta('visibleOnHome');
  @override
  late final GeneratedColumn<bool> visibleOnHome = GeneratedColumn<bool>(
      'visible_on_home', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("visible_on_home" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _layoutMeta = const VerificationMeta('layout');
  @override
  late final GeneratedColumn<String> layout = GeneratedColumn<String>(
      'layout', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        syncStamp,
        id,
        label,
        slug,
        icon,
        color,
        position,
        visibleOnHome,
        layout,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'teaching_types';
  @override
  VerificationContext validateIntegrity(Insertable<TeachingTypeRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('sync_stamp')) {
      context.handle(_syncStampMeta,
          syncStamp.isAcceptableOrUnknown(data['sync_stamp']!, _syncStampMeta));
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('slug')) {
      context.handle(
          _slugMeta, slug.isAcceptableOrUnknown(data['slug']!, _slugMeta));
    } else if (isInserting) {
      context.missing(_slugMeta);
    }
    if (data.containsKey('icon')) {
      context.handle(
          _iconMeta, icon.isAcceptableOrUnknown(data['icon']!, _iconMeta));
    }
    if (data.containsKey('color')) {
      context.handle(
          _colorMeta, color.isAcceptableOrUnknown(data['color']!, _colorMeta));
    }
    if (data.containsKey('position')) {
      context.handle(_positionMeta,
          position.isAcceptableOrUnknown(data['position']!, _positionMeta));
    }
    if (data.containsKey('visible_on_home')) {
      context.handle(
          _visibleOnHomeMeta,
          visibleOnHome.isAcceptableOrUnknown(
              data['visible_on_home']!, _visibleOnHomeMeta));
    }
    if (data.containsKey('layout')) {
      context.handle(_layoutMeta,
          layout.isAcceptableOrUnknown(data['layout']!, _layoutMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TeachingTypeRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TeachingTypeRow(
      syncStamp: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sync_stamp'])!,
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      label: $TeachingTypesTable.$converterlabel.fromSql(attachedDatabase
          .typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}label'])!),
      slug: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}slug'])!,
      icon: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}icon']),
      color: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}color']),
      position: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}position'])!,
      visibleOnHome: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}visible_on_home'])!,
      layout: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}layout']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at']),
    );
  }

  @override
  $TeachingTypesTable createAlias(String alias) {
    return $TeachingTypesTable(attachedDatabase, alias);
  }

  static TypeConverter<Map<String, String>, String> $converterlabel =
      const I18nMapConverter();
}

class TeachingTypeRow extends DataClass implements Insertable<TeachingTypeRow> {
  /// Jeton de la transaction qui a écrit cette ligne pour la dernière fois.
  ///
  /// Le défaut existe pour que l'appelant n'ait **pas** à le renseigner : le
  /// jeton est une mécanique du magasin, posée par `SyncDao`, pas une donnée du
  /// serveur. Une ligne qui arriverait ici sans jeton porterait `0`, donc
  /// serait traitée comme jamais revue — la panne va dans le sens sûr.
  final int syncStamp;
  final int id;

  /// Carte de traduction **entière** `{fr, en, ee}` — jamais la langue retenue.
  /// Le repli se fait à la lecture, via `utils/i18n_text.dart` → `pick`.
  final Map<String, String> label;

  /// Clé stable que le mobile reconnaît : elle survit au renommage du libellé.
  final String slug;
  final String? icon;

  /// Couleur de la rubrique — **dernier maillon** de la cascade. Un
  /// enseignement dont la couleur est nulle hérite de celle-ci, et l'héritage
  /// se calcule à la lecture : le stocker sur l'enseignement figerait une
  /// valeur que changer la couleur d'une rubrique ne mettrait jamais à jour.
  final String? color;
  final int position;

  /// `false` = la rubrique a quitté l'accueil, mais ses enseignements restent.
  final bool visibleOnHome;

  /// `hero` | `carousel` | `list`. Stocké **tel quel**, jamais en enum : un
  /// enum est une décision figée à l'écriture, et le référentiel est
  /// administrable. Une valeur inconnue se replie à l'affichage.
  final String? layout;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  const TeachingTypeRow(
      {required this.syncStamp,
      required this.id,
      required this.label,
      required this.slug,
      this.icon,
      this.color,
      required this.position,
      required this.visibleOnHome,
      this.layout,
      this.createdAt,
      this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['sync_stamp'] = Variable<int>(syncStamp);
    map['id'] = Variable<int>(id);
    {
      map['label'] =
          Variable<String>($TeachingTypesTable.$converterlabel.toSql(label));
    }
    map['slug'] = Variable<String>(slug);
    if (!nullToAbsent || icon != null) {
      map['icon'] = Variable<String>(icon);
    }
    if (!nullToAbsent || color != null) {
      map['color'] = Variable<String>(color);
    }
    map['position'] = Variable<int>(position);
    map['visible_on_home'] = Variable<bool>(visibleOnHome);
    if (!nullToAbsent || layout != null) {
      map['layout'] = Variable<String>(layout);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    return map;
  }

  TeachingTypesCompanion toCompanion(bool nullToAbsent) {
    return TeachingTypesCompanion(
      syncStamp: Value(syncStamp),
      id: Value(id),
      label: Value(label),
      slug: Value(slug),
      icon: icon == null && nullToAbsent ? const Value.absent() : Value(icon),
      color:
          color == null && nullToAbsent ? const Value.absent() : Value(color),
      position: Value(position),
      visibleOnHome: Value(visibleOnHome),
      layout:
          layout == null && nullToAbsent ? const Value.absent() : Value(layout),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory TeachingTypeRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TeachingTypeRow(
      syncStamp: serializer.fromJson<int>(json['syncStamp']),
      id: serializer.fromJson<int>(json['id']),
      label: serializer.fromJson<Map<String, String>>(json['label']),
      slug: serializer.fromJson<String>(json['slug']),
      icon: serializer.fromJson<String?>(json['icon']),
      color: serializer.fromJson<String?>(json['color']),
      position: serializer.fromJson<int>(json['position']),
      visibleOnHome: serializer.fromJson<bool>(json['visibleOnHome']),
      layout: serializer.fromJson<String?>(json['layout']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'syncStamp': serializer.toJson<int>(syncStamp),
      'id': serializer.toJson<int>(id),
      'label': serializer.toJson<Map<String, String>>(label),
      'slug': serializer.toJson<String>(slug),
      'icon': serializer.toJson<String?>(icon),
      'color': serializer.toJson<String?>(color),
      'position': serializer.toJson<int>(position),
      'visibleOnHome': serializer.toJson<bool>(visibleOnHome),
      'layout': serializer.toJson<String?>(layout),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
    };
  }

  TeachingTypeRow copyWith(
          {int? syncStamp,
          int? id,
          Map<String, String>? label,
          String? slug,
          Value<String?> icon = const Value.absent(),
          Value<String?> color = const Value.absent(),
          int? position,
          bool? visibleOnHome,
          Value<String?> layout = const Value.absent(),
          Value<DateTime?> createdAt = const Value.absent(),
          Value<DateTime?> updatedAt = const Value.absent()}) =>
      TeachingTypeRow(
        syncStamp: syncStamp ?? this.syncStamp,
        id: id ?? this.id,
        label: label ?? this.label,
        slug: slug ?? this.slug,
        icon: icon.present ? icon.value : this.icon,
        color: color.present ? color.value : this.color,
        position: position ?? this.position,
        visibleOnHome: visibleOnHome ?? this.visibleOnHome,
        layout: layout.present ? layout.value : this.layout,
        createdAt: createdAt.present ? createdAt.value : this.createdAt,
        updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
      );
  TeachingTypeRow copyWithCompanion(TeachingTypesCompanion data) {
    return TeachingTypeRow(
      syncStamp: data.syncStamp.present ? data.syncStamp.value : this.syncStamp,
      id: data.id.present ? data.id.value : this.id,
      label: data.label.present ? data.label.value : this.label,
      slug: data.slug.present ? data.slug.value : this.slug,
      icon: data.icon.present ? data.icon.value : this.icon,
      color: data.color.present ? data.color.value : this.color,
      position: data.position.present ? data.position.value : this.position,
      visibleOnHome: data.visibleOnHome.present
          ? data.visibleOnHome.value
          : this.visibleOnHome,
      layout: data.layout.present ? data.layout.value : this.layout,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TeachingTypeRow(')
          ..write('syncStamp: $syncStamp, ')
          ..write('id: $id, ')
          ..write('label: $label, ')
          ..write('slug: $slug, ')
          ..write('icon: $icon, ')
          ..write('color: $color, ')
          ..write('position: $position, ')
          ..write('visibleOnHome: $visibleOnHome, ')
          ..write('layout: $layout, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(syncStamp, id, label, slug, icon, color,
      position, visibleOnHome, layout, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TeachingTypeRow &&
          other.syncStamp == this.syncStamp &&
          other.id == this.id &&
          other.label == this.label &&
          other.slug == this.slug &&
          other.icon == this.icon &&
          other.color == this.color &&
          other.position == this.position &&
          other.visibleOnHome == this.visibleOnHome &&
          other.layout == this.layout &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class TeachingTypesCompanion extends UpdateCompanion<TeachingTypeRow> {
  final Value<int> syncStamp;
  final Value<int> id;
  final Value<Map<String, String>> label;
  final Value<String> slug;
  final Value<String?> icon;
  final Value<String?> color;
  final Value<int> position;
  final Value<bool> visibleOnHome;
  final Value<String?> layout;
  final Value<DateTime?> createdAt;
  final Value<DateTime?> updatedAt;
  const TeachingTypesCompanion({
    this.syncStamp = const Value.absent(),
    this.id = const Value.absent(),
    this.label = const Value.absent(),
    this.slug = const Value.absent(),
    this.icon = const Value.absent(),
    this.color = const Value.absent(),
    this.position = const Value.absent(),
    this.visibleOnHome = const Value.absent(),
    this.layout = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  TeachingTypesCompanion.insert({
    this.syncStamp = const Value.absent(),
    this.id = const Value.absent(),
    required Map<String, String> label,
    required String slug,
    this.icon = const Value.absent(),
    this.color = const Value.absent(),
    this.position = const Value.absent(),
    this.visibleOnHome = const Value.absent(),
    this.layout = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  })  : label = Value(label),
        slug = Value(slug);
  static Insertable<TeachingTypeRow> custom({
    Expression<int>? syncStamp,
    Expression<int>? id,
    Expression<String>? label,
    Expression<String>? slug,
    Expression<String>? icon,
    Expression<String>? color,
    Expression<int>? position,
    Expression<bool>? visibleOnHome,
    Expression<String>? layout,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (syncStamp != null) 'sync_stamp': syncStamp,
      if (id != null) 'id': id,
      if (label != null) 'label': label,
      if (slug != null) 'slug': slug,
      if (icon != null) 'icon': icon,
      if (color != null) 'color': color,
      if (position != null) 'position': position,
      if (visibleOnHome != null) 'visible_on_home': visibleOnHome,
      if (layout != null) 'layout': layout,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  TeachingTypesCompanion copyWith(
      {Value<int>? syncStamp,
      Value<int>? id,
      Value<Map<String, String>>? label,
      Value<String>? slug,
      Value<String?>? icon,
      Value<String?>? color,
      Value<int>? position,
      Value<bool>? visibleOnHome,
      Value<String?>? layout,
      Value<DateTime?>? createdAt,
      Value<DateTime?>? updatedAt}) {
    return TeachingTypesCompanion(
      syncStamp: syncStamp ?? this.syncStamp,
      id: id ?? this.id,
      label: label ?? this.label,
      slug: slug ?? this.slug,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      position: position ?? this.position,
      visibleOnHome: visibleOnHome ?? this.visibleOnHome,
      layout: layout ?? this.layout,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (syncStamp.present) {
      map['sync_stamp'] = Variable<int>(syncStamp.value);
    }
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(
          $TeachingTypesTable.$converterlabel.toSql(label.value));
    }
    if (slug.present) {
      map['slug'] = Variable<String>(slug.value);
    }
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (visibleOnHome.present) {
      map['visible_on_home'] = Variable<bool>(visibleOnHome.value);
    }
    if (layout.present) {
      map['layout'] = Variable<String>(layout.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TeachingTypesCompanion(')
          ..write('syncStamp: $syncStamp, ')
          ..write('id: $id, ')
          ..write('label: $label, ')
          ..write('slug: $slug, ')
          ..write('icon: $icon, ')
          ..write('color: $color, ')
          ..write('position: $position, ')
          ..write('visibleOnHome: $visibleOnHome, ')
          ..write('layout: $layout, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $ContributorsTable extends Contributors
    with TableInfo<$ContributorsTable, ContributorRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ContributorsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _syncStampMeta =
      const VerificationMeta('syncStamp');
  @override
  late final GeneratedColumn<int> syncStamp = GeneratedColumn<int>(
      'sync_stamp', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _bioMeta = const VerificationMeta('bio');
  @override
  late final GeneratedColumn<String> bio = GeneratedColumn<String>(
      'bio', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [syncStamp, id, name, bio, createdAt, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'contributors';
  @override
  VerificationContext validateIntegrity(Insertable<ContributorRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('sync_stamp')) {
      context.handle(_syncStampMeta,
          syncStamp.isAcceptableOrUnknown(data['sync_stamp']!, _syncStampMeta));
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('bio')) {
      context.handle(
          _bioMeta, bio.isAcceptableOrUnknown(data['bio']!, _bioMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ContributorRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ContributorRow(
      syncStamp: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sync_stamp'])!,
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      bio: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}bio']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at']),
    );
  }

  @override
  $ContributorsTable createAlias(String alias) {
    return $ContributorsTable(attachedDatabase, alias);
  }
}

class ContributorRow extends DataClass implements Insertable<ContributorRow> {
  /// Jeton de la transaction qui a écrit cette ligne pour la dernière fois.
  ///
  /// Le défaut existe pour que l'appelant n'ait **pas** à le renseigner : le
  /// jeton est une mécanique du magasin, posée par `SyncDao`, pas une donnée du
  /// serveur. Une ligne qui arriverait ici sans jeton porterait `0`, donc
  /// serait traitée comme jamais revue — la panne va dans le sens sûr.
  final int syncStamp;
  final int id;
  final String name;
  final String? bio;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  const ContributorRow(
      {required this.syncStamp,
      required this.id,
      required this.name,
      this.bio,
      this.createdAt,
      this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['sync_stamp'] = Variable<int>(syncStamp);
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || bio != null) {
      map['bio'] = Variable<String>(bio);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    return map;
  }

  ContributorsCompanion toCompanion(bool nullToAbsent) {
    return ContributorsCompanion(
      syncStamp: Value(syncStamp),
      id: Value(id),
      name: Value(name),
      bio: bio == null && nullToAbsent ? const Value.absent() : Value(bio),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory ContributorRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ContributorRow(
      syncStamp: serializer.fromJson<int>(json['syncStamp']),
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      bio: serializer.fromJson<String?>(json['bio']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'syncStamp': serializer.toJson<int>(syncStamp),
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'bio': serializer.toJson<String?>(bio),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
    };
  }

  ContributorRow copyWith(
          {int? syncStamp,
          int? id,
          String? name,
          Value<String?> bio = const Value.absent(),
          Value<DateTime?> createdAt = const Value.absent(),
          Value<DateTime?> updatedAt = const Value.absent()}) =>
      ContributorRow(
        syncStamp: syncStamp ?? this.syncStamp,
        id: id ?? this.id,
        name: name ?? this.name,
        bio: bio.present ? bio.value : this.bio,
        createdAt: createdAt.present ? createdAt.value : this.createdAt,
        updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
      );
  ContributorRow copyWithCompanion(ContributorsCompanion data) {
    return ContributorRow(
      syncStamp: data.syncStamp.present ? data.syncStamp.value : this.syncStamp,
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      bio: data.bio.present ? data.bio.value : this.bio,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ContributorRow(')
          ..write('syncStamp: $syncStamp, ')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('bio: $bio, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(syncStamp, id, name, bio, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ContributorRow &&
          other.syncStamp == this.syncStamp &&
          other.id == this.id &&
          other.name == this.name &&
          other.bio == this.bio &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ContributorsCompanion extends UpdateCompanion<ContributorRow> {
  final Value<int> syncStamp;
  final Value<int> id;
  final Value<String> name;
  final Value<String?> bio;
  final Value<DateTime?> createdAt;
  final Value<DateTime?> updatedAt;
  const ContributorsCompanion({
    this.syncStamp = const Value.absent(),
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.bio = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  ContributorsCompanion.insert({
    this.syncStamp = const Value.absent(),
    this.id = const Value.absent(),
    required String name,
    this.bio = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : name = Value(name);
  static Insertable<ContributorRow> custom({
    Expression<int>? syncStamp,
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? bio,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (syncStamp != null) 'sync_stamp': syncStamp,
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (bio != null) 'bio': bio,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  ContributorsCompanion copyWith(
      {Value<int>? syncStamp,
      Value<int>? id,
      Value<String>? name,
      Value<String?>? bio,
      Value<DateTime?>? createdAt,
      Value<DateTime?>? updatedAt}) {
    return ContributorsCompanion(
      syncStamp: syncStamp ?? this.syncStamp,
      id: id ?? this.id,
      name: name ?? this.name,
      bio: bio ?? this.bio,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (syncStamp.present) {
      map['sync_stamp'] = Variable<int>(syncStamp.value);
    }
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (bio.present) {
      map['bio'] = Variable<String>(bio.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ContributorsCompanion(')
          ..write('syncStamp: $syncStamp, ')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('bio: $bio, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $TeachingsTable extends Teachings
    with TableInfo<$TeachingsTable, TeachingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TeachingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _syncStampMeta =
      const VerificationMeta('syncStamp');
  @override
  late final GeneratedColumn<int> syncStamp = GeneratedColumn<int>(
      'sync_stamp', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _ownerIdMeta =
      const VerificationMeta('ownerId');
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
      'owner_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _branchIdMeta =
      const VerificationMeta('branchId');
  @override
  late final GeneratedColumn<int> branchId = GeneratedColumn<int>(
      'branch_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _contributorIdMeta =
      const VerificationMeta('contributorId');
  @override
  late final GeneratedColumn<int> contributorId = GeneratedColumn<int>(
      'contributor_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _teachingTypeIdMeta =
      const VerificationMeta('teachingTypeId');
  @override
  late final GeneratedColumn<int> teachingTypeId = GeneratedColumn<int>(
      'teaching_type_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isLiveMeta = const VerificationMeta('isLive');
  @override
  late final GeneratedColumn<bool> isLive = GeneratedColumn<bool>(
      'is_live', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_live" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _isFullServiceMeta =
      const VerificationMeta('isFullService');
  @override
  late final GeneratedColumn<bool> isFullService = GeneratedColumn<bool>(
      'is_full_service', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_full_service" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _playlistUrlMeta =
      const VerificationMeta('playlistUrl');
  @override
  late final GeneratedColumn<String> playlistUrl = GeneratedColumn<String>(
      'playlist_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  late final GeneratedColumnWithTypeConverter<TeachingDownload?, String>
      download = GeneratedColumn<String>('download', aliasedName, true,
              type: DriftSqlType.string, requiredDuringInsert: false)
          .withConverter<TeachingDownload?>(
              $TeachingsTable.$converterdownloadn);
  static const VerificationMeta _imageLandscapeUrlMeta =
      const VerificationMeta('imageLandscapeUrl');
  @override
  late final GeneratedColumn<String> imageLandscapeUrl =
      GeneratedColumn<String>('image_landscape_url', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _imagePortraitUrlMeta =
      const VerificationMeta('imagePortraitUrl');
  @override
  late final GeneratedColumn<String> imagePortraitUrl = GeneratedColumn<String>(
      'image_portrait_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _imageSquareUrlMeta =
      const VerificationMeta('imageSquareUrl');
  @override
  late final GeneratedColumn<String> imageSquareUrl = GeneratedColumn<String>(
      'image_square_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _publishedAtMeta =
      const VerificationMeta('publishedAt');
  @override
  late final GeneratedColumn<DateTime> publishedAt = GeneratedColumn<DateTime>(
      'published_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _clientCreatedAtMeta =
      const VerificationMeta('clientCreatedAt');
  @override
  late final GeneratedColumn<DateTime> clientCreatedAt =
      GeneratedColumn<DateTime>('client_created_at', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _recordedAtMeta =
      const VerificationMeta('recordedAt');
  @override
  late final GeneratedColumn<String> recordedAt = GeneratedColumn<String>(
      'recorded_at', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
      'color', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        syncStamp,
        id,
        ownerId,
        branchId,
        contributorId,
        teachingTypeId,
        title,
        description,
        isLive,
        isFullService,
        playlistUrl,
        download,
        imageLandscapeUrl,
        imagePortraitUrl,
        imageSquareUrl,
        publishedAt,
        clientCreatedAt,
        createdAt,
        updatedAt,
        recordedAt,
        color
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'teachings';
  @override
  VerificationContext validateIntegrity(Insertable<TeachingRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('sync_stamp')) {
      context.handle(_syncStampMeta,
          syncStamp.isAcceptableOrUnknown(data['sync_stamp']!, _syncStampMeta));
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('owner_id')) {
      context.handle(_ownerIdMeta,
          ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta));
    }
    if (data.containsKey('branch_id')) {
      context.handle(_branchIdMeta,
          branchId.isAcceptableOrUnknown(data['branch_id']!, _branchIdMeta));
    }
    if (data.containsKey('contributor_id')) {
      context.handle(
          _contributorIdMeta,
          contributorId.isAcceptableOrUnknown(
              data['contributor_id']!, _contributorIdMeta));
    }
    if (data.containsKey('teaching_type_id')) {
      context.handle(
          _teachingTypeIdMeta,
          teachingTypeId.isAcceptableOrUnknown(
              data['teaching_type_id']!, _teachingTypeIdMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    if (data.containsKey('is_live')) {
      context.handle(_isLiveMeta,
          isLive.isAcceptableOrUnknown(data['is_live']!, _isLiveMeta));
    }
    if (data.containsKey('is_full_service')) {
      context.handle(
          _isFullServiceMeta,
          isFullService.isAcceptableOrUnknown(
              data['is_full_service']!, _isFullServiceMeta));
    }
    if (data.containsKey('playlist_url')) {
      context.handle(
          _playlistUrlMeta,
          playlistUrl.isAcceptableOrUnknown(
              data['playlist_url']!, _playlistUrlMeta));
    }
    if (data.containsKey('image_landscape_url')) {
      context.handle(
          _imageLandscapeUrlMeta,
          imageLandscapeUrl.isAcceptableOrUnknown(
              data['image_landscape_url']!, _imageLandscapeUrlMeta));
    }
    if (data.containsKey('image_portrait_url')) {
      context.handle(
          _imagePortraitUrlMeta,
          imagePortraitUrl.isAcceptableOrUnknown(
              data['image_portrait_url']!, _imagePortraitUrlMeta));
    }
    if (data.containsKey('image_square_url')) {
      context.handle(
          _imageSquareUrlMeta,
          imageSquareUrl.isAcceptableOrUnknown(
              data['image_square_url']!, _imageSquareUrlMeta));
    }
    if (data.containsKey('published_at')) {
      context.handle(
          _publishedAtMeta,
          publishedAt.isAcceptableOrUnknown(
              data['published_at']!, _publishedAtMeta));
    }
    if (data.containsKey('client_created_at')) {
      context.handle(
          _clientCreatedAtMeta,
          clientCreatedAt.isAcceptableOrUnknown(
              data['client_created_at']!, _clientCreatedAtMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    if (data.containsKey('recorded_at')) {
      context.handle(
          _recordedAtMeta,
          recordedAt.isAcceptableOrUnknown(
              data['recorded_at']!, _recordedAtMeta));
    }
    if (data.containsKey('color')) {
      context.handle(
          _colorMeta, color.isAcceptableOrUnknown(data['color']!, _colorMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TeachingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TeachingRow(
      syncStamp: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sync_stamp'])!,
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      ownerId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}owner_id']),
      branchId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}branch_id']),
      contributorId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}contributor_id']),
      teachingTypeId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}teaching_type_id']),
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description']),
      isLive: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_live'])!,
      isFullService: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_full_service'])!,
      playlistUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}playlist_url']),
      download: $TeachingsTable.$converterdownloadn.fromSql(attachedDatabase
          .typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}download'])),
      imageLandscapeUrl: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}image_landscape_url']),
      imagePortraitUrl: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}image_portrait_url']),
      imageSquareUrl: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}image_square_url']),
      publishedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}published_at']),
      clientCreatedAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}client_created_at']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at']),
      recordedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}recorded_at']),
      color: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}color']),
    );
  }

  @override
  $TeachingsTable createAlias(String alias) {
    return $TeachingsTable(attachedDatabase, alias);
  }

  static TypeConverter<TeachingDownload, String> $converterdownload =
      const TeachingDownloadConverter();
  static TypeConverter<TeachingDownload?, String?> $converterdownloadn =
      NullAwareTypeConverter.wrap($converterdownload);
}

class TeachingRow extends DataClass implements Insertable<TeachingRow> {
  /// Jeton de la transaction qui a écrit cette ligne pour la dernière fois.
  ///
  /// Le défaut existe pour que l'appelant n'ait **pas** à le renseigner : le
  /// jeton est une mécanique du magasin, posée par `SyncDao`, pas une donnée du
  /// serveur. Une ligne qui arriverait ici sans jeton porterait `0`, donc
  /// serait traitée comme jamais revue — la panne va dans le sens sûr.
  final int syncStamp;

  /// UUIDv7 servi par le serveur, **en chaîne**.
  final String id;
  final String? ownerId;

  /// Branche organisatrice ; `null` = portée **nationale**.
  final int? branchId;

  /// **Entier nu, sans clé étrangère** vers `contributors` : les deux
  /// collections se resynchronisent séparément. Un enseignement dont
  /// l'intervenant manque doit pouvoir être écrit, puis s'afficher.
  final int? contributorId;

  /// **Entier nu, sans clé étrangère** vers `teaching_types`, même raison.
  final int? teachingTypeId;

  /// Titre **monolingue** : le serveur sert une chaîne, pas une carte de
  /// traduction (contrairement à `teaching_types.label`).
  final String title;
  final String? description;
  final bool isLive;
  final bool isFullService;

  /// URL HLS publique. **Peut être nulle** : un enseignement existe avant son
  /// média, et c'est une absence à dessiner, pas un cas impossible.
  final String? playlistUrl;

  /// **Le contrat de téléchargement hors ligne** (ADR-0038) : version du
  /// transcode, durée, et par qualité `{url, bytes}`. Stocké **entier**, tel que
  /// le serveur l'envoie, dans une colonne JSON — même arbitrage que les cartes
  /// de traduction (ADR-0023) : ajouter une qualité ne doit pas coûter une
  /// migration.
  ///
  /// **Peut être nulle**, et se pose atomiquement **avec** [playlistUrl] : un
  /// enseignement du fonds ancien (jamais re-transcodé) n'a pas de `.aac` et son
  /// absence se lit « pas téléchargeable » sans mentir. Le téléchargeable est
  /// **additif** — il ne conditionne pas la visibilité ni l'écoute en ligne.
  ///
  /// C'est cette colonne qui donne au moteur de téléchargement les URLs et les
  /// tailles **hors ligne** ; `download.version` distingue une révision d'un
  /// retrait (ADR-0039).
  final TeachingDownload? download;

  /// URL **relative** (`/uploads/teachings/….jpg`) : l'hôte de l'API change
  /// d'un environnement à l'autre, la résolution appartient au client.
  final String? imageLandscapeUrl;
  final String? imagePortraitUrl;

  /// Le troisième cadrage (1:1), même contrat relatif que ses deux frères.
  /// **Additif** : nullable, aucune ligne existante n'est réécrite.
  final String? imageSquareUrl;
  final DateTime? publishedAt;
  final DateTime? clientCreatedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// **Un jour de calendrier, pas un instant** : `YYYY-MM-DD`, stocké en texte.
  /// Le lire en `DateTime` l'ancrerait à un instant, que le fuseau du lecteur
  /// afficherait un jour trop tôt. La date d'un culte ne se décale pas.
  final String? recordedAt;

  /// Couleur **brute** de la colonne serveur. `null` = « hérite de ma
  /// rubrique » : la cascade se termine à la lecture, sur une rubrique que le
  /// magasin possède déjà. Stocker la couleur résolue figerait une valeur que
  /// changer la couleur d'une rubrique ne toucherait jamais.
  final String? color;
  const TeachingRow(
      {required this.syncStamp,
      required this.id,
      this.ownerId,
      this.branchId,
      this.contributorId,
      this.teachingTypeId,
      required this.title,
      this.description,
      required this.isLive,
      required this.isFullService,
      this.playlistUrl,
      this.download,
      this.imageLandscapeUrl,
      this.imagePortraitUrl,
      this.imageSquareUrl,
      this.publishedAt,
      this.clientCreatedAt,
      this.createdAt,
      this.updatedAt,
      this.recordedAt,
      this.color});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['sync_stamp'] = Variable<int>(syncStamp);
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || ownerId != null) {
      map['owner_id'] = Variable<String>(ownerId);
    }
    if (!nullToAbsent || branchId != null) {
      map['branch_id'] = Variable<int>(branchId);
    }
    if (!nullToAbsent || contributorId != null) {
      map['contributor_id'] = Variable<int>(contributorId);
    }
    if (!nullToAbsent || teachingTypeId != null) {
      map['teaching_type_id'] = Variable<int>(teachingTypeId);
    }
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['is_live'] = Variable<bool>(isLive);
    map['is_full_service'] = Variable<bool>(isFullService);
    if (!nullToAbsent || playlistUrl != null) {
      map['playlist_url'] = Variable<String>(playlistUrl);
    }
    if (!nullToAbsent || download != null) {
      map['download'] =
          Variable<String>($TeachingsTable.$converterdownloadn.toSql(download));
    }
    if (!nullToAbsent || imageLandscapeUrl != null) {
      map['image_landscape_url'] = Variable<String>(imageLandscapeUrl);
    }
    if (!nullToAbsent || imagePortraitUrl != null) {
      map['image_portrait_url'] = Variable<String>(imagePortraitUrl);
    }
    if (!nullToAbsent || imageSquareUrl != null) {
      map['image_square_url'] = Variable<String>(imageSquareUrl);
    }
    if (!nullToAbsent || publishedAt != null) {
      map['published_at'] = Variable<DateTime>(publishedAt);
    }
    if (!nullToAbsent || clientCreatedAt != null) {
      map['client_created_at'] = Variable<DateTime>(clientCreatedAt);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    if (!nullToAbsent || recordedAt != null) {
      map['recorded_at'] = Variable<String>(recordedAt);
    }
    if (!nullToAbsent || color != null) {
      map['color'] = Variable<String>(color);
    }
    return map;
  }

  TeachingsCompanion toCompanion(bool nullToAbsent) {
    return TeachingsCompanion(
      syncStamp: Value(syncStamp),
      id: Value(id),
      ownerId: ownerId == null && nullToAbsent
          ? const Value.absent()
          : Value(ownerId),
      branchId: branchId == null && nullToAbsent
          ? const Value.absent()
          : Value(branchId),
      contributorId: contributorId == null && nullToAbsent
          ? const Value.absent()
          : Value(contributorId),
      teachingTypeId: teachingTypeId == null && nullToAbsent
          ? const Value.absent()
          : Value(teachingTypeId),
      title: Value(title),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      isLive: Value(isLive),
      isFullService: Value(isFullService),
      playlistUrl: playlistUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(playlistUrl),
      download: download == null && nullToAbsent
          ? const Value.absent()
          : Value(download),
      imageLandscapeUrl: imageLandscapeUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(imageLandscapeUrl),
      imagePortraitUrl: imagePortraitUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(imagePortraitUrl),
      imageSquareUrl: imageSquareUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(imageSquareUrl),
      publishedAt: publishedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(publishedAt),
      clientCreatedAt: clientCreatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(clientCreatedAt),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      recordedAt: recordedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(recordedAt),
      color:
          color == null && nullToAbsent ? const Value.absent() : Value(color),
    );
  }

  factory TeachingRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TeachingRow(
      syncStamp: serializer.fromJson<int>(json['syncStamp']),
      id: serializer.fromJson<String>(json['id']),
      ownerId: serializer.fromJson<String?>(json['ownerId']),
      branchId: serializer.fromJson<int?>(json['branchId']),
      contributorId: serializer.fromJson<int?>(json['contributorId']),
      teachingTypeId: serializer.fromJson<int?>(json['teachingTypeId']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String?>(json['description']),
      isLive: serializer.fromJson<bool>(json['isLive']),
      isFullService: serializer.fromJson<bool>(json['isFullService']),
      playlistUrl: serializer.fromJson<String?>(json['playlistUrl']),
      download: serializer.fromJson<TeachingDownload?>(json['download']),
      imageLandscapeUrl:
          serializer.fromJson<String?>(json['imageLandscapeUrl']),
      imagePortraitUrl: serializer.fromJson<String?>(json['imagePortraitUrl']),
      imageSquareUrl: serializer.fromJson<String?>(json['imageSquareUrl']),
      publishedAt: serializer.fromJson<DateTime?>(json['publishedAt']),
      clientCreatedAt: serializer.fromJson<DateTime?>(json['clientCreatedAt']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
      recordedAt: serializer.fromJson<String?>(json['recordedAt']),
      color: serializer.fromJson<String?>(json['color']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'syncStamp': serializer.toJson<int>(syncStamp),
      'id': serializer.toJson<String>(id),
      'ownerId': serializer.toJson<String?>(ownerId),
      'branchId': serializer.toJson<int?>(branchId),
      'contributorId': serializer.toJson<int?>(contributorId),
      'teachingTypeId': serializer.toJson<int?>(teachingTypeId),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String?>(description),
      'isLive': serializer.toJson<bool>(isLive),
      'isFullService': serializer.toJson<bool>(isFullService),
      'playlistUrl': serializer.toJson<String?>(playlistUrl),
      'download': serializer.toJson<TeachingDownload?>(download),
      'imageLandscapeUrl': serializer.toJson<String?>(imageLandscapeUrl),
      'imagePortraitUrl': serializer.toJson<String?>(imagePortraitUrl),
      'imageSquareUrl': serializer.toJson<String?>(imageSquareUrl),
      'publishedAt': serializer.toJson<DateTime?>(publishedAt),
      'clientCreatedAt': serializer.toJson<DateTime?>(clientCreatedAt),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
      'recordedAt': serializer.toJson<String?>(recordedAt),
      'color': serializer.toJson<String?>(color),
    };
  }

  TeachingRow copyWith(
          {int? syncStamp,
          String? id,
          Value<String?> ownerId = const Value.absent(),
          Value<int?> branchId = const Value.absent(),
          Value<int?> contributorId = const Value.absent(),
          Value<int?> teachingTypeId = const Value.absent(),
          String? title,
          Value<String?> description = const Value.absent(),
          bool? isLive,
          bool? isFullService,
          Value<String?> playlistUrl = const Value.absent(),
          Value<TeachingDownload?> download = const Value.absent(),
          Value<String?> imageLandscapeUrl = const Value.absent(),
          Value<String?> imagePortraitUrl = const Value.absent(),
          Value<String?> imageSquareUrl = const Value.absent(),
          Value<DateTime?> publishedAt = const Value.absent(),
          Value<DateTime?> clientCreatedAt = const Value.absent(),
          Value<DateTime?> createdAt = const Value.absent(),
          Value<DateTime?> updatedAt = const Value.absent(),
          Value<String?> recordedAt = const Value.absent(),
          Value<String?> color = const Value.absent()}) =>
      TeachingRow(
        syncStamp: syncStamp ?? this.syncStamp,
        id: id ?? this.id,
        ownerId: ownerId.present ? ownerId.value : this.ownerId,
        branchId: branchId.present ? branchId.value : this.branchId,
        contributorId:
            contributorId.present ? contributorId.value : this.contributorId,
        teachingTypeId:
            teachingTypeId.present ? teachingTypeId.value : this.teachingTypeId,
        title: title ?? this.title,
        description: description.present ? description.value : this.description,
        isLive: isLive ?? this.isLive,
        isFullService: isFullService ?? this.isFullService,
        playlistUrl: playlistUrl.present ? playlistUrl.value : this.playlistUrl,
        download: download.present ? download.value : this.download,
        imageLandscapeUrl: imageLandscapeUrl.present
            ? imageLandscapeUrl.value
            : this.imageLandscapeUrl,
        imagePortraitUrl: imagePortraitUrl.present
            ? imagePortraitUrl.value
            : this.imagePortraitUrl,
        imageSquareUrl:
            imageSquareUrl.present ? imageSquareUrl.value : this.imageSquareUrl,
        publishedAt: publishedAt.present ? publishedAt.value : this.publishedAt,
        clientCreatedAt: clientCreatedAt.present
            ? clientCreatedAt.value
            : this.clientCreatedAt,
        createdAt: createdAt.present ? createdAt.value : this.createdAt,
        updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
        recordedAt: recordedAt.present ? recordedAt.value : this.recordedAt,
        color: color.present ? color.value : this.color,
      );
  TeachingRow copyWithCompanion(TeachingsCompanion data) {
    return TeachingRow(
      syncStamp: data.syncStamp.present ? data.syncStamp.value : this.syncStamp,
      id: data.id.present ? data.id.value : this.id,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      branchId: data.branchId.present ? data.branchId.value : this.branchId,
      contributorId: data.contributorId.present
          ? data.contributorId.value
          : this.contributorId,
      teachingTypeId: data.teachingTypeId.present
          ? data.teachingTypeId.value
          : this.teachingTypeId,
      title: data.title.present ? data.title.value : this.title,
      description:
          data.description.present ? data.description.value : this.description,
      isLive: data.isLive.present ? data.isLive.value : this.isLive,
      isFullService: data.isFullService.present
          ? data.isFullService.value
          : this.isFullService,
      playlistUrl:
          data.playlistUrl.present ? data.playlistUrl.value : this.playlistUrl,
      download: data.download.present ? data.download.value : this.download,
      imageLandscapeUrl: data.imageLandscapeUrl.present
          ? data.imageLandscapeUrl.value
          : this.imageLandscapeUrl,
      imagePortraitUrl: data.imagePortraitUrl.present
          ? data.imagePortraitUrl.value
          : this.imagePortraitUrl,
      imageSquareUrl: data.imageSquareUrl.present
          ? data.imageSquareUrl.value
          : this.imageSquareUrl,
      publishedAt:
          data.publishedAt.present ? data.publishedAt.value : this.publishedAt,
      clientCreatedAt: data.clientCreatedAt.present
          ? data.clientCreatedAt.value
          : this.clientCreatedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      recordedAt:
          data.recordedAt.present ? data.recordedAt.value : this.recordedAt,
      color: data.color.present ? data.color.value : this.color,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TeachingRow(')
          ..write('syncStamp: $syncStamp, ')
          ..write('id: $id, ')
          ..write('ownerId: $ownerId, ')
          ..write('branchId: $branchId, ')
          ..write('contributorId: $contributorId, ')
          ..write('teachingTypeId: $teachingTypeId, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('isLive: $isLive, ')
          ..write('isFullService: $isFullService, ')
          ..write('playlistUrl: $playlistUrl, ')
          ..write('download: $download, ')
          ..write('imageLandscapeUrl: $imageLandscapeUrl, ')
          ..write('imagePortraitUrl: $imagePortraitUrl, ')
          ..write('imageSquareUrl: $imageSquareUrl, ')
          ..write('publishedAt: $publishedAt, ')
          ..write('clientCreatedAt: $clientCreatedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('recordedAt: $recordedAt, ')
          ..write('color: $color')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
        syncStamp,
        id,
        ownerId,
        branchId,
        contributorId,
        teachingTypeId,
        title,
        description,
        isLive,
        isFullService,
        playlistUrl,
        download,
        imageLandscapeUrl,
        imagePortraitUrl,
        imageSquareUrl,
        publishedAt,
        clientCreatedAt,
        createdAt,
        updatedAt,
        recordedAt,
        color
      ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TeachingRow &&
          other.syncStamp == this.syncStamp &&
          other.id == this.id &&
          other.ownerId == this.ownerId &&
          other.branchId == this.branchId &&
          other.contributorId == this.contributorId &&
          other.teachingTypeId == this.teachingTypeId &&
          other.title == this.title &&
          other.description == this.description &&
          other.isLive == this.isLive &&
          other.isFullService == this.isFullService &&
          other.playlistUrl == this.playlistUrl &&
          other.download == this.download &&
          other.imageLandscapeUrl == this.imageLandscapeUrl &&
          other.imagePortraitUrl == this.imagePortraitUrl &&
          other.imageSquareUrl == this.imageSquareUrl &&
          other.publishedAt == this.publishedAt &&
          other.clientCreatedAt == this.clientCreatedAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.recordedAt == this.recordedAt &&
          other.color == this.color);
}

class TeachingsCompanion extends UpdateCompanion<TeachingRow> {
  final Value<int> syncStamp;
  final Value<String> id;
  final Value<String?> ownerId;
  final Value<int?> branchId;
  final Value<int?> contributorId;
  final Value<int?> teachingTypeId;
  final Value<String> title;
  final Value<String?> description;
  final Value<bool> isLive;
  final Value<bool> isFullService;
  final Value<String?> playlistUrl;
  final Value<TeachingDownload?> download;
  final Value<String?> imageLandscapeUrl;
  final Value<String?> imagePortraitUrl;
  final Value<String?> imageSquareUrl;
  final Value<DateTime?> publishedAt;
  final Value<DateTime?> clientCreatedAt;
  final Value<DateTime?> createdAt;
  final Value<DateTime?> updatedAt;
  final Value<String?> recordedAt;
  final Value<String?> color;
  final Value<int> rowid;
  const TeachingsCompanion({
    this.syncStamp = const Value.absent(),
    this.id = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.branchId = const Value.absent(),
    this.contributorId = const Value.absent(),
    this.teachingTypeId = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.isLive = const Value.absent(),
    this.isFullService = const Value.absent(),
    this.playlistUrl = const Value.absent(),
    this.download = const Value.absent(),
    this.imageLandscapeUrl = const Value.absent(),
    this.imagePortraitUrl = const Value.absent(),
    this.imageSquareUrl = const Value.absent(),
    this.publishedAt = const Value.absent(),
    this.clientCreatedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.recordedAt = const Value.absent(),
    this.color = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TeachingsCompanion.insert({
    this.syncStamp = const Value.absent(),
    required String id,
    this.ownerId = const Value.absent(),
    this.branchId = const Value.absent(),
    this.contributorId = const Value.absent(),
    this.teachingTypeId = const Value.absent(),
    required String title,
    this.description = const Value.absent(),
    this.isLive = const Value.absent(),
    this.isFullService = const Value.absent(),
    this.playlistUrl = const Value.absent(),
    this.download = const Value.absent(),
    this.imageLandscapeUrl = const Value.absent(),
    this.imagePortraitUrl = const Value.absent(),
    this.imageSquareUrl = const Value.absent(),
    this.publishedAt = const Value.absent(),
    this.clientCreatedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.recordedAt = const Value.absent(),
    this.color = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        title = Value(title);
  static Insertable<TeachingRow> custom({
    Expression<int>? syncStamp,
    Expression<String>? id,
    Expression<String>? ownerId,
    Expression<int>? branchId,
    Expression<int>? contributorId,
    Expression<int>? teachingTypeId,
    Expression<String>? title,
    Expression<String>? description,
    Expression<bool>? isLive,
    Expression<bool>? isFullService,
    Expression<String>? playlistUrl,
    Expression<String>? download,
    Expression<String>? imageLandscapeUrl,
    Expression<String>? imagePortraitUrl,
    Expression<String>? imageSquareUrl,
    Expression<DateTime>? publishedAt,
    Expression<DateTime>? clientCreatedAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? recordedAt,
    Expression<String>? color,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (syncStamp != null) 'sync_stamp': syncStamp,
      if (id != null) 'id': id,
      if (ownerId != null) 'owner_id': ownerId,
      if (branchId != null) 'branch_id': branchId,
      if (contributorId != null) 'contributor_id': contributorId,
      if (teachingTypeId != null) 'teaching_type_id': teachingTypeId,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (isLive != null) 'is_live': isLive,
      if (isFullService != null) 'is_full_service': isFullService,
      if (playlistUrl != null) 'playlist_url': playlistUrl,
      if (download != null) 'download': download,
      if (imageLandscapeUrl != null) 'image_landscape_url': imageLandscapeUrl,
      if (imagePortraitUrl != null) 'image_portrait_url': imagePortraitUrl,
      if (imageSquareUrl != null) 'image_square_url': imageSquareUrl,
      if (publishedAt != null) 'published_at': publishedAt,
      if (clientCreatedAt != null) 'client_created_at': clientCreatedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (recordedAt != null) 'recorded_at': recordedAt,
      if (color != null) 'color': color,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TeachingsCompanion copyWith(
      {Value<int>? syncStamp,
      Value<String>? id,
      Value<String?>? ownerId,
      Value<int?>? branchId,
      Value<int?>? contributorId,
      Value<int?>? teachingTypeId,
      Value<String>? title,
      Value<String?>? description,
      Value<bool>? isLive,
      Value<bool>? isFullService,
      Value<String?>? playlistUrl,
      Value<TeachingDownload?>? download,
      Value<String?>? imageLandscapeUrl,
      Value<String?>? imagePortraitUrl,
      Value<String?>? imageSquareUrl,
      Value<DateTime?>? publishedAt,
      Value<DateTime?>? clientCreatedAt,
      Value<DateTime?>? createdAt,
      Value<DateTime?>? updatedAt,
      Value<String?>? recordedAt,
      Value<String?>? color,
      Value<int>? rowid}) {
    return TeachingsCompanion(
      syncStamp: syncStamp ?? this.syncStamp,
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      branchId: branchId ?? this.branchId,
      contributorId: contributorId ?? this.contributorId,
      teachingTypeId: teachingTypeId ?? this.teachingTypeId,
      title: title ?? this.title,
      description: description ?? this.description,
      isLive: isLive ?? this.isLive,
      isFullService: isFullService ?? this.isFullService,
      playlistUrl: playlistUrl ?? this.playlistUrl,
      download: download ?? this.download,
      imageLandscapeUrl: imageLandscapeUrl ?? this.imageLandscapeUrl,
      imagePortraitUrl: imagePortraitUrl ?? this.imagePortraitUrl,
      imageSquareUrl: imageSquareUrl ?? this.imageSquareUrl,
      publishedAt: publishedAt ?? this.publishedAt,
      clientCreatedAt: clientCreatedAt ?? this.clientCreatedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      recordedAt: recordedAt ?? this.recordedAt,
      color: color ?? this.color,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (syncStamp.present) {
      map['sync_stamp'] = Variable<int>(syncStamp.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (branchId.present) {
      map['branch_id'] = Variable<int>(branchId.value);
    }
    if (contributorId.present) {
      map['contributor_id'] = Variable<int>(contributorId.value);
    }
    if (teachingTypeId.present) {
      map['teaching_type_id'] = Variable<int>(teachingTypeId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (isLive.present) {
      map['is_live'] = Variable<bool>(isLive.value);
    }
    if (isFullService.present) {
      map['is_full_service'] = Variable<bool>(isFullService.value);
    }
    if (playlistUrl.present) {
      map['playlist_url'] = Variable<String>(playlistUrl.value);
    }
    if (download.present) {
      map['download'] = Variable<String>(
          $TeachingsTable.$converterdownloadn.toSql(download.value));
    }
    if (imageLandscapeUrl.present) {
      map['image_landscape_url'] = Variable<String>(imageLandscapeUrl.value);
    }
    if (imagePortraitUrl.present) {
      map['image_portrait_url'] = Variable<String>(imagePortraitUrl.value);
    }
    if (imageSquareUrl.present) {
      map['image_square_url'] = Variable<String>(imageSquareUrl.value);
    }
    if (publishedAt.present) {
      map['published_at'] = Variable<DateTime>(publishedAt.value);
    }
    if (clientCreatedAt.present) {
      map['client_created_at'] = Variable<DateTime>(clientCreatedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (recordedAt.present) {
      map['recorded_at'] = Variable<String>(recordedAt.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TeachingsCompanion(')
          ..write('syncStamp: $syncStamp, ')
          ..write('id: $id, ')
          ..write('ownerId: $ownerId, ')
          ..write('branchId: $branchId, ')
          ..write('contributorId: $contributorId, ')
          ..write('teachingTypeId: $teachingTypeId, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('isLive: $isLive, ')
          ..write('isFullService: $isFullService, ')
          ..write('playlistUrl: $playlistUrl, ')
          ..write('download: $download, ')
          ..write('imageLandscapeUrl: $imageLandscapeUrl, ')
          ..write('imagePortraitUrl: $imagePortraitUrl, ')
          ..write('imageSquareUrl: $imageSquareUrl, ')
          ..write('publishedAt: $publishedAt, ')
          ..write('clientCreatedAt: $clientCreatedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('recordedAt: $recordedAt, ')
          ..write('color: $color, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TeachingGuestsTable extends TeachingGuests
    with TableInfo<$TeachingGuestsTable, TeachingGuestRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TeachingGuestsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _syncStampMeta =
      const VerificationMeta('syncStamp');
  @override
  late final GeneratedColumn<int> syncStamp = GeneratedColumn<int>(
      'sync_stamp', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _teachingIdMeta =
      const VerificationMeta('teachingId');
  @override
  late final GeneratedColumn<String> teachingId = GeneratedColumn<String>(
      'teaching_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _contributorIdMeta =
      const VerificationMeta('contributorId');
  @override
  late final GeneratedColumn<int> contributorId = GeneratedColumn<int>(
      'contributor_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _positionMeta =
      const VerificationMeta('position');
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
      'position', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        syncStamp,
        id,
        teachingId,
        contributorId,
        position,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'teaching_guests';
  @override
  VerificationContext validateIntegrity(Insertable<TeachingGuestRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('sync_stamp')) {
      context.handle(_syncStampMeta,
          syncStamp.isAcceptableOrUnknown(data['sync_stamp']!, _syncStampMeta));
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('teaching_id')) {
      context.handle(
          _teachingIdMeta,
          teachingId.isAcceptableOrUnknown(
              data['teaching_id']!, _teachingIdMeta));
    } else if (isInserting) {
      context.missing(_teachingIdMeta);
    }
    if (data.containsKey('contributor_id')) {
      context.handle(
          _contributorIdMeta,
          contributorId.isAcceptableOrUnknown(
              data['contributor_id']!, _contributorIdMeta));
    } else if (isInserting) {
      context.missing(_contributorIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(_positionMeta,
          position.isAcceptableOrUnknown(data['position']!, _positionMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TeachingGuestRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TeachingGuestRow(
      syncStamp: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sync_stamp'])!,
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      teachingId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}teaching_id'])!,
      contributorId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}contributor_id'])!,
      position: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}position'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at']),
    );
  }

  @override
  $TeachingGuestsTable createAlias(String alias) {
    return $TeachingGuestsTable(attachedDatabase, alias);
  }
}

class TeachingGuestRow extends DataClass
    implements Insertable<TeachingGuestRow> {
  /// Jeton de la transaction qui a écrit cette ligne pour la dernière fois.
  ///
  /// Le défaut existe pour que l'appelant n'ait **pas** à le renseigner : le
  /// jeton est une mécanique du magasin, posée par `SyncDao`, pas une donnée du
  /// serveur. Une ligne qui arriverait ici sans jeton porterait `0`, donc
  /// serait traitée comme jamais revue — la panne va dans le sens sûr.
  final int syncStamp;

  /// `increments` côté serveur : un **entier**, comme les référentiels — et non
  /// l'UUIDv7 des contenus. C'est ce type que le protocole préserve de bout en
  /// bout, pour ne jamais comparer `'10' < '9'`.
  final int id;

  /// **Chaîne nue, sans clé étrangère** vers `teachings` (UUIDv7) : les deux
  /// collections se resynchronisent séparément, et un crédit peut arriver avant
  /// le contenu qu'il crédite. Une contrainte ferait échouer la page entière.
  final String teachingId;

  /// **Entier nu, sans clé étrangère** vers `contributors`, même raison. La
  /// jointure de lecture est tolérante : un invité dont la ligne `contributors`
  /// n'est pas encore arrivée ne fait pas disparaître les autres.
  final int contributorId;

  /// L'ordre **saisi** au portail, **1-based** — le générique d'un enseignement
  /// à plusieurs voix n'est pas une liste alphabétique. Le défaut vaut `1` comme
  /// côté serveur : une ligne sans position se range en tête plutôt que de
  /// disparaître derrière un `0` qu'aucun écran n'attend.
  final int position;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  const TeachingGuestRow(
      {required this.syncStamp,
      required this.id,
      required this.teachingId,
      required this.contributorId,
      required this.position,
      this.createdAt,
      this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['sync_stamp'] = Variable<int>(syncStamp);
    map['id'] = Variable<int>(id);
    map['teaching_id'] = Variable<String>(teachingId);
    map['contributor_id'] = Variable<int>(contributorId);
    map['position'] = Variable<int>(position);
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    return map;
  }

  TeachingGuestsCompanion toCompanion(bool nullToAbsent) {
    return TeachingGuestsCompanion(
      syncStamp: Value(syncStamp),
      id: Value(id),
      teachingId: Value(teachingId),
      contributorId: Value(contributorId),
      position: Value(position),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory TeachingGuestRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TeachingGuestRow(
      syncStamp: serializer.fromJson<int>(json['syncStamp']),
      id: serializer.fromJson<int>(json['id']),
      teachingId: serializer.fromJson<String>(json['teachingId']),
      contributorId: serializer.fromJson<int>(json['contributorId']),
      position: serializer.fromJson<int>(json['position']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'syncStamp': serializer.toJson<int>(syncStamp),
      'id': serializer.toJson<int>(id),
      'teachingId': serializer.toJson<String>(teachingId),
      'contributorId': serializer.toJson<int>(contributorId),
      'position': serializer.toJson<int>(position),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
    };
  }

  TeachingGuestRow copyWith(
          {int? syncStamp,
          int? id,
          String? teachingId,
          int? contributorId,
          int? position,
          Value<DateTime?> createdAt = const Value.absent(),
          Value<DateTime?> updatedAt = const Value.absent()}) =>
      TeachingGuestRow(
        syncStamp: syncStamp ?? this.syncStamp,
        id: id ?? this.id,
        teachingId: teachingId ?? this.teachingId,
        contributorId: contributorId ?? this.contributorId,
        position: position ?? this.position,
        createdAt: createdAt.present ? createdAt.value : this.createdAt,
        updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
      );
  TeachingGuestRow copyWithCompanion(TeachingGuestsCompanion data) {
    return TeachingGuestRow(
      syncStamp: data.syncStamp.present ? data.syncStamp.value : this.syncStamp,
      id: data.id.present ? data.id.value : this.id,
      teachingId:
          data.teachingId.present ? data.teachingId.value : this.teachingId,
      contributorId: data.contributorId.present
          ? data.contributorId.value
          : this.contributorId,
      position: data.position.present ? data.position.value : this.position,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TeachingGuestRow(')
          ..write('syncStamp: $syncStamp, ')
          ..write('id: $id, ')
          ..write('teachingId: $teachingId, ')
          ..write('contributorId: $contributorId, ')
          ..write('position: $position, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      syncStamp, id, teachingId, contributorId, position, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TeachingGuestRow &&
          other.syncStamp == this.syncStamp &&
          other.id == this.id &&
          other.teachingId == this.teachingId &&
          other.contributorId == this.contributorId &&
          other.position == this.position &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class TeachingGuestsCompanion extends UpdateCompanion<TeachingGuestRow> {
  final Value<int> syncStamp;
  final Value<int> id;
  final Value<String> teachingId;
  final Value<int> contributorId;
  final Value<int> position;
  final Value<DateTime?> createdAt;
  final Value<DateTime?> updatedAt;
  const TeachingGuestsCompanion({
    this.syncStamp = const Value.absent(),
    this.id = const Value.absent(),
    this.teachingId = const Value.absent(),
    this.contributorId = const Value.absent(),
    this.position = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  TeachingGuestsCompanion.insert({
    this.syncStamp = const Value.absent(),
    this.id = const Value.absent(),
    required String teachingId,
    required int contributorId,
    this.position = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  })  : teachingId = Value(teachingId),
        contributorId = Value(contributorId);
  static Insertable<TeachingGuestRow> custom({
    Expression<int>? syncStamp,
    Expression<int>? id,
    Expression<String>? teachingId,
    Expression<int>? contributorId,
    Expression<int>? position,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (syncStamp != null) 'sync_stamp': syncStamp,
      if (id != null) 'id': id,
      if (teachingId != null) 'teaching_id': teachingId,
      if (contributorId != null) 'contributor_id': contributorId,
      if (position != null) 'position': position,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  TeachingGuestsCompanion copyWith(
      {Value<int>? syncStamp,
      Value<int>? id,
      Value<String>? teachingId,
      Value<int>? contributorId,
      Value<int>? position,
      Value<DateTime?>? createdAt,
      Value<DateTime?>? updatedAt}) {
    return TeachingGuestsCompanion(
      syncStamp: syncStamp ?? this.syncStamp,
      id: id ?? this.id,
      teachingId: teachingId ?? this.teachingId,
      contributorId: contributorId ?? this.contributorId,
      position: position ?? this.position,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (syncStamp.present) {
      map['sync_stamp'] = Variable<int>(syncStamp.value);
    }
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (teachingId.present) {
      map['teaching_id'] = Variable<String>(teachingId.value);
    }
    if (contributorId.present) {
      map['contributor_id'] = Variable<int>(contributorId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TeachingGuestsCompanion(')
          ..write('syncStamp: $syncStamp, ')
          ..write('id: $id, ')
          ..write('teachingId: $teachingId, ')
          ..write('contributorId: $contributorId, ')
          ..write('position: $position, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $GatheringTypesTable extends GatheringTypes
    with TableInfo<$GatheringTypesTable, GatheringTypeRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GatheringTypesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _syncStampMeta =
      const VerificationMeta('syncStamp');
  @override
  late final GeneratedColumn<int> syncStamp = GeneratedColumn<int>(
      'sync_stamp', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  @override
  late final GeneratedColumnWithTypeConverter<Map<String, String>, String>
      label = GeneratedColumn<String>('label', aliasedName, false,
              type: DriftSqlType.string, requiredDuringInsert: true)
          .withConverter<Map<String, String>>(
              $GatheringTypesTable.$converterlabel);
  static const VerificationMeta _slugMeta = const VerificationMeta('slug');
  @override
  late final GeneratedColumn<String> slug = GeneratedColumn<String>(
      'slug', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
      'icon', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
      'color', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _positionMeta =
      const VerificationMeta('position');
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
      'position', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _visibleOnHomeMeta =
      const VerificationMeta('visibleOnHome');
  @override
  late final GeneratedColumn<bool> visibleOnHome = GeneratedColumn<bool>(
      'visible_on_home', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("visible_on_home" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _layoutMeta = const VerificationMeta('layout');
  @override
  late final GeneratedColumn<String> layout = GeneratedColumn<String>(
      'layout', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        syncStamp,
        id,
        label,
        slug,
        icon,
        color,
        position,
        visibleOnHome,
        layout,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'gathering_types';
  @override
  VerificationContext validateIntegrity(Insertable<GatheringTypeRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('sync_stamp')) {
      context.handle(_syncStampMeta,
          syncStamp.isAcceptableOrUnknown(data['sync_stamp']!, _syncStampMeta));
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('slug')) {
      context.handle(
          _slugMeta, slug.isAcceptableOrUnknown(data['slug']!, _slugMeta));
    } else if (isInserting) {
      context.missing(_slugMeta);
    }
    if (data.containsKey('icon')) {
      context.handle(
          _iconMeta, icon.isAcceptableOrUnknown(data['icon']!, _iconMeta));
    }
    if (data.containsKey('color')) {
      context.handle(
          _colorMeta, color.isAcceptableOrUnknown(data['color']!, _colorMeta));
    }
    if (data.containsKey('position')) {
      context.handle(_positionMeta,
          position.isAcceptableOrUnknown(data['position']!, _positionMeta));
    }
    if (data.containsKey('visible_on_home')) {
      context.handle(
          _visibleOnHomeMeta,
          visibleOnHome.isAcceptableOrUnknown(
              data['visible_on_home']!, _visibleOnHomeMeta));
    }
    if (data.containsKey('layout')) {
      context.handle(_layoutMeta,
          layout.isAcceptableOrUnknown(data['layout']!, _layoutMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GatheringTypeRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GatheringTypeRow(
      syncStamp: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sync_stamp'])!,
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      label: $GatheringTypesTable.$converterlabel.fromSql(attachedDatabase
          .typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}label'])!),
      slug: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}slug'])!,
      icon: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}icon']),
      color: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}color']),
      position: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}position'])!,
      visibleOnHome: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}visible_on_home'])!,
      layout: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}layout']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at']),
    );
  }

  @override
  $GatheringTypesTable createAlias(String alias) {
    return $GatheringTypesTable(attachedDatabase, alias);
  }

  static TypeConverter<Map<String, String>, String> $converterlabel =
      const I18nMapConverter();
}

class GatheringTypeRow extends DataClass
    implements Insertable<GatheringTypeRow> {
  /// Jeton de la transaction qui a écrit cette ligne pour la dernière fois.
  ///
  /// Le défaut existe pour que l'appelant n'ait **pas** à le renseigner : le
  /// jeton est une mécanique du magasin, posée par `SyncDao`, pas une donnée du
  /// serveur. Une ligne qui arriverait ici sans jeton porterait `0`, donc
  /// serait traitée comme jamais revue — la panne va dans le sens sûr.
  final int syncStamp;
  final int id;

  /// Carte de traduction **entière** `{fr, en, ee}` — jamais la langue retenue.
  /// Le repli se fait à la lecture, via `utils/i18n_text.dart` → `pick`.
  final Map<String, String> label;

  /// Clé stable que le mobile reconnaît : elle survit au renommage du libellé.
  final String slug;
  final String? icon;

  /// Couleur de la rubrique — **dernier maillon** de la cascade, résolue à la
  /// lecture et jamais à l'écriture.
  final String? color;
  final int position;

  /// `false` = la rubrique a quitté l'accueil, mais ses rassemblements restent.
  final bool visibleOnHome;

  /// `hero` | `carousel` | `list`. Stocké **tel quel**, jamais en enum : le
  /// référentiel est administrable. Une valeur inconnue se replie à l'affichage.
  final String? layout;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  const GatheringTypeRow(
      {required this.syncStamp,
      required this.id,
      required this.label,
      required this.slug,
      this.icon,
      this.color,
      required this.position,
      required this.visibleOnHome,
      this.layout,
      this.createdAt,
      this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['sync_stamp'] = Variable<int>(syncStamp);
    map['id'] = Variable<int>(id);
    {
      map['label'] =
          Variable<String>($GatheringTypesTable.$converterlabel.toSql(label));
    }
    map['slug'] = Variable<String>(slug);
    if (!nullToAbsent || icon != null) {
      map['icon'] = Variable<String>(icon);
    }
    if (!nullToAbsent || color != null) {
      map['color'] = Variable<String>(color);
    }
    map['position'] = Variable<int>(position);
    map['visible_on_home'] = Variable<bool>(visibleOnHome);
    if (!nullToAbsent || layout != null) {
      map['layout'] = Variable<String>(layout);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    return map;
  }

  GatheringTypesCompanion toCompanion(bool nullToAbsent) {
    return GatheringTypesCompanion(
      syncStamp: Value(syncStamp),
      id: Value(id),
      label: Value(label),
      slug: Value(slug),
      icon: icon == null && nullToAbsent ? const Value.absent() : Value(icon),
      color:
          color == null && nullToAbsent ? const Value.absent() : Value(color),
      position: Value(position),
      visibleOnHome: Value(visibleOnHome),
      layout:
          layout == null && nullToAbsent ? const Value.absent() : Value(layout),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory GatheringTypeRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GatheringTypeRow(
      syncStamp: serializer.fromJson<int>(json['syncStamp']),
      id: serializer.fromJson<int>(json['id']),
      label: serializer.fromJson<Map<String, String>>(json['label']),
      slug: serializer.fromJson<String>(json['slug']),
      icon: serializer.fromJson<String?>(json['icon']),
      color: serializer.fromJson<String?>(json['color']),
      position: serializer.fromJson<int>(json['position']),
      visibleOnHome: serializer.fromJson<bool>(json['visibleOnHome']),
      layout: serializer.fromJson<String?>(json['layout']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'syncStamp': serializer.toJson<int>(syncStamp),
      'id': serializer.toJson<int>(id),
      'label': serializer.toJson<Map<String, String>>(label),
      'slug': serializer.toJson<String>(slug),
      'icon': serializer.toJson<String?>(icon),
      'color': serializer.toJson<String?>(color),
      'position': serializer.toJson<int>(position),
      'visibleOnHome': serializer.toJson<bool>(visibleOnHome),
      'layout': serializer.toJson<String?>(layout),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
    };
  }

  GatheringTypeRow copyWith(
          {int? syncStamp,
          int? id,
          Map<String, String>? label,
          String? slug,
          Value<String?> icon = const Value.absent(),
          Value<String?> color = const Value.absent(),
          int? position,
          bool? visibleOnHome,
          Value<String?> layout = const Value.absent(),
          Value<DateTime?> createdAt = const Value.absent(),
          Value<DateTime?> updatedAt = const Value.absent()}) =>
      GatheringTypeRow(
        syncStamp: syncStamp ?? this.syncStamp,
        id: id ?? this.id,
        label: label ?? this.label,
        slug: slug ?? this.slug,
        icon: icon.present ? icon.value : this.icon,
        color: color.present ? color.value : this.color,
        position: position ?? this.position,
        visibleOnHome: visibleOnHome ?? this.visibleOnHome,
        layout: layout.present ? layout.value : this.layout,
        createdAt: createdAt.present ? createdAt.value : this.createdAt,
        updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
      );
  GatheringTypeRow copyWithCompanion(GatheringTypesCompanion data) {
    return GatheringTypeRow(
      syncStamp: data.syncStamp.present ? data.syncStamp.value : this.syncStamp,
      id: data.id.present ? data.id.value : this.id,
      label: data.label.present ? data.label.value : this.label,
      slug: data.slug.present ? data.slug.value : this.slug,
      icon: data.icon.present ? data.icon.value : this.icon,
      color: data.color.present ? data.color.value : this.color,
      position: data.position.present ? data.position.value : this.position,
      visibleOnHome: data.visibleOnHome.present
          ? data.visibleOnHome.value
          : this.visibleOnHome,
      layout: data.layout.present ? data.layout.value : this.layout,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GatheringTypeRow(')
          ..write('syncStamp: $syncStamp, ')
          ..write('id: $id, ')
          ..write('label: $label, ')
          ..write('slug: $slug, ')
          ..write('icon: $icon, ')
          ..write('color: $color, ')
          ..write('position: $position, ')
          ..write('visibleOnHome: $visibleOnHome, ')
          ..write('layout: $layout, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(syncStamp, id, label, slug, icon, color,
      position, visibleOnHome, layout, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GatheringTypeRow &&
          other.syncStamp == this.syncStamp &&
          other.id == this.id &&
          other.label == this.label &&
          other.slug == this.slug &&
          other.icon == this.icon &&
          other.color == this.color &&
          other.position == this.position &&
          other.visibleOnHome == this.visibleOnHome &&
          other.layout == this.layout &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class GatheringTypesCompanion extends UpdateCompanion<GatheringTypeRow> {
  final Value<int> syncStamp;
  final Value<int> id;
  final Value<Map<String, String>> label;
  final Value<String> slug;
  final Value<String?> icon;
  final Value<String?> color;
  final Value<int> position;
  final Value<bool> visibleOnHome;
  final Value<String?> layout;
  final Value<DateTime?> createdAt;
  final Value<DateTime?> updatedAt;
  const GatheringTypesCompanion({
    this.syncStamp = const Value.absent(),
    this.id = const Value.absent(),
    this.label = const Value.absent(),
    this.slug = const Value.absent(),
    this.icon = const Value.absent(),
    this.color = const Value.absent(),
    this.position = const Value.absent(),
    this.visibleOnHome = const Value.absent(),
    this.layout = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  GatheringTypesCompanion.insert({
    this.syncStamp = const Value.absent(),
    this.id = const Value.absent(),
    required Map<String, String> label,
    required String slug,
    this.icon = const Value.absent(),
    this.color = const Value.absent(),
    this.position = const Value.absent(),
    this.visibleOnHome = const Value.absent(),
    this.layout = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  })  : label = Value(label),
        slug = Value(slug);
  static Insertable<GatheringTypeRow> custom({
    Expression<int>? syncStamp,
    Expression<int>? id,
    Expression<String>? label,
    Expression<String>? slug,
    Expression<String>? icon,
    Expression<String>? color,
    Expression<int>? position,
    Expression<bool>? visibleOnHome,
    Expression<String>? layout,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (syncStamp != null) 'sync_stamp': syncStamp,
      if (id != null) 'id': id,
      if (label != null) 'label': label,
      if (slug != null) 'slug': slug,
      if (icon != null) 'icon': icon,
      if (color != null) 'color': color,
      if (position != null) 'position': position,
      if (visibleOnHome != null) 'visible_on_home': visibleOnHome,
      if (layout != null) 'layout': layout,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  GatheringTypesCompanion copyWith(
      {Value<int>? syncStamp,
      Value<int>? id,
      Value<Map<String, String>>? label,
      Value<String>? slug,
      Value<String?>? icon,
      Value<String?>? color,
      Value<int>? position,
      Value<bool>? visibleOnHome,
      Value<String?>? layout,
      Value<DateTime?>? createdAt,
      Value<DateTime?>? updatedAt}) {
    return GatheringTypesCompanion(
      syncStamp: syncStamp ?? this.syncStamp,
      id: id ?? this.id,
      label: label ?? this.label,
      slug: slug ?? this.slug,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      position: position ?? this.position,
      visibleOnHome: visibleOnHome ?? this.visibleOnHome,
      layout: layout ?? this.layout,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (syncStamp.present) {
      map['sync_stamp'] = Variable<int>(syncStamp.value);
    }
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(
          $GatheringTypesTable.$converterlabel.toSql(label.value));
    }
    if (slug.present) {
      map['slug'] = Variable<String>(slug.value);
    }
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (visibleOnHome.present) {
      map['visible_on_home'] = Variable<bool>(visibleOnHome.value);
    }
    if (layout.present) {
      map['layout'] = Variable<String>(layout.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GatheringTypesCompanion(')
          ..write('syncStamp: $syncStamp, ')
          ..write('id: $id, ')
          ..write('label: $label, ')
          ..write('slug: $slug, ')
          ..write('icon: $icon, ')
          ..write('color: $color, ')
          ..write('position: $position, ')
          ..write('visibleOnHome: $visibleOnHome, ')
          ..write('layout: $layout, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $GatheringsTable extends Gatherings
    with TableInfo<$GatheringsTable, GatheringRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GatheringsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _syncStampMeta =
      const VerificationMeta('syncStamp');
  @override
  late final GeneratedColumn<int> syncStamp = GeneratedColumn<int>(
      'sync_stamp', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _ownerIdMeta =
      const VerificationMeta('ownerId');
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
      'owner_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _branchIdMeta =
      const VerificationMeta('branchId');
  @override
  late final GeneratedColumn<int> branchId = GeneratedColumn<int>(
      'branch_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _contributorIdMeta =
      const VerificationMeta('contributorId');
  @override
  late final GeneratedColumn<int> contributorId = GeneratedColumn<int>(
      'contributor_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _teachingTypeIdMeta =
      const VerificationMeta('teachingTypeId');
  @override
  late final GeneratedColumn<int> teachingTypeId = GeneratedColumn<int>(
      'teaching_type_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isLiveMeta = const VerificationMeta('isLive');
  @override
  late final GeneratedColumn<bool> isLive = GeneratedColumn<bool>(
      'is_live', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_live" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _isFullServiceMeta =
      const VerificationMeta('isFullService');
  @override
  late final GeneratedColumn<bool> isFullService = GeneratedColumn<bool>(
      'is_full_service', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_full_service" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _playlistUrlMeta =
      const VerificationMeta('playlistUrl');
  @override
  late final GeneratedColumn<String> playlistUrl = GeneratedColumn<String>(
      'playlist_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _imageLandscapeUrlMeta =
      const VerificationMeta('imageLandscapeUrl');
  @override
  late final GeneratedColumn<String> imageLandscapeUrl =
      GeneratedColumn<String>('image_landscape_url', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _imagePortraitUrlMeta =
      const VerificationMeta('imagePortraitUrl');
  @override
  late final GeneratedColumn<String> imagePortraitUrl = GeneratedColumn<String>(
      'image_portrait_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _publishedAtMeta =
      const VerificationMeta('publishedAt');
  @override
  late final GeneratedColumn<DateTime> publishedAt = GeneratedColumn<DateTime>(
      'published_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _clientCreatedAtMeta =
      const VerificationMeta('clientCreatedAt');
  @override
  late final GeneratedColumn<DateTime> clientCreatedAt =
      GeneratedColumn<DateTime>('client_created_at', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _recordedAtMeta =
      const VerificationMeta('recordedAt');
  @override
  late final GeneratedColumn<String> recordedAt = GeneratedColumn<String>(
      'recorded_at', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
      'color', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        syncStamp,
        id,
        ownerId,
        branchId,
        contributorId,
        teachingTypeId,
        title,
        description,
        isLive,
        isFullService,
        playlistUrl,
        imageLandscapeUrl,
        imagePortraitUrl,
        publishedAt,
        clientCreatedAt,
        createdAt,
        updatedAt,
        recordedAt,
        color
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'gatherings';
  @override
  VerificationContext validateIntegrity(Insertable<GatheringRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('sync_stamp')) {
      context.handle(_syncStampMeta,
          syncStamp.isAcceptableOrUnknown(data['sync_stamp']!, _syncStampMeta));
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('owner_id')) {
      context.handle(_ownerIdMeta,
          ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta));
    }
    if (data.containsKey('branch_id')) {
      context.handle(_branchIdMeta,
          branchId.isAcceptableOrUnknown(data['branch_id']!, _branchIdMeta));
    }
    if (data.containsKey('contributor_id')) {
      context.handle(
          _contributorIdMeta,
          contributorId.isAcceptableOrUnknown(
              data['contributor_id']!, _contributorIdMeta));
    }
    if (data.containsKey('teaching_type_id')) {
      context.handle(
          _teachingTypeIdMeta,
          teachingTypeId.isAcceptableOrUnknown(
              data['teaching_type_id']!, _teachingTypeIdMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    if (data.containsKey('is_live')) {
      context.handle(_isLiveMeta,
          isLive.isAcceptableOrUnknown(data['is_live']!, _isLiveMeta));
    }
    if (data.containsKey('is_full_service')) {
      context.handle(
          _isFullServiceMeta,
          isFullService.isAcceptableOrUnknown(
              data['is_full_service']!, _isFullServiceMeta));
    }
    if (data.containsKey('playlist_url')) {
      context.handle(
          _playlistUrlMeta,
          playlistUrl.isAcceptableOrUnknown(
              data['playlist_url']!, _playlistUrlMeta));
    }
    if (data.containsKey('image_landscape_url')) {
      context.handle(
          _imageLandscapeUrlMeta,
          imageLandscapeUrl.isAcceptableOrUnknown(
              data['image_landscape_url']!, _imageLandscapeUrlMeta));
    }
    if (data.containsKey('image_portrait_url')) {
      context.handle(
          _imagePortraitUrlMeta,
          imagePortraitUrl.isAcceptableOrUnknown(
              data['image_portrait_url']!, _imagePortraitUrlMeta));
    }
    if (data.containsKey('published_at')) {
      context.handle(
          _publishedAtMeta,
          publishedAt.isAcceptableOrUnknown(
              data['published_at']!, _publishedAtMeta));
    }
    if (data.containsKey('client_created_at')) {
      context.handle(
          _clientCreatedAtMeta,
          clientCreatedAt.isAcceptableOrUnknown(
              data['client_created_at']!, _clientCreatedAtMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    if (data.containsKey('recorded_at')) {
      context.handle(
          _recordedAtMeta,
          recordedAt.isAcceptableOrUnknown(
              data['recorded_at']!, _recordedAtMeta));
    }
    if (data.containsKey('color')) {
      context.handle(
          _colorMeta, color.isAcceptableOrUnknown(data['color']!, _colorMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GatheringRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GatheringRow(
      syncStamp: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sync_stamp'])!,
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      ownerId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}owner_id']),
      branchId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}branch_id']),
      contributorId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}contributor_id']),
      teachingTypeId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}teaching_type_id']),
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description']),
      isLive: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_live'])!,
      isFullService: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_full_service'])!,
      playlistUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}playlist_url']),
      imageLandscapeUrl: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}image_landscape_url']),
      imagePortraitUrl: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}image_portrait_url']),
      publishedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}published_at']),
      clientCreatedAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}client_created_at']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at']),
      recordedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}recorded_at']),
      color: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}color']),
    );
  }

  @override
  $GatheringsTable createAlias(String alias) {
    return $GatheringsTable(attachedDatabase, alias);
  }
}

class GatheringRow extends DataClass implements Insertable<GatheringRow> {
  /// Jeton de la transaction qui a écrit cette ligne pour la dernière fois.
  ///
  /// Le défaut existe pour que l'appelant n'ait **pas** à le renseigner : le
  /// jeton est une mécanique du magasin, posée par `SyncDao`, pas une donnée du
  /// serveur. Une ligne qui arriverait ici sans jeton porterait `0`, donc
  /// serait traitée comme jamais revue — la panne va dans le sens sûr.
  final int syncStamp;

  /// UUIDv7 servi par le serveur, **en chaîne**.
  final String id;
  final String? ownerId;

  /// Branche organisatrice ; `null` = portée **nationale**.
  final int? branchId;

  /// **Entier nu, sans clé étrangère** vers `contributors` — le référentiel des
  /// intervenants est commun aux deux familles, et les collections se
  /// resynchronisent séparément.
  final int? contributorId;

  /// **Entier nu, sans clé étrangère** vers `gathering_types`. Le nom du champ
  /// est celui du fil (voir la verrue, en tête de classe) ; la table jointe est
  /// bien celle des rubriques de **rassemblement**.
  final int? teachingTypeId;

  /// Titre **monolingue** : le serveur sert une chaîne, pas une carte.
  final String title;
  final String? description;
  final bool isLive;
  final bool isFullService;

  /// URL HLS publique. **Peut être nulle** : un rassemblement existe avant son
  /// média, et c'est une absence à dessiner, pas un cas impossible.
  final String? playlistUrl;

  /// URL **relative** : l'hôte de l'API change d'un environnement à l'autre, la
  /// résolution appartient au client.
  final String? imageLandscapeUrl;
  final String? imagePortraitUrl;
  final DateTime? publishedAt;
  final DateTime? clientCreatedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// **Un jour de calendrier, pas un instant** : `YYYY-MM-DD`, stocké en texte.
  /// La date d'un concert ne se décale pas d'un fuseau.
  final String? recordedAt;

  /// Couleur **brute** de la colonne serveur. `null` = « hérite de ma
  /// rubrique » : la cascade se termine à la lecture.
  final String? color;
  const GatheringRow(
      {required this.syncStamp,
      required this.id,
      this.ownerId,
      this.branchId,
      this.contributorId,
      this.teachingTypeId,
      required this.title,
      this.description,
      required this.isLive,
      required this.isFullService,
      this.playlistUrl,
      this.imageLandscapeUrl,
      this.imagePortraitUrl,
      this.publishedAt,
      this.clientCreatedAt,
      this.createdAt,
      this.updatedAt,
      this.recordedAt,
      this.color});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['sync_stamp'] = Variable<int>(syncStamp);
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || ownerId != null) {
      map['owner_id'] = Variable<String>(ownerId);
    }
    if (!nullToAbsent || branchId != null) {
      map['branch_id'] = Variable<int>(branchId);
    }
    if (!nullToAbsent || contributorId != null) {
      map['contributor_id'] = Variable<int>(contributorId);
    }
    if (!nullToAbsent || teachingTypeId != null) {
      map['teaching_type_id'] = Variable<int>(teachingTypeId);
    }
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['is_live'] = Variable<bool>(isLive);
    map['is_full_service'] = Variable<bool>(isFullService);
    if (!nullToAbsent || playlistUrl != null) {
      map['playlist_url'] = Variable<String>(playlistUrl);
    }
    if (!nullToAbsent || imageLandscapeUrl != null) {
      map['image_landscape_url'] = Variable<String>(imageLandscapeUrl);
    }
    if (!nullToAbsent || imagePortraitUrl != null) {
      map['image_portrait_url'] = Variable<String>(imagePortraitUrl);
    }
    if (!nullToAbsent || publishedAt != null) {
      map['published_at'] = Variable<DateTime>(publishedAt);
    }
    if (!nullToAbsent || clientCreatedAt != null) {
      map['client_created_at'] = Variable<DateTime>(clientCreatedAt);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    if (!nullToAbsent || recordedAt != null) {
      map['recorded_at'] = Variable<String>(recordedAt);
    }
    if (!nullToAbsent || color != null) {
      map['color'] = Variable<String>(color);
    }
    return map;
  }

  GatheringsCompanion toCompanion(bool nullToAbsent) {
    return GatheringsCompanion(
      syncStamp: Value(syncStamp),
      id: Value(id),
      ownerId: ownerId == null && nullToAbsent
          ? const Value.absent()
          : Value(ownerId),
      branchId: branchId == null && nullToAbsent
          ? const Value.absent()
          : Value(branchId),
      contributorId: contributorId == null && nullToAbsent
          ? const Value.absent()
          : Value(contributorId),
      teachingTypeId: teachingTypeId == null && nullToAbsent
          ? const Value.absent()
          : Value(teachingTypeId),
      title: Value(title),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      isLive: Value(isLive),
      isFullService: Value(isFullService),
      playlistUrl: playlistUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(playlistUrl),
      imageLandscapeUrl: imageLandscapeUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(imageLandscapeUrl),
      imagePortraitUrl: imagePortraitUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(imagePortraitUrl),
      publishedAt: publishedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(publishedAt),
      clientCreatedAt: clientCreatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(clientCreatedAt),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      recordedAt: recordedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(recordedAt),
      color:
          color == null && nullToAbsent ? const Value.absent() : Value(color),
    );
  }

  factory GatheringRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GatheringRow(
      syncStamp: serializer.fromJson<int>(json['syncStamp']),
      id: serializer.fromJson<String>(json['id']),
      ownerId: serializer.fromJson<String?>(json['ownerId']),
      branchId: serializer.fromJson<int?>(json['branchId']),
      contributorId: serializer.fromJson<int?>(json['contributorId']),
      teachingTypeId: serializer.fromJson<int?>(json['teachingTypeId']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String?>(json['description']),
      isLive: serializer.fromJson<bool>(json['isLive']),
      isFullService: serializer.fromJson<bool>(json['isFullService']),
      playlistUrl: serializer.fromJson<String?>(json['playlistUrl']),
      imageLandscapeUrl:
          serializer.fromJson<String?>(json['imageLandscapeUrl']),
      imagePortraitUrl: serializer.fromJson<String?>(json['imagePortraitUrl']),
      publishedAt: serializer.fromJson<DateTime?>(json['publishedAt']),
      clientCreatedAt: serializer.fromJson<DateTime?>(json['clientCreatedAt']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
      recordedAt: serializer.fromJson<String?>(json['recordedAt']),
      color: serializer.fromJson<String?>(json['color']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'syncStamp': serializer.toJson<int>(syncStamp),
      'id': serializer.toJson<String>(id),
      'ownerId': serializer.toJson<String?>(ownerId),
      'branchId': serializer.toJson<int?>(branchId),
      'contributorId': serializer.toJson<int?>(contributorId),
      'teachingTypeId': serializer.toJson<int?>(teachingTypeId),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String?>(description),
      'isLive': serializer.toJson<bool>(isLive),
      'isFullService': serializer.toJson<bool>(isFullService),
      'playlistUrl': serializer.toJson<String?>(playlistUrl),
      'imageLandscapeUrl': serializer.toJson<String?>(imageLandscapeUrl),
      'imagePortraitUrl': serializer.toJson<String?>(imagePortraitUrl),
      'publishedAt': serializer.toJson<DateTime?>(publishedAt),
      'clientCreatedAt': serializer.toJson<DateTime?>(clientCreatedAt),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
      'recordedAt': serializer.toJson<String?>(recordedAt),
      'color': serializer.toJson<String?>(color),
    };
  }

  GatheringRow copyWith(
          {int? syncStamp,
          String? id,
          Value<String?> ownerId = const Value.absent(),
          Value<int?> branchId = const Value.absent(),
          Value<int?> contributorId = const Value.absent(),
          Value<int?> teachingTypeId = const Value.absent(),
          String? title,
          Value<String?> description = const Value.absent(),
          bool? isLive,
          bool? isFullService,
          Value<String?> playlistUrl = const Value.absent(),
          Value<String?> imageLandscapeUrl = const Value.absent(),
          Value<String?> imagePortraitUrl = const Value.absent(),
          Value<DateTime?> publishedAt = const Value.absent(),
          Value<DateTime?> clientCreatedAt = const Value.absent(),
          Value<DateTime?> createdAt = const Value.absent(),
          Value<DateTime?> updatedAt = const Value.absent(),
          Value<String?> recordedAt = const Value.absent(),
          Value<String?> color = const Value.absent()}) =>
      GatheringRow(
        syncStamp: syncStamp ?? this.syncStamp,
        id: id ?? this.id,
        ownerId: ownerId.present ? ownerId.value : this.ownerId,
        branchId: branchId.present ? branchId.value : this.branchId,
        contributorId:
            contributorId.present ? contributorId.value : this.contributorId,
        teachingTypeId:
            teachingTypeId.present ? teachingTypeId.value : this.teachingTypeId,
        title: title ?? this.title,
        description: description.present ? description.value : this.description,
        isLive: isLive ?? this.isLive,
        isFullService: isFullService ?? this.isFullService,
        playlistUrl: playlistUrl.present ? playlistUrl.value : this.playlistUrl,
        imageLandscapeUrl: imageLandscapeUrl.present
            ? imageLandscapeUrl.value
            : this.imageLandscapeUrl,
        imagePortraitUrl: imagePortraitUrl.present
            ? imagePortraitUrl.value
            : this.imagePortraitUrl,
        publishedAt: publishedAt.present ? publishedAt.value : this.publishedAt,
        clientCreatedAt: clientCreatedAt.present
            ? clientCreatedAt.value
            : this.clientCreatedAt,
        createdAt: createdAt.present ? createdAt.value : this.createdAt,
        updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
        recordedAt: recordedAt.present ? recordedAt.value : this.recordedAt,
        color: color.present ? color.value : this.color,
      );
  GatheringRow copyWithCompanion(GatheringsCompanion data) {
    return GatheringRow(
      syncStamp: data.syncStamp.present ? data.syncStamp.value : this.syncStamp,
      id: data.id.present ? data.id.value : this.id,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      branchId: data.branchId.present ? data.branchId.value : this.branchId,
      contributorId: data.contributorId.present
          ? data.contributorId.value
          : this.contributorId,
      teachingTypeId: data.teachingTypeId.present
          ? data.teachingTypeId.value
          : this.teachingTypeId,
      title: data.title.present ? data.title.value : this.title,
      description:
          data.description.present ? data.description.value : this.description,
      isLive: data.isLive.present ? data.isLive.value : this.isLive,
      isFullService: data.isFullService.present
          ? data.isFullService.value
          : this.isFullService,
      playlistUrl:
          data.playlistUrl.present ? data.playlistUrl.value : this.playlistUrl,
      imageLandscapeUrl: data.imageLandscapeUrl.present
          ? data.imageLandscapeUrl.value
          : this.imageLandscapeUrl,
      imagePortraitUrl: data.imagePortraitUrl.present
          ? data.imagePortraitUrl.value
          : this.imagePortraitUrl,
      publishedAt:
          data.publishedAt.present ? data.publishedAt.value : this.publishedAt,
      clientCreatedAt: data.clientCreatedAt.present
          ? data.clientCreatedAt.value
          : this.clientCreatedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      recordedAt:
          data.recordedAt.present ? data.recordedAt.value : this.recordedAt,
      color: data.color.present ? data.color.value : this.color,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GatheringRow(')
          ..write('syncStamp: $syncStamp, ')
          ..write('id: $id, ')
          ..write('ownerId: $ownerId, ')
          ..write('branchId: $branchId, ')
          ..write('contributorId: $contributorId, ')
          ..write('teachingTypeId: $teachingTypeId, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('isLive: $isLive, ')
          ..write('isFullService: $isFullService, ')
          ..write('playlistUrl: $playlistUrl, ')
          ..write('imageLandscapeUrl: $imageLandscapeUrl, ')
          ..write('imagePortraitUrl: $imagePortraitUrl, ')
          ..write('publishedAt: $publishedAt, ')
          ..write('clientCreatedAt: $clientCreatedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('recordedAt: $recordedAt, ')
          ..write('color: $color')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      syncStamp,
      id,
      ownerId,
      branchId,
      contributorId,
      teachingTypeId,
      title,
      description,
      isLive,
      isFullService,
      playlistUrl,
      imageLandscapeUrl,
      imagePortraitUrl,
      publishedAt,
      clientCreatedAt,
      createdAt,
      updatedAt,
      recordedAt,
      color);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GatheringRow &&
          other.syncStamp == this.syncStamp &&
          other.id == this.id &&
          other.ownerId == this.ownerId &&
          other.branchId == this.branchId &&
          other.contributorId == this.contributorId &&
          other.teachingTypeId == this.teachingTypeId &&
          other.title == this.title &&
          other.description == this.description &&
          other.isLive == this.isLive &&
          other.isFullService == this.isFullService &&
          other.playlistUrl == this.playlistUrl &&
          other.imageLandscapeUrl == this.imageLandscapeUrl &&
          other.imagePortraitUrl == this.imagePortraitUrl &&
          other.publishedAt == this.publishedAt &&
          other.clientCreatedAt == this.clientCreatedAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.recordedAt == this.recordedAt &&
          other.color == this.color);
}

class GatheringsCompanion extends UpdateCompanion<GatheringRow> {
  final Value<int> syncStamp;
  final Value<String> id;
  final Value<String?> ownerId;
  final Value<int?> branchId;
  final Value<int?> contributorId;
  final Value<int?> teachingTypeId;
  final Value<String> title;
  final Value<String?> description;
  final Value<bool> isLive;
  final Value<bool> isFullService;
  final Value<String?> playlistUrl;
  final Value<String?> imageLandscapeUrl;
  final Value<String?> imagePortraitUrl;
  final Value<DateTime?> publishedAt;
  final Value<DateTime?> clientCreatedAt;
  final Value<DateTime?> createdAt;
  final Value<DateTime?> updatedAt;
  final Value<String?> recordedAt;
  final Value<String?> color;
  final Value<int> rowid;
  const GatheringsCompanion({
    this.syncStamp = const Value.absent(),
    this.id = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.branchId = const Value.absent(),
    this.contributorId = const Value.absent(),
    this.teachingTypeId = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.isLive = const Value.absent(),
    this.isFullService = const Value.absent(),
    this.playlistUrl = const Value.absent(),
    this.imageLandscapeUrl = const Value.absent(),
    this.imagePortraitUrl = const Value.absent(),
    this.publishedAt = const Value.absent(),
    this.clientCreatedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.recordedAt = const Value.absent(),
    this.color = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GatheringsCompanion.insert({
    this.syncStamp = const Value.absent(),
    required String id,
    this.ownerId = const Value.absent(),
    this.branchId = const Value.absent(),
    this.contributorId = const Value.absent(),
    this.teachingTypeId = const Value.absent(),
    required String title,
    this.description = const Value.absent(),
    this.isLive = const Value.absent(),
    this.isFullService = const Value.absent(),
    this.playlistUrl = const Value.absent(),
    this.imageLandscapeUrl = const Value.absent(),
    this.imagePortraitUrl = const Value.absent(),
    this.publishedAt = const Value.absent(),
    this.clientCreatedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.recordedAt = const Value.absent(),
    this.color = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        title = Value(title);
  static Insertable<GatheringRow> custom({
    Expression<int>? syncStamp,
    Expression<String>? id,
    Expression<String>? ownerId,
    Expression<int>? branchId,
    Expression<int>? contributorId,
    Expression<int>? teachingTypeId,
    Expression<String>? title,
    Expression<String>? description,
    Expression<bool>? isLive,
    Expression<bool>? isFullService,
    Expression<String>? playlistUrl,
    Expression<String>? imageLandscapeUrl,
    Expression<String>? imagePortraitUrl,
    Expression<DateTime>? publishedAt,
    Expression<DateTime>? clientCreatedAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? recordedAt,
    Expression<String>? color,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (syncStamp != null) 'sync_stamp': syncStamp,
      if (id != null) 'id': id,
      if (ownerId != null) 'owner_id': ownerId,
      if (branchId != null) 'branch_id': branchId,
      if (contributorId != null) 'contributor_id': contributorId,
      if (teachingTypeId != null) 'teaching_type_id': teachingTypeId,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (isLive != null) 'is_live': isLive,
      if (isFullService != null) 'is_full_service': isFullService,
      if (playlistUrl != null) 'playlist_url': playlistUrl,
      if (imageLandscapeUrl != null) 'image_landscape_url': imageLandscapeUrl,
      if (imagePortraitUrl != null) 'image_portrait_url': imagePortraitUrl,
      if (publishedAt != null) 'published_at': publishedAt,
      if (clientCreatedAt != null) 'client_created_at': clientCreatedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (recordedAt != null) 'recorded_at': recordedAt,
      if (color != null) 'color': color,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GatheringsCompanion copyWith(
      {Value<int>? syncStamp,
      Value<String>? id,
      Value<String?>? ownerId,
      Value<int?>? branchId,
      Value<int?>? contributorId,
      Value<int?>? teachingTypeId,
      Value<String>? title,
      Value<String?>? description,
      Value<bool>? isLive,
      Value<bool>? isFullService,
      Value<String?>? playlistUrl,
      Value<String?>? imageLandscapeUrl,
      Value<String?>? imagePortraitUrl,
      Value<DateTime?>? publishedAt,
      Value<DateTime?>? clientCreatedAt,
      Value<DateTime?>? createdAt,
      Value<DateTime?>? updatedAt,
      Value<String?>? recordedAt,
      Value<String?>? color,
      Value<int>? rowid}) {
    return GatheringsCompanion(
      syncStamp: syncStamp ?? this.syncStamp,
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      branchId: branchId ?? this.branchId,
      contributorId: contributorId ?? this.contributorId,
      teachingTypeId: teachingTypeId ?? this.teachingTypeId,
      title: title ?? this.title,
      description: description ?? this.description,
      isLive: isLive ?? this.isLive,
      isFullService: isFullService ?? this.isFullService,
      playlistUrl: playlistUrl ?? this.playlistUrl,
      imageLandscapeUrl: imageLandscapeUrl ?? this.imageLandscapeUrl,
      imagePortraitUrl: imagePortraitUrl ?? this.imagePortraitUrl,
      publishedAt: publishedAt ?? this.publishedAt,
      clientCreatedAt: clientCreatedAt ?? this.clientCreatedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      recordedAt: recordedAt ?? this.recordedAt,
      color: color ?? this.color,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (syncStamp.present) {
      map['sync_stamp'] = Variable<int>(syncStamp.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (branchId.present) {
      map['branch_id'] = Variable<int>(branchId.value);
    }
    if (contributorId.present) {
      map['contributor_id'] = Variable<int>(contributorId.value);
    }
    if (teachingTypeId.present) {
      map['teaching_type_id'] = Variable<int>(teachingTypeId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (isLive.present) {
      map['is_live'] = Variable<bool>(isLive.value);
    }
    if (isFullService.present) {
      map['is_full_service'] = Variable<bool>(isFullService.value);
    }
    if (playlistUrl.present) {
      map['playlist_url'] = Variable<String>(playlistUrl.value);
    }
    if (imageLandscapeUrl.present) {
      map['image_landscape_url'] = Variable<String>(imageLandscapeUrl.value);
    }
    if (imagePortraitUrl.present) {
      map['image_portrait_url'] = Variable<String>(imagePortraitUrl.value);
    }
    if (publishedAt.present) {
      map['published_at'] = Variable<DateTime>(publishedAt.value);
    }
    if (clientCreatedAt.present) {
      map['client_created_at'] = Variable<DateTime>(clientCreatedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (recordedAt.present) {
      map['recorded_at'] = Variable<String>(recordedAt.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GatheringsCompanion(')
          ..write('syncStamp: $syncStamp, ')
          ..write('id: $id, ')
          ..write('ownerId: $ownerId, ')
          ..write('branchId: $branchId, ')
          ..write('contributorId: $contributorId, ')
          ..write('teachingTypeId: $teachingTypeId, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('isLive: $isLive, ')
          ..write('isFullService: $isFullService, ')
          ..write('playlistUrl: $playlistUrl, ')
          ..write('imageLandscapeUrl: $imageLandscapeUrl, ')
          ..write('imagePortraitUrl: $imagePortraitUrl, ')
          ..write('publishedAt: $publishedAt, ')
          ..write('clientCreatedAt: $clientCreatedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('recordedAt: $recordedAt, ')
          ..write('color: $color, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StatusBackgroundsTable extends StatusBackgrounds
    with TableInfo<$StatusBackgroundsTable, StatusBackgroundRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StatusBackgroundsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _syncStampMeta =
      const VerificationMeta('syncStamp');
  @override
  late final GeneratedColumn<int> syncStamp = GeneratedColumn<int>(
      'sync_stamp', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  @override
  late final GeneratedColumnWithTypeConverter<Map<String, String>, String>
      label = GeneratedColumn<String>('label', aliasedName, false,
              type: DriftSqlType.string, requiredDuringInsert: true)
          .withConverter<Map<String, String>>(
              $StatusBackgroundsTable.$converterlabel);
  static const VerificationMeta _baseColorMeta =
      const VerificationMeta('baseColor');
  @override
  late final GeneratedColumn<String> baseColor = GeneratedColumn<String>(
      'base_color', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _topColorMeta =
      const VerificationMeta('topColor');
  @override
  late final GeneratedColumn<String> topColor = GeneratedColumn<String>(
      'top_color', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _bottomColorMeta =
      const VerificationMeta('bottomColor');
  @override
  late final GeneratedColumn<String> bottomColor = GeneratedColumn<String>(
      'bottom_color', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _inkMeta = const VerificationMeta('ink');
  @override
  late final GeneratedColumn<String> ink = GeneratedColumn<String>(
      'ink', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _positionMeta =
      const VerificationMeta('position');
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
      'position', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _isActiveMeta =
      const VerificationMeta('isActive');
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
      'is_active', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_active" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        syncStamp,
        id,
        label,
        baseColor,
        topColor,
        bottomColor,
        ink,
        position,
        isActive,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'status_backgrounds';
  @override
  VerificationContext validateIntegrity(
      Insertable<StatusBackgroundRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('sync_stamp')) {
      context.handle(_syncStampMeta,
          syncStamp.isAcceptableOrUnknown(data['sync_stamp']!, _syncStampMeta));
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('base_color')) {
      context.handle(_baseColorMeta,
          baseColor.isAcceptableOrUnknown(data['base_color']!, _baseColorMeta));
    } else if (isInserting) {
      context.missing(_baseColorMeta);
    }
    if (data.containsKey('top_color')) {
      context.handle(_topColorMeta,
          topColor.isAcceptableOrUnknown(data['top_color']!, _topColorMeta));
    } else if (isInserting) {
      context.missing(_topColorMeta);
    }
    if (data.containsKey('bottom_color')) {
      context.handle(
          _bottomColorMeta,
          bottomColor.isAcceptableOrUnknown(
              data['bottom_color']!, _bottomColorMeta));
    } else if (isInserting) {
      context.missing(_bottomColorMeta);
    }
    if (data.containsKey('ink')) {
      context.handle(
          _inkMeta, ink.isAcceptableOrUnknown(data['ink']!, _inkMeta));
    } else if (isInserting) {
      context.missing(_inkMeta);
    }
    if (data.containsKey('position')) {
      context.handle(_positionMeta,
          position.isAcceptableOrUnknown(data['position']!, _positionMeta));
    }
    if (data.containsKey('is_active')) {
      context.handle(_isActiveMeta,
          isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StatusBackgroundRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StatusBackgroundRow(
      syncStamp: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sync_stamp'])!,
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      label: $StatusBackgroundsTable.$converterlabel.fromSql(attachedDatabase
          .typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}label'])!),
      baseColor: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}base_color'])!,
      topColor: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}top_color'])!,
      bottomColor: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}bottom_color'])!,
      ink: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}ink'])!,
      position: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}position'])!,
      isActive: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_active'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at']),
    );
  }

  @override
  $StatusBackgroundsTable createAlias(String alias) {
    return $StatusBackgroundsTable(attachedDatabase, alias);
  }

  static TypeConverter<Map<String, String>, String> $converterlabel =
      const I18nMapConverter();
}

class StatusBackgroundRow extends DataClass
    implements Insertable<StatusBackgroundRow> {
  /// Jeton de la transaction qui a écrit cette ligne pour la dernière fois.
  ///
  /// Le défaut existe pour que l'appelant n'ait **pas** à le renseigner : le
  /// jeton est une mécanique du magasin, posée par `SyncDao`, pas une donnée du
  /// serveur. Une ligne qui arriverait ici sans jeton porterait `0`, donc
  /// serait traitée comme jamais revue — la panne va dans le sens sûr.
  final int syncStamp;
  final int id;

  /// Carte de traduction **entière** `{fr, en, ee}` — jamais la langue retenue,
  /// exactement comme `teaching_types.label`. Le repli se fait à la lecture, via
  /// `utils/i18n_text.dart` → `pick`.
  ///
  /// Elle a été **monolingue par erreur** jusqu'à la v6 du schéma, et cette
  /// erreur-là ne coûtait pas un libellé : le serveur déclare la colonne en
  /// `jsonb` (ADR-0023, sur le patron de `teaching_types`), donc chaque ligne
  /// servie faisait lever `_text` — ce qui **coupait le cycle de
  /// synchronisation entier**, et avec lui toutes les collections rangées après
  /// `status_backgrounds` dans le registre : documents légaux, intervenants,
  /// enseignements, rassemblements, annonces. Le libellé du sélecteur de fonds
  /// est ce qu'il y a de plus anodin dans cette table ; il tenait l'application
  /// muette.
  final Map<String, String> label;

  /// Teinte de référence du fond (`#RRGGBB`).
  final String baseColor;

  /// Arrêt **haut** du dégradé, dérivé par le serveur à l'écriture.
  final String topColor;

  /// Arrêt **bas** du dégradé, dérivé par le serveur à l'écriture.
  final String bottomColor;

  /// `light` | `dark` — l'encre lisible sur ce fond. Stocké **tel quel**,
  /// jamais en enum côté magasin : une valeur inconnue se replie à l'affichage
  /// plutôt que de faire échouer l'application d'une page entière.
  final String ink;
  final int position;

  /// `false` = le fond n'est plus proposé à la composition. Les annonces qui le
  /// portent gardent leur habillage.
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  const StatusBackgroundRow(
      {required this.syncStamp,
      required this.id,
      required this.label,
      required this.baseColor,
      required this.topColor,
      required this.bottomColor,
      required this.ink,
      required this.position,
      required this.isActive,
      this.createdAt,
      this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['sync_stamp'] = Variable<int>(syncStamp);
    map['id'] = Variable<int>(id);
    {
      map['label'] = Variable<String>(
          $StatusBackgroundsTable.$converterlabel.toSql(label));
    }
    map['base_color'] = Variable<String>(baseColor);
    map['top_color'] = Variable<String>(topColor);
    map['bottom_color'] = Variable<String>(bottomColor);
    map['ink'] = Variable<String>(ink);
    map['position'] = Variable<int>(position);
    map['is_active'] = Variable<bool>(isActive);
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    return map;
  }

  StatusBackgroundsCompanion toCompanion(bool nullToAbsent) {
    return StatusBackgroundsCompanion(
      syncStamp: Value(syncStamp),
      id: Value(id),
      label: Value(label),
      baseColor: Value(baseColor),
      topColor: Value(topColor),
      bottomColor: Value(bottomColor),
      ink: Value(ink),
      position: Value(position),
      isActive: Value(isActive),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory StatusBackgroundRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StatusBackgroundRow(
      syncStamp: serializer.fromJson<int>(json['syncStamp']),
      id: serializer.fromJson<int>(json['id']),
      label: serializer.fromJson<Map<String, String>>(json['label']),
      baseColor: serializer.fromJson<String>(json['baseColor']),
      topColor: serializer.fromJson<String>(json['topColor']),
      bottomColor: serializer.fromJson<String>(json['bottomColor']),
      ink: serializer.fromJson<String>(json['ink']),
      position: serializer.fromJson<int>(json['position']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'syncStamp': serializer.toJson<int>(syncStamp),
      'id': serializer.toJson<int>(id),
      'label': serializer.toJson<Map<String, String>>(label),
      'baseColor': serializer.toJson<String>(baseColor),
      'topColor': serializer.toJson<String>(topColor),
      'bottomColor': serializer.toJson<String>(bottomColor),
      'ink': serializer.toJson<String>(ink),
      'position': serializer.toJson<int>(position),
      'isActive': serializer.toJson<bool>(isActive),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
    };
  }

  StatusBackgroundRow copyWith(
          {int? syncStamp,
          int? id,
          Map<String, String>? label,
          String? baseColor,
          String? topColor,
          String? bottomColor,
          String? ink,
          int? position,
          bool? isActive,
          Value<DateTime?> createdAt = const Value.absent(),
          Value<DateTime?> updatedAt = const Value.absent()}) =>
      StatusBackgroundRow(
        syncStamp: syncStamp ?? this.syncStamp,
        id: id ?? this.id,
        label: label ?? this.label,
        baseColor: baseColor ?? this.baseColor,
        topColor: topColor ?? this.topColor,
        bottomColor: bottomColor ?? this.bottomColor,
        ink: ink ?? this.ink,
        position: position ?? this.position,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt.present ? createdAt.value : this.createdAt,
        updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
      );
  StatusBackgroundRow copyWithCompanion(StatusBackgroundsCompanion data) {
    return StatusBackgroundRow(
      syncStamp: data.syncStamp.present ? data.syncStamp.value : this.syncStamp,
      id: data.id.present ? data.id.value : this.id,
      label: data.label.present ? data.label.value : this.label,
      baseColor: data.baseColor.present ? data.baseColor.value : this.baseColor,
      topColor: data.topColor.present ? data.topColor.value : this.topColor,
      bottomColor:
          data.bottomColor.present ? data.bottomColor.value : this.bottomColor,
      ink: data.ink.present ? data.ink.value : this.ink,
      position: data.position.present ? data.position.value : this.position,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StatusBackgroundRow(')
          ..write('syncStamp: $syncStamp, ')
          ..write('id: $id, ')
          ..write('label: $label, ')
          ..write('baseColor: $baseColor, ')
          ..write('topColor: $topColor, ')
          ..write('bottomColor: $bottomColor, ')
          ..write('ink: $ink, ')
          ..write('position: $position, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(syncStamp, id, label, baseColor, topColor,
      bottomColor, ink, position, isActive, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StatusBackgroundRow &&
          other.syncStamp == this.syncStamp &&
          other.id == this.id &&
          other.label == this.label &&
          other.baseColor == this.baseColor &&
          other.topColor == this.topColor &&
          other.bottomColor == this.bottomColor &&
          other.ink == this.ink &&
          other.position == this.position &&
          other.isActive == this.isActive &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class StatusBackgroundsCompanion extends UpdateCompanion<StatusBackgroundRow> {
  final Value<int> syncStamp;
  final Value<int> id;
  final Value<Map<String, String>> label;
  final Value<String> baseColor;
  final Value<String> topColor;
  final Value<String> bottomColor;
  final Value<String> ink;
  final Value<int> position;
  final Value<bool> isActive;
  final Value<DateTime?> createdAt;
  final Value<DateTime?> updatedAt;
  const StatusBackgroundsCompanion({
    this.syncStamp = const Value.absent(),
    this.id = const Value.absent(),
    this.label = const Value.absent(),
    this.baseColor = const Value.absent(),
    this.topColor = const Value.absent(),
    this.bottomColor = const Value.absent(),
    this.ink = const Value.absent(),
    this.position = const Value.absent(),
    this.isActive = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  StatusBackgroundsCompanion.insert({
    this.syncStamp = const Value.absent(),
    this.id = const Value.absent(),
    required Map<String, String> label,
    required String baseColor,
    required String topColor,
    required String bottomColor,
    required String ink,
    this.position = const Value.absent(),
    this.isActive = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  })  : label = Value(label),
        baseColor = Value(baseColor),
        topColor = Value(topColor),
        bottomColor = Value(bottomColor),
        ink = Value(ink);
  static Insertable<StatusBackgroundRow> custom({
    Expression<int>? syncStamp,
    Expression<int>? id,
    Expression<String>? label,
    Expression<String>? baseColor,
    Expression<String>? topColor,
    Expression<String>? bottomColor,
    Expression<String>? ink,
    Expression<int>? position,
    Expression<bool>? isActive,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (syncStamp != null) 'sync_stamp': syncStamp,
      if (id != null) 'id': id,
      if (label != null) 'label': label,
      if (baseColor != null) 'base_color': baseColor,
      if (topColor != null) 'top_color': topColor,
      if (bottomColor != null) 'bottom_color': bottomColor,
      if (ink != null) 'ink': ink,
      if (position != null) 'position': position,
      if (isActive != null) 'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  StatusBackgroundsCompanion copyWith(
      {Value<int>? syncStamp,
      Value<int>? id,
      Value<Map<String, String>>? label,
      Value<String>? baseColor,
      Value<String>? topColor,
      Value<String>? bottomColor,
      Value<String>? ink,
      Value<int>? position,
      Value<bool>? isActive,
      Value<DateTime?>? createdAt,
      Value<DateTime?>? updatedAt}) {
    return StatusBackgroundsCompanion(
      syncStamp: syncStamp ?? this.syncStamp,
      id: id ?? this.id,
      label: label ?? this.label,
      baseColor: baseColor ?? this.baseColor,
      topColor: topColor ?? this.topColor,
      bottomColor: bottomColor ?? this.bottomColor,
      ink: ink ?? this.ink,
      position: position ?? this.position,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (syncStamp.present) {
      map['sync_stamp'] = Variable<int>(syncStamp.value);
    }
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(
          $StatusBackgroundsTable.$converterlabel.toSql(label.value));
    }
    if (baseColor.present) {
      map['base_color'] = Variable<String>(baseColor.value);
    }
    if (topColor.present) {
      map['top_color'] = Variable<String>(topColor.value);
    }
    if (bottomColor.present) {
      map['bottom_color'] = Variable<String>(bottomColor.value);
    }
    if (ink.present) {
      map['ink'] = Variable<String>(ink.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StatusBackgroundsCompanion(')
          ..write('syncStamp: $syncStamp, ')
          ..write('id: $id, ')
          ..write('label: $label, ')
          ..write('baseColor: $baseColor, ')
          ..write('topColor: $topColor, ')
          ..write('bottomColor: $bottomColor, ')
          ..write('ink: $ink, ')
          ..write('position: $position, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $OfficialAccountsTable extends OfficialAccounts
    with TableInfo<$OfficialAccountsTable, OfficialAccountRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OfficialAccountsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _syncStampMeta =
      const VerificationMeta('syncStamp');
  @override
  late final GeneratedColumn<int> syncStamp = GeneratedColumn<int>(
      'sync_stamp', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _shortNameMeta =
      const VerificationMeta('shortName');
  @override
  late final GeneratedColumn<String> shortName = GeneratedColumn<String>(
      'short_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _branchIdMeta =
      const VerificationMeta('branchId');
  @override
  late final GeneratedColumn<int> branchId = GeneratedColumn<int>(
      'branch_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _avatarUrlMeta =
      const VerificationMeta('avatarUrl');
  @override
  late final GeneratedColumn<String> avatarUrl = GeneratedColumn<String>(
      'avatar_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _backgroundIdMeta =
      const VerificationMeta('backgroundId');
  @override
  late final GeneratedColumn<int> backgroundId = GeneratedColumn<int>(
      'background_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _isActiveMeta =
      const VerificationMeta('isActive');
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
      'is_active', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_active" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        syncStamp,
        id,
        name,
        shortName,
        branchId,
        avatarUrl,
        backgroundId,
        isActive,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'official_accounts';
  @override
  VerificationContext validateIntegrity(Insertable<OfficialAccountRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('sync_stamp')) {
      context.handle(_syncStampMeta,
          syncStamp.isAcceptableOrUnknown(data['sync_stamp']!, _syncStampMeta));
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('short_name')) {
      context.handle(_shortNameMeta,
          shortName.isAcceptableOrUnknown(data['short_name']!, _shortNameMeta));
    }
    if (data.containsKey('branch_id')) {
      context.handle(_branchIdMeta,
          branchId.isAcceptableOrUnknown(data['branch_id']!, _branchIdMeta));
    }
    if (data.containsKey('avatar_url')) {
      context.handle(_avatarUrlMeta,
          avatarUrl.isAcceptableOrUnknown(data['avatar_url']!, _avatarUrlMeta));
    }
    if (data.containsKey('background_id')) {
      context.handle(
          _backgroundIdMeta,
          backgroundId.isAcceptableOrUnknown(
              data['background_id']!, _backgroundIdMeta));
    }
    if (data.containsKey('is_active')) {
      context.handle(_isActiveMeta,
          isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OfficialAccountRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OfficialAccountRow(
      syncStamp: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sync_stamp'])!,
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      shortName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}short_name']),
      branchId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}branch_id']),
      avatarUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}avatar_url']),
      backgroundId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}background_id']),
      isActive: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_active'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at']),
    );
  }

  @override
  $OfficialAccountsTable createAlias(String alias) {
    return $OfficialAccountsTable(attachedDatabase, alias);
  }
}

class OfficialAccountRow extends DataClass
    implements Insertable<OfficialAccountRow> {
  /// Jeton de la transaction qui a écrit cette ligne pour la dernière fois.
  ///
  /// Le défaut existe pour que l'appelant n'ait **pas** à le renseigner : le
  /// jeton est une mécanique du magasin, posée par `SyncDao`, pas une donnée du
  /// serveur. Une ligne qui arriverait ici sans jeton porterait `0`, donc
  /// serait traitée comme jamais revue — la panne va dans le sens sûr.
  final int syncStamp;
  final int id;
  final String name;

  /// Nom court, préféré à [name] dans l'en-tête quand il existe : « Diaconat »
  /// plutôt que « Diaconat de la Maison du Miracle — Bè Kpota », sur une ligne
  /// où l'ellipse guette.
  final String? shortName;

  /// Branche du compte ; `null` = portée **nationale**, jamais « inconnue ».
  final int? branchId;

  /// URL **relative** de l'avatar : l'hôte de l'API change d'un environnement à
  /// l'autre, la résolution appartient au client (`utils/media_url.dart`).
  final String? avatarUrl;

  /// Fond par défaut du compte — **entier nu, sans clé étrangère** vers
  /// `status_backgrounds`. Il n'habille aucune annonce : c'est la valeur que le
  /// composeur propose. Une annonce porte toujours le sien.
  final int? backgroundId;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  const OfficialAccountRow(
      {required this.syncStamp,
      required this.id,
      required this.name,
      this.shortName,
      this.branchId,
      this.avatarUrl,
      this.backgroundId,
      required this.isActive,
      this.createdAt,
      this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['sync_stamp'] = Variable<int>(syncStamp);
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || shortName != null) {
      map['short_name'] = Variable<String>(shortName);
    }
    if (!nullToAbsent || branchId != null) {
      map['branch_id'] = Variable<int>(branchId);
    }
    if (!nullToAbsent || avatarUrl != null) {
      map['avatar_url'] = Variable<String>(avatarUrl);
    }
    if (!nullToAbsent || backgroundId != null) {
      map['background_id'] = Variable<int>(backgroundId);
    }
    map['is_active'] = Variable<bool>(isActive);
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    return map;
  }

  OfficialAccountsCompanion toCompanion(bool nullToAbsent) {
    return OfficialAccountsCompanion(
      syncStamp: Value(syncStamp),
      id: Value(id),
      name: Value(name),
      shortName: shortName == null && nullToAbsent
          ? const Value.absent()
          : Value(shortName),
      branchId: branchId == null && nullToAbsent
          ? const Value.absent()
          : Value(branchId),
      avatarUrl: avatarUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(avatarUrl),
      backgroundId: backgroundId == null && nullToAbsent
          ? const Value.absent()
          : Value(backgroundId),
      isActive: Value(isActive),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory OfficialAccountRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OfficialAccountRow(
      syncStamp: serializer.fromJson<int>(json['syncStamp']),
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      shortName: serializer.fromJson<String?>(json['shortName']),
      branchId: serializer.fromJson<int?>(json['branchId']),
      avatarUrl: serializer.fromJson<String?>(json['avatarUrl']),
      backgroundId: serializer.fromJson<int?>(json['backgroundId']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'syncStamp': serializer.toJson<int>(syncStamp),
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'shortName': serializer.toJson<String?>(shortName),
      'branchId': serializer.toJson<int?>(branchId),
      'avatarUrl': serializer.toJson<String?>(avatarUrl),
      'backgroundId': serializer.toJson<int?>(backgroundId),
      'isActive': serializer.toJson<bool>(isActive),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
    };
  }

  OfficialAccountRow copyWith(
          {int? syncStamp,
          int? id,
          String? name,
          Value<String?> shortName = const Value.absent(),
          Value<int?> branchId = const Value.absent(),
          Value<String?> avatarUrl = const Value.absent(),
          Value<int?> backgroundId = const Value.absent(),
          bool? isActive,
          Value<DateTime?> createdAt = const Value.absent(),
          Value<DateTime?> updatedAt = const Value.absent()}) =>
      OfficialAccountRow(
        syncStamp: syncStamp ?? this.syncStamp,
        id: id ?? this.id,
        name: name ?? this.name,
        shortName: shortName.present ? shortName.value : this.shortName,
        branchId: branchId.present ? branchId.value : this.branchId,
        avatarUrl: avatarUrl.present ? avatarUrl.value : this.avatarUrl,
        backgroundId:
            backgroundId.present ? backgroundId.value : this.backgroundId,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt.present ? createdAt.value : this.createdAt,
        updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
      );
  OfficialAccountRow copyWithCompanion(OfficialAccountsCompanion data) {
    return OfficialAccountRow(
      syncStamp: data.syncStamp.present ? data.syncStamp.value : this.syncStamp,
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      shortName: data.shortName.present ? data.shortName.value : this.shortName,
      branchId: data.branchId.present ? data.branchId.value : this.branchId,
      avatarUrl: data.avatarUrl.present ? data.avatarUrl.value : this.avatarUrl,
      backgroundId: data.backgroundId.present
          ? data.backgroundId.value
          : this.backgroundId,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OfficialAccountRow(')
          ..write('syncStamp: $syncStamp, ')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('shortName: $shortName, ')
          ..write('branchId: $branchId, ')
          ..write('avatarUrl: $avatarUrl, ')
          ..write('backgroundId: $backgroundId, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(syncStamp, id, name, shortName, branchId,
      avatarUrl, backgroundId, isActive, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OfficialAccountRow &&
          other.syncStamp == this.syncStamp &&
          other.id == this.id &&
          other.name == this.name &&
          other.shortName == this.shortName &&
          other.branchId == this.branchId &&
          other.avatarUrl == this.avatarUrl &&
          other.backgroundId == this.backgroundId &&
          other.isActive == this.isActive &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class OfficialAccountsCompanion extends UpdateCompanion<OfficialAccountRow> {
  final Value<int> syncStamp;
  final Value<int> id;
  final Value<String> name;
  final Value<String?> shortName;
  final Value<int?> branchId;
  final Value<String?> avatarUrl;
  final Value<int?> backgroundId;
  final Value<bool> isActive;
  final Value<DateTime?> createdAt;
  final Value<DateTime?> updatedAt;
  const OfficialAccountsCompanion({
    this.syncStamp = const Value.absent(),
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.shortName = const Value.absent(),
    this.branchId = const Value.absent(),
    this.avatarUrl = const Value.absent(),
    this.backgroundId = const Value.absent(),
    this.isActive = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  OfficialAccountsCompanion.insert({
    this.syncStamp = const Value.absent(),
    this.id = const Value.absent(),
    required String name,
    this.shortName = const Value.absent(),
    this.branchId = const Value.absent(),
    this.avatarUrl = const Value.absent(),
    this.backgroundId = const Value.absent(),
    this.isActive = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : name = Value(name);
  static Insertable<OfficialAccountRow> custom({
    Expression<int>? syncStamp,
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? shortName,
    Expression<int>? branchId,
    Expression<String>? avatarUrl,
    Expression<int>? backgroundId,
    Expression<bool>? isActive,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (syncStamp != null) 'sync_stamp': syncStamp,
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (shortName != null) 'short_name': shortName,
      if (branchId != null) 'branch_id': branchId,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      if (backgroundId != null) 'background_id': backgroundId,
      if (isActive != null) 'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  OfficialAccountsCompanion copyWith(
      {Value<int>? syncStamp,
      Value<int>? id,
      Value<String>? name,
      Value<String?>? shortName,
      Value<int?>? branchId,
      Value<String?>? avatarUrl,
      Value<int?>? backgroundId,
      Value<bool>? isActive,
      Value<DateTime?>? createdAt,
      Value<DateTime?>? updatedAt}) {
    return OfficialAccountsCompanion(
      syncStamp: syncStamp ?? this.syncStamp,
      id: id ?? this.id,
      name: name ?? this.name,
      shortName: shortName ?? this.shortName,
      branchId: branchId ?? this.branchId,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      backgroundId: backgroundId ?? this.backgroundId,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (syncStamp.present) {
      map['sync_stamp'] = Variable<int>(syncStamp.value);
    }
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (shortName.present) {
      map['short_name'] = Variable<String>(shortName.value);
    }
    if (branchId.present) {
      map['branch_id'] = Variable<int>(branchId.value);
    }
    if (avatarUrl.present) {
      map['avatar_url'] = Variable<String>(avatarUrl.value);
    }
    if (backgroundId.present) {
      map['background_id'] = Variable<int>(backgroundId.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OfficialAccountsCompanion(')
          ..write('syncStamp: $syncStamp, ')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('shortName: $shortName, ')
          ..write('branchId: $branchId, ')
          ..write('avatarUrl: $avatarUrl, ')
          ..write('backgroundId: $backgroundId, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $OfficialAccountMembershipsTable extends OfficialAccountMemberships
    with
        TableInfo<$OfficialAccountMembershipsTable,
            OfficialAccountMembershipRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OfficialAccountMembershipsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _syncStampMeta =
      const VerificationMeta('syncStamp');
  @override
  late final GeneratedColumn<int> syncStamp = GeneratedColumn<int>(
      'sync_stamp', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _accountIdMeta =
      const VerificationMeta('accountId');
  @override
  late final GeneratedColumn<int> accountId = GeneratedColumn<int>(
      'account_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [syncStamp, id, accountId, userId, createdAt, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'official_account_memberships';
  @override
  VerificationContext validateIntegrity(
      Insertable<OfficialAccountMembershipRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('sync_stamp')) {
      context.handle(_syncStampMeta,
          syncStamp.isAcceptableOrUnknown(data['sync_stamp']!, _syncStampMeta));
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('account_id')) {
      context.handle(_accountIdMeta,
          accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta));
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OfficialAccountMembershipRow map(Map<String, dynamic> data,
      {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OfficialAccountMembershipRow(
      syncStamp: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sync_stamp'])!,
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      accountId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}account_id'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at']),
    );
  }

  @override
  $OfficialAccountMembershipsTable createAlias(String alias) {
    return $OfficialAccountMembershipsTable(attachedDatabase, alias);
  }
}

class OfficialAccountMembershipRow extends DataClass
    implements Insertable<OfficialAccountMembershipRow> {
  /// Jeton de la transaction qui a écrit cette ligne pour la dernière fois.
  ///
  /// Le défaut existe pour que l'appelant n'ait **pas** à le renseigner : le
  /// jeton est une mécanique du magasin, posée par `SyncDao`, pas une donnée du
  /// serveur. Une ligne qui arriverait ici sans jeton porterait `0`, donc
  /// serait traitée comme jamais revue — la panne va dans le sens sûr.
  final int syncStamp;
  final int id;

  /// **Entier nu, sans clé étrangère** vers `official_accounts` : les deux
  /// collections se resynchronisent séparément.
  final int accountId;

  /// Porteur de l'appartenance — moi, par construction de la collection.
  final String userId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  const OfficialAccountMembershipRow(
      {required this.syncStamp,
      required this.id,
      required this.accountId,
      required this.userId,
      this.createdAt,
      this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['sync_stamp'] = Variable<int>(syncStamp);
    map['id'] = Variable<int>(id);
    map['account_id'] = Variable<int>(accountId);
    map['user_id'] = Variable<String>(userId);
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    return map;
  }

  OfficialAccountMembershipsCompanion toCompanion(bool nullToAbsent) {
    return OfficialAccountMembershipsCompanion(
      syncStamp: Value(syncStamp),
      id: Value(id),
      accountId: Value(accountId),
      userId: Value(userId),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory OfficialAccountMembershipRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OfficialAccountMembershipRow(
      syncStamp: serializer.fromJson<int>(json['syncStamp']),
      id: serializer.fromJson<int>(json['id']),
      accountId: serializer.fromJson<int>(json['accountId']),
      userId: serializer.fromJson<String>(json['userId']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'syncStamp': serializer.toJson<int>(syncStamp),
      'id': serializer.toJson<int>(id),
      'accountId': serializer.toJson<int>(accountId),
      'userId': serializer.toJson<String>(userId),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
    };
  }

  OfficialAccountMembershipRow copyWith(
          {int? syncStamp,
          int? id,
          int? accountId,
          String? userId,
          Value<DateTime?> createdAt = const Value.absent(),
          Value<DateTime?> updatedAt = const Value.absent()}) =>
      OfficialAccountMembershipRow(
        syncStamp: syncStamp ?? this.syncStamp,
        id: id ?? this.id,
        accountId: accountId ?? this.accountId,
        userId: userId ?? this.userId,
        createdAt: createdAt.present ? createdAt.value : this.createdAt,
        updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
      );
  OfficialAccountMembershipRow copyWithCompanion(
      OfficialAccountMembershipsCompanion data) {
    return OfficialAccountMembershipRow(
      syncStamp: data.syncStamp.present ? data.syncStamp.value : this.syncStamp,
      id: data.id.present ? data.id.value : this.id,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      userId: data.userId.present ? data.userId.value : this.userId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OfficialAccountMembershipRow(')
          ..write('syncStamp: $syncStamp, ')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('userId: $userId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(syncStamp, id, accountId, userId, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OfficialAccountMembershipRow &&
          other.syncStamp == this.syncStamp &&
          other.id == this.id &&
          other.accountId == this.accountId &&
          other.userId == this.userId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class OfficialAccountMembershipsCompanion
    extends UpdateCompanion<OfficialAccountMembershipRow> {
  final Value<int> syncStamp;
  final Value<int> id;
  final Value<int> accountId;
  final Value<String> userId;
  final Value<DateTime?> createdAt;
  final Value<DateTime?> updatedAt;
  const OfficialAccountMembershipsCompanion({
    this.syncStamp = const Value.absent(),
    this.id = const Value.absent(),
    this.accountId = const Value.absent(),
    this.userId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  OfficialAccountMembershipsCompanion.insert({
    this.syncStamp = const Value.absent(),
    this.id = const Value.absent(),
    required int accountId,
    required String userId,
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  })  : accountId = Value(accountId),
        userId = Value(userId);
  static Insertable<OfficialAccountMembershipRow> custom({
    Expression<int>? syncStamp,
    Expression<int>? id,
    Expression<int>? accountId,
    Expression<String>? userId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (syncStamp != null) 'sync_stamp': syncStamp,
      if (id != null) 'id': id,
      if (accountId != null) 'account_id': accountId,
      if (userId != null) 'user_id': userId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  OfficialAccountMembershipsCompanion copyWith(
      {Value<int>? syncStamp,
      Value<int>? id,
      Value<int>? accountId,
      Value<String>? userId,
      Value<DateTime?>? createdAt,
      Value<DateTime?>? updatedAt}) {
    return OfficialAccountMembershipsCompanion(
      syncStamp: syncStamp ?? this.syncStamp,
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (syncStamp.present) {
      map['sync_stamp'] = Variable<int>(syncStamp.value);
    }
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<int>(accountId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OfficialAccountMembershipsCompanion(')
          ..write('syncStamp: $syncStamp, ')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('userId: $userId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $AnnouncementsTable extends Announcements
    with TableInfo<$AnnouncementsTable, AnnouncementRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AnnouncementsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _syncStampMeta =
      const VerificationMeta('syncStamp');
  @override
  late final GeneratedColumn<int> syncStamp = GeneratedColumn<int>(
      'sync_stamp', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _accountIdMeta =
      const VerificationMeta('accountId');
  @override
  late final GeneratedColumn<int> accountId = GeneratedColumn<int>(
      'account_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _branchIdMeta =
      const VerificationMeta('branchId');
  @override
  late final GeneratedColumn<int> branchId = GeneratedColumn<int>(
      'branch_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
      'body', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _publishedAtMeta =
      const VerificationMeta('publishedAt');
  @override
  late final GeneratedColumn<DateTime> publishedAt = GeneratedColumn<DateTime>(
      'published_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _expiresAtMeta =
      const VerificationMeta('expiresAt');
  @override
  late final GeneratedColumn<DateTime> expiresAt = GeneratedColumn<DateTime>(
      'expires_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _backgroundIdMeta =
      const VerificationMeta('backgroundId');
  @override
  late final GeneratedColumn<int> backgroundId = GeneratedColumn<int>(
      'background_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _backgroundImageUrlMeta =
      const VerificationMeta('backgroundImageUrl');
  @override
  late final GeneratedColumn<String> backgroundImageUrl =
      GeneratedColumn<String>('background_image_url', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isPinnedMeta =
      const VerificationMeta('isPinned');
  @override
  late final GeneratedColumn<bool> isPinned = GeneratedColumn<bool>(
      'is_pinned', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_pinned" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _ownerIdMeta =
      const VerificationMeta('ownerId');
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
      'owner_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        syncStamp,
        id,
        accountId,
        branchId,
        title,
        body,
        publishedAt,
        expiresAt,
        backgroundId,
        backgroundImageUrl,
        isPinned,
        ownerId,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'announcements';
  @override
  VerificationContext validateIntegrity(Insertable<AnnouncementRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('sync_stamp')) {
      context.handle(_syncStampMeta,
          syncStamp.isAcceptableOrUnknown(data['sync_stamp']!, _syncStampMeta));
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(_accountIdMeta,
          accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta));
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('branch_id')) {
      context.handle(_branchIdMeta,
          branchId.isAcceptableOrUnknown(data['branch_id']!, _branchIdMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    }
    if (data.containsKey('body')) {
      context.handle(
          _bodyMeta, body.isAcceptableOrUnknown(data['body']!, _bodyMeta));
    }
    if (data.containsKey('published_at')) {
      context.handle(
          _publishedAtMeta,
          publishedAt.isAcceptableOrUnknown(
              data['published_at']!, _publishedAtMeta));
    } else if (isInserting) {
      context.missing(_publishedAtMeta);
    }
    if (data.containsKey('expires_at')) {
      context.handle(_expiresAtMeta,
          expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta));
    }
    if (data.containsKey('background_id')) {
      context.handle(
          _backgroundIdMeta,
          backgroundId.isAcceptableOrUnknown(
              data['background_id']!, _backgroundIdMeta));
    }
    if (data.containsKey('background_image_url')) {
      context.handle(
          _backgroundImageUrlMeta,
          backgroundImageUrl.isAcceptableOrUnknown(
              data['background_image_url']!, _backgroundImageUrlMeta));
    }
    if (data.containsKey('is_pinned')) {
      context.handle(_isPinnedMeta,
          isPinned.isAcceptableOrUnknown(data['is_pinned']!, _isPinnedMeta));
    }
    if (data.containsKey('owner_id')) {
      context.handle(_ownerIdMeta,
          ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AnnouncementRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AnnouncementRow(
      syncStamp: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sync_stamp'])!,
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      accountId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}account_id'])!,
      branchId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}branch_id']),
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title']),
      body: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}body']),
      publishedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}published_at'])!,
      expiresAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}expires_at']),
      backgroundId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}background_id']),
      backgroundImageUrl: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}background_image_url']),
      isPinned: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_pinned'])!,
      ownerId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}owner_id']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at']),
    );
  }

  @override
  $AnnouncementsTable createAlias(String alias) {
    return $AnnouncementsTable(attachedDatabase, alias);
  }
}

class AnnouncementRow extends DataClass implements Insertable<AnnouncementRow> {
  /// Jeton de la transaction qui a écrit cette ligne pour la dernière fois.
  ///
  /// Le défaut existe pour que l'appelant n'ait **pas** à le renseigner : le
  /// jeton est une mécanique du magasin, posée par `SyncDao`, pas une donnée du
  /// serveur. Une ligne qui arriverait ici sans jeton porterait `0`, donc
  /// serait traitée comme jamais revue — la panne va dans le sens sûr.
  final int syncStamp;

  /// UUID servi par le serveur, **en chaîne**.
  final String id;

  /// **Entier nu, sans clé étrangère** vers `official_accounts`. La jointure
  /// est tolérante : une annonce dont le compte n'est pas encore arrivé
  /// s'affiche quand même, sans en-tête inventé.
  final int accountId;

  /// Branche de l'annonce ; `null` = portée **nationale**. Le client ne s'en
  /// sert pas pour filtrer — le périmètre est décidé par le serveur, qui ne
  /// sert que ce que l'acteur a le droit de voir.
  final int? branchId;

  /// Absent ⇒ bloc de texte centré, façon WhatsApp.
  final String? title;
  final String? body;

  /// Mise à disposition, en UTC. **Non nulle** : c'est la clé de tri du mur de
  /// statuts, et une annonce sans date n'a pas de place où aller.
  final DateTime publishedAt;

  /// `null` = n'expire jamais (le défaut).
  final DateTime? expiresAt;

  /// **Entier nu, sans clé étrangère** vers `status_backgrounds`. `null` =
  /// aucun fond choisi : le rendu retombe alors sur la teinte dérivée du hash
  /// de l'[id] (`lib/theme/status_palette.dart`).
  final int? backgroundId;

  /// Image de fond, URL **relative** comme partout ailleurs.
  final String? backgroundImageUrl;
  final bool isPinned;

  /// Auteur humain de la publication — l'identité derrière le compte. Elle ne
  /// s'affiche pas : le statut est signé par le **compte**, pas par la personne.
  final String? ownerId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  const AnnouncementRow(
      {required this.syncStamp,
      required this.id,
      required this.accountId,
      this.branchId,
      this.title,
      this.body,
      required this.publishedAt,
      this.expiresAt,
      this.backgroundId,
      this.backgroundImageUrl,
      required this.isPinned,
      this.ownerId,
      this.createdAt,
      this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['sync_stamp'] = Variable<int>(syncStamp);
    map['id'] = Variable<String>(id);
    map['account_id'] = Variable<int>(accountId);
    if (!nullToAbsent || branchId != null) {
      map['branch_id'] = Variable<int>(branchId);
    }
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    if (!nullToAbsent || body != null) {
      map['body'] = Variable<String>(body);
    }
    map['published_at'] = Variable<DateTime>(publishedAt);
    if (!nullToAbsent || expiresAt != null) {
      map['expires_at'] = Variable<DateTime>(expiresAt);
    }
    if (!nullToAbsent || backgroundId != null) {
      map['background_id'] = Variable<int>(backgroundId);
    }
    if (!nullToAbsent || backgroundImageUrl != null) {
      map['background_image_url'] = Variable<String>(backgroundImageUrl);
    }
    map['is_pinned'] = Variable<bool>(isPinned);
    if (!nullToAbsent || ownerId != null) {
      map['owner_id'] = Variable<String>(ownerId);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    return map;
  }

  AnnouncementsCompanion toCompanion(bool nullToAbsent) {
    return AnnouncementsCompanion(
      syncStamp: Value(syncStamp),
      id: Value(id),
      accountId: Value(accountId),
      branchId: branchId == null && nullToAbsent
          ? const Value.absent()
          : Value(branchId),
      title:
          title == null && nullToAbsent ? const Value.absent() : Value(title),
      body: body == null && nullToAbsent ? const Value.absent() : Value(body),
      publishedAt: Value(publishedAt),
      expiresAt: expiresAt == null && nullToAbsent
          ? const Value.absent()
          : Value(expiresAt),
      backgroundId: backgroundId == null && nullToAbsent
          ? const Value.absent()
          : Value(backgroundId),
      backgroundImageUrl: backgroundImageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(backgroundImageUrl),
      isPinned: Value(isPinned),
      ownerId: ownerId == null && nullToAbsent
          ? const Value.absent()
          : Value(ownerId),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory AnnouncementRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AnnouncementRow(
      syncStamp: serializer.fromJson<int>(json['syncStamp']),
      id: serializer.fromJson<String>(json['id']),
      accountId: serializer.fromJson<int>(json['accountId']),
      branchId: serializer.fromJson<int?>(json['branchId']),
      title: serializer.fromJson<String?>(json['title']),
      body: serializer.fromJson<String?>(json['body']),
      publishedAt: serializer.fromJson<DateTime>(json['publishedAt']),
      expiresAt: serializer.fromJson<DateTime?>(json['expiresAt']),
      backgroundId: serializer.fromJson<int?>(json['backgroundId']),
      backgroundImageUrl:
          serializer.fromJson<String?>(json['backgroundImageUrl']),
      isPinned: serializer.fromJson<bool>(json['isPinned']),
      ownerId: serializer.fromJson<String?>(json['ownerId']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'syncStamp': serializer.toJson<int>(syncStamp),
      'id': serializer.toJson<String>(id),
      'accountId': serializer.toJson<int>(accountId),
      'branchId': serializer.toJson<int?>(branchId),
      'title': serializer.toJson<String?>(title),
      'body': serializer.toJson<String?>(body),
      'publishedAt': serializer.toJson<DateTime>(publishedAt),
      'expiresAt': serializer.toJson<DateTime?>(expiresAt),
      'backgroundId': serializer.toJson<int?>(backgroundId),
      'backgroundImageUrl': serializer.toJson<String?>(backgroundImageUrl),
      'isPinned': serializer.toJson<bool>(isPinned),
      'ownerId': serializer.toJson<String?>(ownerId),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
    };
  }

  AnnouncementRow copyWith(
          {int? syncStamp,
          String? id,
          int? accountId,
          Value<int?> branchId = const Value.absent(),
          Value<String?> title = const Value.absent(),
          Value<String?> body = const Value.absent(),
          DateTime? publishedAt,
          Value<DateTime?> expiresAt = const Value.absent(),
          Value<int?> backgroundId = const Value.absent(),
          Value<String?> backgroundImageUrl = const Value.absent(),
          bool? isPinned,
          Value<String?> ownerId = const Value.absent(),
          Value<DateTime?> createdAt = const Value.absent(),
          Value<DateTime?> updatedAt = const Value.absent()}) =>
      AnnouncementRow(
        syncStamp: syncStamp ?? this.syncStamp,
        id: id ?? this.id,
        accountId: accountId ?? this.accountId,
        branchId: branchId.present ? branchId.value : this.branchId,
        title: title.present ? title.value : this.title,
        body: body.present ? body.value : this.body,
        publishedAt: publishedAt ?? this.publishedAt,
        expiresAt: expiresAt.present ? expiresAt.value : this.expiresAt,
        backgroundId:
            backgroundId.present ? backgroundId.value : this.backgroundId,
        backgroundImageUrl: backgroundImageUrl.present
            ? backgroundImageUrl.value
            : this.backgroundImageUrl,
        isPinned: isPinned ?? this.isPinned,
        ownerId: ownerId.present ? ownerId.value : this.ownerId,
        createdAt: createdAt.present ? createdAt.value : this.createdAt,
        updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
      );
  AnnouncementRow copyWithCompanion(AnnouncementsCompanion data) {
    return AnnouncementRow(
      syncStamp: data.syncStamp.present ? data.syncStamp.value : this.syncStamp,
      id: data.id.present ? data.id.value : this.id,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      branchId: data.branchId.present ? data.branchId.value : this.branchId,
      title: data.title.present ? data.title.value : this.title,
      body: data.body.present ? data.body.value : this.body,
      publishedAt:
          data.publishedAt.present ? data.publishedAt.value : this.publishedAt,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
      backgroundId: data.backgroundId.present
          ? data.backgroundId.value
          : this.backgroundId,
      backgroundImageUrl: data.backgroundImageUrl.present
          ? data.backgroundImageUrl.value
          : this.backgroundImageUrl,
      isPinned: data.isPinned.present ? data.isPinned.value : this.isPinned,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AnnouncementRow(')
          ..write('syncStamp: $syncStamp, ')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('branchId: $branchId, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('publishedAt: $publishedAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('backgroundId: $backgroundId, ')
          ..write('backgroundImageUrl: $backgroundImageUrl, ')
          ..write('isPinned: $isPinned, ')
          ..write('ownerId: $ownerId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      syncStamp,
      id,
      accountId,
      branchId,
      title,
      body,
      publishedAt,
      expiresAt,
      backgroundId,
      backgroundImageUrl,
      isPinned,
      ownerId,
      createdAt,
      updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AnnouncementRow &&
          other.syncStamp == this.syncStamp &&
          other.id == this.id &&
          other.accountId == this.accountId &&
          other.branchId == this.branchId &&
          other.title == this.title &&
          other.body == this.body &&
          other.publishedAt == this.publishedAt &&
          other.expiresAt == this.expiresAt &&
          other.backgroundId == this.backgroundId &&
          other.backgroundImageUrl == this.backgroundImageUrl &&
          other.isPinned == this.isPinned &&
          other.ownerId == this.ownerId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class AnnouncementsCompanion extends UpdateCompanion<AnnouncementRow> {
  final Value<int> syncStamp;
  final Value<String> id;
  final Value<int> accountId;
  final Value<int?> branchId;
  final Value<String?> title;
  final Value<String?> body;
  final Value<DateTime> publishedAt;
  final Value<DateTime?> expiresAt;
  final Value<int?> backgroundId;
  final Value<String?> backgroundImageUrl;
  final Value<bool> isPinned;
  final Value<String?> ownerId;
  final Value<DateTime?> createdAt;
  final Value<DateTime?> updatedAt;
  final Value<int> rowid;
  const AnnouncementsCompanion({
    this.syncStamp = const Value.absent(),
    this.id = const Value.absent(),
    this.accountId = const Value.absent(),
    this.branchId = const Value.absent(),
    this.title = const Value.absent(),
    this.body = const Value.absent(),
    this.publishedAt = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.backgroundId = const Value.absent(),
    this.backgroundImageUrl = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AnnouncementsCompanion.insert({
    this.syncStamp = const Value.absent(),
    required String id,
    required int accountId,
    this.branchId = const Value.absent(),
    this.title = const Value.absent(),
    this.body = const Value.absent(),
    required DateTime publishedAt,
    this.expiresAt = const Value.absent(),
    this.backgroundId = const Value.absent(),
    this.backgroundImageUrl = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        accountId = Value(accountId),
        publishedAt = Value(publishedAt);
  static Insertable<AnnouncementRow> custom({
    Expression<int>? syncStamp,
    Expression<String>? id,
    Expression<int>? accountId,
    Expression<int>? branchId,
    Expression<String>? title,
    Expression<String>? body,
    Expression<DateTime>? publishedAt,
    Expression<DateTime>? expiresAt,
    Expression<int>? backgroundId,
    Expression<String>? backgroundImageUrl,
    Expression<bool>? isPinned,
    Expression<String>? ownerId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (syncStamp != null) 'sync_stamp': syncStamp,
      if (id != null) 'id': id,
      if (accountId != null) 'account_id': accountId,
      if (branchId != null) 'branch_id': branchId,
      if (title != null) 'title': title,
      if (body != null) 'body': body,
      if (publishedAt != null) 'published_at': publishedAt,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (backgroundId != null) 'background_id': backgroundId,
      if (backgroundImageUrl != null)
        'background_image_url': backgroundImageUrl,
      if (isPinned != null) 'is_pinned': isPinned,
      if (ownerId != null) 'owner_id': ownerId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AnnouncementsCompanion copyWith(
      {Value<int>? syncStamp,
      Value<String>? id,
      Value<int>? accountId,
      Value<int?>? branchId,
      Value<String?>? title,
      Value<String?>? body,
      Value<DateTime>? publishedAt,
      Value<DateTime?>? expiresAt,
      Value<int?>? backgroundId,
      Value<String?>? backgroundImageUrl,
      Value<bool>? isPinned,
      Value<String?>? ownerId,
      Value<DateTime?>? createdAt,
      Value<DateTime?>? updatedAt,
      Value<int>? rowid}) {
    return AnnouncementsCompanion(
      syncStamp: syncStamp ?? this.syncStamp,
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      branchId: branchId ?? this.branchId,
      title: title ?? this.title,
      body: body ?? this.body,
      publishedAt: publishedAt ?? this.publishedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      backgroundId: backgroundId ?? this.backgroundId,
      backgroundImageUrl: backgroundImageUrl ?? this.backgroundImageUrl,
      isPinned: isPinned ?? this.isPinned,
      ownerId: ownerId ?? this.ownerId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (syncStamp.present) {
      map['sync_stamp'] = Variable<int>(syncStamp.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<int>(accountId.value);
    }
    if (branchId.present) {
      map['branch_id'] = Variable<int>(branchId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (publishedAt.present) {
      map['published_at'] = Variable<DateTime>(publishedAt.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<DateTime>(expiresAt.value);
    }
    if (backgroundId.present) {
      map['background_id'] = Variable<int>(backgroundId.value);
    }
    if (backgroundImageUrl.present) {
      map['background_image_url'] = Variable<String>(backgroundImageUrl.value);
    }
    if (isPinned.present) {
      map['is_pinned'] = Variable<bool>(isPinned.value);
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AnnouncementsCompanion(')
          ..write('syncStamp: $syncStamp, ')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('branchId: $branchId, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('publishedAt: $publishedAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('backgroundId: $backgroundId, ')
          ..write('backgroundImageUrl: $backgroundImageUrl, ')
          ..write('isPinned: $isPinned, ')
          ..write('ownerId: $ownerId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlaybackProgressTable extends PlaybackProgress
    with TableInfo<$PlaybackProgressTable, PlaybackProgressRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaybackProgressTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _syncStampMeta =
      const VerificationMeta('syncStamp');
  @override
  late final GeneratedColumn<int> syncStamp = GeneratedColumn<int>(
      'sync_stamp', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _teachingIdMeta =
      const VerificationMeta('teachingId');
  @override
  late final GeneratedColumn<String> teachingId = GeneratedColumn<String>(
      'teaching_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _positionSecondsMeta =
      const VerificationMeta('positionSeconds');
  @override
  late final GeneratedColumn<int> positionSeconds = GeneratedColumn<int>(
      'position_seconds', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _completedMeta =
      const VerificationMeta('completed');
  @override
  late final GeneratedColumn<bool> completed = GeneratedColumn<bool>(
      'completed', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("completed" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _clientCreatedAtMeta =
      const VerificationMeta('clientCreatedAt');
  @override
  late final GeneratedColumn<DateTime> clientCreatedAt =
      GeneratedColumn<DateTime>('client_created_at', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        syncStamp,
        id,
        userId,
        teachingId,
        positionSeconds,
        completed,
        clientCreatedAt,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playback_progress';
  @override
  VerificationContext validateIntegrity(
      Insertable<PlaybackProgressRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('sync_stamp')) {
      context.handle(_syncStampMeta,
          syncStamp.isAcceptableOrUnknown(data['sync_stamp']!, _syncStampMeta));
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    }
    if (data.containsKey('teaching_id')) {
      context.handle(
          _teachingIdMeta,
          teachingId.isAcceptableOrUnknown(
              data['teaching_id']!, _teachingIdMeta));
    } else if (isInserting) {
      context.missing(_teachingIdMeta);
    }
    if (data.containsKey('position_seconds')) {
      context.handle(
          _positionSecondsMeta,
          positionSeconds.isAcceptableOrUnknown(
              data['position_seconds']!, _positionSecondsMeta));
    } else if (isInserting) {
      context.missing(_positionSecondsMeta);
    }
    if (data.containsKey('completed')) {
      context.handle(_completedMeta,
          completed.isAcceptableOrUnknown(data['completed']!, _completedMeta));
    }
    if (data.containsKey('client_created_at')) {
      context.handle(
          _clientCreatedAtMeta,
          clientCreatedAt.isAcceptableOrUnknown(
              data['client_created_at']!, _clientCreatedAtMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PlaybackProgressRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaybackProgressRow(
      syncStamp: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sync_stamp'])!,
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id']),
      teachingId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}teaching_id'])!,
      positionSeconds: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}position_seconds'])!,
      completed: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}completed'])!,
      clientCreatedAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}client_created_at']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at']),
    );
  }

  @override
  $PlaybackProgressTable createAlias(String alias) {
    return $PlaybackProgressTable(attachedDatabase, alias);
  }
}

class PlaybackProgressRow extends DataClass
    implements Insertable<PlaybackProgressRow> {
  /// Jeton de la transaction qui a écrit cette ligne pour la dernière fois.
  ///
  /// Le défaut existe pour que l'appelant n'ait **pas** à le renseigner : le
  /// jeton est une mécanique du magasin, posée par `SyncDao`, pas une donnée du
  /// serveur. Une ligne qui arriverait ici sans jeton porterait `0`, donc
  /// serait traitée comme jamais revue — la panne va dans le sens sûr.
  final int syncStamp;

  /// UUIDv7 **fabriqué par le client** et conservé par le serveur à l'insert
  /// (ADR-0001/0018). C'est ce qui rend le rapport rejouable : un rejeu retombe
  /// sur la même ligne au lieu d'en créer une seconde.
  final String id;

  /// Porteur de la progression — moi, par construction : la collection est
  /// `private` et son `scopeFilter` est `user_id = soi`. Stocké pour le
  /// diagnostic, jamais pour filtrer.
  final String? userId;

  /// **Entier… non : chaîne nue, et sans clé étrangère.** Le contenu écouté,
  /// enseignement ou rassemblement. La jointure est tolérante et se fait à la
  /// lecture ; la cible n'a pas à exister.
  final String teachingId;

  /// Position de reprise, **en secondes**. C'est la seule unité du contrat
  /// serveur (`vine.number().min(0)`), et la convertir en `Duration` appartient
  /// à la lecture.
  final int positionSeconds;

  /// Décidé par le **client** et stocké tel quel par le serveur. Voir l'en-tête
  /// de cette classe : sans durée, le serveur ne peut rien en dire.
  final bool completed;

  /// Instant de création **côté client**, quand le client en fournit un.
  final DateTime? clientCreatedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  const PlaybackProgressRow(
      {required this.syncStamp,
      required this.id,
      this.userId,
      required this.teachingId,
      required this.positionSeconds,
      required this.completed,
      this.clientCreatedAt,
      this.createdAt,
      this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['sync_stamp'] = Variable<int>(syncStamp);
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || userId != null) {
      map['user_id'] = Variable<String>(userId);
    }
    map['teaching_id'] = Variable<String>(teachingId);
    map['position_seconds'] = Variable<int>(positionSeconds);
    map['completed'] = Variable<bool>(completed);
    if (!nullToAbsent || clientCreatedAt != null) {
      map['client_created_at'] = Variable<DateTime>(clientCreatedAt);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    return map;
  }

  PlaybackProgressCompanion toCompanion(bool nullToAbsent) {
    return PlaybackProgressCompanion(
      syncStamp: Value(syncStamp),
      id: Value(id),
      userId:
          userId == null && nullToAbsent ? const Value.absent() : Value(userId),
      teachingId: Value(teachingId),
      positionSeconds: Value(positionSeconds),
      completed: Value(completed),
      clientCreatedAt: clientCreatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(clientCreatedAt),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory PlaybackProgressRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaybackProgressRow(
      syncStamp: serializer.fromJson<int>(json['syncStamp']),
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String?>(json['userId']),
      teachingId: serializer.fromJson<String>(json['teachingId']),
      positionSeconds: serializer.fromJson<int>(json['positionSeconds']),
      completed: serializer.fromJson<bool>(json['completed']),
      clientCreatedAt: serializer.fromJson<DateTime?>(json['clientCreatedAt']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'syncStamp': serializer.toJson<int>(syncStamp),
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String?>(userId),
      'teachingId': serializer.toJson<String>(teachingId),
      'positionSeconds': serializer.toJson<int>(positionSeconds),
      'completed': serializer.toJson<bool>(completed),
      'clientCreatedAt': serializer.toJson<DateTime?>(clientCreatedAt),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
    };
  }

  PlaybackProgressRow copyWith(
          {int? syncStamp,
          String? id,
          Value<String?> userId = const Value.absent(),
          String? teachingId,
          int? positionSeconds,
          bool? completed,
          Value<DateTime?> clientCreatedAt = const Value.absent(),
          Value<DateTime?> createdAt = const Value.absent(),
          Value<DateTime?> updatedAt = const Value.absent()}) =>
      PlaybackProgressRow(
        syncStamp: syncStamp ?? this.syncStamp,
        id: id ?? this.id,
        userId: userId.present ? userId.value : this.userId,
        teachingId: teachingId ?? this.teachingId,
        positionSeconds: positionSeconds ?? this.positionSeconds,
        completed: completed ?? this.completed,
        clientCreatedAt: clientCreatedAt.present
            ? clientCreatedAt.value
            : this.clientCreatedAt,
        createdAt: createdAt.present ? createdAt.value : this.createdAt,
        updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
      );
  PlaybackProgressRow copyWithCompanion(PlaybackProgressCompanion data) {
    return PlaybackProgressRow(
      syncStamp: data.syncStamp.present ? data.syncStamp.value : this.syncStamp,
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      teachingId:
          data.teachingId.present ? data.teachingId.value : this.teachingId,
      positionSeconds: data.positionSeconds.present
          ? data.positionSeconds.value
          : this.positionSeconds,
      completed: data.completed.present ? data.completed.value : this.completed,
      clientCreatedAt: data.clientCreatedAt.present
          ? data.clientCreatedAt.value
          : this.clientCreatedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaybackProgressRow(')
          ..write('syncStamp: $syncStamp, ')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('teachingId: $teachingId, ')
          ..write('positionSeconds: $positionSeconds, ')
          ..write('completed: $completed, ')
          ..write('clientCreatedAt: $clientCreatedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(syncStamp, id, userId, teachingId,
      positionSeconds, completed, clientCreatedAt, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaybackProgressRow &&
          other.syncStamp == this.syncStamp &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.teachingId == this.teachingId &&
          other.positionSeconds == this.positionSeconds &&
          other.completed == this.completed &&
          other.clientCreatedAt == this.clientCreatedAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class PlaybackProgressCompanion extends UpdateCompanion<PlaybackProgressRow> {
  final Value<int> syncStamp;
  final Value<String> id;
  final Value<String?> userId;
  final Value<String> teachingId;
  final Value<int> positionSeconds;
  final Value<bool> completed;
  final Value<DateTime?> clientCreatedAt;
  final Value<DateTime?> createdAt;
  final Value<DateTime?> updatedAt;
  final Value<int> rowid;
  const PlaybackProgressCompanion({
    this.syncStamp = const Value.absent(),
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.teachingId = const Value.absent(),
    this.positionSeconds = const Value.absent(),
    this.completed = const Value.absent(),
    this.clientCreatedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlaybackProgressCompanion.insert({
    this.syncStamp = const Value.absent(),
    required String id,
    this.userId = const Value.absent(),
    required String teachingId,
    required int positionSeconds,
    this.completed = const Value.absent(),
    this.clientCreatedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        teachingId = Value(teachingId),
        positionSeconds = Value(positionSeconds);
  static Insertable<PlaybackProgressRow> custom({
    Expression<int>? syncStamp,
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? teachingId,
    Expression<int>? positionSeconds,
    Expression<bool>? completed,
    Expression<DateTime>? clientCreatedAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (syncStamp != null) 'sync_stamp': syncStamp,
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (teachingId != null) 'teaching_id': teachingId,
      if (positionSeconds != null) 'position_seconds': positionSeconds,
      if (completed != null) 'completed': completed,
      if (clientCreatedAt != null) 'client_created_at': clientCreatedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlaybackProgressCompanion copyWith(
      {Value<int>? syncStamp,
      Value<String>? id,
      Value<String?>? userId,
      Value<String>? teachingId,
      Value<int>? positionSeconds,
      Value<bool>? completed,
      Value<DateTime?>? clientCreatedAt,
      Value<DateTime?>? createdAt,
      Value<DateTime?>? updatedAt,
      Value<int>? rowid}) {
    return PlaybackProgressCompanion(
      syncStamp: syncStamp ?? this.syncStamp,
      id: id ?? this.id,
      userId: userId ?? this.userId,
      teachingId: teachingId ?? this.teachingId,
      positionSeconds: positionSeconds ?? this.positionSeconds,
      completed: completed ?? this.completed,
      clientCreatedAt: clientCreatedAt ?? this.clientCreatedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (syncStamp.present) {
      map['sync_stamp'] = Variable<int>(syncStamp.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (teachingId.present) {
      map['teaching_id'] = Variable<String>(teachingId.value);
    }
    if (positionSeconds.present) {
      map['position_seconds'] = Variable<int>(positionSeconds.value);
    }
    if (completed.present) {
      map['completed'] = Variable<bool>(completed.value);
    }
    if (clientCreatedAt.present) {
      map['client_created_at'] = Variable<DateTime>(clientCreatedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaybackProgressCompanion(')
          ..write('syncStamp: $syncStamp, ')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('teachingId: $teachingId, ')
          ..write('positionSeconds: $positionSeconds, ')
          ..write('completed: $completed, ')
          ..write('clientCreatedAt: $clientCreatedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalPlaybackPositionsTable extends LocalPlaybackPositions
    with TableInfo<$LocalPlaybackPositionsTable, LocalPlaybackPositionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalPlaybackPositionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _contentIdMeta =
      const VerificationMeta('contentId');
  @override
  late final GeneratedColumn<String> contentId = GeneratedColumn<String>(
      'content_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _progressIdMeta =
      const VerificationMeta('progressId');
  @override
  late final GeneratedColumn<String> progressId = GeneratedColumn<String>(
      'progress_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _positionSecondsMeta =
      const VerificationMeta('positionSeconds');
  @override
  late final GeneratedColumn<int> positionSeconds = GeneratedColumn<int>(
      'position_seconds', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _completedMeta =
      const VerificationMeta('completed');
  @override
  late final GeneratedColumn<bool> completed = GeneratedColumn<bool>(
      'completed', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("completed" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [contentId, progressId, positionSeconds, completed, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_playback_positions';
  @override
  VerificationContext validateIntegrity(
      Insertable<LocalPlaybackPositionRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('content_id')) {
      context.handle(_contentIdMeta,
          contentId.isAcceptableOrUnknown(data['content_id']!, _contentIdMeta));
    } else if (isInserting) {
      context.missing(_contentIdMeta);
    }
    if (data.containsKey('progress_id')) {
      context.handle(
          _progressIdMeta,
          progressId.isAcceptableOrUnknown(
              data['progress_id']!, _progressIdMeta));
    } else if (isInserting) {
      context.missing(_progressIdMeta);
    }
    if (data.containsKey('position_seconds')) {
      context.handle(
          _positionSecondsMeta,
          positionSeconds.isAcceptableOrUnknown(
              data['position_seconds']!, _positionSecondsMeta));
    } else if (isInserting) {
      context.missing(_positionSecondsMeta);
    }
    if (data.containsKey('completed')) {
      context.handle(_completedMeta,
          completed.isAcceptableOrUnknown(data['completed']!, _completedMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {contentId};
  @override
  LocalPlaybackPositionRow map(Map<String, dynamic> data,
      {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalPlaybackPositionRow(
      contentId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}content_id'])!,
      progressId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}progress_id'])!,
      positionSeconds: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}position_seconds'])!,
      completed: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}completed'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $LocalPlaybackPositionsTable createAlias(String alias) {
    return $LocalPlaybackPositionsTable(attachedDatabase, alias);
  }
}

class LocalPlaybackPositionRow extends DataClass
    implements Insertable<LocalPlaybackPositionRow> {
  /// Le contenu écouté — enseignement ou rassemblement, la table ne les
  /// distingue pas : l'identifiant est un UUID et les deux familles partagent
  /// la même route de rapport.
  final String contentId;

  /// **L'UUIDv7 sous lequel ce contenu est rapporté.**
  ///
  /// Frappé par ce client la première fois qu'il rapporte ce contenu, puis
  /// réutilisé — c'est ce qui fait de chaque rapport suivant un rejeu, donc un
  /// `UPDATE` sans doublon. Quand la synchronisation ramène la ligne serveur,
  /// c'est **son** `id` qui fait autorité (voir `PlaybackDao.resumeFor`) : une
  /// progression née sur un autre appareil a déjà son identité.
  final String progressId;

  /// Même unité que la collection répliquée, pour que la résolution des deux
  /// sources n'ait aucune conversion à faire.
  final int positionSeconds;
  final bool completed;

  /// Horloge **de l'appareil**, et c'est ce qui la départage de la ligne
  /// répliquée, dont l'`updatedAt` vient du serveur. Deux horloges comparées :
  /// voir la réserve écrite dans `PlaybackDao.resumeFor`.
  final DateTime updatedAt;
  const LocalPlaybackPositionRow(
      {required this.contentId,
      required this.progressId,
      required this.positionSeconds,
      required this.completed,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['content_id'] = Variable<String>(contentId);
    map['progress_id'] = Variable<String>(progressId);
    map['position_seconds'] = Variable<int>(positionSeconds);
    map['completed'] = Variable<bool>(completed);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  LocalPlaybackPositionsCompanion toCompanion(bool nullToAbsent) {
    return LocalPlaybackPositionsCompanion(
      contentId: Value(contentId),
      progressId: Value(progressId),
      positionSeconds: Value(positionSeconds),
      completed: Value(completed),
      updatedAt: Value(updatedAt),
    );
  }

  factory LocalPlaybackPositionRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalPlaybackPositionRow(
      contentId: serializer.fromJson<String>(json['contentId']),
      progressId: serializer.fromJson<String>(json['progressId']),
      positionSeconds: serializer.fromJson<int>(json['positionSeconds']),
      completed: serializer.fromJson<bool>(json['completed']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'contentId': serializer.toJson<String>(contentId),
      'progressId': serializer.toJson<String>(progressId),
      'positionSeconds': serializer.toJson<int>(positionSeconds),
      'completed': serializer.toJson<bool>(completed),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  LocalPlaybackPositionRow copyWith(
          {String? contentId,
          String? progressId,
          int? positionSeconds,
          bool? completed,
          DateTime? updatedAt}) =>
      LocalPlaybackPositionRow(
        contentId: contentId ?? this.contentId,
        progressId: progressId ?? this.progressId,
        positionSeconds: positionSeconds ?? this.positionSeconds,
        completed: completed ?? this.completed,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  LocalPlaybackPositionRow copyWithCompanion(
      LocalPlaybackPositionsCompanion data) {
    return LocalPlaybackPositionRow(
      contentId: data.contentId.present ? data.contentId.value : this.contentId,
      progressId:
          data.progressId.present ? data.progressId.value : this.progressId,
      positionSeconds: data.positionSeconds.present
          ? data.positionSeconds.value
          : this.positionSeconds,
      completed: data.completed.present ? data.completed.value : this.completed,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalPlaybackPositionRow(')
          ..write('contentId: $contentId, ')
          ..write('progressId: $progressId, ')
          ..write('positionSeconds: $positionSeconds, ')
          ..write('completed: $completed, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(contentId, progressId, positionSeconds, completed, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalPlaybackPositionRow &&
          other.contentId == this.contentId &&
          other.progressId == this.progressId &&
          other.positionSeconds == this.positionSeconds &&
          other.completed == this.completed &&
          other.updatedAt == this.updatedAt);
}

class LocalPlaybackPositionsCompanion
    extends UpdateCompanion<LocalPlaybackPositionRow> {
  final Value<String> contentId;
  final Value<String> progressId;
  final Value<int> positionSeconds;
  final Value<bool> completed;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const LocalPlaybackPositionsCompanion({
    this.contentId = const Value.absent(),
    this.progressId = const Value.absent(),
    this.positionSeconds = const Value.absent(),
    this.completed = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalPlaybackPositionsCompanion.insert({
    required String contentId,
    required String progressId,
    required int positionSeconds,
    this.completed = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : contentId = Value(contentId),
        progressId = Value(progressId),
        positionSeconds = Value(positionSeconds),
        updatedAt = Value(updatedAt);
  static Insertable<LocalPlaybackPositionRow> custom({
    Expression<String>? contentId,
    Expression<String>? progressId,
    Expression<int>? positionSeconds,
    Expression<bool>? completed,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (contentId != null) 'content_id': contentId,
      if (progressId != null) 'progress_id': progressId,
      if (positionSeconds != null) 'position_seconds': positionSeconds,
      if (completed != null) 'completed': completed,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalPlaybackPositionsCompanion copyWith(
      {Value<String>? contentId,
      Value<String>? progressId,
      Value<int>? positionSeconds,
      Value<bool>? completed,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return LocalPlaybackPositionsCompanion(
      contentId: contentId ?? this.contentId,
      progressId: progressId ?? this.progressId,
      positionSeconds: positionSeconds ?? this.positionSeconds,
      completed: completed ?? this.completed,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (contentId.present) {
      map['content_id'] = Variable<String>(contentId.value);
    }
    if (progressId.present) {
      map['progress_id'] = Variable<String>(progressId.value);
    }
    if (positionSeconds.present) {
      map['position_seconds'] = Variable<int>(positionSeconds.value);
    }
    if (completed.present) {
      map['completed'] = Variable<bool>(completed.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalPlaybackPositionsCompanion(')
          ..write('contentId: $contentId, ')
          ..write('progressId: $progressId, ')
          ..write('positionSeconds: $positionSeconds, ')
          ..write('completed: $completed, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LegalDocumentsTable extends LegalDocuments
    with TableInfo<$LegalDocumentsTable, LegalDocumentRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LegalDocumentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _syncStampMeta =
      const VerificationMeta('syncStamp');
  @override
  late final GeneratedColumn<int> syncStamp = GeneratedColumn<int>(
      'sync_stamp', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
      'kind', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _versionMeta =
      const VerificationMeta('version');
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
      'version', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _lastMandatoryVersionMeta =
      const VerificationMeta('lastMandatoryVersion');
  @override
  late final GeneratedColumn<int> lastMandatoryVersion = GeneratedColumn<int>(
      'last_mandatory_version', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  @override
  late final GeneratedColumnWithTypeConverter<List<LegalSection>, String>
      sections = GeneratedColumn<String>('sections', aliasedName, false,
              type: DriftSqlType.string, requiredDuringInsert: true)
          .withConverter<List<LegalSection>>(
              $LegalDocumentsTable.$convertersections);
  static const VerificationMeta _publishedAtMeta =
      const VerificationMeta('publishedAt');
  @override
  late final GeneratedColumn<DateTime> publishedAt = GeneratedColumn<DateTime>(
      'published_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        syncStamp,
        id,
        kind,
        version,
        lastMandatoryVersion,
        sections,
        publishedAt,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'legal_documents';
  @override
  VerificationContext validateIntegrity(Insertable<LegalDocumentRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('sync_stamp')) {
      context.handle(_syncStampMeta,
          syncStamp.isAcceptableOrUnknown(data['sync_stamp']!, _syncStampMeta));
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('kind')) {
      context.handle(
          _kindMeta, kind.isAcceptableOrUnknown(data['kind']!, _kindMeta));
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('version')) {
      context.handle(_versionMeta,
          version.isAcceptableOrUnknown(data['version']!, _versionMeta));
    }
    if (data.containsKey('last_mandatory_version')) {
      context.handle(
          _lastMandatoryVersionMeta,
          lastMandatoryVersion.isAcceptableOrUnknown(
              data['last_mandatory_version']!, _lastMandatoryVersionMeta));
    }
    if (data.containsKey('published_at')) {
      context.handle(
          _publishedAtMeta,
          publishedAt.isAcceptableOrUnknown(
              data['published_at']!, _publishedAtMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LegalDocumentRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LegalDocumentRow(
      syncStamp: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sync_stamp'])!,
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      kind: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      version: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}version'])!,
      lastMandatoryVersion: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}last_mandatory_version']),
      sections: $LegalDocumentsTable.$convertersections.fromSql(attachedDatabase
          .typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sections'])!),
      publishedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}published_at']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at']),
    );
  }

  @override
  $LegalDocumentsTable createAlias(String alias) {
    return $LegalDocumentsTable(attachedDatabase, alias);
  }

  static TypeConverter<List<LegalSection>, String> $convertersections =
      const LegalSectionsConverter();
}

class LegalDocumentRow extends DataClass
    implements Insertable<LegalDocumentRow> {
  /// Jeton de la transaction qui a écrit cette ligne pour la dernière fois.
  ///
  /// Le défaut existe pour que l'appelant n'ait **pas** à le renseigner : le
  /// jeton est une mécanique du magasin, posée par `SyncDao`, pas une donnée du
  /// serveur. Une ligne qui arriverait ici sans jeton porterait `0`, donc
  /// serait traitée comme jamais revue — la panne va dans le sens sûr.
  final int syncStamp;

  /// PK **SERIAL** côté serveur : un référentiel administrable ne se crée
  /// jamais hors ligne.
  final int id;

  /// `cgu`, `privacy` ou `about`. Stocké **tel quel**, jamais en enum : le
  /// magasin n'a pas à refuser une ligne dont il ne connaîtrait pas le genre —
  /// il n'aurait alors ni la ligne, ni le moyen d'apprendre qu'elle existe.
  /// C'est la lecture qui ne demande que les genres qu'un écran sait rendre.
  final String kind;

  /// Numéro d'édition courante, écrit par le serveur. S'affiche au pied du
  /// document.
  final int version;

  /// **Plancher d'acceptation** — la version en deçà de laquelle il faut
  /// ré-accepter. `null` = aucune acceptation exigée (c'est toujours le cas de
  /// `about`).
  ///
  /// Dérivée par le serveur à l'écriture, précisément pour que le client n'ait
  /// pas à la recalculer : un fidèle resté en v2 pendant que passaient 3
  /// (typo), 4 (substantielle) et 5 (typo) doit être arrêté, alors même que
  /// l'édition courante n'exige rien.
  final int? lastMandatoryVersion;

  /// Les sections **brutes**, dans l'ordre de lecture, cartes de traduction
  /// entières comprises. La langue se décide à la lecture et **sur le document
  /// entier** (`resolveLegalLocale`, ADR-0035).
  final List<LegalSection> sections;
  final DateTime? publishedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  const LegalDocumentRow(
      {required this.syncStamp,
      required this.id,
      required this.kind,
      required this.version,
      this.lastMandatoryVersion,
      required this.sections,
      this.publishedAt,
      this.createdAt,
      this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['sync_stamp'] = Variable<int>(syncStamp);
    map['id'] = Variable<int>(id);
    map['kind'] = Variable<String>(kind);
    map['version'] = Variable<int>(version);
    if (!nullToAbsent || lastMandatoryVersion != null) {
      map['last_mandatory_version'] = Variable<int>(lastMandatoryVersion);
    }
    {
      map['sections'] = Variable<String>(
          $LegalDocumentsTable.$convertersections.toSql(sections));
    }
    if (!nullToAbsent || publishedAt != null) {
      map['published_at'] = Variable<DateTime>(publishedAt);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    return map;
  }

  LegalDocumentsCompanion toCompanion(bool nullToAbsent) {
    return LegalDocumentsCompanion(
      syncStamp: Value(syncStamp),
      id: Value(id),
      kind: Value(kind),
      version: Value(version),
      lastMandatoryVersion: lastMandatoryVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(lastMandatoryVersion),
      sections: Value(sections),
      publishedAt: publishedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(publishedAt),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory LegalDocumentRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LegalDocumentRow(
      syncStamp: serializer.fromJson<int>(json['syncStamp']),
      id: serializer.fromJson<int>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      version: serializer.fromJson<int>(json['version']),
      lastMandatoryVersion:
          serializer.fromJson<int?>(json['lastMandatoryVersion']),
      sections: serializer.fromJson<List<LegalSection>>(json['sections']),
      publishedAt: serializer.fromJson<DateTime?>(json['publishedAt']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'syncStamp': serializer.toJson<int>(syncStamp),
      'id': serializer.toJson<int>(id),
      'kind': serializer.toJson<String>(kind),
      'version': serializer.toJson<int>(version),
      'lastMandatoryVersion': serializer.toJson<int?>(lastMandatoryVersion),
      'sections': serializer.toJson<List<LegalSection>>(sections),
      'publishedAt': serializer.toJson<DateTime?>(publishedAt),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
    };
  }

  LegalDocumentRow copyWith(
          {int? syncStamp,
          int? id,
          String? kind,
          int? version,
          Value<int?> lastMandatoryVersion = const Value.absent(),
          List<LegalSection>? sections,
          Value<DateTime?> publishedAt = const Value.absent(),
          Value<DateTime?> createdAt = const Value.absent(),
          Value<DateTime?> updatedAt = const Value.absent()}) =>
      LegalDocumentRow(
        syncStamp: syncStamp ?? this.syncStamp,
        id: id ?? this.id,
        kind: kind ?? this.kind,
        version: version ?? this.version,
        lastMandatoryVersion: lastMandatoryVersion.present
            ? lastMandatoryVersion.value
            : this.lastMandatoryVersion,
        sections: sections ?? this.sections,
        publishedAt: publishedAt.present ? publishedAt.value : this.publishedAt,
        createdAt: createdAt.present ? createdAt.value : this.createdAt,
        updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
      );
  LegalDocumentRow copyWithCompanion(LegalDocumentsCompanion data) {
    return LegalDocumentRow(
      syncStamp: data.syncStamp.present ? data.syncStamp.value : this.syncStamp,
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      version: data.version.present ? data.version.value : this.version,
      lastMandatoryVersion: data.lastMandatoryVersion.present
          ? data.lastMandatoryVersion.value
          : this.lastMandatoryVersion,
      sections: data.sections.present ? data.sections.value : this.sections,
      publishedAt:
          data.publishedAt.present ? data.publishedAt.value : this.publishedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LegalDocumentRow(')
          ..write('syncStamp: $syncStamp, ')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('version: $version, ')
          ..write('lastMandatoryVersion: $lastMandatoryVersion, ')
          ..write('sections: $sections, ')
          ..write('publishedAt: $publishedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(syncStamp, id, kind, version,
      lastMandatoryVersion, sections, publishedAt, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LegalDocumentRow &&
          other.syncStamp == this.syncStamp &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.version == this.version &&
          other.lastMandatoryVersion == this.lastMandatoryVersion &&
          other.sections == this.sections &&
          other.publishedAt == this.publishedAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class LegalDocumentsCompanion extends UpdateCompanion<LegalDocumentRow> {
  final Value<int> syncStamp;
  final Value<int> id;
  final Value<String> kind;
  final Value<int> version;
  final Value<int?> lastMandatoryVersion;
  final Value<List<LegalSection>> sections;
  final Value<DateTime?> publishedAt;
  final Value<DateTime?> createdAt;
  final Value<DateTime?> updatedAt;
  const LegalDocumentsCompanion({
    this.syncStamp = const Value.absent(),
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.version = const Value.absent(),
    this.lastMandatoryVersion = const Value.absent(),
    this.sections = const Value.absent(),
    this.publishedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  LegalDocumentsCompanion.insert({
    this.syncStamp = const Value.absent(),
    this.id = const Value.absent(),
    required String kind,
    this.version = const Value.absent(),
    this.lastMandatoryVersion = const Value.absent(),
    required List<LegalSection> sections,
    this.publishedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  })  : kind = Value(kind),
        sections = Value(sections);
  static Insertable<LegalDocumentRow> custom({
    Expression<int>? syncStamp,
    Expression<int>? id,
    Expression<String>? kind,
    Expression<int>? version,
    Expression<int>? lastMandatoryVersion,
    Expression<String>? sections,
    Expression<DateTime>? publishedAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (syncStamp != null) 'sync_stamp': syncStamp,
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (version != null) 'version': version,
      if (lastMandatoryVersion != null)
        'last_mandatory_version': lastMandatoryVersion,
      if (sections != null) 'sections': sections,
      if (publishedAt != null) 'published_at': publishedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  LegalDocumentsCompanion copyWith(
      {Value<int>? syncStamp,
      Value<int>? id,
      Value<String>? kind,
      Value<int>? version,
      Value<int?>? lastMandatoryVersion,
      Value<List<LegalSection>>? sections,
      Value<DateTime?>? publishedAt,
      Value<DateTime?>? createdAt,
      Value<DateTime?>? updatedAt}) {
    return LegalDocumentsCompanion(
      syncStamp: syncStamp ?? this.syncStamp,
      id: id ?? this.id,
      kind: kind ?? this.kind,
      version: version ?? this.version,
      lastMandatoryVersion: lastMandatoryVersion ?? this.lastMandatoryVersion,
      sections: sections ?? this.sections,
      publishedAt: publishedAt ?? this.publishedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (syncStamp.present) {
      map['sync_stamp'] = Variable<int>(syncStamp.value);
    }
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (lastMandatoryVersion.present) {
      map['last_mandatory_version'] = Variable<int>(lastMandatoryVersion.value);
    }
    if (sections.present) {
      map['sections'] = Variable<String>(
          $LegalDocumentsTable.$convertersections.toSql(sections.value));
    }
    if (publishedAt.present) {
      map['published_at'] = Variable<DateTime>(publishedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LegalDocumentsCompanion(')
          ..write('syncStamp: $syncStamp, ')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('version: $version, ')
          ..write('lastMandatoryVersion: $lastMandatoryVersion, ')
          ..write('sections: $sections, ')
          ..write('publishedAt: $publishedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $SeasonsTable extends Seasons with TableInfo<$SeasonsTable, SeasonRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SeasonsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _syncStampMeta =
      const VerificationMeta('syncStamp');
  @override
  late final GeneratedColumn<int> syncStamp = GeneratedColumn<int>(
      'sync_stamp', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _backgroundUrlMeta =
      const VerificationMeta('backgroundUrl');
  @override
  late final GeneratedColumn<String> backgroundUrl = GeneratedColumn<String>(
      'background_url', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _backgroundVerticalUrlMeta =
      const VerificationMeta('backgroundVerticalUrl');
  @override
  late final GeneratedColumn<String> backgroundVerticalUrl =
      GeneratedColumn<String>('background_vertical_url', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _startsOnMeta =
      const VerificationMeta('startsOn');
  @override
  late final GeneratedColumn<String> startsOn = GeneratedColumn<String>(
      'starts_on', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _endsOnMeta = const VerificationMeta('endsOn');
  @override
  late final GeneratedColumn<String> endsOn = GeneratedColumn<String>(
      'ends_on', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        syncStamp,
        id,
        name,
        backgroundUrl,
        backgroundVerticalUrl,
        startsOn,
        endsOn,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'seasons';
  @override
  VerificationContext validateIntegrity(Insertable<SeasonRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('sync_stamp')) {
      context.handle(_syncStampMeta,
          syncStamp.isAcceptableOrUnknown(data['sync_stamp']!, _syncStampMeta));
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('background_url')) {
      context.handle(
          _backgroundUrlMeta,
          backgroundUrl.isAcceptableOrUnknown(
              data['background_url']!, _backgroundUrlMeta));
    } else if (isInserting) {
      context.missing(_backgroundUrlMeta);
    }
    if (data.containsKey('background_vertical_url')) {
      context.handle(
          _backgroundVerticalUrlMeta,
          backgroundVerticalUrl.isAcceptableOrUnknown(
              data['background_vertical_url']!, _backgroundVerticalUrlMeta));
    }
    if (data.containsKey('starts_on')) {
      context.handle(_startsOnMeta,
          startsOn.isAcceptableOrUnknown(data['starts_on']!, _startsOnMeta));
    } else if (isInserting) {
      context.missing(_startsOnMeta);
    }
    if (data.containsKey('ends_on')) {
      context.handle(_endsOnMeta,
          endsOn.isAcceptableOrUnknown(data['ends_on']!, _endsOnMeta));
    } else if (isInserting) {
      context.missing(_endsOnMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SeasonRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SeasonRow(
      syncStamp: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sync_stamp'])!,
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      backgroundUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}background_url'])!,
      backgroundVerticalUrl: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}background_vertical_url']),
      startsOn: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}starts_on'])!,
      endsOn: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}ends_on'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at']),
    );
  }

  @override
  $SeasonsTable createAlias(String alias) {
    return $SeasonsTable(attachedDatabase, alias);
  }
}

class SeasonRow extends DataClass implements Insertable<SeasonRow> {
  /// Jeton de la transaction qui a écrit cette ligne pour la dernière fois.
  ///
  /// Le défaut existe pour que l'appelant n'ait **pas** à le renseigner : le
  /// jeton est une mécanique du magasin, posée par `SyncDao`, pas une donnée du
  /// serveur. Une ligne qui arriverait ici sans jeton porterait `0`, donc
  /// serait traitée comme jamais revue — la panne va dans le sens sûr.
  final int syncStamp;

  /// PK **SERIAL** côté serveur : une saison s'administre au portail, jamais
  /// hors ligne.
  final int id;

  /// Le nom de la saison. Ne s'affiche nulle part aujourd'hui ; il voyage parce
  /// qu'il est ce qui rend une ligne lisible dans un journal ou une inspection
  /// de base, quand on cherche pourquoi le fond n'est pas celui qu'on croyait.
  final String name;

  /// Le fond **paysage**, toujours servi (il est requis au portail).
  final String backgroundUrl;

  /// Le fond **vertical**, celui des téléphones. `null` = la saison n'en a pas
  /// déposé, et le lecteur retombe sur le paysage — recadré, ce qui reste
  /// préférable à un aplat de couleur.
  final String? backgroundVerticalUrl;

  /// Premier jour, **inclus**, en `YYYY-MM-DD`.
  ///
  /// **Une chaîne, jamais un `DateTime`** — la règle 2 de `sync_rows.dart`, la
  /// même que `teachings.recordedAt` : un jour n'est pas un instant, et le
  /// convertir en poserait un (minuit, dans un fuseau qu'il faudrait choisir),
  /// que le moindre décalage ferait afficher la veille. La comparaison reste
  /// exacte : en ISO, l'ordre lexicographique **est** l'ordre chronologique.
  final String startsOn;

  /// Dernier jour, **inclus**, en `YYYY-MM-DD`. Voir [startsOn].
  final String endsOn;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  const SeasonRow(
      {required this.syncStamp,
      required this.id,
      required this.name,
      required this.backgroundUrl,
      this.backgroundVerticalUrl,
      required this.startsOn,
      required this.endsOn,
      this.createdAt,
      this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['sync_stamp'] = Variable<int>(syncStamp);
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['background_url'] = Variable<String>(backgroundUrl);
    if (!nullToAbsent || backgroundVerticalUrl != null) {
      map['background_vertical_url'] = Variable<String>(backgroundVerticalUrl);
    }
    map['starts_on'] = Variable<String>(startsOn);
    map['ends_on'] = Variable<String>(endsOn);
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    return map;
  }

  SeasonsCompanion toCompanion(bool nullToAbsent) {
    return SeasonsCompanion(
      syncStamp: Value(syncStamp),
      id: Value(id),
      name: Value(name),
      backgroundUrl: Value(backgroundUrl),
      backgroundVerticalUrl: backgroundVerticalUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(backgroundVerticalUrl),
      startsOn: Value(startsOn),
      endsOn: Value(endsOn),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory SeasonRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SeasonRow(
      syncStamp: serializer.fromJson<int>(json['syncStamp']),
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      backgroundUrl: serializer.fromJson<String>(json['backgroundUrl']),
      backgroundVerticalUrl:
          serializer.fromJson<String?>(json['backgroundVerticalUrl']),
      startsOn: serializer.fromJson<String>(json['startsOn']),
      endsOn: serializer.fromJson<String>(json['endsOn']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'syncStamp': serializer.toJson<int>(syncStamp),
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'backgroundUrl': serializer.toJson<String>(backgroundUrl),
      'backgroundVerticalUrl':
          serializer.toJson<String?>(backgroundVerticalUrl),
      'startsOn': serializer.toJson<String>(startsOn),
      'endsOn': serializer.toJson<String>(endsOn),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
    };
  }

  SeasonRow copyWith(
          {int? syncStamp,
          int? id,
          String? name,
          String? backgroundUrl,
          Value<String?> backgroundVerticalUrl = const Value.absent(),
          String? startsOn,
          String? endsOn,
          Value<DateTime?> createdAt = const Value.absent(),
          Value<DateTime?> updatedAt = const Value.absent()}) =>
      SeasonRow(
        syncStamp: syncStamp ?? this.syncStamp,
        id: id ?? this.id,
        name: name ?? this.name,
        backgroundUrl: backgroundUrl ?? this.backgroundUrl,
        backgroundVerticalUrl: backgroundVerticalUrl.present
            ? backgroundVerticalUrl.value
            : this.backgroundVerticalUrl,
        startsOn: startsOn ?? this.startsOn,
        endsOn: endsOn ?? this.endsOn,
        createdAt: createdAt.present ? createdAt.value : this.createdAt,
        updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
      );
  SeasonRow copyWithCompanion(SeasonsCompanion data) {
    return SeasonRow(
      syncStamp: data.syncStamp.present ? data.syncStamp.value : this.syncStamp,
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      backgroundUrl: data.backgroundUrl.present
          ? data.backgroundUrl.value
          : this.backgroundUrl,
      backgroundVerticalUrl: data.backgroundVerticalUrl.present
          ? data.backgroundVerticalUrl.value
          : this.backgroundVerticalUrl,
      startsOn: data.startsOn.present ? data.startsOn.value : this.startsOn,
      endsOn: data.endsOn.present ? data.endsOn.value : this.endsOn,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SeasonRow(')
          ..write('syncStamp: $syncStamp, ')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('backgroundUrl: $backgroundUrl, ')
          ..write('backgroundVerticalUrl: $backgroundVerticalUrl, ')
          ..write('startsOn: $startsOn, ')
          ..write('endsOn: $endsOn, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(syncStamp, id, name, backgroundUrl,
      backgroundVerticalUrl, startsOn, endsOn, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SeasonRow &&
          other.syncStamp == this.syncStamp &&
          other.id == this.id &&
          other.name == this.name &&
          other.backgroundUrl == this.backgroundUrl &&
          other.backgroundVerticalUrl == this.backgroundVerticalUrl &&
          other.startsOn == this.startsOn &&
          other.endsOn == this.endsOn &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class SeasonsCompanion extends UpdateCompanion<SeasonRow> {
  final Value<int> syncStamp;
  final Value<int> id;
  final Value<String> name;
  final Value<String> backgroundUrl;
  final Value<String?> backgroundVerticalUrl;
  final Value<String> startsOn;
  final Value<String> endsOn;
  final Value<DateTime?> createdAt;
  final Value<DateTime?> updatedAt;
  const SeasonsCompanion({
    this.syncStamp = const Value.absent(),
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.backgroundUrl = const Value.absent(),
    this.backgroundVerticalUrl = const Value.absent(),
    this.startsOn = const Value.absent(),
    this.endsOn = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  SeasonsCompanion.insert({
    this.syncStamp = const Value.absent(),
    this.id = const Value.absent(),
    required String name,
    required String backgroundUrl,
    this.backgroundVerticalUrl = const Value.absent(),
    required String startsOn,
    required String endsOn,
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  })  : name = Value(name),
        backgroundUrl = Value(backgroundUrl),
        startsOn = Value(startsOn),
        endsOn = Value(endsOn);
  static Insertable<SeasonRow> custom({
    Expression<int>? syncStamp,
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? backgroundUrl,
    Expression<String>? backgroundVerticalUrl,
    Expression<String>? startsOn,
    Expression<String>? endsOn,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (syncStamp != null) 'sync_stamp': syncStamp,
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (backgroundUrl != null) 'background_url': backgroundUrl,
      if (backgroundVerticalUrl != null)
        'background_vertical_url': backgroundVerticalUrl,
      if (startsOn != null) 'starts_on': startsOn,
      if (endsOn != null) 'ends_on': endsOn,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  SeasonsCompanion copyWith(
      {Value<int>? syncStamp,
      Value<int>? id,
      Value<String>? name,
      Value<String>? backgroundUrl,
      Value<String?>? backgroundVerticalUrl,
      Value<String>? startsOn,
      Value<String>? endsOn,
      Value<DateTime?>? createdAt,
      Value<DateTime?>? updatedAt}) {
    return SeasonsCompanion(
      syncStamp: syncStamp ?? this.syncStamp,
      id: id ?? this.id,
      name: name ?? this.name,
      backgroundUrl: backgroundUrl ?? this.backgroundUrl,
      backgroundVerticalUrl:
          backgroundVerticalUrl ?? this.backgroundVerticalUrl,
      startsOn: startsOn ?? this.startsOn,
      endsOn: endsOn ?? this.endsOn,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (syncStamp.present) {
      map['sync_stamp'] = Variable<int>(syncStamp.value);
    }
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (backgroundUrl.present) {
      map['background_url'] = Variable<String>(backgroundUrl.value);
    }
    if (backgroundVerticalUrl.present) {
      map['background_vertical_url'] =
          Variable<String>(backgroundVerticalUrl.value);
    }
    if (startsOn.present) {
      map['starts_on'] = Variable<String>(startsOn.value);
    }
    if (endsOn.present) {
      map['ends_on'] = Variable<String>(endsOn.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SeasonsCompanion(')
          ..write('syncStamp: $syncStamp, ')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('backgroundUrl: $backgroundUrl, ')
          ..write('backgroundVerticalUrl: $backgroundVerticalUrl, ')
          ..write('startsOn: $startsOn, ')
          ..write('endsOn: $endsOn, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $PresentationVocabularyTable extends PresentationVocabulary
    with TableInfo<$PresentationVocabularyTable, VocabularyRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PresentationVocabularyTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _syncStampMeta =
      const VerificationMeta('syncStamp');
  @override
  late final GeneratedColumn<int> syncStamp = GeneratedColumn<int>(
      'sync_stamp', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
      'kind', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  late final GeneratedColumnWithTypeConverter<Map<String, String>?, String>
      singular = GeneratedColumn<String>('singular', aliasedName, true,
              type: DriftSqlType.string, requiredDuringInsert: false)
          .withConverter<Map<String, String>?>(
              $PresentationVocabularyTable.$convertersingularn);
  @override
  late final GeneratedColumnWithTypeConverter<Map<String, String>?, String>
      plural = GeneratedColumn<String>('plural', aliasedName, true,
              type: DriftSqlType.string, requiredDuringInsert: false)
          .withConverter<Map<String, String>?>(
              $PresentationVocabularyTable.$converterpluraln);
  @override
  late final GeneratedColumnWithTypeConverter<Map<String, String>?, String>
      label = GeneratedColumn<String>('label', aliasedName, true,
              type: DriftSqlType.string, requiredDuringInsert: false)
          .withConverter<Map<String, String>?>(
              $PresentationVocabularyTable.$converterlabeln);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [syncStamp, id, kind, singular, plural, label, createdAt, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'presentation_vocabulary';
  @override
  VerificationContext validateIntegrity(Insertable<VocabularyRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('sync_stamp')) {
      context.handle(_syncStampMeta,
          syncStamp.isAcceptableOrUnknown(data['sync_stamp']!, _syncStampMeta));
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
          _kindMeta, kind.isAcceptableOrUnknown(data['kind']!, _kindMeta));
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  VocabularyRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VocabularyRow(
      syncStamp: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sync_stamp'])!,
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      kind: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      singular: $PresentationVocabularyTable.$convertersingularn.fromSql(
          attachedDatabase.typeMapping
              .read(DriftSqlType.string, data['${effectivePrefix}singular'])),
      plural: $PresentationVocabularyTable.$converterpluraln.fromSql(
          attachedDatabase.typeMapping
              .read(DriftSqlType.string, data['${effectivePrefix}plural'])),
      label: $PresentationVocabularyTable.$converterlabeln.fromSql(
          attachedDatabase.typeMapping
              .read(DriftSqlType.string, data['${effectivePrefix}label'])),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at']),
    );
  }

  @override
  $PresentationVocabularyTable createAlias(String alias) {
    return $PresentationVocabularyTable(attachedDatabase, alias);
  }

  static TypeConverter<Map<String, String>, String> $convertersingular =
      const I18nMapConverter();
  static TypeConverter<Map<String, String>?, String?> $convertersingularn =
      NullAwareTypeConverter.wrap($convertersingular);
  static TypeConverter<Map<String, String>, String> $converterplural =
      const I18nMapConverter();
  static TypeConverter<Map<String, String>?, String?> $converterpluraln =
      NullAwareTypeConverter.wrap($converterplural);
  static TypeConverter<Map<String, String>, String> $converterlabel =
      const I18nMapConverter();
  static TypeConverter<Map<String, String>?, String?> $converterlabeln =
      NullAwareTypeConverter.wrap($converterlabel);
}

class VocabularyRow extends DataClass implements Insertable<VocabularyRow> {
  /// Jeton de la transaction qui a écrit cette ligne pour la dernière fois.
  ///
  /// Le défaut existe pour que l'appelant n'ait **pas** à le renseigner : le
  /// jeton est une mécanique du magasin, posée par `SyncDao`, pas une donnée du
  /// serveur. Une ligne qui arriverait ici sans jeton porterait `0`, donc
  /// serait traitée comme jamais revue — la panne va dans le sens sûr.
  final int syncStamp;

  /// La clé du catalogue — **une chaîne**, à la différence des autres
  /// référentiels (PK `SERIAL`). C'est le premier référentiel du dépôt dans ce
  /// cas, et le tri `(updated_at, id)` y reste total et déterministe.
  final String id;

  /// `'term'` ou `'label'`. Stockée **telle quelle**, jamais refermée sur un
  /// enum : le magasin n'a pas à refuser une nature qu'il ne connaîtrait pas
  /// encore. La déduire de la forme de la clé — « contient-elle un point ? » —
  /// serait une convention qu'un seul renommage casserait en silence.
  final String kind;

  /// Le singulier d'un **terme**. `null` = le mot du dépôt. Toujours `null`
  /// pour une surcharge de libellé.
  final Map<String, String>? singular;

  /// Le pluriel d'un **terme**, écrit à la main au portail. **Aucun accord
  /// n'est jamais calculé** : une phrase composée est sa propre clé, surchargée
  /// entière (décision de cadrage, pas un report).
  final Map<String, String>? plural;

  /// La surcharge d'un **libellé**. `null` = le libellé du dépôt. Toujours
  /// `null` pour un terme.
  final Map<String, String>? label;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  const VocabularyRow(
      {required this.syncStamp,
      required this.id,
      required this.kind,
      this.singular,
      this.plural,
      this.label,
      this.createdAt,
      this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['sync_stamp'] = Variable<int>(syncStamp);
    map['id'] = Variable<String>(id);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || singular != null) {
      map['singular'] = Variable<String>(
          $PresentationVocabularyTable.$convertersingularn.toSql(singular));
    }
    if (!nullToAbsent || plural != null) {
      map['plural'] = Variable<String>(
          $PresentationVocabularyTable.$converterpluraln.toSql(plural));
    }
    if (!nullToAbsent || label != null) {
      map['label'] = Variable<String>(
          $PresentationVocabularyTable.$converterlabeln.toSql(label));
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    return map;
  }

  PresentationVocabularyCompanion toCompanion(bool nullToAbsent) {
    return PresentationVocabularyCompanion(
      syncStamp: Value(syncStamp),
      id: Value(id),
      kind: Value(kind),
      singular: singular == null && nullToAbsent
          ? const Value.absent()
          : Value(singular),
      plural:
          plural == null && nullToAbsent ? const Value.absent() : Value(plural),
      label:
          label == null && nullToAbsent ? const Value.absent() : Value(label),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory VocabularyRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VocabularyRow(
      syncStamp: serializer.fromJson<int>(json['syncStamp']),
      id: serializer.fromJson<String>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      singular: serializer.fromJson<Map<String, String>?>(json['singular']),
      plural: serializer.fromJson<Map<String, String>?>(json['plural']),
      label: serializer.fromJson<Map<String, String>?>(json['label']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'syncStamp': serializer.toJson<int>(syncStamp),
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<String>(kind),
      'singular': serializer.toJson<Map<String, String>?>(singular),
      'plural': serializer.toJson<Map<String, String>?>(plural),
      'label': serializer.toJson<Map<String, String>?>(label),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
    };
  }

  VocabularyRow copyWith(
          {int? syncStamp,
          String? id,
          String? kind,
          Value<Map<String, String>?> singular = const Value.absent(),
          Value<Map<String, String>?> plural = const Value.absent(),
          Value<Map<String, String>?> label = const Value.absent(),
          Value<DateTime?> createdAt = const Value.absent(),
          Value<DateTime?> updatedAt = const Value.absent()}) =>
      VocabularyRow(
        syncStamp: syncStamp ?? this.syncStamp,
        id: id ?? this.id,
        kind: kind ?? this.kind,
        singular: singular.present ? singular.value : this.singular,
        plural: plural.present ? plural.value : this.plural,
        label: label.present ? label.value : this.label,
        createdAt: createdAt.present ? createdAt.value : this.createdAt,
        updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
      );
  VocabularyRow copyWithCompanion(PresentationVocabularyCompanion data) {
    return VocabularyRow(
      syncStamp: data.syncStamp.present ? data.syncStamp.value : this.syncStamp,
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      singular: data.singular.present ? data.singular.value : this.singular,
      plural: data.plural.present ? data.plural.value : this.plural,
      label: data.label.present ? data.label.value : this.label,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VocabularyRow(')
          ..write('syncStamp: $syncStamp, ')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('singular: $singular, ')
          ..write('plural: $plural, ')
          ..write('label: $label, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      syncStamp, id, kind, singular, plural, label, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VocabularyRow &&
          other.syncStamp == this.syncStamp &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.singular == this.singular &&
          other.plural == this.plural &&
          other.label == this.label &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class PresentationVocabularyCompanion extends UpdateCompanion<VocabularyRow> {
  final Value<int> syncStamp;
  final Value<String> id;
  final Value<String> kind;
  final Value<Map<String, String>?> singular;
  final Value<Map<String, String>?> plural;
  final Value<Map<String, String>?> label;
  final Value<DateTime?> createdAt;
  final Value<DateTime?> updatedAt;
  final Value<int> rowid;
  const PresentationVocabularyCompanion({
    this.syncStamp = const Value.absent(),
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.singular = const Value.absent(),
    this.plural = const Value.absent(),
    this.label = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PresentationVocabularyCompanion.insert({
    this.syncStamp = const Value.absent(),
    required String id,
    required String kind,
    this.singular = const Value.absent(),
    this.plural = const Value.absent(),
    this.label = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        kind = Value(kind);
  static Insertable<VocabularyRow> custom({
    Expression<int>? syncStamp,
    Expression<String>? id,
    Expression<String>? kind,
    Expression<String>? singular,
    Expression<String>? plural,
    Expression<String>? label,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (syncStamp != null) 'sync_stamp': syncStamp,
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (singular != null) 'singular': singular,
      if (plural != null) 'plural': plural,
      if (label != null) 'label': label,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PresentationVocabularyCompanion copyWith(
      {Value<int>? syncStamp,
      Value<String>? id,
      Value<String>? kind,
      Value<Map<String, String>?>? singular,
      Value<Map<String, String>?>? plural,
      Value<Map<String, String>?>? label,
      Value<DateTime?>? createdAt,
      Value<DateTime?>? updatedAt,
      Value<int>? rowid}) {
    return PresentationVocabularyCompanion(
      syncStamp: syncStamp ?? this.syncStamp,
      id: id ?? this.id,
      kind: kind ?? this.kind,
      singular: singular ?? this.singular,
      plural: plural ?? this.plural,
      label: label ?? this.label,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (syncStamp.present) {
      map['sync_stamp'] = Variable<int>(syncStamp.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (singular.present) {
      map['singular'] = Variable<String>($PresentationVocabularyTable
          .$convertersingularn
          .toSql(singular.value));
    }
    if (plural.present) {
      map['plural'] = Variable<String>(
          $PresentationVocabularyTable.$converterpluraln.toSql(plural.value));
    }
    if (label.present) {
      map['label'] = Variable<String>(
          $PresentationVocabularyTable.$converterlabeln.toSql(label.value));
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PresentationVocabularyCompanion(')
          ..write('syncStamp: $syncStamp, ')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('singular: $singular, ')
          ..write('plural: $plural, ')
          ..write('label: $label, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DecorTable extends Decor with TableInfo<$DecorTable, DecorRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DecorTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _syncStampMeta =
      const VerificationMeta('syncStamp');
  @override
  late final GeneratedColumn<int> syncStamp = GeneratedColumn<int>(
      'sync_stamp', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _backgroundUrlMeta =
      const VerificationMeta('backgroundUrl');
  @override
  late final GeneratedColumn<String> backgroundUrl = GeneratedColumn<String>(
      'background_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _backgroundVerticalUrlMeta =
      const VerificationMeta('backgroundVerticalUrl');
  @override
  late final GeneratedColumn<String> backgroundVerticalUrl =
      GeneratedColumn<String>('background_vertical_url', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        syncStamp,
        id,
        backgroundUrl,
        backgroundVerticalUrl,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'decor';
  @override
  VerificationContext validateIntegrity(Insertable<DecorRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('sync_stamp')) {
      context.handle(_syncStampMeta,
          syncStamp.isAcceptableOrUnknown(data['sync_stamp']!, _syncStampMeta));
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('background_url')) {
      context.handle(
          _backgroundUrlMeta,
          backgroundUrl.isAcceptableOrUnknown(
              data['background_url']!, _backgroundUrlMeta));
    }
    if (data.containsKey('background_vertical_url')) {
      context.handle(
          _backgroundVerticalUrlMeta,
          backgroundVerticalUrl.isAcceptableOrUnknown(
              data['background_vertical_url']!, _backgroundVerticalUrlMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DecorRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DecorRow(
      syncStamp: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sync_stamp'])!,
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      backgroundUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}background_url']),
      backgroundVerticalUrl: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}background_vertical_url']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at']),
    );
  }

  @override
  $DecorTable createAlias(String alias) {
    return $DecorTable(attachedDatabase, alias);
  }
}

class DecorRow extends DataClass implements Insertable<DecorRow> {
  /// Jeton de la transaction qui a écrit cette ligne pour la dernière fois.
  ///
  /// Le défaut existe pour que l'appelant n'ait **pas** à le renseigner : le
  /// jeton est une mécanique du magasin, posée par `SyncDao`, pas une donnée du
  /// serveur. Une ligne qui arriverait ici sans jeton porterait `0`, donc
  /// serait traitée comme jamais revue — la panne va dans le sens sûr.
  final int syncStamp;

  /// PK **SERIAL** côté serveur. Vaut toujours `1` — la table d'origine est un
  /// singleton —, mais la colonne existe parce que le curseur composé du
  /// protocole en a besoin, et parce qu'une table locale n'a pas à supposer ce
  /// que le serveur garantit.
  final int id;

  /// Le décor **paysage**. `null` = rien n'a été déposé au portail.
  final String? backgroundUrl;

  /// Le décor **vertical**, celui des téléphones. `null` = pas de vertical ; on
  /// retombe sur le paysage, recadré.
  final String? backgroundVerticalUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  const DecorRow(
      {required this.syncStamp,
      required this.id,
      this.backgroundUrl,
      this.backgroundVerticalUrl,
      this.createdAt,
      this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['sync_stamp'] = Variable<int>(syncStamp);
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || backgroundUrl != null) {
      map['background_url'] = Variable<String>(backgroundUrl);
    }
    if (!nullToAbsent || backgroundVerticalUrl != null) {
      map['background_vertical_url'] = Variable<String>(backgroundVerticalUrl);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    return map;
  }

  DecorCompanion toCompanion(bool nullToAbsent) {
    return DecorCompanion(
      syncStamp: Value(syncStamp),
      id: Value(id),
      backgroundUrl: backgroundUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(backgroundUrl),
      backgroundVerticalUrl: backgroundVerticalUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(backgroundVerticalUrl),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory DecorRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DecorRow(
      syncStamp: serializer.fromJson<int>(json['syncStamp']),
      id: serializer.fromJson<int>(json['id']),
      backgroundUrl: serializer.fromJson<String?>(json['backgroundUrl']),
      backgroundVerticalUrl:
          serializer.fromJson<String?>(json['backgroundVerticalUrl']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'syncStamp': serializer.toJson<int>(syncStamp),
      'id': serializer.toJson<int>(id),
      'backgroundUrl': serializer.toJson<String?>(backgroundUrl),
      'backgroundVerticalUrl':
          serializer.toJson<String?>(backgroundVerticalUrl),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
    };
  }

  DecorRow copyWith(
          {int? syncStamp,
          int? id,
          Value<String?> backgroundUrl = const Value.absent(),
          Value<String?> backgroundVerticalUrl = const Value.absent(),
          Value<DateTime?> createdAt = const Value.absent(),
          Value<DateTime?> updatedAt = const Value.absent()}) =>
      DecorRow(
        syncStamp: syncStamp ?? this.syncStamp,
        id: id ?? this.id,
        backgroundUrl:
            backgroundUrl.present ? backgroundUrl.value : this.backgroundUrl,
        backgroundVerticalUrl: backgroundVerticalUrl.present
            ? backgroundVerticalUrl.value
            : this.backgroundVerticalUrl,
        createdAt: createdAt.present ? createdAt.value : this.createdAt,
        updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
      );
  DecorRow copyWithCompanion(DecorCompanion data) {
    return DecorRow(
      syncStamp: data.syncStamp.present ? data.syncStamp.value : this.syncStamp,
      id: data.id.present ? data.id.value : this.id,
      backgroundUrl: data.backgroundUrl.present
          ? data.backgroundUrl.value
          : this.backgroundUrl,
      backgroundVerticalUrl: data.backgroundVerticalUrl.present
          ? data.backgroundVerticalUrl.value
          : this.backgroundVerticalUrl,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DecorRow(')
          ..write('syncStamp: $syncStamp, ')
          ..write('id: $id, ')
          ..write('backgroundUrl: $backgroundUrl, ')
          ..write('backgroundVerticalUrl: $backgroundVerticalUrl, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(syncStamp, id, backgroundUrl,
      backgroundVerticalUrl, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DecorRow &&
          other.syncStamp == this.syncStamp &&
          other.id == this.id &&
          other.backgroundUrl == this.backgroundUrl &&
          other.backgroundVerticalUrl == this.backgroundVerticalUrl &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class DecorCompanion extends UpdateCompanion<DecorRow> {
  final Value<int> syncStamp;
  final Value<int> id;
  final Value<String?> backgroundUrl;
  final Value<String?> backgroundVerticalUrl;
  final Value<DateTime?> createdAt;
  final Value<DateTime?> updatedAt;
  const DecorCompanion({
    this.syncStamp = const Value.absent(),
    this.id = const Value.absent(),
    this.backgroundUrl = const Value.absent(),
    this.backgroundVerticalUrl = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  DecorCompanion.insert({
    this.syncStamp = const Value.absent(),
    this.id = const Value.absent(),
    this.backgroundUrl = const Value.absent(),
    this.backgroundVerticalUrl = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  static Insertable<DecorRow> custom({
    Expression<int>? syncStamp,
    Expression<int>? id,
    Expression<String>? backgroundUrl,
    Expression<String>? backgroundVerticalUrl,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (syncStamp != null) 'sync_stamp': syncStamp,
      if (id != null) 'id': id,
      if (backgroundUrl != null) 'background_url': backgroundUrl,
      if (backgroundVerticalUrl != null)
        'background_vertical_url': backgroundVerticalUrl,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  DecorCompanion copyWith(
      {Value<int>? syncStamp,
      Value<int>? id,
      Value<String?>? backgroundUrl,
      Value<String?>? backgroundVerticalUrl,
      Value<DateTime?>? createdAt,
      Value<DateTime?>? updatedAt}) {
    return DecorCompanion(
      syncStamp: syncStamp ?? this.syncStamp,
      id: id ?? this.id,
      backgroundUrl: backgroundUrl ?? this.backgroundUrl,
      backgroundVerticalUrl:
          backgroundVerticalUrl ?? this.backgroundVerticalUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (syncStamp.present) {
      map['sync_stamp'] = Variable<int>(syncStamp.value);
    }
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (backgroundUrl.present) {
      map['background_url'] = Variable<String>(backgroundUrl.value);
    }
    if (backgroundVerticalUrl.present) {
      map['background_vertical_url'] =
          Variable<String>(backgroundVerticalUrl.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DecorCompanion(')
          ..write('syncStamp: $syncStamp, ')
          ..write('id: $id, ')
          ..write('backgroundUrl: $backgroundUrl, ')
          ..write('backgroundVerticalUrl: $backgroundVerticalUrl, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, AppSettingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
      'value', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(Insertable<AppSettingRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
          _valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppSettingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSettingRow(
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}value'])!,
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class AppSettingRow extends DataClass implements Insertable<AppSettingRow> {
  /// Nom du réglage. Les valeurs vivent dans `MediaPreferenceKind`, jamais en
  /// littéral dispersé.
  final String key;

  /// Valeur **brute**, telle que l'appelant l'a écrite. La conversion vers un
  /// type applicatif se fait à la lecture, avec repli.
  final String value;
  const AppSettingRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(
      key: Value(key),
      value: Value(value),
    );
  }

  factory AppSettingRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSettingRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  AppSettingRow copyWith({String? key, String? value}) => AppSettingRow(
        key: key ?? this.key,
        value: value ?? this.value,
      );
  AppSettingRow copyWithCompanion(AppSettingsCompanion data) {
    return AppSettingRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSettingRow &&
          other.key == this.key &&
          other.value == this.value);
}

class AppSettingsCompanion extends UpdateCompanion<AppSettingRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const AppSettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  })  : key = Value(key),
        value = Value(value);
  static Insertable<AppSettingRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppSettingsCompanion copyWith(
      {Value<String>? key, Value<String>? value, Value<int>? rowid}) {
    return AppSettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DownloadsTable extends Downloads
    with TableInfo<$DownloadsTable, DownloadRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DownloadsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _contentTypeMeta =
      const VerificationMeta('contentType');
  @override
  late final GeneratedColumn<String> contentType = GeneratedColumn<String>(
      'content_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _contentIdMeta =
      const VerificationMeta('contentId');
  @override
  late final GeneratedColumn<String> contentId = GeneratedColumn<String>(
      'content_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _qualityMeta =
      const VerificationMeta('quality');
  @override
  late final GeneratedColumn<String> quality = GeneratedColumn<String>(
      'quality', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  late final GeneratedColumnWithTypeConverter<DownloadState, String> state =
      GeneratedColumn<String>('state', aliasedName, false,
              type: DriftSqlType.string,
              requiredDuringInsert: false,
              defaultValue: Constant(DownloadState.queued.name))
          .withConverter<DownloadState>($DownloadsTable.$converterstate);
  static const VerificationMeta _bytesReceivedMeta =
      const VerificationMeta('bytesReceived');
  @override
  late final GeneratedColumn<int> bytesReceived = GeneratedColumn<int>(
      'bytes_received', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _bytesTotalMeta =
      const VerificationMeta('bytesTotal');
  @override
  late final GeneratedColumn<int> bytesTotal = GeneratedColumn<int>(
      'bytes_total', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _localPathMeta =
      const VerificationMeta('localPath');
  @override
  late final GeneratedColumn<String> localPath = GeneratedColumn<String>(
      'local_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
      'task_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _versionIdMeta =
      const VerificationMeta('versionId');
  @override
  late final GeneratedColumn<String> versionId = GeneratedColumn<String>(
      'version_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _failureReasonMeta =
      const VerificationMeta('failureReason');
  @override
  late final GeneratedColumn<String> failureReason = GeneratedColumn<String>(
      'failure_reason', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        contentType,
        contentId,
        quality,
        state,
        bytesReceived,
        bytesTotal,
        localPath,
        taskId,
        versionId,
        createdAt,
        failureReason
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'downloads';
  @override
  VerificationContext validateIntegrity(Insertable<DownloadRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('content_type')) {
      context.handle(
          _contentTypeMeta,
          contentType.isAcceptableOrUnknown(
              data['content_type']!, _contentTypeMeta));
    } else if (isInserting) {
      context.missing(_contentTypeMeta);
    }
    if (data.containsKey('content_id')) {
      context.handle(_contentIdMeta,
          contentId.isAcceptableOrUnknown(data['content_id']!, _contentIdMeta));
    } else if (isInserting) {
      context.missing(_contentIdMeta);
    }
    if (data.containsKey('quality')) {
      context.handle(_qualityMeta,
          quality.isAcceptableOrUnknown(data['quality']!, _qualityMeta));
    } else if (isInserting) {
      context.missing(_qualityMeta);
    }
    if (data.containsKey('bytes_received')) {
      context.handle(
          _bytesReceivedMeta,
          bytesReceived.isAcceptableOrUnknown(
              data['bytes_received']!, _bytesReceivedMeta));
    }
    if (data.containsKey('bytes_total')) {
      context.handle(
          _bytesTotalMeta,
          bytesTotal.isAcceptableOrUnknown(
              data['bytes_total']!, _bytesTotalMeta));
    }
    if (data.containsKey('local_path')) {
      context.handle(_localPathMeta,
          localPath.isAcceptableOrUnknown(data['local_path']!, _localPathMeta));
    }
    if (data.containsKey('task_id')) {
      context.handle(_taskIdMeta,
          taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta));
    }
    if (data.containsKey('version_id')) {
      context.handle(_versionIdMeta,
          versionId.isAcceptableOrUnknown(data['version_id']!, _versionIdMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('failure_reason')) {
      context.handle(
          _failureReasonMeta,
          failureReason.isAcceptableOrUnknown(
              data['failure_reason']!, _failureReasonMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {contentId};
  @override
  DownloadRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DownloadRow(
      contentType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}content_type'])!,
      contentId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}content_id'])!,
      quality: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}quality'])!,
      state: $DownloadsTable.$converterstate.fromSql(attachedDatabase
          .typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}state'])!),
      bytesReceived: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}bytes_received'])!,
      bytesTotal: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}bytes_total'])!,
      localPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}local_path']),
      taskId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}task_id']),
      versionId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}version_id']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      failureReason: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}failure_reason']),
    );
  }

  @override
  $DownloadsTable createAlias(String alias) {
    return $DownloadsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<DownloadState, String, String> $converterstate =
      const EnumNameConverter<DownloadState>(DownloadState.values);
}

class DownloadRow extends DataClass implements Insertable<DownloadRow> {
  /// `teaching` en v1. Gardé pour rester agnostique au type de contenu (PRD :
  /// brancher les rassemblements ensuite sans refonte).
  final String contentType;

  /// L'UUID du contenu téléchargé — la même identité que dans `teachings`.
  final String contentId;

  /// La qualité **concrète** téléchargée : `low` | `mid` | `high`
  /// ([MediaQuality.key]). Jamais `auto` — le moteur résout le réglage en un
  /// palier concret avant d'écrire ici (le fichier `.aac` en a un).
  final String quality;

  /// L'état courant. Défaut [DownloadState.queued] : une ligne naît en file.
  final DownloadState state;

  /// Octets déjà sur le disque. Alimente le pourcentage et **valide la reprise**
  /// (`Range`) : on ne recolle jamais des octets par-dessus un total inconnu.
  final int bytesReceived;

  /// Taille totale attendue, connue **avant** le réseau (`download.bytes`,
  /// ADR-0038). Sert le pourcentage et le **pré-check d'espace disque** (F9).
  final int bytesTotal;

  /// Chemin du fichier sur l'appareil, résolu par le moteur natif. Nul tant que
  /// la tâche n'a pas commencé à écrire. La lecture offline-first (#191) le lit.
  final String? localPath;

  /// L'identifiant de tâche `background_downloader`. C'est le pont entre cette
  /// ligne et le moteur natif : les rappels de progression/état l'apportent, on
  /// retrouve la ligne par lui. Nul si l'enqueue n'a pas (encore) abouti.
  final String? taskId;

  /// `download.version` au moment du téléchargement — l'identité du transcode.
  /// C'est la comparaison avec la version courante de l'enseignement (livrée par
  /// la sync) qui détecte une **révision** (ADR-0039) et fait passer
  /// [DownloadState.outdated]. La détection elle-même est #194.
  final String? versionId;
  final DateTime createdAt;

  /// Le motif d'échec, quand [state] vaut [DownloadState.failed]. Stocké en
  /// texte (clé stable), l'écran choisit la phrase — comme partout ailleurs, une
  /// erreur ne sort jamais en brut.
  final String? failureReason;
  const DownloadRow(
      {required this.contentType,
      required this.contentId,
      required this.quality,
      required this.state,
      required this.bytesReceived,
      required this.bytesTotal,
      this.localPath,
      this.taskId,
      this.versionId,
      required this.createdAt,
      this.failureReason});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['content_type'] = Variable<String>(contentType);
    map['content_id'] = Variable<String>(contentId);
    map['quality'] = Variable<String>(quality);
    {
      map['state'] =
          Variable<String>($DownloadsTable.$converterstate.toSql(state));
    }
    map['bytes_received'] = Variable<int>(bytesReceived);
    map['bytes_total'] = Variable<int>(bytesTotal);
    if (!nullToAbsent || localPath != null) {
      map['local_path'] = Variable<String>(localPath);
    }
    if (!nullToAbsent || taskId != null) {
      map['task_id'] = Variable<String>(taskId);
    }
    if (!nullToAbsent || versionId != null) {
      map['version_id'] = Variable<String>(versionId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || failureReason != null) {
      map['failure_reason'] = Variable<String>(failureReason);
    }
    return map;
  }

  DownloadsCompanion toCompanion(bool nullToAbsent) {
    return DownloadsCompanion(
      contentType: Value(contentType),
      contentId: Value(contentId),
      quality: Value(quality),
      state: Value(state),
      bytesReceived: Value(bytesReceived),
      bytesTotal: Value(bytesTotal),
      localPath: localPath == null && nullToAbsent
          ? const Value.absent()
          : Value(localPath),
      taskId:
          taskId == null && nullToAbsent ? const Value.absent() : Value(taskId),
      versionId: versionId == null && nullToAbsent
          ? const Value.absent()
          : Value(versionId),
      createdAt: Value(createdAt),
      failureReason: failureReason == null && nullToAbsent
          ? const Value.absent()
          : Value(failureReason),
    );
  }

  factory DownloadRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DownloadRow(
      contentType: serializer.fromJson<String>(json['contentType']),
      contentId: serializer.fromJson<String>(json['contentId']),
      quality: serializer.fromJson<String>(json['quality']),
      state: $DownloadsTable.$converterstate
          .fromJson(serializer.fromJson<String>(json['state'])),
      bytesReceived: serializer.fromJson<int>(json['bytesReceived']),
      bytesTotal: serializer.fromJson<int>(json['bytesTotal']),
      localPath: serializer.fromJson<String?>(json['localPath']),
      taskId: serializer.fromJson<String?>(json['taskId']),
      versionId: serializer.fromJson<String?>(json['versionId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      failureReason: serializer.fromJson<String?>(json['failureReason']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'contentType': serializer.toJson<String>(contentType),
      'contentId': serializer.toJson<String>(contentId),
      'quality': serializer.toJson<String>(quality),
      'state': serializer
          .toJson<String>($DownloadsTable.$converterstate.toJson(state)),
      'bytesReceived': serializer.toJson<int>(bytesReceived),
      'bytesTotal': serializer.toJson<int>(bytesTotal),
      'localPath': serializer.toJson<String?>(localPath),
      'taskId': serializer.toJson<String?>(taskId),
      'versionId': serializer.toJson<String?>(versionId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'failureReason': serializer.toJson<String?>(failureReason),
    };
  }

  DownloadRow copyWith(
          {String? contentType,
          String? contentId,
          String? quality,
          DownloadState? state,
          int? bytesReceived,
          int? bytesTotal,
          Value<String?> localPath = const Value.absent(),
          Value<String?> taskId = const Value.absent(),
          Value<String?> versionId = const Value.absent(),
          DateTime? createdAt,
          Value<String?> failureReason = const Value.absent()}) =>
      DownloadRow(
        contentType: contentType ?? this.contentType,
        contentId: contentId ?? this.contentId,
        quality: quality ?? this.quality,
        state: state ?? this.state,
        bytesReceived: bytesReceived ?? this.bytesReceived,
        bytesTotal: bytesTotal ?? this.bytesTotal,
        localPath: localPath.present ? localPath.value : this.localPath,
        taskId: taskId.present ? taskId.value : this.taskId,
        versionId: versionId.present ? versionId.value : this.versionId,
        createdAt: createdAt ?? this.createdAt,
        failureReason:
            failureReason.present ? failureReason.value : this.failureReason,
      );
  DownloadRow copyWithCompanion(DownloadsCompanion data) {
    return DownloadRow(
      contentType:
          data.contentType.present ? data.contentType.value : this.contentType,
      contentId: data.contentId.present ? data.contentId.value : this.contentId,
      quality: data.quality.present ? data.quality.value : this.quality,
      state: data.state.present ? data.state.value : this.state,
      bytesReceived: data.bytesReceived.present
          ? data.bytesReceived.value
          : this.bytesReceived,
      bytesTotal:
          data.bytesTotal.present ? data.bytesTotal.value : this.bytesTotal,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      versionId: data.versionId.present ? data.versionId.value : this.versionId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      failureReason: data.failureReason.present
          ? data.failureReason.value
          : this.failureReason,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DownloadRow(')
          ..write('contentType: $contentType, ')
          ..write('contentId: $contentId, ')
          ..write('quality: $quality, ')
          ..write('state: $state, ')
          ..write('bytesReceived: $bytesReceived, ')
          ..write('bytesTotal: $bytesTotal, ')
          ..write('localPath: $localPath, ')
          ..write('taskId: $taskId, ')
          ..write('versionId: $versionId, ')
          ..write('createdAt: $createdAt, ')
          ..write('failureReason: $failureReason')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      contentType,
      contentId,
      quality,
      state,
      bytesReceived,
      bytesTotal,
      localPath,
      taskId,
      versionId,
      createdAt,
      failureReason);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DownloadRow &&
          other.contentType == this.contentType &&
          other.contentId == this.contentId &&
          other.quality == this.quality &&
          other.state == this.state &&
          other.bytesReceived == this.bytesReceived &&
          other.bytesTotal == this.bytesTotal &&
          other.localPath == this.localPath &&
          other.taskId == this.taskId &&
          other.versionId == this.versionId &&
          other.createdAt == this.createdAt &&
          other.failureReason == this.failureReason);
}

class DownloadsCompanion extends UpdateCompanion<DownloadRow> {
  final Value<String> contentType;
  final Value<String> contentId;
  final Value<String> quality;
  final Value<DownloadState> state;
  final Value<int> bytesReceived;
  final Value<int> bytesTotal;
  final Value<String?> localPath;
  final Value<String?> taskId;
  final Value<String?> versionId;
  final Value<DateTime> createdAt;
  final Value<String?> failureReason;
  final Value<int> rowid;
  const DownloadsCompanion({
    this.contentType = const Value.absent(),
    this.contentId = const Value.absent(),
    this.quality = const Value.absent(),
    this.state = const Value.absent(),
    this.bytesReceived = const Value.absent(),
    this.bytesTotal = const Value.absent(),
    this.localPath = const Value.absent(),
    this.taskId = const Value.absent(),
    this.versionId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.failureReason = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DownloadsCompanion.insert({
    required String contentType,
    required String contentId,
    required String quality,
    this.state = const Value.absent(),
    this.bytesReceived = const Value.absent(),
    this.bytesTotal = const Value.absent(),
    this.localPath = const Value.absent(),
    this.taskId = const Value.absent(),
    this.versionId = const Value.absent(),
    required DateTime createdAt,
    this.failureReason = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : contentType = Value(contentType),
        contentId = Value(contentId),
        quality = Value(quality),
        createdAt = Value(createdAt);
  static Insertable<DownloadRow> custom({
    Expression<String>? contentType,
    Expression<String>? contentId,
    Expression<String>? quality,
    Expression<String>? state,
    Expression<int>? bytesReceived,
    Expression<int>? bytesTotal,
    Expression<String>? localPath,
    Expression<String>? taskId,
    Expression<String>? versionId,
    Expression<DateTime>? createdAt,
    Expression<String>? failureReason,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (contentType != null) 'content_type': contentType,
      if (contentId != null) 'content_id': contentId,
      if (quality != null) 'quality': quality,
      if (state != null) 'state': state,
      if (bytesReceived != null) 'bytes_received': bytesReceived,
      if (bytesTotal != null) 'bytes_total': bytesTotal,
      if (localPath != null) 'local_path': localPath,
      if (taskId != null) 'task_id': taskId,
      if (versionId != null) 'version_id': versionId,
      if (createdAt != null) 'created_at': createdAt,
      if (failureReason != null) 'failure_reason': failureReason,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DownloadsCompanion copyWith(
      {Value<String>? contentType,
      Value<String>? contentId,
      Value<String>? quality,
      Value<DownloadState>? state,
      Value<int>? bytesReceived,
      Value<int>? bytesTotal,
      Value<String?>? localPath,
      Value<String?>? taskId,
      Value<String?>? versionId,
      Value<DateTime>? createdAt,
      Value<String?>? failureReason,
      Value<int>? rowid}) {
    return DownloadsCompanion(
      contentType: contentType ?? this.contentType,
      contentId: contentId ?? this.contentId,
      quality: quality ?? this.quality,
      state: state ?? this.state,
      bytesReceived: bytesReceived ?? this.bytesReceived,
      bytesTotal: bytesTotal ?? this.bytesTotal,
      localPath: localPath ?? this.localPath,
      taskId: taskId ?? this.taskId,
      versionId: versionId ?? this.versionId,
      createdAt: createdAt ?? this.createdAt,
      failureReason: failureReason ?? this.failureReason,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (contentType.present) {
      map['content_type'] = Variable<String>(contentType.value);
    }
    if (contentId.present) {
      map['content_id'] = Variable<String>(contentId.value);
    }
    if (quality.present) {
      map['quality'] = Variable<String>(quality.value);
    }
    if (state.present) {
      map['state'] =
          Variable<String>($DownloadsTable.$converterstate.toSql(state.value));
    }
    if (bytesReceived.present) {
      map['bytes_received'] = Variable<int>(bytesReceived.value);
    }
    if (bytesTotal.present) {
      map['bytes_total'] = Variable<int>(bytesTotal.value);
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (versionId.present) {
      map['version_id'] = Variable<String>(versionId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (failureReason.present) {
      map['failure_reason'] = Variable<String>(failureReason.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DownloadsCompanion(')
          ..write('contentType: $contentType, ')
          ..write('contentId: $contentId, ')
          ..write('quality: $quality, ')
          ..write('state: $state, ')
          ..write('bytesReceived: $bytesReceived, ')
          ..write('bytesTotal: $bytesTotal, ')
          ..write('localPath: $localPath, ')
          ..write('taskId: $taskId, ')
          ..write('versionId: $versionId, ')
          ..write('createdAt: $createdAt, ')
          ..write('failureReason: $failureReason, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DownloadTitlesTable extends DownloadTitles
    with TableInfo<$DownloadTitlesTable, DownloadTitleRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DownloadTitlesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _contentIdMeta =
      const VerificationMeta('contentId');
  @override
  late final GeneratedColumn<String> contentId = GeneratedColumn<String>(
      'content_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [contentId, title];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'download_titles';
  @override
  VerificationContext validateIntegrity(Insertable<DownloadTitleRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('content_id')) {
      context.handle(_contentIdMeta,
          contentId.isAcceptableOrUnknown(data['content_id']!, _contentIdMeta));
    } else if (isInserting) {
      context.missing(_contentIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {contentId};
  @override
  DownloadTitleRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DownloadTitleRow(
      contentId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}content_id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title']),
    );
  }

  @override
  $DownloadTitlesTable createAlias(String alias) {
    return $DownloadTitlesTable(attachedDatabase, alias);
  }
}

class DownloadTitleRow extends DataClass
    implements Insertable<DownloadTitleRow> {
  /// L'UUID du contenu — la même identité que dans `downloads`.
  final String contentId;

  /// Le titre à afficher. Nullable : un enseignement sans titre connu au moment
  /// du téléchargement le laisse à `NULL`, et la notification se replie alors
  /// sur une phrase générique.
  final String? title;
  const DownloadTitleRow({required this.contentId, this.title});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['content_id'] = Variable<String>(contentId);
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    return map;
  }

  DownloadTitlesCompanion toCompanion(bool nullToAbsent) {
    return DownloadTitlesCompanion(
      contentId: Value(contentId),
      title:
          title == null && nullToAbsent ? const Value.absent() : Value(title),
    );
  }

  factory DownloadTitleRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DownloadTitleRow(
      contentId: serializer.fromJson<String>(json['contentId']),
      title: serializer.fromJson<String?>(json['title']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'contentId': serializer.toJson<String>(contentId),
      'title': serializer.toJson<String?>(title),
    };
  }

  DownloadTitleRow copyWith(
          {String? contentId, Value<String?> title = const Value.absent()}) =>
      DownloadTitleRow(
        contentId: contentId ?? this.contentId,
        title: title.present ? title.value : this.title,
      );
  DownloadTitleRow copyWithCompanion(DownloadTitlesCompanion data) {
    return DownloadTitleRow(
      contentId: data.contentId.present ? data.contentId.value : this.contentId,
      title: data.title.present ? data.title.value : this.title,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DownloadTitleRow(')
          ..write('contentId: $contentId, ')
          ..write('title: $title')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(contentId, title);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DownloadTitleRow &&
          other.contentId == this.contentId &&
          other.title == this.title);
}

class DownloadTitlesCompanion extends UpdateCompanion<DownloadTitleRow> {
  final Value<String> contentId;
  final Value<String?> title;
  final Value<int> rowid;
  const DownloadTitlesCompanion({
    this.contentId = const Value.absent(),
    this.title = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DownloadTitlesCompanion.insert({
    required String contentId,
    this.title = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : contentId = Value(contentId);
  static Insertable<DownloadTitleRow> custom({
    Expression<String>? contentId,
    Expression<String>? title,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (contentId != null) 'content_id': contentId,
      if (title != null) 'title': title,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DownloadTitlesCompanion copyWith(
      {Value<String>? contentId, Value<String?>? title, Value<int>? rowid}) {
    return DownloadTitlesCompanion(
      contentId: contentId ?? this.contentId,
      title: title ?? this.title,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (contentId.present) {
      map['content_id'] = Variable<String>(contentId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DownloadTitlesCompanion(')
          ..write('contentId: $contentId, ')
          ..write('title: $title, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DownloadNotificationsTable extends DownloadNotifications
    with TableInfo<$DownloadNotificationsTable, DownloadNotificationRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DownloadNotificationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _contentIdMeta =
      const VerificationMeta('contentId');
  @override
  late final GeneratedColumn<String> contentId = GeneratedColumn<String>(
      'content_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, contentId, title, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'download_notifications';
  @override
  VerificationContext validateIntegrity(
      Insertable<DownloadNotificationRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('content_id')) {
      context.handle(_contentIdMeta,
          contentId.isAcceptableOrUnknown(data['content_id']!, _contentIdMeta));
    } else if (isInserting) {
      context.missing(_contentIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DownloadNotificationRow map(Map<String, dynamic> data,
      {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DownloadNotificationRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      contentId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}content_id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $DownloadNotificationsTable createAlias(String alias) {
    return $DownloadNotificationsTable(attachedDatabase, alias);
  }
}

class DownloadNotificationRow extends DataClass
    implements Insertable<DownloadNotificationRow> {
  /// Clé technique auto-incrémentée : une notification n'a pas d'identité
  /// métier, et le même contenu pourrait être retiré, re-téléchargé, re-retiré.
  final int id;

  /// L'UUID de l'enseignement retiré — la même identité que dans `downloads`.
  final String contentId;

  /// Le titre à afficher, recopié de la ligne `downloads` purgée. Nullable : un
  /// téléchargement d'avant la dénormalisation (v8) n'en portait pas ; l'écran
  /// se replie alors sur une phrase générique.
  final String? title;
  final DateTime createdAt;
  const DownloadNotificationRow(
      {required this.id,
      required this.contentId,
      this.title,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['content_id'] = Variable<String>(contentId);
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  DownloadNotificationsCompanion toCompanion(bool nullToAbsent) {
    return DownloadNotificationsCompanion(
      id: Value(id),
      contentId: Value(contentId),
      title:
          title == null && nullToAbsent ? const Value.absent() : Value(title),
      createdAt: Value(createdAt),
    );
  }

  factory DownloadNotificationRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DownloadNotificationRow(
      id: serializer.fromJson<int>(json['id']),
      contentId: serializer.fromJson<String>(json['contentId']),
      title: serializer.fromJson<String?>(json['title']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'contentId': serializer.toJson<String>(contentId),
      'title': serializer.toJson<String?>(title),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  DownloadNotificationRow copyWith(
          {int? id,
          String? contentId,
          Value<String?> title = const Value.absent(),
          DateTime? createdAt}) =>
      DownloadNotificationRow(
        id: id ?? this.id,
        contentId: contentId ?? this.contentId,
        title: title.present ? title.value : this.title,
        createdAt: createdAt ?? this.createdAt,
      );
  DownloadNotificationRow copyWithCompanion(
      DownloadNotificationsCompanion data) {
    return DownloadNotificationRow(
      id: data.id.present ? data.id.value : this.id,
      contentId: data.contentId.present ? data.contentId.value : this.contentId,
      title: data.title.present ? data.title.value : this.title,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DownloadNotificationRow(')
          ..write('id: $id, ')
          ..write('contentId: $contentId, ')
          ..write('title: $title, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, contentId, title, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DownloadNotificationRow &&
          other.id == this.id &&
          other.contentId == this.contentId &&
          other.title == this.title &&
          other.createdAt == this.createdAt);
}

class DownloadNotificationsCompanion
    extends UpdateCompanion<DownloadNotificationRow> {
  final Value<int> id;
  final Value<String> contentId;
  final Value<String?> title;
  final Value<DateTime> createdAt;
  const DownloadNotificationsCompanion({
    this.id = const Value.absent(),
    this.contentId = const Value.absent(),
    this.title = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  DownloadNotificationsCompanion.insert({
    this.id = const Value.absent(),
    required String contentId,
    this.title = const Value.absent(),
    required DateTime createdAt,
  })  : contentId = Value(contentId),
        createdAt = Value(createdAt);
  static Insertable<DownloadNotificationRow> custom({
    Expression<int>? id,
    Expression<String>? contentId,
    Expression<String>? title,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (contentId != null) 'content_id': contentId,
      if (title != null) 'title': title,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  DownloadNotificationsCompanion copyWith(
      {Value<int>? id,
      Value<String>? contentId,
      Value<String?>? title,
      Value<DateTime>? createdAt}) {
    return DownloadNotificationsCompanion(
      id: id ?? this.id,
      contentId: contentId ?? this.contentId,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (contentId.present) {
      map['content_id'] = Variable<String>(contentId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DownloadNotificationsCompanion(')
          ..write('id: $id, ')
          ..write('contentId: $contentId, ')
          ..write('title: $title, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SyncCursorsTable syncCursors = $SyncCursorsTable(this);
  late final $SyncStateTable syncState = $SyncStateTable(this);
  late final $ResyncTokensTable resyncTokens = $ResyncTokensTable(this);
  late final $BranchesTable branches = $BranchesTable(this);
  late final $TeachingTypesTable teachingTypes = $TeachingTypesTable(this);
  late final $ContributorsTable contributors = $ContributorsTable(this);
  late final $TeachingsTable teachings = $TeachingsTable(this);
  late final $TeachingGuestsTable teachingGuests = $TeachingGuestsTable(this);
  late final $GatheringTypesTable gatheringTypes = $GatheringTypesTable(this);
  late final $GatheringsTable gatherings = $GatheringsTable(this);
  late final $StatusBackgroundsTable statusBackgrounds =
      $StatusBackgroundsTable(this);
  late final $OfficialAccountsTable officialAccounts =
      $OfficialAccountsTable(this);
  late final $OfficialAccountMembershipsTable officialAccountMemberships =
      $OfficialAccountMembershipsTable(this);
  late final $AnnouncementsTable announcements = $AnnouncementsTable(this);
  late final $PlaybackProgressTable playbackProgress =
      $PlaybackProgressTable(this);
  late final $LocalPlaybackPositionsTable localPlaybackPositions =
      $LocalPlaybackPositionsTable(this);
  late final $LegalDocumentsTable legalDocuments = $LegalDocumentsTable(this);
  late final $SeasonsTable seasons = $SeasonsTable(this);
  late final $PresentationVocabularyTable presentationVocabulary =
      $PresentationVocabularyTable(this);
  late final $DecorTable decor = $DecorTable(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  late final $DownloadsTable downloads = $DownloadsTable(this);
  late final $DownloadTitlesTable downloadTitles = $DownloadTitlesTable(this);
  late final $DownloadNotificationsTable downloadNotifications =
      $DownloadNotificationsTable(this);
  late final SyncDao syncDao = SyncDao(this as AppDatabase);
  late final MediathequeDao mediathequeDao =
      MediathequeDao(this as AppDatabase);
  late final GatheringDao gatheringDao = GatheringDao(this as AppDatabase);
  late final AnnouncementDao announcementDao =
      AnnouncementDao(this as AppDatabase);
  late final PlaybackDao playbackDao = PlaybackDao(this as AppDatabase);
  late final LegalDao legalDao = LegalDao(this as AppDatabase);
  late final SeasonDao seasonDao = SeasonDao(this as AppDatabase);
  late final VocabularyDao vocabularyDao = VocabularyDao(this as AppDatabase);
  late final SettingsDao settingsDao = SettingsDao(this as AppDatabase);
  late final DownloadsDao downloadsDao = DownloadsDao(this as AppDatabase);
  late final DownloadNotificationsDao downloadNotificationsDao =
      DownloadNotificationsDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        syncCursors,
        syncState,
        resyncTokens,
        branches,
        teachingTypes,
        contributors,
        teachings,
        teachingGuests,
        gatheringTypes,
        gatherings,
        statusBackgrounds,
        officialAccounts,
        officialAccountMemberships,
        announcements,
        playbackProgress,
        localPlaybackPositions,
        legalDocuments,
        seasons,
        presentationVocabulary,
        decor,
        appSettings,
        downloads,
        downloadTitles,
        downloadNotifications
      ];
}

typedef $$SyncCursorsTableCreateCompanionBuilder = SyncCursorsCompanion
    Function({
  required String collection,
  Value<String?> cursor,
  required DateTime syncedAt,
  Value<int> rowid,
});
typedef $$SyncCursorsTableUpdateCompanionBuilder = SyncCursorsCompanion
    Function({
  Value<String> collection,
  Value<String?> cursor,
  Value<DateTime> syncedAt,
  Value<int> rowid,
});

class $$SyncCursorsTableFilterComposer
    extends Composer<_$AppDatabase, $SyncCursorsTable> {
  $$SyncCursorsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get collection => $composableBuilder(
      column: $table.collection, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get cursor => $composableBuilder(
      column: $table.cursor, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnFilters(column));
}

class $$SyncCursorsTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncCursorsTable> {
  $$SyncCursorsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get collection => $composableBuilder(
      column: $table.collection, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get cursor => $composableBuilder(
      column: $table.cursor, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnOrderings(column));
}

class $$SyncCursorsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncCursorsTable> {
  $$SyncCursorsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get collection => $composableBuilder(
      column: $table.collection, builder: (column) => column);

  GeneratedColumn<String> get cursor =>
      $composableBuilder(column: $table.cursor, builder: (column) => column);

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);
}

class $$SyncCursorsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SyncCursorsTable,
    SyncCursorRow,
    $$SyncCursorsTableFilterComposer,
    $$SyncCursorsTableOrderingComposer,
    $$SyncCursorsTableAnnotationComposer,
    $$SyncCursorsTableCreateCompanionBuilder,
    $$SyncCursorsTableUpdateCompanionBuilder,
    (
      SyncCursorRow,
      BaseReferences<_$AppDatabase, $SyncCursorsTable, SyncCursorRow>
    ),
    SyncCursorRow,
    PrefetchHooks Function()> {
  $$SyncCursorsTableTableManager(_$AppDatabase db, $SyncCursorsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncCursorsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncCursorsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncCursorsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> collection = const Value.absent(),
            Value<String?> cursor = const Value.absent(),
            Value<DateTime> syncedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SyncCursorsCompanion(
            collection: collection,
            cursor: cursor,
            syncedAt: syncedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String collection,
            Value<String?> cursor = const Value.absent(),
            required DateTime syncedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              SyncCursorsCompanion.insert(
            collection: collection,
            cursor: cursor,
            syncedAt: syncedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SyncCursorsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SyncCursorsTable,
    SyncCursorRow,
    $$SyncCursorsTableFilterComposer,
    $$SyncCursorsTableOrderingComposer,
    $$SyncCursorsTableAnnotationComposer,
    $$SyncCursorsTableCreateCompanionBuilder,
    $$SyncCursorsTableUpdateCompanionBuilder,
    (
      SyncCursorRow,
      BaseReferences<_$AppDatabase, $SyncCursorsTable, SyncCursorRow>
    ),
    SyncCursorRow,
    PrefetchHooks Function()>;
typedef $$SyncStateTableCreateCompanionBuilder = SyncStateCompanion Function({
  Value<int> id,
  Value<int?> scopeVersion,
  Value<int> nextStamp,
});
typedef $$SyncStateTableUpdateCompanionBuilder = SyncStateCompanion Function({
  Value<int> id,
  Value<int?> scopeVersion,
  Value<int> nextStamp,
});

class $$SyncStateTableFilterComposer
    extends Composer<_$AppDatabase, $SyncStateTable> {
  $$SyncStateTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get scopeVersion => $composableBuilder(
      column: $table.scopeVersion, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get nextStamp => $composableBuilder(
      column: $table.nextStamp, builder: (column) => ColumnFilters(column));
}

class $$SyncStateTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncStateTable> {
  $$SyncStateTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get scopeVersion => $composableBuilder(
      column: $table.scopeVersion,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get nextStamp => $composableBuilder(
      column: $table.nextStamp, builder: (column) => ColumnOrderings(column));
}

class $$SyncStateTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncStateTable> {
  $$SyncStateTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get scopeVersion => $composableBuilder(
      column: $table.scopeVersion, builder: (column) => column);

  GeneratedColumn<int> get nextStamp =>
      $composableBuilder(column: $table.nextStamp, builder: (column) => column);
}

class $$SyncStateTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SyncStateTable,
    SyncStateRow,
    $$SyncStateTableFilterComposer,
    $$SyncStateTableOrderingComposer,
    $$SyncStateTableAnnotationComposer,
    $$SyncStateTableCreateCompanionBuilder,
    $$SyncStateTableUpdateCompanionBuilder,
    (
      SyncStateRow,
      BaseReferences<_$AppDatabase, $SyncStateTable, SyncStateRow>
    ),
    SyncStateRow,
    PrefetchHooks Function()> {
  $$SyncStateTableTableManager(_$AppDatabase db, $SyncStateTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncStateTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncStateTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncStateTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int?> scopeVersion = const Value.absent(),
            Value<int> nextStamp = const Value.absent(),
          }) =>
              SyncStateCompanion(
            id: id,
            scopeVersion: scopeVersion,
            nextStamp: nextStamp,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int?> scopeVersion = const Value.absent(),
            Value<int> nextStamp = const Value.absent(),
          }) =>
              SyncStateCompanion.insert(
            id: id,
            scopeVersion: scopeVersion,
            nextStamp: nextStamp,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SyncStateTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SyncStateTable,
    SyncStateRow,
    $$SyncStateTableFilterComposer,
    $$SyncStateTableOrderingComposer,
    $$SyncStateTableAnnotationComposer,
    $$SyncStateTableCreateCompanionBuilder,
    $$SyncStateTableUpdateCompanionBuilder,
    (
      SyncStateRow,
      BaseReferences<_$AppDatabase, $SyncStateTable, SyncStateRow>
    ),
    SyncStateRow,
    PrefetchHooks Function()>;
typedef $$ResyncTokensTableCreateCompanionBuilder = ResyncTokensCompanion
    Function({
  required String collection,
  required int stamp,
  required DateTime startedAt,
  Value<int> rowid,
});
typedef $$ResyncTokensTableUpdateCompanionBuilder = ResyncTokensCompanion
    Function({
  Value<String> collection,
  Value<int> stamp,
  Value<DateTime> startedAt,
  Value<int> rowid,
});

class $$ResyncTokensTableFilterComposer
    extends Composer<_$AppDatabase, $ResyncTokensTable> {
  $$ResyncTokensTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get collection => $composableBuilder(
      column: $table.collection, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get stamp => $composableBuilder(
      column: $table.stamp, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
      column: $table.startedAt, builder: (column) => ColumnFilters(column));
}

class $$ResyncTokensTableOrderingComposer
    extends Composer<_$AppDatabase, $ResyncTokensTable> {
  $$ResyncTokensTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get collection => $composableBuilder(
      column: $table.collection, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get stamp => $composableBuilder(
      column: $table.stamp, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
      column: $table.startedAt, builder: (column) => ColumnOrderings(column));
}

class $$ResyncTokensTableAnnotationComposer
    extends Composer<_$AppDatabase, $ResyncTokensTable> {
  $$ResyncTokensTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get collection => $composableBuilder(
      column: $table.collection, builder: (column) => column);

  GeneratedColumn<int> get stamp =>
      $composableBuilder(column: $table.stamp, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);
}

class $$ResyncTokensTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ResyncTokensTable,
    ResyncTokenRow,
    $$ResyncTokensTableFilterComposer,
    $$ResyncTokensTableOrderingComposer,
    $$ResyncTokensTableAnnotationComposer,
    $$ResyncTokensTableCreateCompanionBuilder,
    $$ResyncTokensTableUpdateCompanionBuilder,
    (
      ResyncTokenRow,
      BaseReferences<_$AppDatabase, $ResyncTokensTable, ResyncTokenRow>
    ),
    ResyncTokenRow,
    PrefetchHooks Function()> {
  $$ResyncTokensTableTableManager(_$AppDatabase db, $ResyncTokensTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ResyncTokensTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ResyncTokensTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ResyncTokensTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> collection = const Value.absent(),
            Value<int> stamp = const Value.absent(),
            Value<DateTime> startedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ResyncTokensCompanion(
            collection: collection,
            stamp: stamp,
            startedAt: startedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String collection,
            required int stamp,
            required DateTime startedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              ResyncTokensCompanion.insert(
            collection: collection,
            stamp: stamp,
            startedAt: startedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ResyncTokensTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ResyncTokensTable,
    ResyncTokenRow,
    $$ResyncTokensTableFilterComposer,
    $$ResyncTokensTableOrderingComposer,
    $$ResyncTokensTableAnnotationComposer,
    $$ResyncTokensTableCreateCompanionBuilder,
    $$ResyncTokensTableUpdateCompanionBuilder,
    (
      ResyncTokenRow,
      BaseReferences<_$AppDatabase, $ResyncTokensTable, ResyncTokenRow>
    ),
    ResyncTokenRow,
    PrefetchHooks Function()>;
typedef $$BranchesTableCreateCompanionBuilder = BranchesCompanion Function({
  Value<int> syncStamp,
  Value<int> id,
  required String name,
  Value<bool> isMotherChurch,
  Value<String?> address,
  Value<String?> email,
  Value<String?> phone,
  Value<String?> postalBox,
  Value<DateTime?> createdAt,
  Value<DateTime?> updatedAt,
});
typedef $$BranchesTableUpdateCompanionBuilder = BranchesCompanion Function({
  Value<int> syncStamp,
  Value<int> id,
  Value<String> name,
  Value<bool> isMotherChurch,
  Value<String?> address,
  Value<String?> email,
  Value<String?> phone,
  Value<String?> postalBox,
  Value<DateTime?> createdAt,
  Value<DateTime?> updatedAt,
});

class $$BranchesTableFilterComposer
    extends Composer<_$AppDatabase, $BranchesTable> {
  $$BranchesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get syncStamp => $composableBuilder(
      column: $table.syncStamp, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isMotherChurch => $composableBuilder(
      column: $table.isMotherChurch,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get address => $composableBuilder(
      column: $table.address, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get email => $composableBuilder(
      column: $table.email, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get phone => $composableBuilder(
      column: $table.phone, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get postalBox => $composableBuilder(
      column: $table.postalBox, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$BranchesTableOrderingComposer
    extends Composer<_$AppDatabase, $BranchesTable> {
  $$BranchesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get syncStamp => $composableBuilder(
      column: $table.syncStamp, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isMotherChurch => $composableBuilder(
      column: $table.isMotherChurch,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get address => $composableBuilder(
      column: $table.address, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get email => $composableBuilder(
      column: $table.email, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get phone => $composableBuilder(
      column: $table.phone, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get postalBox => $composableBuilder(
      column: $table.postalBox, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$BranchesTableAnnotationComposer
    extends Composer<_$AppDatabase, $BranchesTable> {
  $$BranchesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get syncStamp =>
      $composableBuilder(column: $table.syncStamp, builder: (column) => column);

  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<bool> get isMotherChurch => $composableBuilder(
      column: $table.isMotherChurch, builder: (column) => column);

  GeneratedColumn<String> get address =>
      $composableBuilder(column: $table.address, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get postalBox =>
      $composableBuilder(column: $table.postalBox, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$BranchesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $BranchesTable,
    BranchRow,
    $$BranchesTableFilterComposer,
    $$BranchesTableOrderingComposer,
    $$BranchesTableAnnotationComposer,
    $$BranchesTableCreateCompanionBuilder,
    $$BranchesTableUpdateCompanionBuilder,
    (BranchRow, BaseReferences<_$AppDatabase, $BranchesTable, BranchRow>),
    BranchRow,
    PrefetchHooks Function()> {
  $$BranchesTableTableManager(_$AppDatabase db, $BranchesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BranchesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BranchesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BranchesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> syncStamp = const Value.absent(),
            Value<int> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<bool> isMotherChurch = const Value.absent(),
            Value<String?> address = const Value.absent(),
            Value<String?> email = const Value.absent(),
            Value<String?> phone = const Value.absent(),
            Value<String?> postalBox = const Value.absent(),
            Value<DateTime?> createdAt = const Value.absent(),
            Value<DateTime?> updatedAt = const Value.absent(),
          }) =>
              BranchesCompanion(
            syncStamp: syncStamp,
            id: id,
            name: name,
            isMotherChurch: isMotherChurch,
            address: address,
            email: email,
            phone: phone,
            postalBox: postalBox,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> syncStamp = const Value.absent(),
            Value<int> id = const Value.absent(),
            required String name,
            Value<bool> isMotherChurch = const Value.absent(),
            Value<String?> address = const Value.absent(),
            Value<String?> email = const Value.absent(),
            Value<String?> phone = const Value.absent(),
            Value<String?> postalBox = const Value.absent(),
            Value<DateTime?> createdAt = const Value.absent(),
            Value<DateTime?> updatedAt = const Value.absent(),
          }) =>
              BranchesCompanion.insert(
            syncStamp: syncStamp,
            id: id,
            name: name,
            isMotherChurch: isMotherChurch,
            address: address,
            email: email,
            phone: phone,
            postalBox: postalBox,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$BranchesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $BranchesTable,
    BranchRow,
    $$BranchesTableFilterComposer,
    $$BranchesTableOrderingComposer,
    $$BranchesTableAnnotationComposer,
    $$BranchesTableCreateCompanionBuilder,
    $$BranchesTableUpdateCompanionBuilder,
    (BranchRow, BaseReferences<_$AppDatabase, $BranchesTable, BranchRow>),
    BranchRow,
    PrefetchHooks Function()>;
typedef $$TeachingTypesTableCreateCompanionBuilder = TeachingTypesCompanion
    Function({
  Value<int> syncStamp,
  Value<int> id,
  required Map<String, String> label,
  required String slug,
  Value<String?> icon,
  Value<String?> color,
  Value<int> position,
  Value<bool> visibleOnHome,
  Value<String?> layout,
  Value<DateTime?> createdAt,
  Value<DateTime?> updatedAt,
});
typedef $$TeachingTypesTableUpdateCompanionBuilder = TeachingTypesCompanion
    Function({
  Value<int> syncStamp,
  Value<int> id,
  Value<Map<String, String>> label,
  Value<String> slug,
  Value<String?> icon,
  Value<String?> color,
  Value<int> position,
  Value<bool> visibleOnHome,
  Value<String?> layout,
  Value<DateTime?> createdAt,
  Value<DateTime?> updatedAt,
});

class $$TeachingTypesTableFilterComposer
    extends Composer<_$AppDatabase, $TeachingTypesTable> {
  $$TeachingTypesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get syncStamp => $composableBuilder(
      column: $table.syncStamp, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<Map<String, String>, Map<String, String>,
          String>
      get label => $composableBuilder(
          column: $table.label,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<String> get slug => $composableBuilder(
      column: $table.slug, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get icon => $composableBuilder(
      column: $table.icon, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get color => $composableBuilder(
      column: $table.color, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get position => $composableBuilder(
      column: $table.position, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get visibleOnHome => $composableBuilder(
      column: $table.visibleOnHome, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get layout => $composableBuilder(
      column: $table.layout, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$TeachingTypesTableOrderingComposer
    extends Composer<_$AppDatabase, $TeachingTypesTable> {
  $$TeachingTypesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get syncStamp => $composableBuilder(
      column: $table.syncStamp, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get label => $composableBuilder(
      column: $table.label, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get slug => $composableBuilder(
      column: $table.slug, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get icon => $composableBuilder(
      column: $table.icon, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get color => $composableBuilder(
      column: $table.color, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get position => $composableBuilder(
      column: $table.position, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get visibleOnHome => $composableBuilder(
      column: $table.visibleOnHome,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get layout => $composableBuilder(
      column: $table.layout, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$TeachingTypesTableAnnotationComposer
    extends Composer<_$AppDatabase, $TeachingTypesTable> {
  $$TeachingTypesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get syncStamp =>
      $composableBuilder(column: $table.syncStamp, builder: (column) => column);

  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Map<String, String>, String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<String> get slug =>
      $composableBuilder(column: $table.slug, builder: (column) => column);

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<bool> get visibleOnHome => $composableBuilder(
      column: $table.visibleOnHome, builder: (column) => column);

  GeneratedColumn<String> get layout =>
      $composableBuilder(column: $table.layout, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$TeachingTypesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $TeachingTypesTable,
    TeachingTypeRow,
    $$TeachingTypesTableFilterComposer,
    $$TeachingTypesTableOrderingComposer,
    $$TeachingTypesTableAnnotationComposer,
    $$TeachingTypesTableCreateCompanionBuilder,
    $$TeachingTypesTableUpdateCompanionBuilder,
    (
      TeachingTypeRow,
      BaseReferences<_$AppDatabase, $TeachingTypesTable, TeachingTypeRow>
    ),
    TeachingTypeRow,
    PrefetchHooks Function()> {
  $$TeachingTypesTableTableManager(_$AppDatabase db, $TeachingTypesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TeachingTypesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TeachingTypesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TeachingTypesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> syncStamp = const Value.absent(),
            Value<int> id = const Value.absent(),
            Value<Map<String, String>> label = const Value.absent(),
            Value<String> slug = const Value.absent(),
            Value<String?> icon = const Value.absent(),
            Value<String?> color = const Value.absent(),
            Value<int> position = const Value.absent(),
            Value<bool> visibleOnHome = const Value.absent(),
            Value<String?> layout = const Value.absent(),
            Value<DateTime?> createdAt = const Value.absent(),
            Value<DateTime?> updatedAt = const Value.absent(),
          }) =>
              TeachingTypesCompanion(
            syncStamp: syncStamp,
            id: id,
            label: label,
            slug: slug,
            icon: icon,
            color: color,
            position: position,
            visibleOnHome: visibleOnHome,
            layout: layout,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> syncStamp = const Value.absent(),
            Value<int> id = const Value.absent(),
            required Map<String, String> label,
            required String slug,
            Value<String?> icon = const Value.absent(),
            Value<String?> color = const Value.absent(),
            Value<int> position = const Value.absent(),
            Value<bool> visibleOnHome = const Value.absent(),
            Value<String?> layout = const Value.absent(),
            Value<DateTime?> createdAt = const Value.absent(),
            Value<DateTime?> updatedAt = const Value.absent(),
          }) =>
              TeachingTypesCompanion.insert(
            syncStamp: syncStamp,
            id: id,
            label: label,
            slug: slug,
            icon: icon,
            color: color,
            position: position,
            visibleOnHome: visibleOnHome,
            layout: layout,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$TeachingTypesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $TeachingTypesTable,
    TeachingTypeRow,
    $$TeachingTypesTableFilterComposer,
    $$TeachingTypesTableOrderingComposer,
    $$TeachingTypesTableAnnotationComposer,
    $$TeachingTypesTableCreateCompanionBuilder,
    $$TeachingTypesTableUpdateCompanionBuilder,
    (
      TeachingTypeRow,
      BaseReferences<_$AppDatabase, $TeachingTypesTable, TeachingTypeRow>
    ),
    TeachingTypeRow,
    PrefetchHooks Function()>;
typedef $$ContributorsTableCreateCompanionBuilder = ContributorsCompanion
    Function({
  Value<int> syncStamp,
  Value<int> id,
  required String name,
  Value<String?> bio,
  Value<DateTime?> createdAt,
  Value<DateTime?> updatedAt,
});
typedef $$ContributorsTableUpdateCompanionBuilder = ContributorsCompanion
    Function({
  Value<int> syncStamp,
  Value<int> id,
  Value<String> name,
  Value<String?> bio,
  Value<DateTime?> createdAt,
  Value<DateTime?> updatedAt,
});

class $$ContributorsTableFilterComposer
    extends Composer<_$AppDatabase, $ContributorsTable> {
  $$ContributorsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get syncStamp => $composableBuilder(
      column: $table.syncStamp, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get bio => $composableBuilder(
      column: $table.bio, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$ContributorsTableOrderingComposer
    extends Composer<_$AppDatabase, $ContributorsTable> {
  $$ContributorsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get syncStamp => $composableBuilder(
      column: $table.syncStamp, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get bio => $composableBuilder(
      column: $table.bio, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$ContributorsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ContributorsTable> {
  $$ContributorsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get syncStamp =>
      $composableBuilder(column: $table.syncStamp, builder: (column) => column);

  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get bio =>
      $composableBuilder(column: $table.bio, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ContributorsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ContributorsTable,
    ContributorRow,
    $$ContributorsTableFilterComposer,
    $$ContributorsTableOrderingComposer,
    $$ContributorsTableAnnotationComposer,
    $$ContributorsTableCreateCompanionBuilder,
    $$ContributorsTableUpdateCompanionBuilder,
    (
      ContributorRow,
      BaseReferences<_$AppDatabase, $ContributorsTable, ContributorRow>
    ),
    ContributorRow,
    PrefetchHooks Function()> {
  $$ContributorsTableTableManager(_$AppDatabase db, $ContributorsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ContributorsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ContributorsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ContributorsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> syncStamp = const Value.absent(),
            Value<int> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> bio = const Value.absent(),
            Value<DateTime?> createdAt = const Value.absent(),
            Value<DateTime?> updatedAt = const Value.absent(),
          }) =>
              ContributorsCompanion(
            syncStamp: syncStamp,
            id: id,
            name: name,
            bio: bio,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> syncStamp = const Value.absent(),
            Value<int> id = const Value.absent(),
            required String name,
            Value<String?> bio = const Value.absent(),
            Value<DateTime?> createdAt = const Value.absent(),
            Value<DateTime?> updatedAt = const Value.absent(),
          }) =>
              ContributorsCompanion.insert(
            syncStamp: syncStamp,
            id: id,
            name: name,
            bio: bio,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ContributorsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ContributorsTable,
    ContributorRow,
    $$ContributorsTableFilterComposer,
    $$ContributorsTableOrderingComposer,
    $$ContributorsTableAnnotationComposer,
    $$ContributorsTableCreateCompanionBuilder,
    $$ContributorsTableUpdateCompanionBuilder,
    (
      ContributorRow,
      BaseReferences<_$AppDatabase, $ContributorsTable, ContributorRow>
    ),
    ContributorRow,
    PrefetchHooks Function()>;
typedef $$TeachingsTableCreateCompanionBuilder = TeachingsCompanion Function({
  Value<int> syncStamp,
  required String id,
  Value<String?> ownerId,
  Value<int?> branchId,
  Value<int?> contributorId,
  Value<int?> teachingTypeId,
  required String title,
  Value<String?> description,
  Value<bool> isLive,
  Value<bool> isFullService,
  Value<String?> playlistUrl,
  Value<TeachingDownload?> download,
  Value<String?> imageLandscapeUrl,
  Value<String?> imagePortraitUrl,
  Value<String?> imageSquareUrl,
  Value<DateTime?> publishedAt,
  Value<DateTime?> clientCreatedAt,
  Value<DateTime?> createdAt,
  Value<DateTime?> updatedAt,
  Value<String?> recordedAt,
  Value<String?> color,
  Value<int> rowid,
});
typedef $$TeachingsTableUpdateCompanionBuilder = TeachingsCompanion Function({
  Value<int> syncStamp,
  Value<String> id,
  Value<String?> ownerId,
  Value<int?> branchId,
  Value<int?> contributorId,
  Value<int?> teachingTypeId,
  Value<String> title,
  Value<String?> description,
  Value<bool> isLive,
  Value<bool> isFullService,
  Value<String?> playlistUrl,
  Value<TeachingDownload?> download,
  Value<String?> imageLandscapeUrl,
  Value<String?> imagePortraitUrl,
  Value<String?> imageSquareUrl,
  Value<DateTime?> publishedAt,
  Value<DateTime?> clientCreatedAt,
  Value<DateTime?> createdAt,
  Value<DateTime?> updatedAt,
  Value<String?> recordedAt,
  Value<String?> color,
  Value<int> rowid,
});

class $$TeachingsTableFilterComposer
    extends Composer<_$AppDatabase, $TeachingsTable> {
  $$TeachingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get syncStamp => $composableBuilder(
      column: $table.syncStamp, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get ownerId => $composableBuilder(
      column: $table.ownerId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get branchId => $composableBuilder(
      column: $table.branchId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get contributorId => $composableBuilder(
      column: $table.contributorId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get teachingTypeId => $composableBuilder(
      column: $table.teachingTypeId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isLive => $composableBuilder(
      column: $table.isLive, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isFullService => $composableBuilder(
      column: $table.isFullService, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get playlistUrl => $composableBuilder(
      column: $table.playlistUrl, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<TeachingDownload?, TeachingDownload, String>
      get download => $composableBuilder(
          column: $table.download,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<String> get imageLandscapeUrl => $composableBuilder(
      column: $table.imageLandscapeUrl,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get imagePortraitUrl => $composableBuilder(
      column: $table.imagePortraitUrl,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get imageSquareUrl => $composableBuilder(
      column: $table.imageSquareUrl,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get publishedAt => $composableBuilder(
      column: $table.publishedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get clientCreatedAt => $composableBuilder(
      column: $table.clientCreatedAt,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get recordedAt => $composableBuilder(
      column: $table.recordedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get color => $composableBuilder(
      column: $table.color, builder: (column) => ColumnFilters(column));
}

class $$TeachingsTableOrderingComposer
    extends Composer<_$AppDatabase, $TeachingsTable> {
  $$TeachingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get syncStamp => $composableBuilder(
      column: $table.syncStamp, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get ownerId => $composableBuilder(
      column: $table.ownerId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get branchId => $composableBuilder(
      column: $table.branchId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get contributorId => $composableBuilder(
      column: $table.contributorId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get teachingTypeId => $composableBuilder(
      column: $table.teachingTypeId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isLive => $composableBuilder(
      column: $table.isLive, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isFullService => $composableBuilder(
      column: $table.isFullService,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get playlistUrl => $composableBuilder(
      column: $table.playlistUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get download => $composableBuilder(
      column: $table.download, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get imageLandscapeUrl => $composableBuilder(
      column: $table.imageLandscapeUrl,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get imagePortraitUrl => $composableBuilder(
      column: $table.imagePortraitUrl,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get imageSquareUrl => $composableBuilder(
      column: $table.imageSquareUrl,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get publishedAt => $composableBuilder(
      column: $table.publishedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get clientCreatedAt => $composableBuilder(
      column: $table.clientCreatedAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get recordedAt => $composableBuilder(
      column: $table.recordedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get color => $composableBuilder(
      column: $table.color, builder: (column) => ColumnOrderings(column));
}

class $$TeachingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TeachingsTable> {
  $$TeachingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get syncStamp =>
      $composableBuilder(column: $table.syncStamp, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<int> get branchId =>
      $composableBuilder(column: $table.branchId, builder: (column) => column);

  GeneratedColumn<int> get contributorId => $composableBuilder(
      column: $table.contributorId, builder: (column) => column);

  GeneratedColumn<int> get teachingTypeId => $composableBuilder(
      column: $table.teachingTypeId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<bool> get isLive =>
      $composableBuilder(column: $table.isLive, builder: (column) => column);

  GeneratedColumn<bool> get isFullService => $composableBuilder(
      column: $table.isFullService, builder: (column) => column);

  GeneratedColumn<String> get playlistUrl => $composableBuilder(
      column: $table.playlistUrl, builder: (column) => column);

  GeneratedColumnWithTypeConverter<TeachingDownload?, String> get download =>
      $composableBuilder(column: $table.download, builder: (column) => column);

  GeneratedColumn<String> get imageLandscapeUrl => $composableBuilder(
      column: $table.imageLandscapeUrl, builder: (column) => column);

  GeneratedColumn<String> get imagePortraitUrl => $composableBuilder(
      column: $table.imagePortraitUrl, builder: (column) => column);

  GeneratedColumn<String> get imageSquareUrl => $composableBuilder(
      column: $table.imageSquareUrl, builder: (column) => column);

  GeneratedColumn<DateTime> get publishedAt => $composableBuilder(
      column: $table.publishedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get clientCreatedAt => $composableBuilder(
      column: $table.clientCreatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get recordedAt => $composableBuilder(
      column: $table.recordedAt, builder: (column) => column);

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);
}

class $$TeachingsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $TeachingsTable,
    TeachingRow,
    $$TeachingsTableFilterComposer,
    $$TeachingsTableOrderingComposer,
    $$TeachingsTableAnnotationComposer,
    $$TeachingsTableCreateCompanionBuilder,
    $$TeachingsTableUpdateCompanionBuilder,
    (TeachingRow, BaseReferences<_$AppDatabase, $TeachingsTable, TeachingRow>),
    TeachingRow,
    PrefetchHooks Function()> {
  $$TeachingsTableTableManager(_$AppDatabase db, $TeachingsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TeachingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TeachingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TeachingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> syncStamp = const Value.absent(),
            Value<String> id = const Value.absent(),
            Value<String?> ownerId = const Value.absent(),
            Value<int?> branchId = const Value.absent(),
            Value<int?> contributorId = const Value.absent(),
            Value<int?> teachingTypeId = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<bool> isLive = const Value.absent(),
            Value<bool> isFullService = const Value.absent(),
            Value<String?> playlistUrl = const Value.absent(),
            Value<TeachingDownload?> download = const Value.absent(),
            Value<String?> imageLandscapeUrl = const Value.absent(),
            Value<String?> imagePortraitUrl = const Value.absent(),
            Value<String?> imageSquareUrl = const Value.absent(),
            Value<DateTime?> publishedAt = const Value.absent(),
            Value<DateTime?> clientCreatedAt = const Value.absent(),
            Value<DateTime?> createdAt = const Value.absent(),
            Value<DateTime?> updatedAt = const Value.absent(),
            Value<String?> recordedAt = const Value.absent(),
            Value<String?> color = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TeachingsCompanion(
            syncStamp: syncStamp,
            id: id,
            ownerId: ownerId,
            branchId: branchId,
            contributorId: contributorId,
            teachingTypeId: teachingTypeId,
            title: title,
            description: description,
            isLive: isLive,
            isFullService: isFullService,
            playlistUrl: playlistUrl,
            download: download,
            imageLandscapeUrl: imageLandscapeUrl,
            imagePortraitUrl: imagePortraitUrl,
            imageSquareUrl: imageSquareUrl,
            publishedAt: publishedAt,
            clientCreatedAt: clientCreatedAt,
            createdAt: createdAt,
            updatedAt: updatedAt,
            recordedAt: recordedAt,
            color: color,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            Value<int> syncStamp = const Value.absent(),
            required String id,
            Value<String?> ownerId = const Value.absent(),
            Value<int?> branchId = const Value.absent(),
            Value<int?> contributorId = const Value.absent(),
            Value<int?> teachingTypeId = const Value.absent(),
            required String title,
            Value<String?> description = const Value.absent(),
            Value<bool> isLive = const Value.absent(),
            Value<bool> isFullService = const Value.absent(),
            Value<String?> playlistUrl = const Value.absent(),
            Value<TeachingDownload?> download = const Value.absent(),
            Value<String?> imageLandscapeUrl = const Value.absent(),
            Value<String?> imagePortraitUrl = const Value.absent(),
            Value<String?> imageSquareUrl = const Value.absent(),
            Value<DateTime?> publishedAt = const Value.absent(),
            Value<DateTime?> clientCreatedAt = const Value.absent(),
            Value<DateTime?> createdAt = const Value.absent(),
            Value<DateTime?> updatedAt = const Value.absent(),
            Value<String?> recordedAt = const Value.absent(),
            Value<String?> color = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TeachingsCompanion.insert(
            syncStamp: syncStamp,
            id: id,
            ownerId: ownerId,
            branchId: branchId,
            contributorId: contributorId,
            teachingTypeId: teachingTypeId,
            title: title,
            description: description,
            isLive: isLive,
            isFullService: isFullService,
            playlistUrl: playlistUrl,
            download: download,
            imageLandscapeUrl: imageLandscapeUrl,
            imagePortraitUrl: imagePortraitUrl,
            imageSquareUrl: imageSquareUrl,
            publishedAt: publishedAt,
            clientCreatedAt: clientCreatedAt,
            createdAt: createdAt,
            updatedAt: updatedAt,
            recordedAt: recordedAt,
            color: color,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$TeachingsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $TeachingsTable,
    TeachingRow,
    $$TeachingsTableFilterComposer,
    $$TeachingsTableOrderingComposer,
    $$TeachingsTableAnnotationComposer,
    $$TeachingsTableCreateCompanionBuilder,
    $$TeachingsTableUpdateCompanionBuilder,
    (TeachingRow, BaseReferences<_$AppDatabase, $TeachingsTable, TeachingRow>),
    TeachingRow,
    PrefetchHooks Function()>;
typedef $$TeachingGuestsTableCreateCompanionBuilder = TeachingGuestsCompanion
    Function({
  Value<int> syncStamp,
  Value<int> id,
  required String teachingId,
  required int contributorId,
  Value<int> position,
  Value<DateTime?> createdAt,
  Value<DateTime?> updatedAt,
});
typedef $$TeachingGuestsTableUpdateCompanionBuilder = TeachingGuestsCompanion
    Function({
  Value<int> syncStamp,
  Value<int> id,
  Value<String> teachingId,
  Value<int> contributorId,
  Value<int> position,
  Value<DateTime?> createdAt,
  Value<DateTime?> updatedAt,
});

class $$TeachingGuestsTableFilterComposer
    extends Composer<_$AppDatabase, $TeachingGuestsTable> {
  $$TeachingGuestsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get syncStamp => $composableBuilder(
      column: $table.syncStamp, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get teachingId => $composableBuilder(
      column: $table.teachingId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get contributorId => $composableBuilder(
      column: $table.contributorId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get position => $composableBuilder(
      column: $table.position, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$TeachingGuestsTableOrderingComposer
    extends Composer<_$AppDatabase, $TeachingGuestsTable> {
  $$TeachingGuestsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get syncStamp => $composableBuilder(
      column: $table.syncStamp, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get teachingId => $composableBuilder(
      column: $table.teachingId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get contributorId => $composableBuilder(
      column: $table.contributorId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get position => $composableBuilder(
      column: $table.position, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$TeachingGuestsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TeachingGuestsTable> {
  $$TeachingGuestsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get syncStamp =>
      $composableBuilder(column: $table.syncStamp, builder: (column) => column);

  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get teachingId => $composableBuilder(
      column: $table.teachingId, builder: (column) => column);

  GeneratedColumn<int> get contributorId => $composableBuilder(
      column: $table.contributorId, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$TeachingGuestsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $TeachingGuestsTable,
    TeachingGuestRow,
    $$TeachingGuestsTableFilterComposer,
    $$TeachingGuestsTableOrderingComposer,
    $$TeachingGuestsTableAnnotationComposer,
    $$TeachingGuestsTableCreateCompanionBuilder,
    $$TeachingGuestsTableUpdateCompanionBuilder,
    (
      TeachingGuestRow,
      BaseReferences<_$AppDatabase, $TeachingGuestsTable, TeachingGuestRow>
    ),
    TeachingGuestRow,
    PrefetchHooks Function()> {
  $$TeachingGuestsTableTableManager(
      _$AppDatabase db, $TeachingGuestsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TeachingGuestsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TeachingGuestsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TeachingGuestsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> syncStamp = const Value.absent(),
            Value<int> id = const Value.absent(),
            Value<String> teachingId = const Value.absent(),
            Value<int> contributorId = const Value.absent(),
            Value<int> position = const Value.absent(),
            Value<DateTime?> createdAt = const Value.absent(),
            Value<DateTime?> updatedAt = const Value.absent(),
          }) =>
              TeachingGuestsCompanion(
            syncStamp: syncStamp,
            id: id,
            teachingId: teachingId,
            contributorId: contributorId,
            position: position,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> syncStamp = const Value.absent(),
            Value<int> id = const Value.absent(),
            required String teachingId,
            required int contributorId,
            Value<int> position = const Value.absent(),
            Value<DateTime?> createdAt = const Value.absent(),
            Value<DateTime?> updatedAt = const Value.absent(),
          }) =>
              TeachingGuestsCompanion.insert(
            syncStamp: syncStamp,
            id: id,
            teachingId: teachingId,
            contributorId: contributorId,
            position: position,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$TeachingGuestsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $TeachingGuestsTable,
    TeachingGuestRow,
    $$TeachingGuestsTableFilterComposer,
    $$TeachingGuestsTableOrderingComposer,
    $$TeachingGuestsTableAnnotationComposer,
    $$TeachingGuestsTableCreateCompanionBuilder,
    $$TeachingGuestsTableUpdateCompanionBuilder,
    (
      TeachingGuestRow,
      BaseReferences<_$AppDatabase, $TeachingGuestsTable, TeachingGuestRow>
    ),
    TeachingGuestRow,
    PrefetchHooks Function()>;
typedef $$GatheringTypesTableCreateCompanionBuilder = GatheringTypesCompanion
    Function({
  Value<int> syncStamp,
  Value<int> id,
  required Map<String, String> label,
  required String slug,
  Value<String?> icon,
  Value<String?> color,
  Value<int> position,
  Value<bool> visibleOnHome,
  Value<String?> layout,
  Value<DateTime?> createdAt,
  Value<DateTime?> updatedAt,
});
typedef $$GatheringTypesTableUpdateCompanionBuilder = GatheringTypesCompanion
    Function({
  Value<int> syncStamp,
  Value<int> id,
  Value<Map<String, String>> label,
  Value<String> slug,
  Value<String?> icon,
  Value<String?> color,
  Value<int> position,
  Value<bool> visibleOnHome,
  Value<String?> layout,
  Value<DateTime?> createdAt,
  Value<DateTime?> updatedAt,
});

class $$GatheringTypesTableFilterComposer
    extends Composer<_$AppDatabase, $GatheringTypesTable> {
  $$GatheringTypesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get syncStamp => $composableBuilder(
      column: $table.syncStamp, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<Map<String, String>, Map<String, String>,
          String>
      get label => $composableBuilder(
          column: $table.label,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<String> get slug => $composableBuilder(
      column: $table.slug, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get icon => $composableBuilder(
      column: $table.icon, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get color => $composableBuilder(
      column: $table.color, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get position => $composableBuilder(
      column: $table.position, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get visibleOnHome => $composableBuilder(
      column: $table.visibleOnHome, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get layout => $composableBuilder(
      column: $table.layout, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$GatheringTypesTableOrderingComposer
    extends Composer<_$AppDatabase, $GatheringTypesTable> {
  $$GatheringTypesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get syncStamp => $composableBuilder(
      column: $table.syncStamp, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get label => $composableBuilder(
      column: $table.label, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get slug => $composableBuilder(
      column: $table.slug, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get icon => $composableBuilder(
      column: $table.icon, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get color => $composableBuilder(
      column: $table.color, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get position => $composableBuilder(
      column: $table.position, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get visibleOnHome => $composableBuilder(
      column: $table.visibleOnHome,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get layout => $composableBuilder(
      column: $table.layout, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$GatheringTypesTableAnnotationComposer
    extends Composer<_$AppDatabase, $GatheringTypesTable> {
  $$GatheringTypesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get syncStamp =>
      $composableBuilder(column: $table.syncStamp, builder: (column) => column);

  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Map<String, String>, String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<String> get slug =>
      $composableBuilder(column: $table.slug, builder: (column) => column);

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<bool> get visibleOnHome => $composableBuilder(
      column: $table.visibleOnHome, builder: (column) => column);

  GeneratedColumn<String> get layout =>
      $composableBuilder(column: $table.layout, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$GatheringTypesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $GatheringTypesTable,
    GatheringTypeRow,
    $$GatheringTypesTableFilterComposer,
    $$GatheringTypesTableOrderingComposer,
    $$GatheringTypesTableAnnotationComposer,
    $$GatheringTypesTableCreateCompanionBuilder,
    $$GatheringTypesTableUpdateCompanionBuilder,
    (
      GatheringTypeRow,
      BaseReferences<_$AppDatabase, $GatheringTypesTable, GatheringTypeRow>
    ),
    GatheringTypeRow,
    PrefetchHooks Function()> {
  $$GatheringTypesTableTableManager(
      _$AppDatabase db, $GatheringTypesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GatheringTypesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GatheringTypesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GatheringTypesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> syncStamp = const Value.absent(),
            Value<int> id = const Value.absent(),
            Value<Map<String, String>> label = const Value.absent(),
            Value<String> slug = const Value.absent(),
            Value<String?> icon = const Value.absent(),
            Value<String?> color = const Value.absent(),
            Value<int> position = const Value.absent(),
            Value<bool> visibleOnHome = const Value.absent(),
            Value<String?> layout = const Value.absent(),
            Value<DateTime?> createdAt = const Value.absent(),
            Value<DateTime?> updatedAt = const Value.absent(),
          }) =>
              GatheringTypesCompanion(
            syncStamp: syncStamp,
            id: id,
            label: label,
            slug: slug,
            icon: icon,
            color: color,
            position: position,
            visibleOnHome: visibleOnHome,
            layout: layout,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> syncStamp = const Value.absent(),
            Value<int> id = const Value.absent(),
            required Map<String, String> label,
            required String slug,
            Value<String?> icon = const Value.absent(),
            Value<String?> color = const Value.absent(),
            Value<int> position = const Value.absent(),
            Value<bool> visibleOnHome = const Value.absent(),
            Value<String?> layout = const Value.absent(),
            Value<DateTime?> createdAt = const Value.absent(),
            Value<DateTime?> updatedAt = const Value.absent(),
          }) =>
              GatheringTypesCompanion.insert(
            syncStamp: syncStamp,
            id: id,
            label: label,
            slug: slug,
            icon: icon,
            color: color,
            position: position,
            visibleOnHome: visibleOnHome,
            layout: layout,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$GatheringTypesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $GatheringTypesTable,
    GatheringTypeRow,
    $$GatheringTypesTableFilterComposer,
    $$GatheringTypesTableOrderingComposer,
    $$GatheringTypesTableAnnotationComposer,
    $$GatheringTypesTableCreateCompanionBuilder,
    $$GatheringTypesTableUpdateCompanionBuilder,
    (
      GatheringTypeRow,
      BaseReferences<_$AppDatabase, $GatheringTypesTable, GatheringTypeRow>
    ),
    GatheringTypeRow,
    PrefetchHooks Function()>;
typedef $$GatheringsTableCreateCompanionBuilder = GatheringsCompanion Function({
  Value<int> syncStamp,
  required String id,
  Value<String?> ownerId,
  Value<int?> branchId,
  Value<int?> contributorId,
  Value<int?> teachingTypeId,
  required String title,
  Value<String?> description,
  Value<bool> isLive,
  Value<bool> isFullService,
  Value<String?> playlistUrl,
  Value<String?> imageLandscapeUrl,
  Value<String?> imagePortraitUrl,
  Value<DateTime?> publishedAt,
  Value<DateTime?> clientCreatedAt,
  Value<DateTime?> createdAt,
  Value<DateTime?> updatedAt,
  Value<String?> recordedAt,
  Value<String?> color,
  Value<int> rowid,
});
typedef $$GatheringsTableUpdateCompanionBuilder = GatheringsCompanion Function({
  Value<int> syncStamp,
  Value<String> id,
  Value<String?> ownerId,
  Value<int?> branchId,
  Value<int?> contributorId,
  Value<int?> teachingTypeId,
  Value<String> title,
  Value<String?> description,
  Value<bool> isLive,
  Value<bool> isFullService,
  Value<String?> playlistUrl,
  Value<String?> imageLandscapeUrl,
  Value<String?> imagePortraitUrl,
  Value<DateTime?> publishedAt,
  Value<DateTime?> clientCreatedAt,
  Value<DateTime?> createdAt,
  Value<DateTime?> updatedAt,
  Value<String?> recordedAt,
  Value<String?> color,
  Value<int> rowid,
});

class $$GatheringsTableFilterComposer
    extends Composer<_$AppDatabase, $GatheringsTable> {
  $$GatheringsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get syncStamp => $composableBuilder(
      column: $table.syncStamp, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get ownerId => $composableBuilder(
      column: $table.ownerId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get branchId => $composableBuilder(
      column: $table.branchId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get contributorId => $composableBuilder(
      column: $table.contributorId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get teachingTypeId => $composableBuilder(
      column: $table.teachingTypeId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isLive => $composableBuilder(
      column: $table.isLive, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isFullService => $composableBuilder(
      column: $table.isFullService, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get playlistUrl => $composableBuilder(
      column: $table.playlistUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get imageLandscapeUrl => $composableBuilder(
      column: $table.imageLandscapeUrl,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get imagePortraitUrl => $composableBuilder(
      column: $table.imagePortraitUrl,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get publishedAt => $composableBuilder(
      column: $table.publishedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get clientCreatedAt => $composableBuilder(
      column: $table.clientCreatedAt,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get recordedAt => $composableBuilder(
      column: $table.recordedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get color => $composableBuilder(
      column: $table.color, builder: (column) => ColumnFilters(column));
}

class $$GatheringsTableOrderingComposer
    extends Composer<_$AppDatabase, $GatheringsTable> {
  $$GatheringsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get syncStamp => $composableBuilder(
      column: $table.syncStamp, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get ownerId => $composableBuilder(
      column: $table.ownerId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get branchId => $composableBuilder(
      column: $table.branchId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get contributorId => $composableBuilder(
      column: $table.contributorId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get teachingTypeId => $composableBuilder(
      column: $table.teachingTypeId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isLive => $composableBuilder(
      column: $table.isLive, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isFullService => $composableBuilder(
      column: $table.isFullService,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get playlistUrl => $composableBuilder(
      column: $table.playlistUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get imageLandscapeUrl => $composableBuilder(
      column: $table.imageLandscapeUrl,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get imagePortraitUrl => $composableBuilder(
      column: $table.imagePortraitUrl,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get publishedAt => $composableBuilder(
      column: $table.publishedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get clientCreatedAt => $composableBuilder(
      column: $table.clientCreatedAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get recordedAt => $composableBuilder(
      column: $table.recordedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get color => $composableBuilder(
      column: $table.color, builder: (column) => ColumnOrderings(column));
}

class $$GatheringsTableAnnotationComposer
    extends Composer<_$AppDatabase, $GatheringsTable> {
  $$GatheringsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get syncStamp =>
      $composableBuilder(column: $table.syncStamp, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<int> get branchId =>
      $composableBuilder(column: $table.branchId, builder: (column) => column);

  GeneratedColumn<int> get contributorId => $composableBuilder(
      column: $table.contributorId, builder: (column) => column);

  GeneratedColumn<int> get teachingTypeId => $composableBuilder(
      column: $table.teachingTypeId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<bool> get isLive =>
      $composableBuilder(column: $table.isLive, builder: (column) => column);

  GeneratedColumn<bool> get isFullService => $composableBuilder(
      column: $table.isFullService, builder: (column) => column);

  GeneratedColumn<String> get playlistUrl => $composableBuilder(
      column: $table.playlistUrl, builder: (column) => column);

  GeneratedColumn<String> get imageLandscapeUrl => $composableBuilder(
      column: $table.imageLandscapeUrl, builder: (column) => column);

  GeneratedColumn<String> get imagePortraitUrl => $composableBuilder(
      column: $table.imagePortraitUrl, builder: (column) => column);

  GeneratedColumn<DateTime> get publishedAt => $composableBuilder(
      column: $table.publishedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get clientCreatedAt => $composableBuilder(
      column: $table.clientCreatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get recordedAt => $composableBuilder(
      column: $table.recordedAt, builder: (column) => column);

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);
}

class $$GatheringsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $GatheringsTable,
    GatheringRow,
    $$GatheringsTableFilterComposer,
    $$GatheringsTableOrderingComposer,
    $$GatheringsTableAnnotationComposer,
    $$GatheringsTableCreateCompanionBuilder,
    $$GatheringsTableUpdateCompanionBuilder,
    (
      GatheringRow,
      BaseReferences<_$AppDatabase, $GatheringsTable, GatheringRow>
    ),
    GatheringRow,
    PrefetchHooks Function()> {
  $$GatheringsTableTableManager(_$AppDatabase db, $GatheringsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GatheringsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GatheringsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GatheringsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> syncStamp = const Value.absent(),
            Value<String> id = const Value.absent(),
            Value<String?> ownerId = const Value.absent(),
            Value<int?> branchId = const Value.absent(),
            Value<int?> contributorId = const Value.absent(),
            Value<int?> teachingTypeId = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<bool> isLive = const Value.absent(),
            Value<bool> isFullService = const Value.absent(),
            Value<String?> playlistUrl = const Value.absent(),
            Value<String?> imageLandscapeUrl = const Value.absent(),
            Value<String?> imagePortraitUrl = const Value.absent(),
            Value<DateTime?> publishedAt = const Value.absent(),
            Value<DateTime?> clientCreatedAt = const Value.absent(),
            Value<DateTime?> createdAt = const Value.absent(),
            Value<DateTime?> updatedAt = const Value.absent(),
            Value<String?> recordedAt = const Value.absent(),
            Value<String?> color = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              GatheringsCompanion(
            syncStamp: syncStamp,
            id: id,
            ownerId: ownerId,
            branchId: branchId,
            contributorId: contributorId,
            teachingTypeId: teachingTypeId,
            title: title,
            description: description,
            isLive: isLive,
            isFullService: isFullService,
            playlistUrl: playlistUrl,
            imageLandscapeUrl: imageLandscapeUrl,
            imagePortraitUrl: imagePortraitUrl,
            publishedAt: publishedAt,
            clientCreatedAt: clientCreatedAt,
            createdAt: createdAt,
            updatedAt: updatedAt,
            recordedAt: recordedAt,
            color: color,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            Value<int> syncStamp = const Value.absent(),
            required String id,
            Value<String?> ownerId = const Value.absent(),
            Value<int?> branchId = const Value.absent(),
            Value<int?> contributorId = const Value.absent(),
            Value<int?> teachingTypeId = const Value.absent(),
            required String title,
            Value<String?> description = const Value.absent(),
            Value<bool> isLive = const Value.absent(),
            Value<bool> isFullService = const Value.absent(),
            Value<String?> playlistUrl = const Value.absent(),
            Value<String?> imageLandscapeUrl = const Value.absent(),
            Value<String?> imagePortraitUrl = const Value.absent(),
            Value<DateTime?> publishedAt = const Value.absent(),
            Value<DateTime?> clientCreatedAt = const Value.absent(),
            Value<DateTime?> createdAt = const Value.absent(),
            Value<DateTime?> updatedAt = const Value.absent(),
            Value<String?> recordedAt = const Value.absent(),
            Value<String?> color = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              GatheringsCompanion.insert(
            syncStamp: syncStamp,
            id: id,
            ownerId: ownerId,
            branchId: branchId,
            contributorId: contributorId,
            teachingTypeId: teachingTypeId,
            title: title,
            description: description,
            isLive: isLive,
            isFullService: isFullService,
            playlistUrl: playlistUrl,
            imageLandscapeUrl: imageLandscapeUrl,
            imagePortraitUrl: imagePortraitUrl,
            publishedAt: publishedAt,
            clientCreatedAt: clientCreatedAt,
            createdAt: createdAt,
            updatedAt: updatedAt,
            recordedAt: recordedAt,
            color: color,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$GatheringsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $GatheringsTable,
    GatheringRow,
    $$GatheringsTableFilterComposer,
    $$GatheringsTableOrderingComposer,
    $$GatheringsTableAnnotationComposer,
    $$GatheringsTableCreateCompanionBuilder,
    $$GatheringsTableUpdateCompanionBuilder,
    (
      GatheringRow,
      BaseReferences<_$AppDatabase, $GatheringsTable, GatheringRow>
    ),
    GatheringRow,
    PrefetchHooks Function()>;
typedef $$StatusBackgroundsTableCreateCompanionBuilder
    = StatusBackgroundsCompanion Function({
  Value<int> syncStamp,
  Value<int> id,
  required Map<String, String> label,
  required String baseColor,
  required String topColor,
  required String bottomColor,
  required String ink,
  Value<int> position,
  Value<bool> isActive,
  Value<DateTime?> createdAt,
  Value<DateTime?> updatedAt,
});
typedef $$StatusBackgroundsTableUpdateCompanionBuilder
    = StatusBackgroundsCompanion Function({
  Value<int> syncStamp,
  Value<int> id,
  Value<Map<String, String>> label,
  Value<String> baseColor,
  Value<String> topColor,
  Value<String> bottomColor,
  Value<String> ink,
  Value<int> position,
  Value<bool> isActive,
  Value<DateTime?> createdAt,
  Value<DateTime?> updatedAt,
});

class $$StatusBackgroundsTableFilterComposer
    extends Composer<_$AppDatabase, $StatusBackgroundsTable> {
  $$StatusBackgroundsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get syncStamp => $composableBuilder(
      column: $table.syncStamp, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<Map<String, String>, Map<String, String>,
          String>
      get label => $composableBuilder(
          column: $table.label,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<String> get baseColor => $composableBuilder(
      column: $table.baseColor, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get topColor => $composableBuilder(
      column: $table.topColor, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get bottomColor => $composableBuilder(
      column: $table.bottomColor, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get ink => $composableBuilder(
      column: $table.ink, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get position => $composableBuilder(
      column: $table.position, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isActive => $composableBuilder(
      column: $table.isActive, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$StatusBackgroundsTableOrderingComposer
    extends Composer<_$AppDatabase, $StatusBackgroundsTable> {
  $$StatusBackgroundsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get syncStamp => $composableBuilder(
      column: $table.syncStamp, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get label => $composableBuilder(
      column: $table.label, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get baseColor => $composableBuilder(
      column: $table.baseColor, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get topColor => $composableBuilder(
      column: $table.topColor, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get bottomColor => $composableBuilder(
      column: $table.bottomColor, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get ink => $composableBuilder(
      column: $table.ink, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get position => $composableBuilder(
      column: $table.position, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isActive => $composableBuilder(
      column: $table.isActive, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$StatusBackgroundsTableAnnotationComposer
    extends Composer<_$AppDatabase, $StatusBackgroundsTable> {
  $$StatusBackgroundsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get syncStamp =>
      $composableBuilder(column: $table.syncStamp, builder: (column) => column);

  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Map<String, String>, String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<String> get baseColor =>
      $composableBuilder(column: $table.baseColor, builder: (column) => column);

  GeneratedColumn<String> get topColor =>
      $composableBuilder(column: $table.topColor, builder: (column) => column);

  GeneratedColumn<String> get bottomColor => $composableBuilder(
      column: $table.bottomColor, builder: (column) => column);

  GeneratedColumn<String> get ink =>
      $composableBuilder(column: $table.ink, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$StatusBackgroundsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $StatusBackgroundsTable,
    StatusBackgroundRow,
    $$StatusBackgroundsTableFilterComposer,
    $$StatusBackgroundsTableOrderingComposer,
    $$StatusBackgroundsTableAnnotationComposer,
    $$StatusBackgroundsTableCreateCompanionBuilder,
    $$StatusBackgroundsTableUpdateCompanionBuilder,
    (
      StatusBackgroundRow,
      BaseReferences<_$AppDatabase, $StatusBackgroundsTable,
          StatusBackgroundRow>
    ),
    StatusBackgroundRow,
    PrefetchHooks Function()> {
  $$StatusBackgroundsTableTableManager(
      _$AppDatabase db, $StatusBackgroundsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StatusBackgroundsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StatusBackgroundsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StatusBackgroundsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> syncStamp = const Value.absent(),
            Value<int> id = const Value.absent(),
            Value<Map<String, String>> label = const Value.absent(),
            Value<String> baseColor = const Value.absent(),
            Value<String> topColor = const Value.absent(),
            Value<String> bottomColor = const Value.absent(),
            Value<String> ink = const Value.absent(),
            Value<int> position = const Value.absent(),
            Value<bool> isActive = const Value.absent(),
            Value<DateTime?> createdAt = const Value.absent(),
            Value<DateTime?> updatedAt = const Value.absent(),
          }) =>
              StatusBackgroundsCompanion(
            syncStamp: syncStamp,
            id: id,
            label: label,
            baseColor: baseColor,
            topColor: topColor,
            bottomColor: bottomColor,
            ink: ink,
            position: position,
            isActive: isActive,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> syncStamp = const Value.absent(),
            Value<int> id = const Value.absent(),
            required Map<String, String> label,
            required String baseColor,
            required String topColor,
            required String bottomColor,
            required String ink,
            Value<int> position = const Value.absent(),
            Value<bool> isActive = const Value.absent(),
            Value<DateTime?> createdAt = const Value.absent(),
            Value<DateTime?> updatedAt = const Value.absent(),
          }) =>
              StatusBackgroundsCompanion.insert(
            syncStamp: syncStamp,
            id: id,
            label: label,
            baseColor: baseColor,
            topColor: topColor,
            bottomColor: bottomColor,
            ink: ink,
            position: position,
            isActive: isActive,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$StatusBackgroundsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $StatusBackgroundsTable,
    StatusBackgroundRow,
    $$StatusBackgroundsTableFilterComposer,
    $$StatusBackgroundsTableOrderingComposer,
    $$StatusBackgroundsTableAnnotationComposer,
    $$StatusBackgroundsTableCreateCompanionBuilder,
    $$StatusBackgroundsTableUpdateCompanionBuilder,
    (
      StatusBackgroundRow,
      BaseReferences<_$AppDatabase, $StatusBackgroundsTable,
          StatusBackgroundRow>
    ),
    StatusBackgroundRow,
    PrefetchHooks Function()>;
typedef $$OfficialAccountsTableCreateCompanionBuilder
    = OfficialAccountsCompanion Function({
  Value<int> syncStamp,
  Value<int> id,
  required String name,
  Value<String?> shortName,
  Value<int?> branchId,
  Value<String?> avatarUrl,
  Value<int?> backgroundId,
  Value<bool> isActive,
  Value<DateTime?> createdAt,
  Value<DateTime?> updatedAt,
});
typedef $$OfficialAccountsTableUpdateCompanionBuilder
    = OfficialAccountsCompanion Function({
  Value<int> syncStamp,
  Value<int> id,
  Value<String> name,
  Value<String?> shortName,
  Value<int?> branchId,
  Value<String?> avatarUrl,
  Value<int?> backgroundId,
  Value<bool> isActive,
  Value<DateTime?> createdAt,
  Value<DateTime?> updatedAt,
});

class $$OfficialAccountsTableFilterComposer
    extends Composer<_$AppDatabase, $OfficialAccountsTable> {
  $$OfficialAccountsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get syncStamp => $composableBuilder(
      column: $table.syncStamp, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get shortName => $composableBuilder(
      column: $table.shortName, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get branchId => $composableBuilder(
      column: $table.branchId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get avatarUrl => $composableBuilder(
      column: $table.avatarUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get backgroundId => $composableBuilder(
      column: $table.backgroundId, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isActive => $composableBuilder(
      column: $table.isActive, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$OfficialAccountsTableOrderingComposer
    extends Composer<_$AppDatabase, $OfficialAccountsTable> {
  $$OfficialAccountsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get syncStamp => $composableBuilder(
      column: $table.syncStamp, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get shortName => $composableBuilder(
      column: $table.shortName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get branchId => $composableBuilder(
      column: $table.branchId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get avatarUrl => $composableBuilder(
      column: $table.avatarUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get backgroundId => $composableBuilder(
      column: $table.backgroundId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isActive => $composableBuilder(
      column: $table.isActive, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$OfficialAccountsTableAnnotationComposer
    extends Composer<_$AppDatabase, $OfficialAccountsTable> {
  $$OfficialAccountsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get syncStamp =>
      $composableBuilder(column: $table.syncStamp, builder: (column) => column);

  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get shortName =>
      $composableBuilder(column: $table.shortName, builder: (column) => column);

  GeneratedColumn<int> get branchId =>
      $composableBuilder(column: $table.branchId, builder: (column) => column);

  GeneratedColumn<String> get avatarUrl =>
      $composableBuilder(column: $table.avatarUrl, builder: (column) => column);

  GeneratedColumn<int> get backgroundId => $composableBuilder(
      column: $table.backgroundId, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$OfficialAccountsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $OfficialAccountsTable,
    OfficialAccountRow,
    $$OfficialAccountsTableFilterComposer,
    $$OfficialAccountsTableOrderingComposer,
    $$OfficialAccountsTableAnnotationComposer,
    $$OfficialAccountsTableCreateCompanionBuilder,
    $$OfficialAccountsTableUpdateCompanionBuilder,
    (
      OfficialAccountRow,
      BaseReferences<_$AppDatabase, $OfficialAccountsTable, OfficialAccountRow>
    ),
    OfficialAccountRow,
    PrefetchHooks Function()> {
  $$OfficialAccountsTableTableManager(
      _$AppDatabase db, $OfficialAccountsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OfficialAccountsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OfficialAccountsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OfficialAccountsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> syncStamp = const Value.absent(),
            Value<int> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> shortName = const Value.absent(),
            Value<int?> branchId = const Value.absent(),
            Value<String?> avatarUrl = const Value.absent(),
            Value<int?> backgroundId = const Value.absent(),
            Value<bool> isActive = const Value.absent(),
            Value<DateTime?> createdAt = const Value.absent(),
            Value<DateTime?> updatedAt = const Value.absent(),
          }) =>
              OfficialAccountsCompanion(
            syncStamp: syncStamp,
            id: id,
            name: name,
            shortName: shortName,
            branchId: branchId,
            avatarUrl: avatarUrl,
            backgroundId: backgroundId,
            isActive: isActive,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> syncStamp = const Value.absent(),
            Value<int> id = const Value.absent(),
            required String name,
            Value<String?> shortName = const Value.absent(),
            Value<int?> branchId = const Value.absent(),
            Value<String?> avatarUrl = const Value.absent(),
            Value<int?> backgroundId = const Value.absent(),
            Value<bool> isActive = const Value.absent(),
            Value<DateTime?> createdAt = const Value.absent(),
            Value<DateTime?> updatedAt = const Value.absent(),
          }) =>
              OfficialAccountsCompanion.insert(
            syncStamp: syncStamp,
            id: id,
            name: name,
            shortName: shortName,
            branchId: branchId,
            avatarUrl: avatarUrl,
            backgroundId: backgroundId,
            isActive: isActive,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$OfficialAccountsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $OfficialAccountsTable,
    OfficialAccountRow,
    $$OfficialAccountsTableFilterComposer,
    $$OfficialAccountsTableOrderingComposer,
    $$OfficialAccountsTableAnnotationComposer,
    $$OfficialAccountsTableCreateCompanionBuilder,
    $$OfficialAccountsTableUpdateCompanionBuilder,
    (
      OfficialAccountRow,
      BaseReferences<_$AppDatabase, $OfficialAccountsTable, OfficialAccountRow>
    ),
    OfficialAccountRow,
    PrefetchHooks Function()>;
typedef $$OfficialAccountMembershipsTableCreateCompanionBuilder
    = OfficialAccountMembershipsCompanion Function({
  Value<int> syncStamp,
  Value<int> id,
  required int accountId,
  required String userId,
  Value<DateTime?> createdAt,
  Value<DateTime?> updatedAt,
});
typedef $$OfficialAccountMembershipsTableUpdateCompanionBuilder
    = OfficialAccountMembershipsCompanion Function({
  Value<int> syncStamp,
  Value<int> id,
  Value<int> accountId,
  Value<String> userId,
  Value<DateTime?> createdAt,
  Value<DateTime?> updatedAt,
});

class $$OfficialAccountMembershipsTableFilterComposer
    extends Composer<_$AppDatabase, $OfficialAccountMembershipsTable> {
  $$OfficialAccountMembershipsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get syncStamp => $composableBuilder(
      column: $table.syncStamp, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get accountId => $composableBuilder(
      column: $table.accountId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$OfficialAccountMembershipsTableOrderingComposer
    extends Composer<_$AppDatabase, $OfficialAccountMembershipsTable> {
  $$OfficialAccountMembershipsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get syncStamp => $composableBuilder(
      column: $table.syncStamp, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get accountId => $composableBuilder(
      column: $table.accountId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$OfficialAccountMembershipsTableAnnotationComposer
    extends Composer<_$AppDatabase, $OfficialAccountMembershipsTable> {
  $$OfficialAccountMembershipsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get syncStamp =>
      $composableBuilder(column: $table.syncStamp, builder: (column) => column);

  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$OfficialAccountMembershipsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $OfficialAccountMembershipsTable,
    OfficialAccountMembershipRow,
    $$OfficialAccountMembershipsTableFilterComposer,
    $$OfficialAccountMembershipsTableOrderingComposer,
    $$OfficialAccountMembershipsTableAnnotationComposer,
    $$OfficialAccountMembershipsTableCreateCompanionBuilder,
    $$OfficialAccountMembershipsTableUpdateCompanionBuilder,
    (
      OfficialAccountMembershipRow,
      BaseReferences<_$AppDatabase, $OfficialAccountMembershipsTable,
          OfficialAccountMembershipRow>
    ),
    OfficialAccountMembershipRow,
    PrefetchHooks Function()> {
  $$OfficialAccountMembershipsTableTableManager(
      _$AppDatabase db, $OfficialAccountMembershipsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OfficialAccountMembershipsTableFilterComposer(
                  $db: db, $table: table),
          createOrderingComposer: () =>
              $$OfficialAccountMembershipsTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OfficialAccountMembershipsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> syncStamp = const Value.absent(),
            Value<int> id = const Value.absent(),
            Value<int> accountId = const Value.absent(),
            Value<String> userId = const Value.absent(),
            Value<DateTime?> createdAt = const Value.absent(),
            Value<DateTime?> updatedAt = const Value.absent(),
          }) =>
              OfficialAccountMembershipsCompanion(
            syncStamp: syncStamp,
            id: id,
            accountId: accountId,
            userId: userId,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> syncStamp = const Value.absent(),
            Value<int> id = const Value.absent(),
            required int accountId,
            required String userId,
            Value<DateTime?> createdAt = const Value.absent(),
            Value<DateTime?> updatedAt = const Value.absent(),
          }) =>
              OfficialAccountMembershipsCompanion.insert(
            syncStamp: syncStamp,
            id: id,
            accountId: accountId,
            userId: userId,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$OfficialAccountMembershipsTableProcessedTableManager
    = ProcessedTableManager<
        _$AppDatabase,
        $OfficialAccountMembershipsTable,
        OfficialAccountMembershipRow,
        $$OfficialAccountMembershipsTableFilterComposer,
        $$OfficialAccountMembershipsTableOrderingComposer,
        $$OfficialAccountMembershipsTableAnnotationComposer,
        $$OfficialAccountMembershipsTableCreateCompanionBuilder,
        $$OfficialAccountMembershipsTableUpdateCompanionBuilder,
        (
          OfficialAccountMembershipRow,
          BaseReferences<_$AppDatabase, $OfficialAccountMembershipsTable,
              OfficialAccountMembershipRow>
        ),
        OfficialAccountMembershipRow,
        PrefetchHooks Function()>;
typedef $$AnnouncementsTableCreateCompanionBuilder = AnnouncementsCompanion
    Function({
  Value<int> syncStamp,
  required String id,
  required int accountId,
  Value<int?> branchId,
  Value<String?> title,
  Value<String?> body,
  required DateTime publishedAt,
  Value<DateTime?> expiresAt,
  Value<int?> backgroundId,
  Value<String?> backgroundImageUrl,
  Value<bool> isPinned,
  Value<String?> ownerId,
  Value<DateTime?> createdAt,
  Value<DateTime?> updatedAt,
  Value<int> rowid,
});
typedef $$AnnouncementsTableUpdateCompanionBuilder = AnnouncementsCompanion
    Function({
  Value<int> syncStamp,
  Value<String> id,
  Value<int> accountId,
  Value<int?> branchId,
  Value<String?> title,
  Value<String?> body,
  Value<DateTime> publishedAt,
  Value<DateTime?> expiresAt,
  Value<int?> backgroundId,
  Value<String?> backgroundImageUrl,
  Value<bool> isPinned,
  Value<String?> ownerId,
  Value<DateTime?> createdAt,
  Value<DateTime?> updatedAt,
  Value<int> rowid,
});

class $$AnnouncementsTableFilterComposer
    extends Composer<_$AppDatabase, $AnnouncementsTable> {
  $$AnnouncementsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get syncStamp => $composableBuilder(
      column: $table.syncStamp, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get accountId => $composableBuilder(
      column: $table.accountId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get branchId => $composableBuilder(
      column: $table.branchId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get body => $composableBuilder(
      column: $table.body, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get publishedAt => $composableBuilder(
      column: $table.publishedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get expiresAt => $composableBuilder(
      column: $table.expiresAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get backgroundId => $composableBuilder(
      column: $table.backgroundId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get backgroundImageUrl => $composableBuilder(
      column: $table.backgroundImageUrl,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isPinned => $composableBuilder(
      column: $table.isPinned, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get ownerId => $composableBuilder(
      column: $table.ownerId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$AnnouncementsTableOrderingComposer
    extends Composer<_$AppDatabase, $AnnouncementsTable> {
  $$AnnouncementsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get syncStamp => $composableBuilder(
      column: $table.syncStamp, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get accountId => $composableBuilder(
      column: $table.accountId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get branchId => $composableBuilder(
      column: $table.branchId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get body => $composableBuilder(
      column: $table.body, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get publishedAt => $composableBuilder(
      column: $table.publishedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get expiresAt => $composableBuilder(
      column: $table.expiresAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get backgroundId => $composableBuilder(
      column: $table.backgroundId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get backgroundImageUrl => $composableBuilder(
      column: $table.backgroundImageUrl,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isPinned => $composableBuilder(
      column: $table.isPinned, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get ownerId => $composableBuilder(
      column: $table.ownerId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$AnnouncementsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AnnouncementsTable> {
  $$AnnouncementsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get syncStamp =>
      $composableBuilder(column: $table.syncStamp, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<int> get branchId =>
      $composableBuilder(column: $table.branchId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<DateTime> get publishedAt => $composableBuilder(
      column: $table.publishedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);

  GeneratedColumn<int> get backgroundId => $composableBuilder(
      column: $table.backgroundId, builder: (column) => column);

  GeneratedColumn<String> get backgroundImageUrl => $composableBuilder(
      column: $table.backgroundImageUrl, builder: (column) => column);

  GeneratedColumn<bool> get isPinned =>
      $composableBuilder(column: $table.isPinned, builder: (column) => column);

  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$AnnouncementsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AnnouncementsTable,
    AnnouncementRow,
    $$AnnouncementsTableFilterComposer,
    $$AnnouncementsTableOrderingComposer,
    $$AnnouncementsTableAnnotationComposer,
    $$AnnouncementsTableCreateCompanionBuilder,
    $$AnnouncementsTableUpdateCompanionBuilder,
    (
      AnnouncementRow,
      BaseReferences<_$AppDatabase, $AnnouncementsTable, AnnouncementRow>
    ),
    AnnouncementRow,
    PrefetchHooks Function()> {
  $$AnnouncementsTableTableManager(_$AppDatabase db, $AnnouncementsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AnnouncementsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AnnouncementsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AnnouncementsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> syncStamp = const Value.absent(),
            Value<String> id = const Value.absent(),
            Value<int> accountId = const Value.absent(),
            Value<int?> branchId = const Value.absent(),
            Value<String?> title = const Value.absent(),
            Value<String?> body = const Value.absent(),
            Value<DateTime> publishedAt = const Value.absent(),
            Value<DateTime?> expiresAt = const Value.absent(),
            Value<int?> backgroundId = const Value.absent(),
            Value<String?> backgroundImageUrl = const Value.absent(),
            Value<bool> isPinned = const Value.absent(),
            Value<String?> ownerId = const Value.absent(),
            Value<DateTime?> createdAt = const Value.absent(),
            Value<DateTime?> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AnnouncementsCompanion(
            syncStamp: syncStamp,
            id: id,
            accountId: accountId,
            branchId: branchId,
            title: title,
            body: body,
            publishedAt: publishedAt,
            expiresAt: expiresAt,
            backgroundId: backgroundId,
            backgroundImageUrl: backgroundImageUrl,
            isPinned: isPinned,
            ownerId: ownerId,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            Value<int> syncStamp = const Value.absent(),
            required String id,
            required int accountId,
            Value<int?> branchId = const Value.absent(),
            Value<String?> title = const Value.absent(),
            Value<String?> body = const Value.absent(),
            required DateTime publishedAt,
            Value<DateTime?> expiresAt = const Value.absent(),
            Value<int?> backgroundId = const Value.absent(),
            Value<String?> backgroundImageUrl = const Value.absent(),
            Value<bool> isPinned = const Value.absent(),
            Value<String?> ownerId = const Value.absent(),
            Value<DateTime?> createdAt = const Value.absent(),
            Value<DateTime?> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AnnouncementsCompanion.insert(
            syncStamp: syncStamp,
            id: id,
            accountId: accountId,
            branchId: branchId,
            title: title,
            body: body,
            publishedAt: publishedAt,
            expiresAt: expiresAt,
            backgroundId: backgroundId,
            backgroundImageUrl: backgroundImageUrl,
            isPinned: isPinned,
            ownerId: ownerId,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AnnouncementsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AnnouncementsTable,
    AnnouncementRow,
    $$AnnouncementsTableFilterComposer,
    $$AnnouncementsTableOrderingComposer,
    $$AnnouncementsTableAnnotationComposer,
    $$AnnouncementsTableCreateCompanionBuilder,
    $$AnnouncementsTableUpdateCompanionBuilder,
    (
      AnnouncementRow,
      BaseReferences<_$AppDatabase, $AnnouncementsTable, AnnouncementRow>
    ),
    AnnouncementRow,
    PrefetchHooks Function()>;
typedef $$PlaybackProgressTableCreateCompanionBuilder
    = PlaybackProgressCompanion Function({
  Value<int> syncStamp,
  required String id,
  Value<String?> userId,
  required String teachingId,
  required int positionSeconds,
  Value<bool> completed,
  Value<DateTime?> clientCreatedAt,
  Value<DateTime?> createdAt,
  Value<DateTime?> updatedAt,
  Value<int> rowid,
});
typedef $$PlaybackProgressTableUpdateCompanionBuilder
    = PlaybackProgressCompanion Function({
  Value<int> syncStamp,
  Value<String> id,
  Value<String?> userId,
  Value<String> teachingId,
  Value<int> positionSeconds,
  Value<bool> completed,
  Value<DateTime?> clientCreatedAt,
  Value<DateTime?> createdAt,
  Value<DateTime?> updatedAt,
  Value<int> rowid,
});

class $$PlaybackProgressTableFilterComposer
    extends Composer<_$AppDatabase, $PlaybackProgressTable> {
  $$PlaybackProgressTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get syncStamp => $composableBuilder(
      column: $table.syncStamp, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get teachingId => $composableBuilder(
      column: $table.teachingId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get positionSeconds => $composableBuilder(
      column: $table.positionSeconds,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get completed => $composableBuilder(
      column: $table.completed, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get clientCreatedAt => $composableBuilder(
      column: $table.clientCreatedAt,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$PlaybackProgressTableOrderingComposer
    extends Composer<_$AppDatabase, $PlaybackProgressTable> {
  $$PlaybackProgressTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get syncStamp => $composableBuilder(
      column: $table.syncStamp, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get teachingId => $composableBuilder(
      column: $table.teachingId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get positionSeconds => $composableBuilder(
      column: $table.positionSeconds,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get completed => $composableBuilder(
      column: $table.completed, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get clientCreatedAt => $composableBuilder(
      column: $table.clientCreatedAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$PlaybackProgressTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlaybackProgressTable> {
  $$PlaybackProgressTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get syncStamp =>
      $composableBuilder(column: $table.syncStamp, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get teachingId => $composableBuilder(
      column: $table.teachingId, builder: (column) => column);

  GeneratedColumn<int> get positionSeconds => $composableBuilder(
      column: $table.positionSeconds, builder: (column) => column);

  GeneratedColumn<bool> get completed =>
      $composableBuilder(column: $table.completed, builder: (column) => column);

  GeneratedColumn<DateTime> get clientCreatedAt => $composableBuilder(
      column: $table.clientCreatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$PlaybackProgressTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PlaybackProgressTable,
    PlaybackProgressRow,
    $$PlaybackProgressTableFilterComposer,
    $$PlaybackProgressTableOrderingComposer,
    $$PlaybackProgressTableAnnotationComposer,
    $$PlaybackProgressTableCreateCompanionBuilder,
    $$PlaybackProgressTableUpdateCompanionBuilder,
    (
      PlaybackProgressRow,
      BaseReferences<_$AppDatabase, $PlaybackProgressTable, PlaybackProgressRow>
    ),
    PlaybackProgressRow,
    PrefetchHooks Function()> {
  $$PlaybackProgressTableTableManager(
      _$AppDatabase db, $PlaybackProgressTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaybackProgressTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaybackProgressTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaybackProgressTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> syncStamp = const Value.absent(),
            Value<String> id = const Value.absent(),
            Value<String?> userId = const Value.absent(),
            Value<String> teachingId = const Value.absent(),
            Value<int> positionSeconds = const Value.absent(),
            Value<bool> completed = const Value.absent(),
            Value<DateTime?> clientCreatedAt = const Value.absent(),
            Value<DateTime?> createdAt = const Value.absent(),
            Value<DateTime?> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PlaybackProgressCompanion(
            syncStamp: syncStamp,
            id: id,
            userId: userId,
            teachingId: teachingId,
            positionSeconds: positionSeconds,
            completed: completed,
            clientCreatedAt: clientCreatedAt,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            Value<int> syncStamp = const Value.absent(),
            required String id,
            Value<String?> userId = const Value.absent(),
            required String teachingId,
            required int positionSeconds,
            Value<bool> completed = const Value.absent(),
            Value<DateTime?> clientCreatedAt = const Value.absent(),
            Value<DateTime?> createdAt = const Value.absent(),
            Value<DateTime?> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PlaybackProgressCompanion.insert(
            syncStamp: syncStamp,
            id: id,
            userId: userId,
            teachingId: teachingId,
            positionSeconds: positionSeconds,
            completed: completed,
            clientCreatedAt: clientCreatedAt,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PlaybackProgressTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PlaybackProgressTable,
    PlaybackProgressRow,
    $$PlaybackProgressTableFilterComposer,
    $$PlaybackProgressTableOrderingComposer,
    $$PlaybackProgressTableAnnotationComposer,
    $$PlaybackProgressTableCreateCompanionBuilder,
    $$PlaybackProgressTableUpdateCompanionBuilder,
    (
      PlaybackProgressRow,
      BaseReferences<_$AppDatabase, $PlaybackProgressTable, PlaybackProgressRow>
    ),
    PlaybackProgressRow,
    PrefetchHooks Function()>;
typedef $$LocalPlaybackPositionsTableCreateCompanionBuilder
    = LocalPlaybackPositionsCompanion Function({
  required String contentId,
  required String progressId,
  required int positionSeconds,
  Value<bool> completed,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$LocalPlaybackPositionsTableUpdateCompanionBuilder
    = LocalPlaybackPositionsCompanion Function({
  Value<String> contentId,
  Value<String> progressId,
  Value<int> positionSeconds,
  Value<bool> completed,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$LocalPlaybackPositionsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalPlaybackPositionsTable> {
  $$LocalPlaybackPositionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get contentId => $composableBuilder(
      column: $table.contentId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get progressId => $composableBuilder(
      column: $table.progressId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get positionSeconds => $composableBuilder(
      column: $table.positionSeconds,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get completed => $composableBuilder(
      column: $table.completed, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$LocalPlaybackPositionsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalPlaybackPositionsTable> {
  $$LocalPlaybackPositionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get contentId => $composableBuilder(
      column: $table.contentId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get progressId => $composableBuilder(
      column: $table.progressId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get positionSeconds => $composableBuilder(
      column: $table.positionSeconds,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get completed => $composableBuilder(
      column: $table.completed, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$LocalPlaybackPositionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalPlaybackPositionsTable> {
  $$LocalPlaybackPositionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get contentId =>
      $composableBuilder(column: $table.contentId, builder: (column) => column);

  GeneratedColumn<String> get progressId => $composableBuilder(
      column: $table.progressId, builder: (column) => column);

  GeneratedColumn<int> get positionSeconds => $composableBuilder(
      column: $table.positionSeconds, builder: (column) => column);

  GeneratedColumn<bool> get completed =>
      $composableBuilder(column: $table.completed, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$LocalPlaybackPositionsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $LocalPlaybackPositionsTable,
    LocalPlaybackPositionRow,
    $$LocalPlaybackPositionsTableFilterComposer,
    $$LocalPlaybackPositionsTableOrderingComposer,
    $$LocalPlaybackPositionsTableAnnotationComposer,
    $$LocalPlaybackPositionsTableCreateCompanionBuilder,
    $$LocalPlaybackPositionsTableUpdateCompanionBuilder,
    (
      LocalPlaybackPositionRow,
      BaseReferences<_$AppDatabase, $LocalPlaybackPositionsTable,
          LocalPlaybackPositionRow>
    ),
    LocalPlaybackPositionRow,
    PrefetchHooks Function()> {
  $$LocalPlaybackPositionsTableTableManager(
      _$AppDatabase db, $LocalPlaybackPositionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalPlaybackPositionsTableFilterComposer(
                  $db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalPlaybackPositionsTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalPlaybackPositionsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> contentId = const Value.absent(),
            Value<String> progressId = const Value.absent(),
            Value<int> positionSeconds = const Value.absent(),
            Value<bool> completed = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalPlaybackPositionsCompanion(
            contentId: contentId,
            progressId: progressId,
            positionSeconds: positionSeconds,
            completed: completed,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String contentId,
            required String progressId,
            required int positionSeconds,
            Value<bool> completed = const Value.absent(),
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalPlaybackPositionsCompanion.insert(
            contentId: contentId,
            progressId: progressId,
            positionSeconds: positionSeconds,
            completed: completed,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalPlaybackPositionsTableProcessedTableManager
    = ProcessedTableManager<
        _$AppDatabase,
        $LocalPlaybackPositionsTable,
        LocalPlaybackPositionRow,
        $$LocalPlaybackPositionsTableFilterComposer,
        $$LocalPlaybackPositionsTableOrderingComposer,
        $$LocalPlaybackPositionsTableAnnotationComposer,
        $$LocalPlaybackPositionsTableCreateCompanionBuilder,
        $$LocalPlaybackPositionsTableUpdateCompanionBuilder,
        (
          LocalPlaybackPositionRow,
          BaseReferences<_$AppDatabase, $LocalPlaybackPositionsTable,
              LocalPlaybackPositionRow>
        ),
        LocalPlaybackPositionRow,
        PrefetchHooks Function()>;
typedef $$LegalDocumentsTableCreateCompanionBuilder = LegalDocumentsCompanion
    Function({
  Value<int> syncStamp,
  Value<int> id,
  required String kind,
  Value<int> version,
  Value<int?> lastMandatoryVersion,
  required List<LegalSection> sections,
  Value<DateTime?> publishedAt,
  Value<DateTime?> createdAt,
  Value<DateTime?> updatedAt,
});
typedef $$LegalDocumentsTableUpdateCompanionBuilder = LegalDocumentsCompanion
    Function({
  Value<int> syncStamp,
  Value<int> id,
  Value<String> kind,
  Value<int> version,
  Value<int?> lastMandatoryVersion,
  Value<List<LegalSection>> sections,
  Value<DateTime?> publishedAt,
  Value<DateTime?> createdAt,
  Value<DateTime?> updatedAt,
});

class $$LegalDocumentsTableFilterComposer
    extends Composer<_$AppDatabase, $LegalDocumentsTable> {
  $$LegalDocumentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get syncStamp => $composableBuilder(
      column: $table.syncStamp, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get lastMandatoryVersion => $composableBuilder(
      column: $table.lastMandatoryVersion,
      builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<List<LegalSection>, List<LegalSection>, String>
      get sections => $composableBuilder(
          column: $table.sections,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<DateTime> get publishedAt => $composableBuilder(
      column: $table.publishedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$LegalDocumentsTableOrderingComposer
    extends Composer<_$AppDatabase, $LegalDocumentsTable> {
  $$LegalDocumentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get syncStamp => $composableBuilder(
      column: $table.syncStamp, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get lastMandatoryVersion => $composableBuilder(
      column: $table.lastMandatoryVersion,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sections => $composableBuilder(
      column: $table.sections, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get publishedAt => $composableBuilder(
      column: $table.publishedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$LegalDocumentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LegalDocumentsTable> {
  $$LegalDocumentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get syncStamp =>
      $composableBuilder(column: $table.syncStamp, builder: (column) => column);

  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<int> get lastMandatoryVersion => $composableBuilder(
      column: $table.lastMandatoryVersion, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<LegalSection>, String> get sections =>
      $composableBuilder(column: $table.sections, builder: (column) => column);

  GeneratedColumn<DateTime> get publishedAt => $composableBuilder(
      column: $table.publishedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$LegalDocumentsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $LegalDocumentsTable,
    LegalDocumentRow,
    $$LegalDocumentsTableFilterComposer,
    $$LegalDocumentsTableOrderingComposer,
    $$LegalDocumentsTableAnnotationComposer,
    $$LegalDocumentsTableCreateCompanionBuilder,
    $$LegalDocumentsTableUpdateCompanionBuilder,
    (
      LegalDocumentRow,
      BaseReferences<_$AppDatabase, $LegalDocumentsTable, LegalDocumentRow>
    ),
    LegalDocumentRow,
    PrefetchHooks Function()> {
  $$LegalDocumentsTableTableManager(
      _$AppDatabase db, $LegalDocumentsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LegalDocumentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LegalDocumentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LegalDocumentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> syncStamp = const Value.absent(),
            Value<int> id = const Value.absent(),
            Value<String> kind = const Value.absent(),
            Value<int> version = const Value.absent(),
            Value<int?> lastMandatoryVersion = const Value.absent(),
            Value<List<LegalSection>> sections = const Value.absent(),
            Value<DateTime?> publishedAt = const Value.absent(),
            Value<DateTime?> createdAt = const Value.absent(),
            Value<DateTime?> updatedAt = const Value.absent(),
          }) =>
              LegalDocumentsCompanion(
            syncStamp: syncStamp,
            id: id,
            kind: kind,
            version: version,
            lastMandatoryVersion: lastMandatoryVersion,
            sections: sections,
            publishedAt: publishedAt,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> syncStamp = const Value.absent(),
            Value<int> id = const Value.absent(),
            required String kind,
            Value<int> version = const Value.absent(),
            Value<int?> lastMandatoryVersion = const Value.absent(),
            required List<LegalSection> sections,
            Value<DateTime?> publishedAt = const Value.absent(),
            Value<DateTime?> createdAt = const Value.absent(),
            Value<DateTime?> updatedAt = const Value.absent(),
          }) =>
              LegalDocumentsCompanion.insert(
            syncStamp: syncStamp,
            id: id,
            kind: kind,
            version: version,
            lastMandatoryVersion: lastMandatoryVersion,
            sections: sections,
            publishedAt: publishedAt,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LegalDocumentsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $LegalDocumentsTable,
    LegalDocumentRow,
    $$LegalDocumentsTableFilterComposer,
    $$LegalDocumentsTableOrderingComposer,
    $$LegalDocumentsTableAnnotationComposer,
    $$LegalDocumentsTableCreateCompanionBuilder,
    $$LegalDocumentsTableUpdateCompanionBuilder,
    (
      LegalDocumentRow,
      BaseReferences<_$AppDatabase, $LegalDocumentsTable, LegalDocumentRow>
    ),
    LegalDocumentRow,
    PrefetchHooks Function()>;
typedef $$SeasonsTableCreateCompanionBuilder = SeasonsCompanion Function({
  Value<int> syncStamp,
  Value<int> id,
  required String name,
  required String backgroundUrl,
  Value<String?> backgroundVerticalUrl,
  required String startsOn,
  required String endsOn,
  Value<DateTime?> createdAt,
  Value<DateTime?> updatedAt,
});
typedef $$SeasonsTableUpdateCompanionBuilder = SeasonsCompanion Function({
  Value<int> syncStamp,
  Value<int> id,
  Value<String> name,
  Value<String> backgroundUrl,
  Value<String?> backgroundVerticalUrl,
  Value<String> startsOn,
  Value<String> endsOn,
  Value<DateTime?> createdAt,
  Value<DateTime?> updatedAt,
});

class $$SeasonsTableFilterComposer
    extends Composer<_$AppDatabase, $SeasonsTable> {
  $$SeasonsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get syncStamp => $composableBuilder(
      column: $table.syncStamp, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get backgroundUrl => $composableBuilder(
      column: $table.backgroundUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get backgroundVerticalUrl => $composableBuilder(
      column: $table.backgroundVerticalUrl,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get startsOn => $composableBuilder(
      column: $table.startsOn, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get endsOn => $composableBuilder(
      column: $table.endsOn, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$SeasonsTableOrderingComposer
    extends Composer<_$AppDatabase, $SeasonsTable> {
  $$SeasonsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get syncStamp => $composableBuilder(
      column: $table.syncStamp, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get backgroundUrl => $composableBuilder(
      column: $table.backgroundUrl,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get backgroundVerticalUrl => $composableBuilder(
      column: $table.backgroundVerticalUrl,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get startsOn => $composableBuilder(
      column: $table.startsOn, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get endsOn => $composableBuilder(
      column: $table.endsOn, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$SeasonsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SeasonsTable> {
  $$SeasonsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get syncStamp =>
      $composableBuilder(column: $table.syncStamp, builder: (column) => column);

  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get backgroundUrl => $composableBuilder(
      column: $table.backgroundUrl, builder: (column) => column);

  GeneratedColumn<String> get backgroundVerticalUrl => $composableBuilder(
      column: $table.backgroundVerticalUrl, builder: (column) => column);

  GeneratedColumn<String> get startsOn =>
      $composableBuilder(column: $table.startsOn, builder: (column) => column);

  GeneratedColumn<String> get endsOn =>
      $composableBuilder(column: $table.endsOn, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SeasonsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SeasonsTable,
    SeasonRow,
    $$SeasonsTableFilterComposer,
    $$SeasonsTableOrderingComposer,
    $$SeasonsTableAnnotationComposer,
    $$SeasonsTableCreateCompanionBuilder,
    $$SeasonsTableUpdateCompanionBuilder,
    (SeasonRow, BaseReferences<_$AppDatabase, $SeasonsTable, SeasonRow>),
    SeasonRow,
    PrefetchHooks Function()> {
  $$SeasonsTableTableManager(_$AppDatabase db, $SeasonsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SeasonsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SeasonsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SeasonsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> syncStamp = const Value.absent(),
            Value<int> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> backgroundUrl = const Value.absent(),
            Value<String?> backgroundVerticalUrl = const Value.absent(),
            Value<String> startsOn = const Value.absent(),
            Value<String> endsOn = const Value.absent(),
            Value<DateTime?> createdAt = const Value.absent(),
            Value<DateTime?> updatedAt = const Value.absent(),
          }) =>
              SeasonsCompanion(
            syncStamp: syncStamp,
            id: id,
            name: name,
            backgroundUrl: backgroundUrl,
            backgroundVerticalUrl: backgroundVerticalUrl,
            startsOn: startsOn,
            endsOn: endsOn,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> syncStamp = const Value.absent(),
            Value<int> id = const Value.absent(),
            required String name,
            required String backgroundUrl,
            Value<String?> backgroundVerticalUrl = const Value.absent(),
            required String startsOn,
            required String endsOn,
            Value<DateTime?> createdAt = const Value.absent(),
            Value<DateTime?> updatedAt = const Value.absent(),
          }) =>
              SeasonsCompanion.insert(
            syncStamp: syncStamp,
            id: id,
            name: name,
            backgroundUrl: backgroundUrl,
            backgroundVerticalUrl: backgroundVerticalUrl,
            startsOn: startsOn,
            endsOn: endsOn,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SeasonsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SeasonsTable,
    SeasonRow,
    $$SeasonsTableFilterComposer,
    $$SeasonsTableOrderingComposer,
    $$SeasonsTableAnnotationComposer,
    $$SeasonsTableCreateCompanionBuilder,
    $$SeasonsTableUpdateCompanionBuilder,
    (SeasonRow, BaseReferences<_$AppDatabase, $SeasonsTable, SeasonRow>),
    SeasonRow,
    PrefetchHooks Function()>;
typedef $$PresentationVocabularyTableCreateCompanionBuilder
    = PresentationVocabularyCompanion Function({
  Value<int> syncStamp,
  required String id,
  required String kind,
  Value<Map<String, String>?> singular,
  Value<Map<String, String>?> plural,
  Value<Map<String, String>?> label,
  Value<DateTime?> createdAt,
  Value<DateTime?> updatedAt,
  Value<int> rowid,
});
typedef $$PresentationVocabularyTableUpdateCompanionBuilder
    = PresentationVocabularyCompanion Function({
  Value<int> syncStamp,
  Value<String> id,
  Value<String> kind,
  Value<Map<String, String>?> singular,
  Value<Map<String, String>?> plural,
  Value<Map<String, String>?> label,
  Value<DateTime?> createdAt,
  Value<DateTime?> updatedAt,
  Value<int> rowid,
});

class $$PresentationVocabularyTableFilterComposer
    extends Composer<_$AppDatabase, $PresentationVocabularyTable> {
  $$PresentationVocabularyTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get syncStamp => $composableBuilder(
      column: $table.syncStamp, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<Map<String, String>?, Map<String, String>,
          String>
      get singular => $composableBuilder(
          column: $table.singular,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnWithTypeConverterFilters<Map<String, String>?, Map<String, String>,
          String>
      get plural => $composableBuilder(
          column: $table.plural,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnWithTypeConverterFilters<Map<String, String>?, Map<String, String>,
          String>
      get label => $composableBuilder(
          column: $table.label,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$PresentationVocabularyTableOrderingComposer
    extends Composer<_$AppDatabase, $PresentationVocabularyTable> {
  $$PresentationVocabularyTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get syncStamp => $composableBuilder(
      column: $table.syncStamp, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get singular => $composableBuilder(
      column: $table.singular, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get plural => $composableBuilder(
      column: $table.plural, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get label => $composableBuilder(
      column: $table.label, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$PresentationVocabularyTableAnnotationComposer
    extends Composer<_$AppDatabase, $PresentationVocabularyTable> {
  $$PresentationVocabularyTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get syncStamp =>
      $composableBuilder(column: $table.syncStamp, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Map<String, String>?, String> get singular =>
      $composableBuilder(column: $table.singular, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Map<String, String>?, String> get plural =>
      $composableBuilder(column: $table.plural, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Map<String, String>?, String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$PresentationVocabularyTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PresentationVocabularyTable,
    VocabularyRow,
    $$PresentationVocabularyTableFilterComposer,
    $$PresentationVocabularyTableOrderingComposer,
    $$PresentationVocabularyTableAnnotationComposer,
    $$PresentationVocabularyTableCreateCompanionBuilder,
    $$PresentationVocabularyTableUpdateCompanionBuilder,
    (
      VocabularyRow,
      BaseReferences<_$AppDatabase, $PresentationVocabularyTable, VocabularyRow>
    ),
    VocabularyRow,
    PrefetchHooks Function()> {
  $$PresentationVocabularyTableTableManager(
      _$AppDatabase db, $PresentationVocabularyTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PresentationVocabularyTableFilterComposer(
                  $db: db, $table: table),
          createOrderingComposer: () =>
              $$PresentationVocabularyTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PresentationVocabularyTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> syncStamp = const Value.absent(),
            Value<String> id = const Value.absent(),
            Value<String> kind = const Value.absent(),
            Value<Map<String, String>?> singular = const Value.absent(),
            Value<Map<String, String>?> plural = const Value.absent(),
            Value<Map<String, String>?> label = const Value.absent(),
            Value<DateTime?> createdAt = const Value.absent(),
            Value<DateTime?> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PresentationVocabularyCompanion(
            syncStamp: syncStamp,
            id: id,
            kind: kind,
            singular: singular,
            plural: plural,
            label: label,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            Value<int> syncStamp = const Value.absent(),
            required String id,
            required String kind,
            Value<Map<String, String>?> singular = const Value.absent(),
            Value<Map<String, String>?> plural = const Value.absent(),
            Value<Map<String, String>?> label = const Value.absent(),
            Value<DateTime?> createdAt = const Value.absent(),
            Value<DateTime?> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PresentationVocabularyCompanion.insert(
            syncStamp: syncStamp,
            id: id,
            kind: kind,
            singular: singular,
            plural: plural,
            label: label,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PresentationVocabularyTableProcessedTableManager
    = ProcessedTableManager<
        _$AppDatabase,
        $PresentationVocabularyTable,
        VocabularyRow,
        $$PresentationVocabularyTableFilterComposer,
        $$PresentationVocabularyTableOrderingComposer,
        $$PresentationVocabularyTableAnnotationComposer,
        $$PresentationVocabularyTableCreateCompanionBuilder,
        $$PresentationVocabularyTableUpdateCompanionBuilder,
        (
          VocabularyRow,
          BaseReferences<_$AppDatabase, $PresentationVocabularyTable,
              VocabularyRow>
        ),
        VocabularyRow,
        PrefetchHooks Function()>;
typedef $$DecorTableCreateCompanionBuilder = DecorCompanion Function({
  Value<int> syncStamp,
  Value<int> id,
  Value<String?> backgroundUrl,
  Value<String?> backgroundVerticalUrl,
  Value<DateTime?> createdAt,
  Value<DateTime?> updatedAt,
});
typedef $$DecorTableUpdateCompanionBuilder = DecorCompanion Function({
  Value<int> syncStamp,
  Value<int> id,
  Value<String?> backgroundUrl,
  Value<String?> backgroundVerticalUrl,
  Value<DateTime?> createdAt,
  Value<DateTime?> updatedAt,
});

class $$DecorTableFilterComposer extends Composer<_$AppDatabase, $DecorTable> {
  $$DecorTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get syncStamp => $composableBuilder(
      column: $table.syncStamp, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get backgroundUrl => $composableBuilder(
      column: $table.backgroundUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get backgroundVerticalUrl => $composableBuilder(
      column: $table.backgroundVerticalUrl,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$DecorTableOrderingComposer
    extends Composer<_$AppDatabase, $DecorTable> {
  $$DecorTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get syncStamp => $composableBuilder(
      column: $table.syncStamp, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get backgroundUrl => $composableBuilder(
      column: $table.backgroundUrl,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get backgroundVerticalUrl => $composableBuilder(
      column: $table.backgroundVerticalUrl,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$DecorTableAnnotationComposer
    extends Composer<_$AppDatabase, $DecorTable> {
  $$DecorTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get syncStamp =>
      $composableBuilder(column: $table.syncStamp, builder: (column) => column);

  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get backgroundUrl => $composableBuilder(
      column: $table.backgroundUrl, builder: (column) => column);

  GeneratedColumn<String> get backgroundVerticalUrl => $composableBuilder(
      column: $table.backgroundVerticalUrl, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$DecorTableTableManager extends RootTableManager<
    _$AppDatabase,
    $DecorTable,
    DecorRow,
    $$DecorTableFilterComposer,
    $$DecorTableOrderingComposer,
    $$DecorTableAnnotationComposer,
    $$DecorTableCreateCompanionBuilder,
    $$DecorTableUpdateCompanionBuilder,
    (DecorRow, BaseReferences<_$AppDatabase, $DecorTable, DecorRow>),
    DecorRow,
    PrefetchHooks Function()> {
  $$DecorTableTableManager(_$AppDatabase db, $DecorTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DecorTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DecorTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DecorTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> syncStamp = const Value.absent(),
            Value<int> id = const Value.absent(),
            Value<String?> backgroundUrl = const Value.absent(),
            Value<String?> backgroundVerticalUrl = const Value.absent(),
            Value<DateTime?> createdAt = const Value.absent(),
            Value<DateTime?> updatedAt = const Value.absent(),
          }) =>
              DecorCompanion(
            syncStamp: syncStamp,
            id: id,
            backgroundUrl: backgroundUrl,
            backgroundVerticalUrl: backgroundVerticalUrl,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> syncStamp = const Value.absent(),
            Value<int> id = const Value.absent(),
            Value<String?> backgroundUrl = const Value.absent(),
            Value<String?> backgroundVerticalUrl = const Value.absent(),
            Value<DateTime?> createdAt = const Value.absent(),
            Value<DateTime?> updatedAt = const Value.absent(),
          }) =>
              DecorCompanion.insert(
            syncStamp: syncStamp,
            id: id,
            backgroundUrl: backgroundUrl,
            backgroundVerticalUrl: backgroundVerticalUrl,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$DecorTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $DecorTable,
    DecorRow,
    $$DecorTableFilterComposer,
    $$DecorTableOrderingComposer,
    $$DecorTableAnnotationComposer,
    $$DecorTableCreateCompanionBuilder,
    $$DecorTableUpdateCompanionBuilder,
    (DecorRow, BaseReferences<_$AppDatabase, $DecorTable, DecorRow>),
    DecorRow,
    PrefetchHooks Function()>;
typedef $$AppSettingsTableCreateCompanionBuilder = AppSettingsCompanion
    Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$AppSettingsTableUpdateCompanionBuilder = AppSettingsCompanion
    Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$AppSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnFilters(column));
}

class $$AppSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnOrderings(column));
}

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$AppSettingsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AppSettingsTable,
    AppSettingRow,
    $$AppSettingsTableFilterComposer,
    $$AppSettingsTableOrderingComposer,
    $$AppSettingsTableAnnotationComposer,
    $$AppSettingsTableCreateCompanionBuilder,
    $$AppSettingsTableUpdateCompanionBuilder,
    (
      AppSettingRow,
      BaseReferences<_$AppDatabase, $AppSettingsTable, AppSettingRow>
    ),
    AppSettingRow,
    PrefetchHooks Function()> {
  $$AppSettingsTableTableManager(_$AppDatabase db, $AppSettingsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AppSettingsCompanion(
            key: key,
            value: value,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) =>
              AppSettingsCompanion.insert(
            key: key,
            value: value,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AppSettingsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AppSettingsTable,
    AppSettingRow,
    $$AppSettingsTableFilterComposer,
    $$AppSettingsTableOrderingComposer,
    $$AppSettingsTableAnnotationComposer,
    $$AppSettingsTableCreateCompanionBuilder,
    $$AppSettingsTableUpdateCompanionBuilder,
    (
      AppSettingRow,
      BaseReferences<_$AppDatabase, $AppSettingsTable, AppSettingRow>
    ),
    AppSettingRow,
    PrefetchHooks Function()>;
typedef $$DownloadsTableCreateCompanionBuilder = DownloadsCompanion Function({
  required String contentType,
  required String contentId,
  required String quality,
  Value<DownloadState> state,
  Value<int> bytesReceived,
  Value<int> bytesTotal,
  Value<String?> localPath,
  Value<String?> taskId,
  Value<String?> versionId,
  required DateTime createdAt,
  Value<String?> failureReason,
  Value<int> rowid,
});
typedef $$DownloadsTableUpdateCompanionBuilder = DownloadsCompanion Function({
  Value<String> contentType,
  Value<String> contentId,
  Value<String> quality,
  Value<DownloadState> state,
  Value<int> bytesReceived,
  Value<int> bytesTotal,
  Value<String?> localPath,
  Value<String?> taskId,
  Value<String?> versionId,
  Value<DateTime> createdAt,
  Value<String?> failureReason,
  Value<int> rowid,
});

class $$DownloadsTableFilterComposer
    extends Composer<_$AppDatabase, $DownloadsTable> {
  $$DownloadsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get contentType => $composableBuilder(
      column: $table.contentType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get contentId => $composableBuilder(
      column: $table.contentId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get quality => $composableBuilder(
      column: $table.quality, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<DownloadState, DownloadState, String>
      get state => $composableBuilder(
          column: $table.state,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<int> get bytesReceived => $composableBuilder(
      column: $table.bytesReceived, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get bytesTotal => $composableBuilder(
      column: $table.bytesTotal, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get localPath => $composableBuilder(
      column: $table.localPath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get taskId => $composableBuilder(
      column: $table.taskId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get versionId => $composableBuilder(
      column: $table.versionId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get failureReason => $composableBuilder(
      column: $table.failureReason, builder: (column) => ColumnFilters(column));
}

class $$DownloadsTableOrderingComposer
    extends Composer<_$AppDatabase, $DownloadsTable> {
  $$DownloadsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get contentType => $composableBuilder(
      column: $table.contentType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get contentId => $composableBuilder(
      column: $table.contentId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get quality => $composableBuilder(
      column: $table.quality, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get state => $composableBuilder(
      column: $table.state, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get bytesReceived => $composableBuilder(
      column: $table.bytesReceived,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get bytesTotal => $composableBuilder(
      column: $table.bytesTotal, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get localPath => $composableBuilder(
      column: $table.localPath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get taskId => $composableBuilder(
      column: $table.taskId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get versionId => $composableBuilder(
      column: $table.versionId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get failureReason => $composableBuilder(
      column: $table.failureReason,
      builder: (column) => ColumnOrderings(column));
}

class $$DownloadsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DownloadsTable> {
  $$DownloadsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get contentType => $composableBuilder(
      column: $table.contentType, builder: (column) => column);

  GeneratedColumn<String> get contentId =>
      $composableBuilder(column: $table.contentId, builder: (column) => column);

  GeneratedColumn<String> get quality =>
      $composableBuilder(column: $table.quality, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DownloadState, String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<int> get bytesReceived => $composableBuilder(
      column: $table.bytesReceived, builder: (column) => column);

  GeneratedColumn<int> get bytesTotal => $composableBuilder(
      column: $table.bytesTotal, builder: (column) => column);

  GeneratedColumn<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => column);

  GeneratedColumn<String> get taskId =>
      $composableBuilder(column: $table.taskId, builder: (column) => column);

  GeneratedColumn<String> get versionId =>
      $composableBuilder(column: $table.versionId, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get failureReason => $composableBuilder(
      column: $table.failureReason, builder: (column) => column);
}

class $$DownloadsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $DownloadsTable,
    DownloadRow,
    $$DownloadsTableFilterComposer,
    $$DownloadsTableOrderingComposer,
    $$DownloadsTableAnnotationComposer,
    $$DownloadsTableCreateCompanionBuilder,
    $$DownloadsTableUpdateCompanionBuilder,
    (DownloadRow, BaseReferences<_$AppDatabase, $DownloadsTable, DownloadRow>),
    DownloadRow,
    PrefetchHooks Function()> {
  $$DownloadsTableTableManager(_$AppDatabase db, $DownloadsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DownloadsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DownloadsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DownloadsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> contentType = const Value.absent(),
            Value<String> contentId = const Value.absent(),
            Value<String> quality = const Value.absent(),
            Value<DownloadState> state = const Value.absent(),
            Value<int> bytesReceived = const Value.absent(),
            Value<int> bytesTotal = const Value.absent(),
            Value<String?> localPath = const Value.absent(),
            Value<String?> taskId = const Value.absent(),
            Value<String?> versionId = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<String?> failureReason = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DownloadsCompanion(
            contentType: contentType,
            contentId: contentId,
            quality: quality,
            state: state,
            bytesReceived: bytesReceived,
            bytesTotal: bytesTotal,
            localPath: localPath,
            taskId: taskId,
            versionId: versionId,
            createdAt: createdAt,
            failureReason: failureReason,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String contentType,
            required String contentId,
            required String quality,
            Value<DownloadState> state = const Value.absent(),
            Value<int> bytesReceived = const Value.absent(),
            Value<int> bytesTotal = const Value.absent(),
            Value<String?> localPath = const Value.absent(),
            Value<String?> taskId = const Value.absent(),
            Value<String?> versionId = const Value.absent(),
            required DateTime createdAt,
            Value<String?> failureReason = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DownloadsCompanion.insert(
            contentType: contentType,
            contentId: contentId,
            quality: quality,
            state: state,
            bytesReceived: bytesReceived,
            bytesTotal: bytesTotal,
            localPath: localPath,
            taskId: taskId,
            versionId: versionId,
            createdAt: createdAt,
            failureReason: failureReason,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$DownloadsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $DownloadsTable,
    DownloadRow,
    $$DownloadsTableFilterComposer,
    $$DownloadsTableOrderingComposer,
    $$DownloadsTableAnnotationComposer,
    $$DownloadsTableCreateCompanionBuilder,
    $$DownloadsTableUpdateCompanionBuilder,
    (DownloadRow, BaseReferences<_$AppDatabase, $DownloadsTable, DownloadRow>),
    DownloadRow,
    PrefetchHooks Function()>;
typedef $$DownloadTitlesTableCreateCompanionBuilder = DownloadTitlesCompanion
    Function({
  required String contentId,
  Value<String?> title,
  Value<int> rowid,
});
typedef $$DownloadTitlesTableUpdateCompanionBuilder = DownloadTitlesCompanion
    Function({
  Value<String> contentId,
  Value<String?> title,
  Value<int> rowid,
});

class $$DownloadTitlesTableFilterComposer
    extends Composer<_$AppDatabase, $DownloadTitlesTable> {
  $$DownloadTitlesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get contentId => $composableBuilder(
      column: $table.contentId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));
}

class $$DownloadTitlesTableOrderingComposer
    extends Composer<_$AppDatabase, $DownloadTitlesTable> {
  $$DownloadTitlesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get contentId => $composableBuilder(
      column: $table.contentId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));
}

class $$DownloadTitlesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DownloadTitlesTable> {
  $$DownloadTitlesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get contentId =>
      $composableBuilder(column: $table.contentId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);
}

class $$DownloadTitlesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $DownloadTitlesTable,
    DownloadTitleRow,
    $$DownloadTitlesTableFilterComposer,
    $$DownloadTitlesTableOrderingComposer,
    $$DownloadTitlesTableAnnotationComposer,
    $$DownloadTitlesTableCreateCompanionBuilder,
    $$DownloadTitlesTableUpdateCompanionBuilder,
    (
      DownloadTitleRow,
      BaseReferences<_$AppDatabase, $DownloadTitlesTable, DownloadTitleRow>
    ),
    DownloadTitleRow,
    PrefetchHooks Function()> {
  $$DownloadTitlesTableTableManager(
      _$AppDatabase db, $DownloadTitlesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DownloadTitlesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DownloadTitlesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DownloadTitlesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> contentId = const Value.absent(),
            Value<String?> title = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DownloadTitlesCompanion(
            contentId: contentId,
            title: title,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String contentId,
            Value<String?> title = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DownloadTitlesCompanion.insert(
            contentId: contentId,
            title: title,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$DownloadTitlesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $DownloadTitlesTable,
    DownloadTitleRow,
    $$DownloadTitlesTableFilterComposer,
    $$DownloadTitlesTableOrderingComposer,
    $$DownloadTitlesTableAnnotationComposer,
    $$DownloadTitlesTableCreateCompanionBuilder,
    $$DownloadTitlesTableUpdateCompanionBuilder,
    (
      DownloadTitleRow,
      BaseReferences<_$AppDatabase, $DownloadTitlesTable, DownloadTitleRow>
    ),
    DownloadTitleRow,
    PrefetchHooks Function()>;
typedef $$DownloadNotificationsTableCreateCompanionBuilder
    = DownloadNotificationsCompanion Function({
  Value<int> id,
  required String contentId,
  Value<String?> title,
  required DateTime createdAt,
});
typedef $$DownloadNotificationsTableUpdateCompanionBuilder
    = DownloadNotificationsCompanion Function({
  Value<int> id,
  Value<String> contentId,
  Value<String?> title,
  Value<DateTime> createdAt,
});

class $$DownloadNotificationsTableFilterComposer
    extends Composer<_$AppDatabase, $DownloadNotificationsTable> {
  $$DownloadNotificationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get contentId => $composableBuilder(
      column: $table.contentId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$DownloadNotificationsTableOrderingComposer
    extends Composer<_$AppDatabase, $DownloadNotificationsTable> {
  $$DownloadNotificationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get contentId => $composableBuilder(
      column: $table.contentId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$DownloadNotificationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DownloadNotificationsTable> {
  $$DownloadNotificationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get contentId =>
      $composableBuilder(column: $table.contentId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$DownloadNotificationsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $DownloadNotificationsTable,
    DownloadNotificationRow,
    $$DownloadNotificationsTableFilterComposer,
    $$DownloadNotificationsTableOrderingComposer,
    $$DownloadNotificationsTableAnnotationComposer,
    $$DownloadNotificationsTableCreateCompanionBuilder,
    $$DownloadNotificationsTableUpdateCompanionBuilder,
    (
      DownloadNotificationRow,
      BaseReferences<_$AppDatabase, $DownloadNotificationsTable,
          DownloadNotificationRow>
    ),
    DownloadNotificationRow,
    PrefetchHooks Function()> {
  $$DownloadNotificationsTableTableManager(
      _$AppDatabase db, $DownloadNotificationsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DownloadNotificationsTableFilterComposer(
                  $db: db, $table: table),
          createOrderingComposer: () =>
              $$DownloadNotificationsTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DownloadNotificationsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> contentId = const Value.absent(),
            Value<String?> title = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              DownloadNotificationsCompanion(
            id: id,
            contentId: contentId,
            title: title,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String contentId,
            Value<String?> title = const Value.absent(),
            required DateTime createdAt,
          }) =>
              DownloadNotificationsCompanion.insert(
            id: id,
            contentId: contentId,
            title: title,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$DownloadNotificationsTableProcessedTableManager
    = ProcessedTableManager<
        _$AppDatabase,
        $DownloadNotificationsTable,
        DownloadNotificationRow,
        $$DownloadNotificationsTableFilterComposer,
        $$DownloadNotificationsTableOrderingComposer,
        $$DownloadNotificationsTableAnnotationComposer,
        $$DownloadNotificationsTableCreateCompanionBuilder,
        $$DownloadNotificationsTableUpdateCompanionBuilder,
        (
          DownloadNotificationRow,
          BaseReferences<_$AppDatabase, $DownloadNotificationsTable,
              DownloadNotificationRow>
        ),
        DownloadNotificationRow,
        PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SyncCursorsTableTableManager get syncCursors =>
      $$SyncCursorsTableTableManager(_db, _db.syncCursors);
  $$SyncStateTableTableManager get syncState =>
      $$SyncStateTableTableManager(_db, _db.syncState);
  $$ResyncTokensTableTableManager get resyncTokens =>
      $$ResyncTokensTableTableManager(_db, _db.resyncTokens);
  $$BranchesTableTableManager get branches =>
      $$BranchesTableTableManager(_db, _db.branches);
  $$TeachingTypesTableTableManager get teachingTypes =>
      $$TeachingTypesTableTableManager(_db, _db.teachingTypes);
  $$ContributorsTableTableManager get contributors =>
      $$ContributorsTableTableManager(_db, _db.contributors);
  $$TeachingsTableTableManager get teachings =>
      $$TeachingsTableTableManager(_db, _db.teachings);
  $$TeachingGuestsTableTableManager get teachingGuests =>
      $$TeachingGuestsTableTableManager(_db, _db.teachingGuests);
  $$GatheringTypesTableTableManager get gatheringTypes =>
      $$GatheringTypesTableTableManager(_db, _db.gatheringTypes);
  $$GatheringsTableTableManager get gatherings =>
      $$GatheringsTableTableManager(_db, _db.gatherings);
  $$StatusBackgroundsTableTableManager get statusBackgrounds =>
      $$StatusBackgroundsTableTableManager(_db, _db.statusBackgrounds);
  $$OfficialAccountsTableTableManager get officialAccounts =>
      $$OfficialAccountsTableTableManager(_db, _db.officialAccounts);
  $$OfficialAccountMembershipsTableTableManager
      get officialAccountMemberships =>
          $$OfficialAccountMembershipsTableTableManager(
              _db, _db.officialAccountMemberships);
  $$AnnouncementsTableTableManager get announcements =>
      $$AnnouncementsTableTableManager(_db, _db.announcements);
  $$PlaybackProgressTableTableManager get playbackProgress =>
      $$PlaybackProgressTableTableManager(_db, _db.playbackProgress);
  $$LocalPlaybackPositionsTableTableManager get localPlaybackPositions =>
      $$LocalPlaybackPositionsTableTableManager(
          _db, _db.localPlaybackPositions);
  $$LegalDocumentsTableTableManager get legalDocuments =>
      $$LegalDocumentsTableTableManager(_db, _db.legalDocuments);
  $$SeasonsTableTableManager get seasons =>
      $$SeasonsTableTableManager(_db, _db.seasons);
  $$PresentationVocabularyTableTableManager get presentationVocabulary =>
      $$PresentationVocabularyTableTableManager(
          _db, _db.presentationVocabulary);
  $$DecorTableTableManager get decor =>
      $$DecorTableTableManager(_db, _db.decor);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
  $$DownloadsTableTableManager get downloads =>
      $$DownloadsTableTableManager(_db, _db.downloads);
  $$DownloadTitlesTableTableManager get downloadTitles =>
      $$DownloadTitlesTableTableManager(_db, _db.downloadTitles);
  $$DownloadNotificationsTableTableManager get downloadNotifications =>
      $$DownloadNotificationsTableTableManager(_db, _db.downloadNotifications);
}
