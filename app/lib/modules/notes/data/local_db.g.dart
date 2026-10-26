// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_db.dart';

// ignore_for_file: type=lint
class $LocalFoldersTable extends LocalFolders with TableInfo<$LocalFoldersTable, LocalFolder> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalFoldersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _parentIdMeta = const VerificationMeta('parentId');
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
    'parent_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta('position');
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, parentId, name, position, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_folders';
  @override
  VerificationContext validateIntegrity(Insertable<LocalFolder> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('parent_id')) {
      context.handle(_parentIdMeta, parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta));
    }
    if (data.containsKey('name')) {
      context.handle(_nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('position')) {
      context.handle(_positionMeta, position.isAcceptableOrUnknown(data['position']!, _positionMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta, updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalFolder map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalFolder(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      parentId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}parent_id']),
      name: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      position: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}position'])!,
      updatedAt: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $LocalFoldersTable createAlias(String alias) {
    return $LocalFoldersTable(attachedDatabase, alias);
  }
}

class LocalFolder extends DataClass implements Insertable<LocalFolder> {
  final String id;
  final String? parentId;
  final String name;
  final int position;
  final DateTime updatedAt;
  const LocalFolder({
    required this.id,
    this.parentId,
    required this.name,
    required this.position,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<String>(parentId);
    }
    map['name'] = Variable<String>(name);
    map['position'] = Variable<int>(position);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  LocalFoldersCompanion toCompanion(bool nullToAbsent) {
    return LocalFoldersCompanion(
      id: Value(id),
      parentId: parentId == null && nullToAbsent ? const Value.absent() : Value(parentId),
      name: Value(name),
      position: Value(position),
      updatedAt: Value(updatedAt),
    );
  }

  factory LocalFolder.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalFolder(
      id: serializer.fromJson<String>(json['id']),
      parentId: serializer.fromJson<String?>(json['parentId']),
      name: serializer.fromJson<String>(json['name']),
      position: serializer.fromJson<int>(json['position']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'parentId': serializer.toJson<String?>(parentId),
      'name': serializer.toJson<String>(name),
      'position': serializer.toJson<int>(position),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  LocalFolder copyWith({
    String? id,
    Value<String?> parentId = const Value.absent(),
    String? name,
    int? position,
    DateTime? updatedAt,
  }) => LocalFolder(
    id: id ?? this.id,
    parentId: parentId.present ? parentId.value : this.parentId,
    name: name ?? this.name,
    position: position ?? this.position,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  LocalFolder copyWithCompanion(LocalFoldersCompanion data) {
    return LocalFolder(
      id: data.id.present ? data.id.value : this.id,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      name: data.name.present ? data.name.value : this.name,
      position: data.position.present ? data.position.value : this.position,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalFolder(')
          ..write('id: $id, ')
          ..write('parentId: $parentId, ')
          ..write('name: $name, ')
          ..write('position: $position, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, parentId, name, position, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalFolder &&
          other.id == this.id &&
          other.parentId == this.parentId &&
          other.name == this.name &&
          other.position == this.position &&
          other.updatedAt == this.updatedAt);
}

class LocalFoldersCompanion extends UpdateCompanion<LocalFolder> {
  final Value<String> id;
  final Value<String?> parentId;
  final Value<String> name;
  final Value<int> position;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const LocalFoldersCompanion({
    this.id = const Value.absent(),
    this.parentId = const Value.absent(),
    this.name = const Value.absent(),
    this.position = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalFoldersCompanion.insert({
    required String id,
    this.parentId = const Value.absent(),
    required String name,
    this.position = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       updatedAt = Value(updatedAt);
  static Insertable<LocalFolder> custom({
    Expression<String>? id,
    Expression<String>? parentId,
    Expression<String>? name,
    Expression<int>? position,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (parentId != null) 'parent_id': parentId,
      if (name != null) 'name': name,
      if (position != null) 'position': position,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalFoldersCompanion copyWith({
    Value<String>? id,
    Value<String?>? parentId,
    Value<String>? name,
    Value<int>? position,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return LocalFoldersCompanion(
      id: id ?? this.id,
      parentId: parentId ?? this.parentId,
      name: name ?? this.name,
      position: position ?? this.position,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
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
    return (StringBuffer('LocalFoldersCompanion(')
          ..write('id: $id, ')
          ..write('parentId: $parentId, ')
          ..write('name: $name, ')
          ..write('position: $position, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalNotesTable extends LocalNotes with TableInfo<$LocalNotesTable, LocalNote> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalNotesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _folderIdMeta = const VerificationMeta('folderId');
  @override
  late final GeneratedColumn<String> folderId = GeneratedColumn<String>(
    'folder_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pinnedAtMeta = const VerificationMeta('pinnedAt');
  @override
  late final GeneratedColumn<DateTime> pinnedAt = GeneratedColumn<DateTime>(
    'pinned_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _archivedAtMeta = const VerificationMeta('archivedAt');
  @override
  late final GeneratedColumn<DateTime> archivedAt = GeneratedColumn<DateTime>(
    'archived_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _checkedBehaviorMeta = const VerificationMeta('checkedBehavior');
  @override
  late final GeneratedColumn<String> checkedBehavior = GeneratedColumn<String>(
    'checked_behavior',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('move'),
  );
  static const VerificationMeta _isPrimaryMeta = const VerificationMeta('isPrimary');
  @override
  late final GeneratedColumn<bool> isPrimary = GeneratedColumn<bool>(
    'is_primary',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("is_primary" IN (0, 1))'),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _sortMeta = const VerificationMeta('sort');
  @override
  late final GeneratedColumn<int> sort = GeneratedColumn<int>(
    'sort',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    folderId,
    type,
    title,
    body,
    pinnedAt,
    archivedAt,
    deletedAt,
    checkedBehavior,
    isPrimary,
    sort,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_notes';
  @override
  VerificationContext validateIntegrity(Insertable<LocalNote> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('folder_id')) {
      context.handle(_folderIdMeta, folderId.isAcceptableOrUnknown(data['folder_id']!, _folderIdMeta));
    }
    if (data.containsKey('type')) {
      context.handle(_typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('title')) {
      context.handle(_titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    }
    if (data.containsKey('body')) {
      context.handle(_bodyMeta, body.isAcceptableOrUnknown(data['body']!, _bodyMeta));
    }
    if (data.containsKey('pinned_at')) {
      context.handle(_pinnedAtMeta, pinnedAt.isAcceptableOrUnknown(data['pinned_at']!, _pinnedAtMeta));
    }
    if (data.containsKey('archived_at')) {
      context.handle(_archivedAtMeta, archivedAt.isAcceptableOrUnknown(data['archived_at']!, _archivedAtMeta));
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta, deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    if (data.containsKey('checked_behavior')) {
      context.handle(
        _checkedBehaviorMeta,
        checkedBehavior.isAcceptableOrUnknown(data['checked_behavior']!, _checkedBehaviorMeta),
      );
    }
    if (data.containsKey('is_primary')) {
      context.handle(_isPrimaryMeta, isPrimary.isAcceptableOrUnknown(data['is_primary']!, _isPrimaryMeta));
    }
    if (data.containsKey('sort')) {
      context.handle(_sortMeta, sort.isAcceptableOrUnknown(data['sort']!, _sortMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta, createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta, updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalNote map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalNote(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      folderId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}folder_id']),
      type: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      title: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}title']),
      body: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}body']),
      pinnedAt: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}pinned_at']),
      archivedAt: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}archived_at']),
      deletedAt: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at']),
      checkedBehavior: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}checked_behavior'],
      )!,
      isPrimary: attachedDatabase.typeMapping.read(DriftSqlType.bool, data['${effectivePrefix}is_primary'])!,
      sort: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}sort'])!,
      createdAt: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $LocalNotesTable createAlias(String alias) {
    return $LocalNotesTable(attachedDatabase, alias);
  }
}

class LocalNote extends DataClass implements Insertable<LocalNote> {
  final String id;
  final String? folderId;
  final String type;
  final String? title;
  final String? body;
  final DateTime? pinnedAt;
  final DateTime? archivedAt;
  final DateTime? deletedAt;
  final String checkedBehavior;
  final bool isPrimary;
  final int sort;
  final DateTime createdAt;
  final DateTime updatedAt;
  const LocalNote({
    required this.id,
    this.folderId,
    required this.type,
    this.title,
    this.body,
    this.pinnedAt,
    this.archivedAt,
    this.deletedAt,
    required this.checkedBehavior,
    required this.isPrimary,
    required this.sort,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || folderId != null) {
      map['folder_id'] = Variable<String>(folderId);
    }
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    if (!nullToAbsent || body != null) {
      map['body'] = Variable<String>(body);
    }
    if (!nullToAbsent || pinnedAt != null) {
      map['pinned_at'] = Variable<DateTime>(pinnedAt);
    }
    if (!nullToAbsent || archivedAt != null) {
      map['archived_at'] = Variable<DateTime>(archivedAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['checked_behavior'] = Variable<String>(checkedBehavior);
    map['is_primary'] = Variable<bool>(isPrimary);
    map['sort'] = Variable<int>(sort);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  LocalNotesCompanion toCompanion(bool nullToAbsent) {
    return LocalNotesCompanion(
      id: Value(id),
      folderId: folderId == null && nullToAbsent ? const Value.absent() : Value(folderId),
      type: Value(type),
      title: title == null && nullToAbsent ? const Value.absent() : Value(title),
      body: body == null && nullToAbsent ? const Value.absent() : Value(body),
      pinnedAt: pinnedAt == null && nullToAbsent ? const Value.absent() : Value(pinnedAt),
      archivedAt: archivedAt == null && nullToAbsent ? const Value.absent() : Value(archivedAt),
      deletedAt: deletedAt == null && nullToAbsent ? const Value.absent() : Value(deletedAt),
      checkedBehavior: Value(checkedBehavior),
      isPrimary: Value(isPrimary),
      sort: Value(sort),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory LocalNote.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalNote(
      id: serializer.fromJson<String>(json['id']),
      folderId: serializer.fromJson<String?>(json['folderId']),
      type: serializer.fromJson<String>(json['type']),
      title: serializer.fromJson<String?>(json['title']),
      body: serializer.fromJson<String?>(json['body']),
      pinnedAt: serializer.fromJson<DateTime?>(json['pinnedAt']),
      archivedAt: serializer.fromJson<DateTime?>(json['archivedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      checkedBehavior: serializer.fromJson<String>(json['checkedBehavior']),
      isPrimary: serializer.fromJson<bool>(json['isPrimary']),
      sort: serializer.fromJson<int>(json['sort']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'folderId': serializer.toJson<String?>(folderId),
      'type': serializer.toJson<String>(type),
      'title': serializer.toJson<String?>(title),
      'body': serializer.toJson<String?>(body),
      'pinnedAt': serializer.toJson<DateTime?>(pinnedAt),
      'archivedAt': serializer.toJson<DateTime?>(archivedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'checkedBehavior': serializer.toJson<String>(checkedBehavior),
      'isPrimary': serializer.toJson<bool>(isPrimary),
      'sort': serializer.toJson<int>(sort),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  LocalNote copyWith({
    String? id,
    Value<String?> folderId = const Value.absent(),
    String? type,
    Value<String?> title = const Value.absent(),
    Value<String?> body = const Value.absent(),
    Value<DateTime?> pinnedAt = const Value.absent(),
    Value<DateTime?> archivedAt = const Value.absent(),
    Value<DateTime?> deletedAt = const Value.absent(),
    String? checkedBehavior,
    bool? isPrimary,
    int? sort,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => LocalNote(
    id: id ?? this.id,
    folderId: folderId.present ? folderId.value : this.folderId,
    type: type ?? this.type,
    title: title.present ? title.value : this.title,
    body: body.present ? body.value : this.body,
    pinnedAt: pinnedAt.present ? pinnedAt.value : this.pinnedAt,
    archivedAt: archivedAt.present ? archivedAt.value : this.archivedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    checkedBehavior: checkedBehavior ?? this.checkedBehavior,
    isPrimary: isPrimary ?? this.isPrimary,
    sort: sort ?? this.sort,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  LocalNote copyWithCompanion(LocalNotesCompanion data) {
    return LocalNote(
      id: data.id.present ? data.id.value : this.id,
      folderId: data.folderId.present ? data.folderId.value : this.folderId,
      type: data.type.present ? data.type.value : this.type,
      title: data.title.present ? data.title.value : this.title,
      body: data.body.present ? data.body.value : this.body,
      pinnedAt: data.pinnedAt.present ? data.pinnedAt.value : this.pinnedAt,
      archivedAt: data.archivedAt.present ? data.archivedAt.value : this.archivedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      checkedBehavior: data.checkedBehavior.present ? data.checkedBehavior.value : this.checkedBehavior,
      isPrimary: data.isPrimary.present ? data.isPrimary.value : this.isPrimary,
      sort: data.sort.present ? data.sort.value : this.sort,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalNote(')
          ..write('id: $id, ')
          ..write('folderId: $folderId, ')
          ..write('type: $type, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('pinnedAt: $pinnedAt, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('checkedBehavior: $checkedBehavior, ')
          ..write('isPrimary: $isPrimary, ')
          ..write('sort: $sort, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    folderId,
    type,
    title,
    body,
    pinnedAt,
    archivedAt,
    deletedAt,
    checkedBehavior,
    isPrimary,
    sort,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalNote &&
          other.id == this.id &&
          other.folderId == this.folderId &&
          other.type == this.type &&
          other.title == this.title &&
          other.body == this.body &&
          other.pinnedAt == this.pinnedAt &&
          other.archivedAt == this.archivedAt &&
          other.deletedAt == this.deletedAt &&
          other.checkedBehavior == this.checkedBehavior &&
          other.isPrimary == this.isPrimary &&
          other.sort == this.sort &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class LocalNotesCompanion extends UpdateCompanion<LocalNote> {
  final Value<String> id;
  final Value<String?> folderId;
  final Value<String> type;
  final Value<String?> title;
  final Value<String?> body;
  final Value<DateTime?> pinnedAt;
  final Value<DateTime?> archivedAt;
  final Value<DateTime?> deletedAt;
  final Value<String> checkedBehavior;
  final Value<bool> isPrimary;
  final Value<int> sort;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const LocalNotesCompanion({
    this.id = const Value.absent(),
    this.folderId = const Value.absent(),
    this.type = const Value.absent(),
    this.title = const Value.absent(),
    this.body = const Value.absent(),
    this.pinnedAt = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.checkedBehavior = const Value.absent(),
    this.isPrimary = const Value.absent(),
    this.sort = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalNotesCompanion.insert({
    required String id,
    this.folderId = const Value.absent(),
    required String type,
    this.title = const Value.absent(),
    this.body = const Value.absent(),
    this.pinnedAt = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.checkedBehavior = const Value.absent(),
    this.isPrimary = const Value.absent(),
    this.sort = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       type = Value(type),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<LocalNote> custom({
    Expression<String>? id,
    Expression<String>? folderId,
    Expression<String>? type,
    Expression<String>? title,
    Expression<String>? body,
    Expression<DateTime>? pinnedAt,
    Expression<DateTime>? archivedAt,
    Expression<DateTime>? deletedAt,
    Expression<String>? checkedBehavior,
    Expression<bool>? isPrimary,
    Expression<int>? sort,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (folderId != null) 'folder_id': folderId,
      if (type != null) 'type': type,
      if (title != null) 'title': title,
      if (body != null) 'body': body,
      if (pinnedAt != null) 'pinned_at': pinnedAt,
      if (archivedAt != null) 'archived_at': archivedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (checkedBehavior != null) 'checked_behavior': checkedBehavior,
      if (isPrimary != null) 'is_primary': isPrimary,
      if (sort != null) 'sort': sort,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalNotesCompanion copyWith({
    Value<String>? id,
    Value<String?>? folderId,
    Value<String>? type,
    Value<String?>? title,
    Value<String?>? body,
    Value<DateTime?>? pinnedAt,
    Value<DateTime?>? archivedAt,
    Value<DateTime?>? deletedAt,
    Value<String>? checkedBehavior,
    Value<bool>? isPrimary,
    Value<int>? sort,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return LocalNotesCompanion(
      id: id ?? this.id,
      folderId: folderId ?? this.folderId,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      pinnedAt: pinnedAt ?? this.pinnedAt,
      archivedAt: archivedAt ?? this.archivedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      checkedBehavior: checkedBehavior ?? this.checkedBehavior,
      isPrimary: isPrimary ?? this.isPrimary,
      sort: sort ?? this.sort,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (folderId.present) {
      map['folder_id'] = Variable<String>(folderId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (pinnedAt.present) {
      map['pinned_at'] = Variable<DateTime>(pinnedAt.value);
    }
    if (archivedAt.present) {
      map['archived_at'] = Variable<DateTime>(archivedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (checkedBehavior.present) {
      map['checked_behavior'] = Variable<String>(checkedBehavior.value);
    }
    if (isPrimary.present) {
      map['is_primary'] = Variable<bool>(isPrimary.value);
    }
    if (sort.present) {
      map['sort'] = Variable<int>(sort.value);
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
    return (StringBuffer('LocalNotesCompanion(')
          ..write('id: $id, ')
          ..write('folderId: $folderId, ')
          ..write('type: $type, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('pinnedAt: $pinnedAt, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('checkedBehavior: $checkedBehavior, ')
          ..write('isPrimary: $isPrimary, ')
          ..write('sort: $sort, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalItemsTable extends LocalItems with TableInfo<$LocalItemsTable, LocalItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteIdMeta = const VerificationMeta('noteId');
  @override
  late final GeneratedColumn<String> noteId = GeneratedColumn<String>(
    'note_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _productIdMeta = const VerificationMeta('productId');
  @override
  late final GeneratedColumn<String> productId = GeneratedColumn<String>(
    'product_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta('content');
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quantityMeta = const VerificationMeta('quantity');
  @override
  late final GeneratedColumn<String> quantity = GeneratedColumn<String>(
    'quantity',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sectionIdMeta = const VerificationMeta('sectionId');
  @override
  late final GeneratedColumn<String> sectionId = GeneratedColumn<String>(
    'section_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _checkedAtMeta = const VerificationMeta('checkedAt');
  @override
  late final GeneratedColumn<DateTime> checkedAt = GeneratedColumn<DateTime>(
    'checked_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta('position');
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    noteId,
    productId,
    content,
    quantity,
    sectionId,
    checkedAt,
    position,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_items';
  @override
  VerificationContext validateIntegrity(Insertable<LocalItem> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('note_id')) {
      context.handle(_noteIdMeta, noteId.isAcceptableOrUnknown(data['note_id']!, _noteIdMeta));
    } else if (isInserting) {
      context.missing(_noteIdMeta);
    }
    if (data.containsKey('product_id')) {
      context.handle(_productIdMeta, productId.isAcceptableOrUnknown(data['product_id']!, _productIdMeta));
    }
    if (data.containsKey('content')) {
      context.handle(_contentMeta, content.isAcceptableOrUnknown(data['content']!, _contentMeta));
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(_quantityMeta, quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta));
    }
    if (data.containsKey('section_id')) {
      context.handle(_sectionIdMeta, sectionId.isAcceptableOrUnknown(data['section_id']!, _sectionIdMeta));
    }
    if (data.containsKey('checked_at')) {
      context.handle(_checkedAtMeta, checkedAt.isAcceptableOrUnknown(data['checked_at']!, _checkedAtMeta));
    }
    if (data.containsKey('position')) {
      context.handle(_positionMeta, position.isAcceptableOrUnknown(data['position']!, _positionMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta, updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalItem(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      noteId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}note_id'])!,
      productId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}product_id']),
      content: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}content'])!,
      quantity: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}quantity']),
      sectionId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}section_id']),
      checkedAt: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}checked_at']),
      position: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}position'])!,
      updatedAt: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $LocalItemsTable createAlias(String alias) {
    return $LocalItemsTable(attachedDatabase, alias);
  }
}

class LocalItem extends DataClass implements Insertable<LocalItem> {
  final String id;
  final String noteId;
  final String? productId;
  final String content;
  final String? quantity;
  final String? sectionId;
  final DateTime? checkedAt;
  final int position;
  final DateTime updatedAt;
  const LocalItem({
    required this.id,
    required this.noteId,
    this.productId,
    required this.content,
    this.quantity,
    this.sectionId,
    this.checkedAt,
    required this.position,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['note_id'] = Variable<String>(noteId);
    if (!nullToAbsent || productId != null) {
      map['product_id'] = Variable<String>(productId);
    }
    map['content'] = Variable<String>(content);
    if (!nullToAbsent || quantity != null) {
      map['quantity'] = Variable<String>(quantity);
    }
    if (!nullToAbsent || sectionId != null) {
      map['section_id'] = Variable<String>(sectionId);
    }
    if (!nullToAbsent || checkedAt != null) {
      map['checked_at'] = Variable<DateTime>(checkedAt);
    }
    map['position'] = Variable<int>(position);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  LocalItemsCompanion toCompanion(bool nullToAbsent) {
    return LocalItemsCompanion(
      id: Value(id),
      noteId: Value(noteId),
      productId: productId == null && nullToAbsent ? const Value.absent() : Value(productId),
      content: Value(content),
      quantity: quantity == null && nullToAbsent ? const Value.absent() : Value(quantity),
      sectionId: sectionId == null && nullToAbsent ? const Value.absent() : Value(sectionId),
      checkedAt: checkedAt == null && nullToAbsent ? const Value.absent() : Value(checkedAt),
      position: Value(position),
      updatedAt: Value(updatedAt),
    );
  }

  factory LocalItem.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalItem(
      id: serializer.fromJson<String>(json['id']),
      noteId: serializer.fromJson<String>(json['noteId']),
      productId: serializer.fromJson<String?>(json['productId']),
      content: serializer.fromJson<String>(json['content']),
      quantity: serializer.fromJson<String?>(json['quantity']),
      sectionId: serializer.fromJson<String?>(json['sectionId']),
      checkedAt: serializer.fromJson<DateTime?>(json['checkedAt']),
      position: serializer.fromJson<int>(json['position']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'noteId': serializer.toJson<String>(noteId),
      'productId': serializer.toJson<String?>(productId),
      'content': serializer.toJson<String>(content),
      'quantity': serializer.toJson<String?>(quantity),
      'sectionId': serializer.toJson<String?>(sectionId),
      'checkedAt': serializer.toJson<DateTime?>(checkedAt),
      'position': serializer.toJson<int>(position),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  LocalItem copyWith({
    String? id,
    String? noteId,
    Value<String?> productId = const Value.absent(),
    String? content,
    Value<String?> quantity = const Value.absent(),
    Value<String?> sectionId = const Value.absent(),
    Value<DateTime?> checkedAt = const Value.absent(),
    int? position,
    DateTime? updatedAt,
  }) => LocalItem(
    id: id ?? this.id,
    noteId: noteId ?? this.noteId,
    productId: productId.present ? productId.value : this.productId,
    content: content ?? this.content,
    quantity: quantity.present ? quantity.value : this.quantity,
    sectionId: sectionId.present ? sectionId.value : this.sectionId,
    checkedAt: checkedAt.present ? checkedAt.value : this.checkedAt,
    position: position ?? this.position,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  LocalItem copyWithCompanion(LocalItemsCompanion data) {
    return LocalItem(
      id: data.id.present ? data.id.value : this.id,
      noteId: data.noteId.present ? data.noteId.value : this.noteId,
      productId: data.productId.present ? data.productId.value : this.productId,
      content: data.content.present ? data.content.value : this.content,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      sectionId: data.sectionId.present ? data.sectionId.value : this.sectionId,
      checkedAt: data.checkedAt.present ? data.checkedAt.value : this.checkedAt,
      position: data.position.present ? data.position.value : this.position,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalItem(')
          ..write('id: $id, ')
          ..write('noteId: $noteId, ')
          ..write('productId: $productId, ')
          ..write('content: $content, ')
          ..write('quantity: $quantity, ')
          ..write('sectionId: $sectionId, ')
          ..write('checkedAt: $checkedAt, ')
          ..write('position: $position, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, noteId, productId, content, quantity, sectionId, checkedAt, position, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalItem &&
          other.id == this.id &&
          other.noteId == this.noteId &&
          other.productId == this.productId &&
          other.content == this.content &&
          other.quantity == this.quantity &&
          other.sectionId == this.sectionId &&
          other.checkedAt == this.checkedAt &&
          other.position == this.position &&
          other.updatedAt == this.updatedAt);
}

class LocalItemsCompanion extends UpdateCompanion<LocalItem> {
  final Value<String> id;
  final Value<String> noteId;
  final Value<String?> productId;
  final Value<String> content;
  final Value<String?> quantity;
  final Value<String?> sectionId;
  final Value<DateTime?> checkedAt;
  final Value<int> position;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const LocalItemsCompanion({
    this.id = const Value.absent(),
    this.noteId = const Value.absent(),
    this.productId = const Value.absent(),
    this.content = const Value.absent(),
    this.quantity = const Value.absent(),
    this.sectionId = const Value.absent(),
    this.checkedAt = const Value.absent(),
    this.position = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalItemsCompanion.insert({
    required String id,
    required String noteId,
    this.productId = const Value.absent(),
    required String content,
    this.quantity = const Value.absent(),
    this.sectionId = const Value.absent(),
    this.checkedAt = const Value.absent(),
    this.position = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       noteId = Value(noteId),
       content = Value(content),
       updatedAt = Value(updatedAt);
  static Insertable<LocalItem> custom({
    Expression<String>? id,
    Expression<String>? noteId,
    Expression<String>? productId,
    Expression<String>? content,
    Expression<String>? quantity,
    Expression<String>? sectionId,
    Expression<DateTime>? checkedAt,
    Expression<int>? position,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (noteId != null) 'note_id': noteId,
      if (productId != null) 'product_id': productId,
      if (content != null) 'content': content,
      if (quantity != null) 'quantity': quantity,
      if (sectionId != null) 'section_id': sectionId,
      if (checkedAt != null) 'checked_at': checkedAt,
      if (position != null) 'position': position,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? noteId,
    Value<String?>? productId,
    Value<String>? content,
    Value<String?>? quantity,
    Value<String?>? sectionId,
    Value<DateTime?>? checkedAt,
    Value<int>? position,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return LocalItemsCompanion(
      id: id ?? this.id,
      noteId: noteId ?? this.noteId,
      productId: productId ?? this.productId,
      content: content ?? this.content,
      quantity: quantity ?? this.quantity,
      sectionId: sectionId ?? this.sectionId,
      checkedAt: checkedAt ?? this.checkedAt,
      position: position ?? this.position,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (noteId.present) {
      map['note_id'] = Variable<String>(noteId.value);
    }
    if (productId.present) {
      map['product_id'] = Variable<String>(productId.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<String>(quantity.value);
    }
    if (sectionId.present) {
      map['section_id'] = Variable<String>(sectionId.value);
    }
    if (checkedAt.present) {
      map['checked_at'] = Variable<DateTime>(checkedAt.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
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
    return (StringBuffer('LocalItemsCompanion(')
          ..write('id: $id, ')
          ..write('noteId: $noteId, ')
          ..write('productId: $productId, ')
          ..write('content: $content, ')
          ..write('quantity: $quantity, ')
          ..write('sectionId: $sectionId, ')
          ..write('checkedAt: $checkedAt, ')
          ..write('position: $position, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalSectionsTable extends LocalSections with TableInfo<$LocalSectionsTable, LocalSection> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalSectionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta('position');
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, position, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_sections';
  @override
  VerificationContext validateIntegrity(Insertable<LocalSection> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(_nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('position')) {
      context.handle(_positionMeta, position.isAcceptableOrUnknown(data['position']!, _positionMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta, updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalSection map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalSection(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      position: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}position'])!,
      updatedAt: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $LocalSectionsTable createAlias(String alias) {
    return $LocalSectionsTable(attachedDatabase, alias);
  }
}

class LocalSection extends DataClass implements Insertable<LocalSection> {
  final String id;
  final String name;
  final int position;
  final DateTime updatedAt;
  const LocalSection({required this.id, required this.name, required this.position, required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['position'] = Variable<int>(position);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  LocalSectionsCompanion toCompanion(bool nullToAbsent) {
    return LocalSectionsCompanion(
      id: Value(id),
      name: Value(name),
      position: Value(position),
      updatedAt: Value(updatedAt),
    );
  }

  factory LocalSection.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalSection(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      position: serializer.fromJson<int>(json['position']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'position': serializer.toJson<int>(position),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  LocalSection copyWith({String? id, String? name, int? position, DateTime? updatedAt}) => LocalSection(
    id: id ?? this.id,
    name: name ?? this.name,
    position: position ?? this.position,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  LocalSection copyWithCompanion(LocalSectionsCompanion data) {
    return LocalSection(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      position: data.position.present ? data.position.value : this.position,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalSection(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('position: $position, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, position, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalSection &&
          other.id == this.id &&
          other.name == this.name &&
          other.position == this.position &&
          other.updatedAt == this.updatedAt);
}

class LocalSectionsCompanion extends UpdateCompanion<LocalSection> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> position;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const LocalSectionsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.position = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalSectionsCompanion.insert({
    required String id,
    required String name,
    this.position = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       updatedAt = Value(updatedAt);
  static Insertable<LocalSection> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? position,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (position != null) 'position': position,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalSectionsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int>? position,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return LocalSectionsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      position: position ?? this.position,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
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
    return (StringBuffer('LocalSectionsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('position: $position, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalProductsTable extends LocalProducts with TableInfo<$LocalProductsTable, LocalProduct> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalProductsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteIdMeta = const VerificationMeta('noteId');
  @override
  late final GeneratedColumn<String> noteId = GeneratedColumn<String>(
    'note_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sectionIdMeta = const VerificationMeta('sectionId');
  @override
  late final GeneratedColumn<String> sectionId = GeneratedColumn<String>(
    'section_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _defaultQuantityMeta = const VerificationMeta('defaultQuantity');
  @override
  late final GeneratedColumn<String> defaultQuantity = GeneratedColumn<String>(
    'default_quantity',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _restockModeMeta = const VerificationMeta('restockMode');
  @override
  late final GeneratedColumn<String> restockMode = GeneratedColumn<String>(
    'restock_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('none'),
  );
  static const VerificationMeta _restockIntervalDaysMeta = const VerificationMeta('restockIntervalDays');
  @override
  late final GeneratedColumn<int> restockIntervalDays = GeneratedColumn<int>(
    'restock_interval_days',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastBoughtAtMeta = const VerificationMeta('lastBoughtAt');
  @override
  late final GeneratedColumn<DateTime> lastBoughtAt = GeneratedColumn<DateTime>(
    'last_bought_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _timesBoughtMeta = const VerificationMeta('timesBought');
  @override
  late final GeneratedColumn<int> timesBought = GeneratedColumn<int>(
    'times_bought',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _restockedForMeta = const VerificationMeta('restockedFor');
  @override
  late final GeneratedColumn<String> restockedFor = GeneratedColumn<String>(
    'restocked_for',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    noteId,
    name,
    sectionId,
    defaultQuantity,
    restockMode,
    restockIntervalDays,
    lastBoughtAt,
    timesBought,
    restockedFor,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_products';
  @override
  VerificationContext validateIntegrity(Insertable<LocalProduct> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('note_id')) {
      context.handle(_noteIdMeta, noteId.isAcceptableOrUnknown(data['note_id']!, _noteIdMeta));
    } else if (isInserting) {
      context.missing(_noteIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(_nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('section_id')) {
      context.handle(_sectionIdMeta, sectionId.isAcceptableOrUnknown(data['section_id']!, _sectionIdMeta));
    }
    if (data.containsKey('default_quantity')) {
      context.handle(
        _defaultQuantityMeta,
        defaultQuantity.isAcceptableOrUnknown(data['default_quantity']!, _defaultQuantityMeta),
      );
    }
    if (data.containsKey('restock_mode')) {
      context.handle(_restockModeMeta, restockMode.isAcceptableOrUnknown(data['restock_mode']!, _restockModeMeta));
    }
    if (data.containsKey('restock_interval_days')) {
      context.handle(
        _restockIntervalDaysMeta,
        restockIntervalDays.isAcceptableOrUnknown(data['restock_interval_days']!, _restockIntervalDaysMeta),
      );
    }
    if (data.containsKey('last_bought_at')) {
      context.handle(_lastBoughtAtMeta, lastBoughtAt.isAcceptableOrUnknown(data['last_bought_at']!, _lastBoughtAtMeta));
    }
    if (data.containsKey('times_bought')) {
      context.handle(_timesBoughtMeta, timesBought.isAcceptableOrUnknown(data['times_bought']!, _timesBoughtMeta));
    }
    if (data.containsKey('restocked_for')) {
      context.handle(_restockedForMeta, restockedFor.isAcceptableOrUnknown(data['restocked_for']!, _restockedForMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta, updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalProduct map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalProduct(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      noteId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}note_id'])!,
      name: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      sectionId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}section_id']),
      defaultQuantity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}default_quantity'],
      ),
      restockMode: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}restock_mode'])!,
      restockIntervalDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}restock_interval_days'],
      ),
      lastBoughtAt: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}last_bought_at']),
      timesBought: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}times_bought'])!,
      restockedFor: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}restocked_for']),
      updatedAt: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $LocalProductsTable createAlias(String alias) {
    return $LocalProductsTable(attachedDatabase, alias);
  }
}

class LocalProduct extends DataClass implements Insertable<LocalProduct> {
  final String id;
  final String noteId;
  final String name;
  final String? sectionId;
  final String? defaultQuantity;
  final String restockMode;
  final int? restockIntervalDays;
  final DateTime? lastBoughtAt;
  final int timesBought;
  final String? restockedFor;
  final DateTime updatedAt;
  const LocalProduct({
    required this.id,
    required this.noteId,
    required this.name,
    this.sectionId,
    this.defaultQuantity,
    required this.restockMode,
    this.restockIntervalDays,
    this.lastBoughtAt,
    required this.timesBought,
    this.restockedFor,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['note_id'] = Variable<String>(noteId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || sectionId != null) {
      map['section_id'] = Variable<String>(sectionId);
    }
    if (!nullToAbsent || defaultQuantity != null) {
      map['default_quantity'] = Variable<String>(defaultQuantity);
    }
    map['restock_mode'] = Variable<String>(restockMode);
    if (!nullToAbsent || restockIntervalDays != null) {
      map['restock_interval_days'] = Variable<int>(restockIntervalDays);
    }
    if (!nullToAbsent || lastBoughtAt != null) {
      map['last_bought_at'] = Variable<DateTime>(lastBoughtAt);
    }
    map['times_bought'] = Variable<int>(timesBought);
    if (!nullToAbsent || restockedFor != null) {
      map['restocked_for'] = Variable<String>(restockedFor);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  LocalProductsCompanion toCompanion(bool nullToAbsent) {
    return LocalProductsCompanion(
      id: Value(id),
      noteId: Value(noteId),
      name: Value(name),
      sectionId: sectionId == null && nullToAbsent ? const Value.absent() : Value(sectionId),
      defaultQuantity: defaultQuantity == null && nullToAbsent ? const Value.absent() : Value(defaultQuantity),
      restockMode: Value(restockMode),
      restockIntervalDays: restockIntervalDays == null && nullToAbsent
          ? const Value.absent()
          : Value(restockIntervalDays),
      lastBoughtAt: lastBoughtAt == null && nullToAbsent ? const Value.absent() : Value(lastBoughtAt),
      timesBought: Value(timesBought),
      restockedFor: restockedFor == null && nullToAbsent ? const Value.absent() : Value(restockedFor),
      updatedAt: Value(updatedAt),
    );
  }

  factory LocalProduct.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalProduct(
      id: serializer.fromJson<String>(json['id']),
      noteId: serializer.fromJson<String>(json['noteId']),
      name: serializer.fromJson<String>(json['name']),
      sectionId: serializer.fromJson<String?>(json['sectionId']),
      defaultQuantity: serializer.fromJson<String?>(json['defaultQuantity']),
      restockMode: serializer.fromJson<String>(json['restockMode']),
      restockIntervalDays: serializer.fromJson<int?>(json['restockIntervalDays']),
      lastBoughtAt: serializer.fromJson<DateTime?>(json['lastBoughtAt']),
      timesBought: serializer.fromJson<int>(json['timesBought']),
      restockedFor: serializer.fromJson<String?>(json['restockedFor']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'noteId': serializer.toJson<String>(noteId),
      'name': serializer.toJson<String>(name),
      'sectionId': serializer.toJson<String?>(sectionId),
      'defaultQuantity': serializer.toJson<String?>(defaultQuantity),
      'restockMode': serializer.toJson<String>(restockMode),
      'restockIntervalDays': serializer.toJson<int?>(restockIntervalDays),
      'lastBoughtAt': serializer.toJson<DateTime?>(lastBoughtAt),
      'timesBought': serializer.toJson<int>(timesBought),
      'restockedFor': serializer.toJson<String?>(restockedFor),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  LocalProduct copyWith({
    String? id,
    String? noteId,
    String? name,
    Value<String?> sectionId = const Value.absent(),
    Value<String?> defaultQuantity = const Value.absent(),
    String? restockMode,
    Value<int?> restockIntervalDays = const Value.absent(),
    Value<DateTime?> lastBoughtAt = const Value.absent(),
    int? timesBought,
    Value<String?> restockedFor = const Value.absent(),
    DateTime? updatedAt,
  }) => LocalProduct(
    id: id ?? this.id,
    noteId: noteId ?? this.noteId,
    name: name ?? this.name,
    sectionId: sectionId.present ? sectionId.value : this.sectionId,
    defaultQuantity: defaultQuantity.present ? defaultQuantity.value : this.defaultQuantity,
    restockMode: restockMode ?? this.restockMode,
    restockIntervalDays: restockIntervalDays.present ? restockIntervalDays.value : this.restockIntervalDays,
    lastBoughtAt: lastBoughtAt.present ? lastBoughtAt.value : this.lastBoughtAt,
    timesBought: timesBought ?? this.timesBought,
    restockedFor: restockedFor.present ? restockedFor.value : this.restockedFor,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  LocalProduct copyWithCompanion(LocalProductsCompanion data) {
    return LocalProduct(
      id: data.id.present ? data.id.value : this.id,
      noteId: data.noteId.present ? data.noteId.value : this.noteId,
      name: data.name.present ? data.name.value : this.name,
      sectionId: data.sectionId.present ? data.sectionId.value : this.sectionId,
      defaultQuantity: data.defaultQuantity.present ? data.defaultQuantity.value : this.defaultQuantity,
      restockMode: data.restockMode.present ? data.restockMode.value : this.restockMode,
      restockIntervalDays: data.restockIntervalDays.present ? data.restockIntervalDays.value : this.restockIntervalDays,
      lastBoughtAt: data.lastBoughtAt.present ? data.lastBoughtAt.value : this.lastBoughtAt,
      timesBought: data.timesBought.present ? data.timesBought.value : this.timesBought,
      restockedFor: data.restockedFor.present ? data.restockedFor.value : this.restockedFor,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalProduct(')
          ..write('id: $id, ')
          ..write('noteId: $noteId, ')
          ..write('name: $name, ')
          ..write('sectionId: $sectionId, ')
          ..write('defaultQuantity: $defaultQuantity, ')
          ..write('restockMode: $restockMode, ')
          ..write('restockIntervalDays: $restockIntervalDays, ')
          ..write('lastBoughtAt: $lastBoughtAt, ')
          ..write('timesBought: $timesBought, ')
          ..write('restockedFor: $restockedFor, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    noteId,
    name,
    sectionId,
    defaultQuantity,
    restockMode,
    restockIntervalDays,
    lastBoughtAt,
    timesBought,
    restockedFor,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalProduct &&
          other.id == this.id &&
          other.noteId == this.noteId &&
          other.name == this.name &&
          other.sectionId == this.sectionId &&
          other.defaultQuantity == this.defaultQuantity &&
          other.restockMode == this.restockMode &&
          other.restockIntervalDays == this.restockIntervalDays &&
          other.lastBoughtAt == this.lastBoughtAt &&
          other.timesBought == this.timesBought &&
          other.restockedFor == this.restockedFor &&
          other.updatedAt == this.updatedAt);
}

class LocalProductsCompanion extends UpdateCompanion<LocalProduct> {
  final Value<String> id;
  final Value<String> noteId;
  final Value<String> name;
  final Value<String?> sectionId;
  final Value<String?> defaultQuantity;
  final Value<String> restockMode;
  final Value<int?> restockIntervalDays;
  final Value<DateTime?> lastBoughtAt;
  final Value<int> timesBought;
  final Value<String?> restockedFor;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const LocalProductsCompanion({
    this.id = const Value.absent(),
    this.noteId = const Value.absent(),
    this.name = const Value.absent(),
    this.sectionId = const Value.absent(),
    this.defaultQuantity = const Value.absent(),
    this.restockMode = const Value.absent(),
    this.restockIntervalDays = const Value.absent(),
    this.lastBoughtAt = const Value.absent(),
    this.timesBought = const Value.absent(),
    this.restockedFor = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalProductsCompanion.insert({
    required String id,
    required String noteId,
    required String name,
    this.sectionId = const Value.absent(),
    this.defaultQuantity = const Value.absent(),
    this.restockMode = const Value.absent(),
    this.restockIntervalDays = const Value.absent(),
    this.lastBoughtAt = const Value.absent(),
    this.timesBought = const Value.absent(),
    this.restockedFor = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       noteId = Value(noteId),
       name = Value(name),
       updatedAt = Value(updatedAt);
  static Insertable<LocalProduct> custom({
    Expression<String>? id,
    Expression<String>? noteId,
    Expression<String>? name,
    Expression<String>? sectionId,
    Expression<String>? defaultQuantity,
    Expression<String>? restockMode,
    Expression<int>? restockIntervalDays,
    Expression<DateTime>? lastBoughtAt,
    Expression<int>? timesBought,
    Expression<String>? restockedFor,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (noteId != null) 'note_id': noteId,
      if (name != null) 'name': name,
      if (sectionId != null) 'section_id': sectionId,
      if (defaultQuantity != null) 'default_quantity': defaultQuantity,
      if (restockMode != null) 'restock_mode': restockMode,
      if (restockIntervalDays != null) 'restock_interval_days': restockIntervalDays,
      if (lastBoughtAt != null) 'last_bought_at': lastBoughtAt,
      if (timesBought != null) 'times_bought': timesBought,
      if (restockedFor != null) 'restocked_for': restockedFor,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalProductsCompanion copyWith({
    Value<String>? id,
    Value<String>? noteId,
    Value<String>? name,
    Value<String?>? sectionId,
    Value<String?>? defaultQuantity,
    Value<String>? restockMode,
    Value<int?>? restockIntervalDays,
    Value<DateTime?>? lastBoughtAt,
    Value<int>? timesBought,
    Value<String?>? restockedFor,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return LocalProductsCompanion(
      id: id ?? this.id,
      noteId: noteId ?? this.noteId,
      name: name ?? this.name,
      sectionId: sectionId ?? this.sectionId,
      defaultQuantity: defaultQuantity ?? this.defaultQuantity,
      restockMode: restockMode ?? this.restockMode,
      restockIntervalDays: restockIntervalDays ?? this.restockIntervalDays,
      lastBoughtAt: lastBoughtAt ?? this.lastBoughtAt,
      timesBought: timesBought ?? this.timesBought,
      restockedFor: restockedFor ?? this.restockedFor,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (noteId.present) {
      map['note_id'] = Variable<String>(noteId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (sectionId.present) {
      map['section_id'] = Variable<String>(sectionId.value);
    }
    if (defaultQuantity.present) {
      map['default_quantity'] = Variable<String>(defaultQuantity.value);
    }
    if (restockMode.present) {
      map['restock_mode'] = Variable<String>(restockMode.value);
    }
    if (restockIntervalDays.present) {
      map['restock_interval_days'] = Variable<int>(restockIntervalDays.value);
    }
    if (lastBoughtAt.present) {
      map['last_bought_at'] = Variable<DateTime>(lastBoughtAt.value);
    }
    if (timesBought.present) {
      map['times_bought'] = Variable<int>(timesBought.value);
    }
    if (restockedFor.present) {
      map['restocked_for'] = Variable<String>(restockedFor.value);
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
    return (StringBuffer('LocalProductsCompanion(')
          ..write('id: $id, ')
          ..write('noteId: $noteId, ')
          ..write('name: $name, ')
          ..write('sectionId: $sectionId, ')
          ..write('defaultQuantity: $defaultQuantity, ')
          ..write('restockMode: $restockMode, ')
          ..write('restockIntervalDays: $restockIntervalDays, ')
          ..write('lastBoughtAt: $lastBoughtAt, ')
          ..write('timesBought: $timesBought, ')
          ..write('restockedFor: $restockedFor, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PendingOperationsTable extends PendingOperations with TableInfo<$PendingOperationsTable, PendingOperation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingOperationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'),
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _atMeta = const VerificationMeta('at');
  @override
  late final GeneratedColumn<DateTime> at = GeneratedColumn<DateTime>(
    'at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta('payload');
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [seq, id, type, at, payload];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_operations';
  @override
  VerificationContext validateIntegrity(Insertable<PendingOperation> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('seq')) {
      context.handle(_seqMeta, seq.isAcceptableOrUnknown(data['seq']!, _seqMeta));
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('type')) {
      context.handle(_typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('at')) {
      context.handle(_atMeta, at.isAcceptableOrUnknown(data['at']!, _atMeta));
    } else if (isInserting) {
      context.missing(_atMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(_payloadMeta, payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta));
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {seq};
  @override
  PendingOperation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingOperation(
      seq: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}seq'])!,
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      type: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      at: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}at'])!,
      payload: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}payload'])!,
    );
  }

  @override
  $PendingOperationsTable createAlias(String alias) {
    return $PendingOperationsTable(attachedDatabase, alias);
  }
}

class PendingOperation extends DataClass implements Insertable<PendingOperation> {
  final int seq;
  final String id;
  final String type;
  final DateTime at;
  final String payload;
  const PendingOperation({
    required this.seq,
    required this.id,
    required this.type,
    required this.at,
    required this.payload,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['seq'] = Variable<int>(seq);
    map['id'] = Variable<String>(id);
    map['type'] = Variable<String>(type);
    map['at'] = Variable<DateTime>(at);
    map['payload'] = Variable<String>(payload);
    return map;
  }

  PendingOperationsCompanion toCompanion(bool nullToAbsent) {
    return PendingOperationsCompanion(
      seq: Value(seq),
      id: Value(id),
      type: Value(type),
      at: Value(at),
      payload: Value(payload),
    );
  }

  factory PendingOperation.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingOperation(
      seq: serializer.fromJson<int>(json['seq']),
      id: serializer.fromJson<String>(json['id']),
      type: serializer.fromJson<String>(json['type']),
      at: serializer.fromJson<DateTime>(json['at']),
      payload: serializer.fromJson<String>(json['payload']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'seq': serializer.toJson<int>(seq),
      'id': serializer.toJson<String>(id),
      'type': serializer.toJson<String>(type),
      'at': serializer.toJson<DateTime>(at),
      'payload': serializer.toJson<String>(payload),
    };
  }

  PendingOperation copyWith({int? seq, String? id, String? type, DateTime? at, String? payload}) => PendingOperation(
    seq: seq ?? this.seq,
    id: id ?? this.id,
    type: type ?? this.type,
    at: at ?? this.at,
    payload: payload ?? this.payload,
  );
  PendingOperation copyWithCompanion(PendingOperationsCompanion data) {
    return PendingOperation(
      seq: data.seq.present ? data.seq.value : this.seq,
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      at: data.at.present ? data.at.value : this.at,
      payload: data.payload.present ? data.payload.value : this.payload,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingOperation(')
          ..write('seq: $seq, ')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('at: $at, ')
          ..write('payload: $payload')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(seq, id, type, at, payload);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingOperation &&
          other.seq == this.seq &&
          other.id == this.id &&
          other.type == this.type &&
          other.at == this.at &&
          other.payload == this.payload);
}

class PendingOperationsCompanion extends UpdateCompanion<PendingOperation> {
  final Value<int> seq;
  final Value<String> id;
  final Value<String> type;
  final Value<DateTime> at;
  final Value<String> payload;
  const PendingOperationsCompanion({
    this.seq = const Value.absent(),
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.at = const Value.absent(),
    this.payload = const Value.absent(),
  });
  PendingOperationsCompanion.insert({
    this.seq = const Value.absent(),
    required String id,
    required String type,
    required DateTime at,
    required String payload,
  }) : id = Value(id),
       type = Value(type),
       at = Value(at),
       payload = Value(payload);
  static Insertable<PendingOperation> custom({
    Expression<int>? seq,
    Expression<String>? id,
    Expression<String>? type,
    Expression<DateTime>? at,
    Expression<String>? payload,
  }) {
    return RawValuesInsertable({
      if (seq != null) 'seq': seq,
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (at != null) 'at': at,
      if (payload != null) 'payload': payload,
    });
  }

  PendingOperationsCompanion copyWith({
    Value<int>? seq,
    Value<String>? id,
    Value<String>? type,
    Value<DateTime>? at,
    Value<String>? payload,
  }) {
    return PendingOperationsCompanion(
      seq: seq ?? this.seq,
      id: id ?? this.id,
      type: type ?? this.type,
      at: at ?? this.at,
      payload: payload ?? this.payload,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (at.present) {
      map['at'] = Variable<DateTime>(at.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingOperationsCompanion(')
          ..write('seq: $seq, ')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('at: $at, ')
          ..write('payload: $payload')
          ..write(')'))
        .toString();
  }
}

abstract class _$NotesDatabase extends GeneratedDatabase {
  _$NotesDatabase(QueryExecutor e) : super(e);
  $NotesDatabaseManager get managers => $NotesDatabaseManager(this);
  late final $LocalFoldersTable localFolders = $LocalFoldersTable(this);
  late final $LocalNotesTable localNotes = $LocalNotesTable(this);
  late final $LocalItemsTable localItems = $LocalItemsTable(this);
  late final $LocalSectionsTable localSections = $LocalSectionsTable(this);
  late final $LocalProductsTable localProducts = $LocalProductsTable(this);
  late final $PendingOperationsTable pendingOperations = $PendingOperationsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    localFolders,
    localNotes,
    localItems,
    localSections,
    localProducts,
    pendingOperations,
  ];
}

typedef $$LocalFoldersTableCreateCompanionBuilder = LocalFoldersCompanion Function({
  required String id,
  Value<String?> parentId,
  required String name,
  Value<int> position,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$LocalFoldersTableUpdateCompanionBuilder = LocalFoldersCompanion Function({
  Value<String> id,
  Value<String?> parentId,
  Value<String> name,
  Value<int> position,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$LocalFoldersTableFilterComposer extends Composer<_$NotesDatabase, $LocalFoldersTable> {
  $$LocalFoldersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$LocalFoldersTableOrderingComposer extends Composer<_$NotesDatabase, $LocalFoldersTable> {
  $$LocalFoldersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$LocalFoldersTableAnnotationComposer extends Composer<_$NotesDatabase, $LocalFoldersTable> {
  $$LocalFoldersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get parentId => $composableBuilder(column: $table.parentId, builder: (column) => column);

  GeneratedColumn<String> get name => $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get position => $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt => $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$LocalFoldersTableTableManager
    extends
        RootTableManager<
          _$NotesDatabase,
          $LocalFoldersTable,
          LocalFolder,
          $$LocalFoldersTableFilterComposer,
          $$LocalFoldersTableOrderingComposer,
          $$LocalFoldersTableAnnotationComposer,
          $$LocalFoldersTableCreateCompanionBuilder,
          $$LocalFoldersTableUpdateCompanionBuilder,
          (LocalFolder, BaseReferences<_$NotesDatabase, $LocalFoldersTable, LocalFolder>),
          LocalFolder,
          PrefetchHooks Function()
        > {
  $$LocalFoldersTableTableManager(_$NotesDatabase db, $LocalFoldersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$LocalFoldersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$LocalFoldersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$LocalFoldersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalFoldersCompanion(
                id: id,
                parentId: parentId,
                name: name,
                position: position,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> parentId = const Value.absent(),
                required String name,
                Value<int> position = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => LocalFoldersCompanion.insert(
                id: id,
                parentId: parentId,
                name: name,
                position: position,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalFoldersTable, LocalFolder>(table),
                  BaseReferences<_$NotesDatabase, $LocalFoldersTable, LocalFolder>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalFoldersTableProcessedTableManager =
    ProcessedTableManager<
      _$NotesDatabase,
      $LocalFoldersTable,
      LocalFolder,
      $$LocalFoldersTableFilterComposer,
      $$LocalFoldersTableOrderingComposer,
      $$LocalFoldersTableAnnotationComposer,
      $$LocalFoldersTableCreateCompanionBuilder,
      $$LocalFoldersTableUpdateCompanionBuilder,
      (LocalFolder, BaseReferences<_$NotesDatabase, $LocalFoldersTable, LocalFolder>),
      LocalFolder,
      PrefetchHooks Function()
    >;
typedef $$LocalNotesTableCreateCompanionBuilder = LocalNotesCompanion Function({
  required String id,
  Value<String?> folderId,
  required String type,
  Value<String?> title,
  Value<String?> body,
  Value<DateTime?> pinnedAt,
  Value<DateTime?> archivedAt,
  Value<DateTime?> deletedAt,
  Value<String> checkedBehavior,
  Value<bool> isPrimary,
  Value<int> sort,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$LocalNotesTableUpdateCompanionBuilder = LocalNotesCompanion Function({
  Value<String> id,
  Value<String?> folderId,
  Value<String> type,
  Value<String?> title,
  Value<String?> body,
  Value<DateTime?> pinnedAt,
  Value<DateTime?> archivedAt,
  Value<DateTime?> deletedAt,
  Value<String> checkedBehavior,
  Value<bool> isPrimary,
  Value<int> sort,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$LocalNotesTableFilterComposer extends Composer<_$NotesDatabase, $LocalNotesTable> {
  $$LocalNotesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get folderId =>
      $composableBuilder(column: $table.folderId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get body => $composableBuilder(column: $table.body, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get pinnedAt =>
      $composableBuilder(column: $table.pinnedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get archivedAt =>
      $composableBuilder(column: $table.archivedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get checkedBehavior =>
      $composableBuilder(column: $table.checkedBehavior, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isPrimary =>
      $composableBuilder(column: $table.isPrimary, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sort => $composableBuilder(column: $table.sort, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$LocalNotesTableOrderingComposer extends Composer<_$NotesDatabase, $LocalNotesTable> {
  $$LocalNotesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get folderId =>
      $composableBuilder(column: $table.folderId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get pinnedAt =>
      $composableBuilder(column: $table.pinnedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get archivedAt =>
      $composableBuilder(column: $table.archivedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get checkedBehavior =>
      $composableBuilder(column: $table.checkedBehavior, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isPrimary =>
      $composableBuilder(column: $table.isPrimary, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sort =>
      $composableBuilder(column: $table.sort, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$LocalNotesTableAnnotationComposer extends Composer<_$NotesDatabase, $LocalNotesTable> {
  $$LocalNotesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get folderId => $composableBuilder(column: $table.folderId, builder: (column) => column);

  GeneratedColumn<String> get type => $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get title => $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get body => $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<DateTime> get pinnedAt => $composableBuilder(column: $table.pinnedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get archivedAt =>
      $composableBuilder(column: $table.archivedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt => $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get checkedBehavior =>
      $composableBuilder(column: $table.checkedBehavior, builder: (column) => column);

  GeneratedColumn<bool> get isPrimary => $composableBuilder(column: $table.isPrimary, builder: (column) => column);

  GeneratedColumn<int> get sort => $composableBuilder(column: $table.sort, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt => $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt => $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$LocalNotesTableTableManager
    extends
        RootTableManager<
          _$NotesDatabase,
          $LocalNotesTable,
          LocalNote,
          $$LocalNotesTableFilterComposer,
          $$LocalNotesTableOrderingComposer,
          $$LocalNotesTableAnnotationComposer,
          $$LocalNotesTableCreateCompanionBuilder,
          $$LocalNotesTableUpdateCompanionBuilder,
          (LocalNote, BaseReferences<_$NotesDatabase, $LocalNotesTable, LocalNote>),
          LocalNote,
          PrefetchHooks Function()
        > {
  $$LocalNotesTableTableManager(_$NotesDatabase db, $LocalNotesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$LocalNotesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$LocalNotesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$LocalNotesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> folderId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String?> body = const Value.absent(),
                Value<DateTime?> pinnedAt = const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String> checkedBehavior = const Value.absent(),
                Value<bool> isPrimary = const Value.absent(),
                Value<int> sort = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalNotesCompanion(
                id: id,
                folderId: folderId,
                type: type,
                title: title,
                body: body,
                pinnedAt: pinnedAt,
                archivedAt: archivedAt,
                deletedAt: deletedAt,
                checkedBehavior: checkedBehavior,
                isPrimary: isPrimary,
                sort: sort,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> folderId = const Value.absent(),
                required String type,
                Value<String?> title = const Value.absent(),
                Value<String?> body = const Value.absent(),
                Value<DateTime?> pinnedAt = const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String> checkedBehavior = const Value.absent(),
                Value<bool> isPrimary = const Value.absent(),
                Value<int> sort = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => LocalNotesCompanion.insert(
                id: id,
                folderId: folderId,
                type: type,
                title: title,
                body: body,
                pinnedAt: pinnedAt,
                archivedAt: archivedAt,
                deletedAt: deletedAt,
                checkedBehavior: checkedBehavior,
                isPrimary: isPrimary,
                sort: sort,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalNotesTable, LocalNote>(table),
                  BaseReferences<_$NotesDatabase, $LocalNotesTable, LocalNote>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalNotesTableProcessedTableManager =
    ProcessedTableManager<
      _$NotesDatabase,
      $LocalNotesTable,
      LocalNote,
      $$LocalNotesTableFilterComposer,
      $$LocalNotesTableOrderingComposer,
      $$LocalNotesTableAnnotationComposer,
      $$LocalNotesTableCreateCompanionBuilder,
      $$LocalNotesTableUpdateCompanionBuilder,
      (LocalNote, BaseReferences<_$NotesDatabase, $LocalNotesTable, LocalNote>),
      LocalNote,
      PrefetchHooks Function()
    >;
typedef $$LocalItemsTableCreateCompanionBuilder = LocalItemsCompanion Function({
  required String id,
  required String noteId,
  Value<String?> productId,
  required String content,
  Value<String?> quantity,
  Value<String?> sectionId,
  Value<DateTime?> checkedAt,
  Value<int> position,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$LocalItemsTableUpdateCompanionBuilder = LocalItemsCompanion Function({
  Value<String> id,
  Value<String> noteId,
  Value<String?> productId,
  Value<String> content,
  Value<String?> quantity,
  Value<String?> sectionId,
  Value<DateTime?> checkedAt,
  Value<int> position,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$LocalItemsTableFilterComposer extends Composer<_$NotesDatabase, $LocalItemsTable> {
  $$LocalItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get noteId =>
      $composableBuilder(column: $table.noteId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get productId =>
      $composableBuilder(column: $table.productId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sectionId =>
      $composableBuilder(column: $table.sectionId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get checkedAt =>
      $composableBuilder(column: $table.checkedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$LocalItemsTableOrderingComposer extends Composer<_$NotesDatabase, $LocalItemsTable> {
  $$LocalItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get noteId =>
      $composableBuilder(column: $table.noteId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get productId =>
      $composableBuilder(column: $table.productId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sectionId =>
      $composableBuilder(column: $table.sectionId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get checkedAt =>
      $composableBuilder(column: $table.checkedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$LocalItemsTableAnnotationComposer extends Composer<_$NotesDatabase, $LocalItemsTable> {
  $$LocalItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get noteId => $composableBuilder(column: $table.noteId, builder: (column) => column);

  GeneratedColumn<String> get productId => $composableBuilder(column: $table.productId, builder: (column) => column);

  GeneratedColumn<String> get content => $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get quantity => $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<String> get sectionId => $composableBuilder(column: $table.sectionId, builder: (column) => column);

  GeneratedColumn<DateTime> get checkedAt => $composableBuilder(column: $table.checkedAt, builder: (column) => column);

  GeneratedColumn<int> get position => $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt => $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$LocalItemsTableTableManager
    extends
        RootTableManager<
          _$NotesDatabase,
          $LocalItemsTable,
          LocalItem,
          $$LocalItemsTableFilterComposer,
          $$LocalItemsTableOrderingComposer,
          $$LocalItemsTableAnnotationComposer,
          $$LocalItemsTableCreateCompanionBuilder,
          $$LocalItemsTableUpdateCompanionBuilder,
          (LocalItem, BaseReferences<_$NotesDatabase, $LocalItemsTable, LocalItem>),
          LocalItem,
          PrefetchHooks Function()
        > {
  $$LocalItemsTableTableManager(_$NotesDatabase db, $LocalItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$LocalItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$LocalItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$LocalItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> noteId = const Value.absent(),
                Value<String?> productId = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String?> quantity = const Value.absent(),
                Value<String?> sectionId = const Value.absent(),
                Value<DateTime?> checkedAt = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalItemsCompanion(
                id: id,
                noteId: noteId,
                productId: productId,
                content: content,
                quantity: quantity,
                sectionId: sectionId,
                checkedAt: checkedAt,
                position: position,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String noteId,
                Value<String?> productId = const Value.absent(),
                required String content,
                Value<String?> quantity = const Value.absent(),
                Value<String?> sectionId = const Value.absent(),
                Value<DateTime?> checkedAt = const Value.absent(),
                Value<int> position = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => LocalItemsCompanion.insert(
                id: id,
                noteId: noteId,
                productId: productId,
                content: content,
                quantity: quantity,
                sectionId: sectionId,
                checkedAt: checkedAt,
                position: position,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalItemsTable, LocalItem>(table),
                  BaseReferences<_$NotesDatabase, $LocalItemsTable, LocalItem>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$NotesDatabase,
      $LocalItemsTable,
      LocalItem,
      $$LocalItemsTableFilterComposer,
      $$LocalItemsTableOrderingComposer,
      $$LocalItemsTableAnnotationComposer,
      $$LocalItemsTableCreateCompanionBuilder,
      $$LocalItemsTableUpdateCompanionBuilder,
      (LocalItem, BaseReferences<_$NotesDatabase, $LocalItemsTable, LocalItem>),
      LocalItem,
      PrefetchHooks Function()
    >;
typedef $$LocalSectionsTableCreateCompanionBuilder = LocalSectionsCompanion Function({
  required String id,
  required String name,
  Value<int> position,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$LocalSectionsTableUpdateCompanionBuilder = LocalSectionsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<int> position,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$LocalSectionsTableFilterComposer extends Composer<_$NotesDatabase, $LocalSectionsTable> {
  $$LocalSectionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$LocalSectionsTableOrderingComposer extends Composer<_$NotesDatabase, $LocalSectionsTable> {
  $$LocalSectionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$LocalSectionsTableAnnotationComposer extends Composer<_$NotesDatabase, $LocalSectionsTable> {
  $$LocalSectionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name => $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get position => $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt => $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$LocalSectionsTableTableManager
    extends
        RootTableManager<
          _$NotesDatabase,
          $LocalSectionsTable,
          LocalSection,
          $$LocalSectionsTableFilterComposer,
          $$LocalSectionsTableOrderingComposer,
          $$LocalSectionsTableAnnotationComposer,
          $$LocalSectionsTableCreateCompanionBuilder,
          $$LocalSectionsTableUpdateCompanionBuilder,
          (LocalSection, BaseReferences<_$NotesDatabase, $LocalSectionsTable, LocalSection>),
          LocalSection,
          PrefetchHooks Function()
        > {
  $$LocalSectionsTableTableManager(_$NotesDatabase db, $LocalSectionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$LocalSectionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$LocalSectionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$LocalSectionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<int> position = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => LocalSectionsCompanion(id: id, name: name, position: position, updatedAt: updatedAt, rowid: rowid),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<int> position = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => LocalSectionsCompanion.insert(
                id: id,
                name: name,
                position: position,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalSectionsTable, LocalSection>(table),
                  BaseReferences<_$NotesDatabase, $LocalSectionsTable, LocalSection>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalSectionsTableProcessedTableManager =
    ProcessedTableManager<
      _$NotesDatabase,
      $LocalSectionsTable,
      LocalSection,
      $$LocalSectionsTableFilterComposer,
      $$LocalSectionsTableOrderingComposer,
      $$LocalSectionsTableAnnotationComposer,
      $$LocalSectionsTableCreateCompanionBuilder,
      $$LocalSectionsTableUpdateCompanionBuilder,
      (LocalSection, BaseReferences<_$NotesDatabase, $LocalSectionsTable, LocalSection>),
      LocalSection,
      PrefetchHooks Function()
    >;
typedef $$LocalProductsTableCreateCompanionBuilder = LocalProductsCompanion Function({
  required String id,
  required String noteId,
  required String name,
  Value<String?> sectionId,
  Value<String?> defaultQuantity,
  Value<String> restockMode,
  Value<int?> restockIntervalDays,
  Value<DateTime?> lastBoughtAt,
  Value<int> timesBought,
  Value<String?> restockedFor,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$LocalProductsTableUpdateCompanionBuilder = LocalProductsCompanion Function({
  Value<String> id,
  Value<String> noteId,
  Value<String> name,
  Value<String?> sectionId,
  Value<String?> defaultQuantity,
  Value<String> restockMode,
  Value<int?> restockIntervalDays,
  Value<DateTime?> lastBoughtAt,
  Value<int> timesBought,
  Value<String?> restockedFor,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$LocalProductsTableFilterComposer extends Composer<_$NotesDatabase, $LocalProductsTable> {
  $$LocalProductsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get noteId =>
      $composableBuilder(column: $table.noteId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sectionId =>
      $composableBuilder(column: $table.sectionId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get defaultQuantity =>
      $composableBuilder(column: $table.defaultQuantity, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get restockMode =>
      $composableBuilder(column: $table.restockMode, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get restockIntervalDays =>
      $composableBuilder(column: $table.restockIntervalDays, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastBoughtAt =>
      $composableBuilder(column: $table.lastBoughtAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get timesBought =>
      $composableBuilder(column: $table.timesBought, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get restockedFor =>
      $composableBuilder(column: $table.restockedFor, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$LocalProductsTableOrderingComposer extends Composer<_$NotesDatabase, $LocalProductsTable> {
  $$LocalProductsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get noteId =>
      $composableBuilder(column: $table.noteId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sectionId =>
      $composableBuilder(column: $table.sectionId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get defaultQuantity =>
      $composableBuilder(column: $table.defaultQuantity, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get restockMode =>
      $composableBuilder(column: $table.restockMode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get restockIntervalDays =>
      $composableBuilder(column: $table.restockIntervalDays, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastBoughtAt =>
      $composableBuilder(column: $table.lastBoughtAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get timesBought =>
      $composableBuilder(column: $table.timesBought, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get restockedFor =>
      $composableBuilder(column: $table.restockedFor, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$LocalProductsTableAnnotationComposer extends Composer<_$NotesDatabase, $LocalProductsTable> {
  $$LocalProductsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get noteId => $composableBuilder(column: $table.noteId, builder: (column) => column);

  GeneratedColumn<String> get name => $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get sectionId => $composableBuilder(column: $table.sectionId, builder: (column) => column);

  GeneratedColumn<String> get defaultQuantity =>
      $composableBuilder(column: $table.defaultQuantity, builder: (column) => column);

  GeneratedColumn<String> get restockMode =>
      $composableBuilder(column: $table.restockMode, builder: (column) => column);

  GeneratedColumn<int> get restockIntervalDays =>
      $composableBuilder(column: $table.restockIntervalDays, builder: (column) => column);

  GeneratedColumn<DateTime> get lastBoughtAt =>
      $composableBuilder(column: $table.lastBoughtAt, builder: (column) => column);

  GeneratedColumn<int> get timesBought => $composableBuilder(column: $table.timesBought, builder: (column) => column);

  GeneratedColumn<String> get restockedFor =>
      $composableBuilder(column: $table.restockedFor, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt => $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$LocalProductsTableTableManager
    extends
        RootTableManager<
          _$NotesDatabase,
          $LocalProductsTable,
          LocalProduct,
          $$LocalProductsTableFilterComposer,
          $$LocalProductsTableOrderingComposer,
          $$LocalProductsTableAnnotationComposer,
          $$LocalProductsTableCreateCompanionBuilder,
          $$LocalProductsTableUpdateCompanionBuilder,
          (LocalProduct, BaseReferences<_$NotesDatabase, $LocalProductsTable, LocalProduct>),
          LocalProduct,
          PrefetchHooks Function()
        > {
  $$LocalProductsTableTableManager(_$NotesDatabase db, $LocalProductsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$LocalProductsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$LocalProductsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$LocalProductsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> noteId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> sectionId = const Value.absent(),
                Value<String?> defaultQuantity = const Value.absent(),
                Value<String> restockMode = const Value.absent(),
                Value<int?> restockIntervalDays = const Value.absent(),
                Value<DateTime?> lastBoughtAt = const Value.absent(),
                Value<int> timesBought = const Value.absent(),
                Value<String?> restockedFor = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalProductsCompanion(
                id: id,
                noteId: noteId,
                name: name,
                sectionId: sectionId,
                defaultQuantity: defaultQuantity,
                restockMode: restockMode,
                restockIntervalDays: restockIntervalDays,
                lastBoughtAt: lastBoughtAt,
                timesBought: timesBought,
                restockedFor: restockedFor,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String noteId,
                required String name,
                Value<String?> sectionId = const Value.absent(),
                Value<String?> defaultQuantity = const Value.absent(),
                Value<String> restockMode = const Value.absent(),
                Value<int?> restockIntervalDays = const Value.absent(),
                Value<DateTime?> lastBoughtAt = const Value.absent(),
                Value<int> timesBought = const Value.absent(),
                Value<String?> restockedFor = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => LocalProductsCompanion.insert(
                id: id,
                noteId: noteId,
                name: name,
                sectionId: sectionId,
                defaultQuantity: defaultQuantity,
                restockMode: restockMode,
                restockIntervalDays: restockIntervalDays,
                lastBoughtAt: lastBoughtAt,
                timesBought: timesBought,
                restockedFor: restockedFor,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalProductsTable, LocalProduct>(table),
                  BaseReferences<_$NotesDatabase, $LocalProductsTable, LocalProduct>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalProductsTableProcessedTableManager =
    ProcessedTableManager<
      _$NotesDatabase,
      $LocalProductsTable,
      LocalProduct,
      $$LocalProductsTableFilterComposer,
      $$LocalProductsTableOrderingComposer,
      $$LocalProductsTableAnnotationComposer,
      $$LocalProductsTableCreateCompanionBuilder,
      $$LocalProductsTableUpdateCompanionBuilder,
      (LocalProduct, BaseReferences<_$NotesDatabase, $LocalProductsTable, LocalProduct>),
      LocalProduct,
      PrefetchHooks Function()
    >;
typedef $$PendingOperationsTableCreateCompanionBuilder = PendingOperationsCompanion Function({
  Value<int> seq,
  required String id,
  required String type,
  required DateTime at,
  required String payload,
});
typedef $$PendingOperationsTableUpdateCompanionBuilder = PendingOperationsCompanion Function({
  Value<int> seq,
  Value<String> id,
  Value<String> type,
  Value<DateTime> at,
  Value<String> payload,
});

class $$PendingOperationsTableFilterComposer extends Composer<_$NotesDatabase, $PendingOperationsTable> {
  $$PendingOperationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get seq => $composableBuilder(column: $table.seq, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get at => $composableBuilder(column: $table.at, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => ColumnFilters(column));
}

class $$PendingOperationsTableOrderingComposer extends Composer<_$NotesDatabase, $PendingOperationsTable> {
  $$PendingOperationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get seq => $composableBuilder(column: $table.seq, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get at =>
      $composableBuilder(column: $table.at, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => ColumnOrderings(column));
}

class $$PendingOperationsTableAnnotationComposer extends Composer<_$NotesDatabase, $PendingOperationsTable> {
  $$PendingOperationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get seq => $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<String> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type => $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<DateTime> get at => $composableBuilder(column: $table.at, builder: (column) => column);

  GeneratedColumn<String> get payload => $composableBuilder(column: $table.payload, builder: (column) => column);
}

class $$PendingOperationsTableTableManager
    extends
        RootTableManager<
          _$NotesDatabase,
          $PendingOperationsTable,
          PendingOperation,
          $$PendingOperationsTableFilterComposer,
          $$PendingOperationsTableOrderingComposer,
          $$PendingOperationsTableAnnotationComposer,
          $$PendingOperationsTableCreateCompanionBuilder,
          $$PendingOperationsTableUpdateCompanionBuilder,
          (PendingOperation, BaseReferences<_$NotesDatabase, $PendingOperationsTable, PendingOperation>),
          PendingOperation,
          PrefetchHooks Function()
        > {
  $$PendingOperationsTableTableManager(_$NotesDatabase db, $PendingOperationsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$PendingOperationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$PendingOperationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$PendingOperationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> seq = const Value.absent(),
            Value<String> id = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<DateTime> at = const Value.absent(),
            Value<String> payload = const Value.absent(),
          }) => PendingOperationsCompanion(seq: seq, id: id, type: type, at: at, payload: payload),
          createCompanionCallback: ({
            Value<int> seq = const Value.absent(),
            required String id,
            required String type,
            required DateTime at,
            required String payload,
          }) => PendingOperationsCompanion.insert(seq: seq, id: id, type: type, at: at, payload: payload),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PendingOperationsTable, PendingOperation>(table),
                  BaseReferences<_$NotesDatabase, $PendingOperationsTable, PendingOperation>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PendingOperationsTableProcessedTableManager =
    ProcessedTableManager<
      _$NotesDatabase,
      $PendingOperationsTable,
      PendingOperation,
      $$PendingOperationsTableFilterComposer,
      $$PendingOperationsTableOrderingComposer,
      $$PendingOperationsTableAnnotationComposer,
      $$PendingOperationsTableCreateCompanionBuilder,
      $$PendingOperationsTableUpdateCompanionBuilder,
      (PendingOperation, BaseReferences<_$NotesDatabase, $PendingOperationsTable, PendingOperation>),
      PendingOperation,
      PrefetchHooks Function()
    >;

class $NotesDatabaseManager {
  final _$NotesDatabase _db;
  $NotesDatabaseManager(this._db);
  $$LocalFoldersTableTableManager get localFolders => $$LocalFoldersTableTableManager(_db, _db.localFolders);
  $$LocalNotesTableTableManager get localNotes => $$LocalNotesTableTableManager(_db, _db.localNotes);
  $$LocalItemsTableTableManager get localItems => $$LocalItemsTableTableManager(_db, _db.localItems);
  $$LocalSectionsTableTableManager get localSections => $$LocalSectionsTableTableManager(_db, _db.localSections);
  $$LocalProductsTableTableManager get localProducts => $$LocalProductsTableTableManager(_db, _db.localProducts);
  $$PendingOperationsTableTableManager get pendingOperations =>
      $$PendingOperationsTableTableManager(_db, _db.pendingOperations);
}
