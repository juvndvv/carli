import 'dart:convert';

import 'package:drift/drift.dart';

import '../../finance/data/json.dart';
import 'local_db.dart';
import 'models.dart';
import 'restock.dart';

/// A change made on the device. It is applied to the local cache right away and queued for `POST /notes/sync`,
/// where the server applies it again with the same rules.
class NoteOperation {
  const NoteOperation({required this.id, required this.type, required this.at, required this.payload});

  factory NoteOperation.fromRow(PendingOperation row) =>
      NoteOperation(id: row.id, type: row.type, at: row.at, payload: jsonDecode(row.payload) as Json);

  final String id;
  final String type;
  final DateTime at;
  final Json payload;

  Json toJson() => {'id': id, 'type': type, 'at': at.toUtc().toIso8601String(), 'payload': payload};
}

class NotesIndex {
  NotesIndex({required this.folders, required this.notes, required this.sections, required this.products});

  static final empty = NotesIndex(folders: const [], notes: const [], sections: const [], products: const []);

  final List<NoteFolder> folders;
  final List<Note> notes;
  final List<ShoppingSection> sections;
  final List<ShoppingProduct> products;

  late final Map<String, Note> _notesById = {for (final note in notes) note.id: note};
  late final Map<String, NoteFolder> _foldersById = {for (final folder in folders) folder.id: folder};

  Note? note(String id) => _notesById[id];

  NoteFolder? folder(String? id) => id == null ? null : _foldersById[id];

  List<ShoppingProduct> productsOf(String noteId) => [
    for (final product in products)
      if (product.noteId == noteId) product,
  ];
}

DateTime? _time(Object? value) => value is String ? DateTime.parse(value) : null;

Value<T> _present<T>(Json payload, String key, T Function(Object?) read) =>
    payload.containsKey(key) ? Value(read(payload[key])) : const Value.absent();

String? _string(Object? value) => value as String?;

int _int(Object? value) => (value as num?)?.toInt() ?? 0;

class NotesStore {
  NotesStore(this.db);

  final NotesDatabase db;

  Stream<NotesIndex> watch() async* {
    yield await load();
    yield* db.tableUpdates(TableUpdateQuery.onAllTables(db.contentTables)).asyncMap((_) => load());
  }

  Future<NotesIndex> load() async {
    final rows = await (db.select(db.localItems)..orderBy([(item) => OrderingTerm.asc(item.position)])).get();
    final itemsByNote = <String, List<NoteItem>>{};
    for (final row in rows) {
      (itemsByNote[row.noteId] ??= []).add(_item(row));
    }
    final folders = await (db.select(db.localFolders)..orderBy([(folder) => OrderingTerm.asc(folder.position)])).get();
    final notes = await db.select(db.localNotes).get();
    final sections = await (db.select(db.localSections)..orderBy([(s) => OrderingTerm.asc(s.position)])).get();
    final products = await db.select(db.localProducts).get();
    return NotesIndex(
      folders: [for (final row in folders) _folder(row)],
      notes: [for (final row in notes) _note(row, itemsByNote[row.id] ?? const [])],
      sections: [for (final row in sections) ShoppingSection(id: row.id, name: row.name, position: row.position)],
      products: [for (final row in products) _product(row)],
    );
  }

  Future<List<NoteOperation>> pending({int limit = 500}) async {
    final rows =
        await (db.select(db.pendingOperations)
              ..orderBy([(op) => OrderingTerm.asc(op.seq)])
              ..limit(limit))
            .get();
    return [for (final row in rows) NoteOperation.fromRow(row)];
  }

  Future<int> pendingCount() async {
    final count = db.pendingOperations.seq.count();
    return (await (db.selectOnly(db.pendingOperations)..addColumns([count])).getSingle()).read(count) ?? 0;
  }

  Future<void> record(NoteOperation operation) => db.transaction(() async {
    await apply(operation);
    await db
        .into(db.pendingOperations)
        .insert(
          PendingOperationsCompanion.insert(
            id: operation.id,
            type: operation.type,
            at: operation.at,
            payload: jsonEncode(operation.payload),
          ),
        );
  });

  /// Replaces the cache with the server's state, then replays the changes that have not reached it yet.
  Future<void> replaceWith(Json snapshot, {required DateTime today, Iterable<String> acknowledged = const []}) =>
      db.transaction(() async {
        await (db.delete(db.pendingOperations)..where((op) => op.id.isIn(acknowledged))).go();
        for (final table in db.contentTables) {
          await db.delete(table).go();
        }
        await db.batch((batch) {
          batch.insertAll(db.localFolders, [
            for (final json in snapshot['folders'] as List? ?? const [])
              LocalFoldersCompanion.insert(
                id: json['id'] as String,
                parentId: Value(json['parent_id'] as String?),
                name: json['name'] as String,
                position: Value(_int(json['position'])),
                updatedAt: _time(json['updated_at'])!,
              ),
          ]);
          for (final json in snapshot['notes'] as List? ?? const []) {
            batch.insert(
              db.localNotes,
              LocalNotesCompanion.insert(
                id: json['id'] as String,
                folderId: Value(json['folder_id'] as String?),
                type: json['type'] as String,
                title: Value(json['title'] as String?),
                body: Value(json['body'] as String?),
                pinnedAt: Value(_time(json['pinned_at'])),
                archivedAt: Value(_time(json['archived_at'])),
                deletedAt: Value(_time(json['deleted_at'])),
                checkedBehavior: Value(json['checked_behavior'] as String? ?? 'move'),
                isPrimary: Value(json['is_primary'] == true),
                sort: Value(_int(json['sort'])),
                createdAt: _time(json['created_at']) ?? _time(json['updated_at'])!,
                updatedAt: _time(json['updated_at'])!,
              ),
            );
            batch.insertAll(db.localItems, [
              for (final item in json['items'] as List? ?? const [])
                LocalItemsCompanion.insert(
                  id: item['id'] as String,
                  noteId: json['id'] as String,
                  productId: Value(item['product_id'] as String?),
                  content: item['text'] as String? ?? '',
                  quantity: Value(item['quantity'] as String?),
                  sectionId: Value(item['section_id'] as String?),
                  checkedAt: Value(_time(item['checked_at'])),
                  position: Value(_int(item['position'])),
                  updatedAt: _time(item['updated_at'])!,
                ),
            ]);
          }
          batch.insertAll(db.localSections, [
            for (final json in snapshot['sections'] as List? ?? const [])
              LocalSectionsCompanion.insert(
                id: json['id'] as String,
                name: json['name'] as String,
                position: Value(_int(json['position'])),
                updatedAt: _time(json['updated_at']) ?? DateTime.now(),
              ),
          ]);
          batch.insertAll(db.localProducts, [
            for (final json in snapshot['products'] as List? ?? const [])
              LocalProductsCompanion.insert(
                id: json['id'] as String,
                noteId: json['note_id'] as String,
                name: json['name'] as String,
                sectionId: Value(json['section_id'] as String?),
                defaultQuantity: Value(json['default_quantity'] as String?),
                restockMode: Value(json['restock_mode'] as String? ?? 'none'),
                restockIntervalDays: Value(intOrNull(json['restock_interval_days'])),
                lastBoughtAt: Value(_time(json['last_bought_at'])),
                timesBought: Value(_int(json['times_bought'])),
                restockedFor: Value(json['restocked_for'] as String?),
                updatedAt: _time(json['updated_at'])!,
              ),
          ]);
        });
        for (final operation in await pending()) {
          await apply(operation);
        }
        await restock(today);
      });

  Future<void> apply(NoteOperation operation) async {
    final payload = operation.payload;
    final at = operation.at;
    switch (operation.type) {
      case 'folder.upsert':
        await _upsertFolder(payload, at);
      case 'folder.delete':
        await _deleteFolder(payload['id'] as String);
      case 'note.upsert':
        await _upsertNote(payload, at);
      case 'note.purge':
        await _purgeNote(payload['id'] as String);
      case 'item.upsert':
        await _upsertItem(payload, at);
      case 'item.delete':
        await (db.delete(db.localItems)..where((item) => item.id.equals(payload['id'] as String))).go();
      case 'product.upsert':
        await _upsertProduct(payload, at);
      case 'product.delete':
        await _deleteProduct(payload['id'] as String);
      case 'section.upsert':
        await _upsertSection(payload, at);
      case 'section.delete':
        await _deleteSection(payload['id'] as String);
      case 'shopping.finish':
        await _finishShopping(payload);
    }
  }

  Future<void> restock(DateTime today) async {
    final shoppingNotes = await (db.select(
      db.localNotes,
    )..where((note) => note.type.equals(NoteType.shopping.wire) & note.deletedAt.isNull())).get();
    for (final note in shoppingNotes) {
      await _restockNote(note.id, today);
    }
  }

  Future<void> _restockNote(String noteId, DateTime today) async {
    final items = await (db.select(db.localItems)..where((item) => item.noteId.equals(noteId))).get();
    final products = await (db.select(db.localProducts)..where((product) => product.noteId.equals(noteId))).get();
    final due = productsToRestock(
      products: [for (final row in products) _product(row)],
      items: [for (final row in items) _item(row)],
      today: today,
    );
    var position = items.fold(-1, (max, item) => item.position > max ? item.position : max);
    for (final product in due) {
      final key = restockCycleKey(product.id, product.lastBoughtAt!);
      await db
          .into(db.localItems)
          .insert(
            LocalItemsCompanion.insert(
              id: restockItemId(key),
              noteId: noteId,
              productId: Value(product.id),
              content: product.name,
              quantity: Value(product.defaultQuantity),
              sectionId: Value(product.sectionId),
              position: Value(++position),
              updatedAt: DateTime.now(),
            ),
            mode: InsertMode.insertOrIgnore,
          );
      await (db.update(
        db.localProducts,
      )..where((row) => row.id.equals(product.id))).write(LocalProductsCompanion(restockedFor: Value(key)));
    }
  }

  Future<void> _upsertFolder(Json payload, DateTime at) async {
    final id = payload['id'] as String;
    final companion = LocalFoldersCompanion(
      parentId: _present(payload, 'parent_id', _string),
      name: _present(payload, 'name', (value) => value as String),
      position: _present(payload, 'position', _int),
      updatedAt: Value(at),
    );
    final updated = await (db.update(db.localFolders)..where((folder) => folder.id.equals(id))).write(companion);
    if (updated == 0 && payload['name'] != null) {
      await db.into(db.localFolders).insert(companion.copyWith(id: Value(id)));
    }
  }

  Future<void> _deleteFolder(String id) async {
    final folder = await (db.select(db.localFolders)..where((row) => row.id.equals(id))).getSingleOrNull();
    if (folder == null) return;
    await (db.update(
      db.localFolders,
    )..where((row) => row.parentId.equals(id))).write(LocalFoldersCompanion(parentId: Value(folder.parentId)));
    await (db.update(
      db.localNotes,
    )..where((row) => row.folderId.equals(id))).write(LocalNotesCompanion(folderId: Value(folder.parentId)));
    await (db.delete(db.localFolders)..where((row) => row.id.equals(id))).go();
  }

  Future<void> _upsertNote(Json payload, DateTime at) async {
    final id = payload['id'] as String;
    final existing = await (db.select(db.localNotes)..where((note) => note.id.equals(id))).getSingleOrNull();
    if (existing == null && payload['type'] == null) return;
    DateTime? flag(String key, DateTime? current) => payload[key] == true ? current ?? at : null;
    final type = payload['type'] as String? ?? existing!.type;
    var primary = _present(payload, 'is_primary', (value) => value == true);
    if (existing == null && type == NoteType.shopping.wire && !(primary.present && primary.value)) {
      final hasPrimary = await (db.select(
        db.localNotes,
      )..where((note) => note.isPrimary.equals(true) & note.deletedAt.isNull())).get();
      if (hasPrimary.isEmpty) primary = const Value(true);
    }
    if (primary.present && primary.value) {
      await (db.update(
        db.localNotes,
      )..where((note) => note.id.isNotValue(id))).write(const LocalNotesCompanion(isPrimary: Value(false)));
    }
    final companion = LocalNotesCompanion(
      type: _present(payload, 'type', (value) => value as String),
      folderId: _present(payload, 'folder_id', _string),
      title: _present(payload, 'title', _string),
      body: _present(payload, 'body', _string),
      pinnedAt: _present(payload, 'pinned', (_) => flag('pinned', existing?.pinnedAt)),
      archivedAt: _present(payload, 'archived', (_) => flag('archived', existing?.archivedAt)),
      deletedAt: _present(payload, 'deleted', (_) => flag('deleted', existing?.deletedAt)),
      checkedBehavior: _present(payload, 'checked_behavior', (value) => value as String),
      isPrimary: primary,
      sort: _present(payload, 'sort', _int),
      updatedAt: Value(at),
    );
    if (existing == null) {
      await db.into(db.localNotes).insert(companion.copyWith(id: Value(id), createdAt: Value(at)));
    } else {
      await (db.update(db.localNotes)..where((note) => note.id.equals(id))).write(companion);
    }
  }

  Future<void> _purgeNote(String id) async {
    await (db.delete(db.localItems)..where((item) => item.noteId.equals(id))).go();
    await (db.delete(db.localProducts)..where((product) => product.noteId.equals(id))).go();
    await (db.delete(db.localNotes)..where((note) => note.id.equals(id))).go();
  }

  Future<void> _upsertItem(Json payload, DateTime at) async {
    final id = payload['id'] as String;
    final existing = await (db.select(db.localItems)..where((item) => item.id.equals(id))).getSingleOrNull();
    final companion = LocalItemsCompanion(
      noteId: _present(payload, 'note_id', (value) => value as String),
      productId: _present(payload, 'product_id', _string),
      content: _present(payload, 'text', (value) => value as String),
      quantity: _present(payload, 'quantity', _string),
      sectionId: _present(payload, 'section_id', _string),
      checkedAt: _present(payload, 'checked', (value) => value == true ? existing?.checkedAt ?? at : null),
      position: _present(payload, 'position', _int),
      updatedAt: Value(at),
    );
    if (existing != null) {
      await (db.update(db.localItems)..where((item) => item.id.equals(id))).write(companion);
    } else if (payload['note_id'] != null && payload['text'] != null) {
      await db.into(db.localItems).insert(companion.copyWith(id: Value(id)));
    }
  }

  Future<void> _upsertProduct(Json payload, DateTime at) async {
    final id = payload['id'] as String;
    final companion = LocalProductsCompanion(
      noteId: _present(payload, 'note_id', (value) => value as String),
      name: _present(payload, 'name', (value) => value as String),
      sectionId: _present(payload, 'section_id', _string),
      defaultQuantity: _present(payload, 'default_quantity', _string),
      restockMode: _present(payload, 'restock_mode', (value) => value as String),
      restockIntervalDays: _present(payload, 'restock_interval_days', intOrNull),
      lastBoughtAt: _present(payload, 'last_bought_at', _time),
      timesBought: _present(payload, 'times_bought', _int),
      restockedFor: _present(payload, 'restocked_for', _string),
      updatedAt: Value(at),
    );
    final updated = await (db.update(db.localProducts)..where((product) => product.id.equals(id))).write(companion);
    if (updated == 0 && payload['note_id'] != null && payload['name'] != null) {
      await db.into(db.localProducts).insert(companion.copyWith(id: Value(id)));
    }
  }

  Future<void> _deleteProduct(String id) async {
    await (db.update(
      db.localItems,
    )..where((item) => item.productId.equals(id))).write(const LocalItemsCompanion(productId: Value(null)));
    await (db.delete(db.localProducts)..where((product) => product.id.equals(id))).go();
  }

  Future<void> _upsertSection(Json payload, DateTime at) async {
    final id = payload['id'] as String;
    final companion = LocalSectionsCompanion(
      name: _present(payload, 'name', (value) => value as String),
      position: _present(payload, 'position', _int),
      updatedAt: Value(at),
    );
    final updated = await (db.update(db.localSections)..where((section) => section.id.equals(id))).write(companion);
    if (updated == 0 && payload['name'] != null) {
      await db.into(db.localSections).insert(companion.copyWith(id: Value(id)));
    }
  }

  Future<void> _deleteSection(String id) async {
    await (db.update(
      db.localItems,
    )..where((item) => item.sectionId.equals(id))).write(const LocalItemsCompanion(sectionId: Value(null)));
    await (db.update(
      db.localProducts,
    )..where((product) => product.sectionId.equals(id))).write(const LocalProductsCompanion(sectionId: Value(null)));
    await (db.delete(db.localSections)..where((section) => section.id.equals(id))).go();
  }

  Future<void> _finishShopping(Json payload) async {
    final noteId = payload['note_id'] as String;
    final finishedAt = DateTime.fromMillisecondsSinceEpoch(
      DateTime.parse(payload['finished_at'] as String).millisecondsSinceEpoch ~/ 1000 * 1000,
    );
    final ids = [for (final id in payload['item_ids'] as List? ?? const []) id as String];
    final items = await (db.select(
      db.localItems,
    )..where((item) => item.noteId.equals(noteId) & item.id.isIn(ids))).get();
    for (final item in items) {
      final productId = item.productId;
      if (productId == null) continue;
      await db.customUpdate(
        'UPDATE local_products SET last_bought_at = ?, times_bought = times_bought + 1 WHERE id = ?',
        variables: [Variable(finishedAt), Variable(productId)],
        updates: {db.localProducts},
      );
    }
    await (db.delete(db.localItems)..where((item) => item.id.isIn([for (final item in items) item.id]))).go();
    await _restockNote(noteId, finishedAt);
  }

  static NoteFolder _folder(LocalFolder row) =>
      NoteFolder(id: row.id, parentId: row.parentId, name: row.name, position: row.position, updatedAt: row.updatedAt);

  static NoteItem _item(LocalItem row) => NoteItem(
    id: row.id,
    noteId: row.noteId,
    productId: row.productId,
    text: row.content,
    quantity: row.quantity,
    sectionId: row.sectionId,
    checkedAt: row.checkedAt,
    position: row.position,
    updatedAt: row.updatedAt,
  );

  static Note _note(LocalNote row, List<NoteItem> items) => Note(
    id: row.id,
    type: NoteType.parse(row.type),
    folderId: row.folderId,
    title: row.title,
    body: row.body,
    pinnedAt: row.pinnedAt,
    archivedAt: row.archivedAt,
    deletedAt: row.deletedAt,
    checkedBehavior: CheckedBehavior.parse(row.checkedBehavior),
    isPrimary: row.isPrimary,
    sort: row.sort,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    items: items,
  );

  static ShoppingProduct _product(LocalProduct row) => ShoppingProduct(
    id: row.id,
    noteId: row.noteId,
    name: row.name,
    sectionId: row.sectionId,
    defaultQuantity: row.defaultQuantity,
    restockMode: RestockMode.parse(row.restockMode),
    restockIntervalDays: row.restockIntervalDays,
    lastBoughtAt: row.lastBoughtAt,
    timesBought: row.timesBought,
    restockedFor: row.restockedFor,
    updatedAt: row.updatedAt,
  );
}
