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
  $TeachingsTable createAlias(String alias) {
    return $TeachingsTable(attachedDatabase, alias);
  }
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

  /// URL **relative** (`/uploads/teachings/….jpg`) : l'hôte de l'API change
  /// d'un environnement à l'autre, la résolution appartient au client.
  final String? imageLandscapeUrl;
  final String? imagePortraitUrl;
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
          Value<String?> imageLandscapeUrl = const Value.absent(),
          Value<String?> imagePortraitUrl = const Value.absent(),
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
          other.imageLandscapeUrl == this.imageLandscapeUrl &&
          other.imagePortraitUrl == this.imagePortraitUrl &&
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
  final Value<String?> imageLandscapeUrl;
  final Value<String?> imagePortraitUrl;
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
      Value<String?>? imageLandscapeUrl,
      Value<String?>? imagePortraitUrl,
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
  late final SyncDao syncDao = SyncDao(this as AppDatabase);
  late final MediathequeDao mediathequeDao =
      MediathequeDao(this as AppDatabase);
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
        teachings
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
}
