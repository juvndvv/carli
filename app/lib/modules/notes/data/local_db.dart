import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'local_db.g.dart';

class LocalFolders extends Table {
  TextColumn get id => text()();
  TextColumn get parentId => text().nullable()();
  TextColumn get name => text()();
  IntColumn get position => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalNotes extends Table {
  TextColumn get id => text()();
  TextColumn get folderId => text().nullable()();
  TextColumn get type => text()();
  TextColumn get title => text().nullable()();
  TextColumn get body => text().nullable()();
  DateTimeColumn get pinnedAt => dateTime().nullable()();
  DateTimeColumn get archivedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get checkedBehavior => text().withDefault(const Constant('move'))();
  BoolColumn get isPrimary => boolean().withDefault(const Constant(false))();
  IntColumn get sort => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalItems extends Table {
  TextColumn get id => text()();
  TextColumn get noteId => text()();
  TextColumn get productId => text().nullable()();
  TextColumn get content => text()();
  TextColumn get quantity => text().nullable()();
  TextColumn get sectionId => text().nullable()();
  DateTimeColumn get checkedAt => dateTime().nullable()();
  IntColumn get position => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalSections extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get position => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalProducts extends Table {
  TextColumn get id => text()();
  TextColumn get noteId => text()();
  TextColumn get name => text()();
  TextColumn get sectionId => text().nullable()();
  TextColumn get defaultQuantity => text().nullable()();
  TextColumn get restockMode => text().withDefault(const Constant('none'))();
  IntColumn get restockIntervalDays => integer().nullable()();
  DateTimeColumn get lastBoughtAt => dateTime().nullable()();
  IntColumn get timesBought => integer().withDefault(const Constant(0))();
  TextColumn get restockedFor => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class PendingOperations extends Table {
  IntColumn get seq => integer().autoIncrement()();
  TextColumn get id => text().unique()();
  TextColumn get type => text()();
  DateTimeColumn get at => dateTime()();
  TextColumn get payload => text()();
}

@DriftDatabase(tables: [LocalFolders, LocalNotes, LocalItems, LocalSections, LocalProducts, PendingOperations])
class NotesDatabase extends _$NotesDatabase {
  NotesDatabase([QueryExecutor? executor]) : super(executor ?? driftDatabase(name: 'carli_notes'));

  @override
  int get schemaVersion => 1;

  List<TableInfo> get contentTables => [localFolders, localNotes, localItems, localSections, localProducts];

  Future<void> wipe() => transaction(() async {
    for (final table in [...contentTables, pendingOperations]) {
      await delete(table).go();
    }
  });
}
