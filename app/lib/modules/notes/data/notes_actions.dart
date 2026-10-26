import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../finance/data/json.dart';
import 'models.dart';
import 'notes_store.dart';
import 'notes_sync.dart';
import 'section_guess.dart';
import 'text_fold.dart';
import 'views.dart';

final notesActionsProvider = Provider<NotesActions>(NotesActions.new);

/// Every change to Notas goes through here: it is applied to the local cache at once and queued for the server.
class NotesActions {
  NotesActions(this._ref);

  final Ref _ref;

  static const _uuid = Uuid();

  NotesStore get _store => _ref.read(notesStoreProvider);

  DateTime _now() => _ref.read(notesClockProvider)();

  String newId() => _uuid.v7();

  Future<NotesIndex> _index() => _store.load();

  Future<void> _record(String type, Json payload) async {
    await _store.record(NoteOperation(id: newId(), type: type, at: _now(), payload: payload));
    _ref.read(notesSyncProvider.notifier).requestSync();
  }

  Future<void> refreshRestock() => _store.restock(_now());

  Future<String> createNote(NoteType type, {String? folderId, String? title, String? body}) async {
    final id = newId();
    await _record('note.upsert', {
      'id': id,
      'type': type.wire,
      'folder_id': folderId,
      'title': title,
      'body': body,
      'checked_behavior': (await _defaultCheckedBehavior()).wire,
    });
    return id;
  }

  Future<CheckedBehavior> _defaultCheckedBehavior() async => _ref.read(notesDefaultCheckedBehaviorProvider);

  Future<void> updateNote(String id, {String? title, String? body}) =>
      _record('note.upsert', {'id': id, 'title': ?title, 'body': ?body});

  Future<void> setPinned(String id, bool pinned) => _record('note.upsert', {'id': id, 'pinned': pinned});

  Future<void> setArchived(String id, bool archived) => _record('note.upsert', {'id': id, 'archived': archived});

  Future<void> setDeleted(String id, bool deleted) => _record('note.upsert', {'id': id, 'deleted': deleted});

  Future<void> purge(String id) => _record('note.purge', {'id': id});

  Future<void> moveNote(String id, String? folderId) => _record('note.upsert', {'id': id, 'folder_id': folderId});

  Future<void> setCheckedBehavior(String id, CheckedBehavior behavior) =>
      _record('note.upsert', {'id': id, 'checked_behavior': behavior.wire});

  Future<void> makePrimary(String id) => _record('note.upsert', {'id': id, 'is_primary': true});

  /// Discards a note left empty when its editor closes.
  Future<void> discardIfEmpty(String id) async {
    final note = (await _index()).note(id);
    if (note != null && note.isEmpty && note.type != NoteType.shopping) await purge(id);
  }

  Future<String> duplicate(Note note) async {
    final id = await createNote(
      note.type,
      folderId: note.folderId,
      title: '${note.displayTitle} (copia)',
      body: note.body,
    );
    for (final item in note.items) {
      await _record('item.upsert', {
        'id': newId(),
        'note_id': id,
        'text': item.text,
        'quantity': item.quantity,
        'section_id': item.sectionId,
        'checked': false,
        'position': item.position,
      });
    }
    return id;
  }

  /// Text ↔ list: every non-empty line becomes an item, and the items become lines.
  Future<void> convert(Note note) async {
    switch (note.type) {
      case NoteType.text:
        final lines = (note.body ?? '').split('\n').map((line) => line.trim()).where((line) => line.isNotEmpty);
        await _record('note.upsert', {'id': note.id, 'type': NoteType.list.wire, 'body': null});
        for (final (index, line) in lines.indexed) {
          await _record('item.upsert', {
            'id': newId(),
            'note_id': note.id,
            'text': line.replaceFirst(RegExp(r'^[-*•]\s*'), ''),
            'checked': false,
            'position': index,
          });
        }
      case NoteType.list:
        await _record('note.upsert', {
          'id': note.id,
          'type': NoteType.text.wire,
          'body': note.items.map((item) => item.text).join('\n'),
        });
        for (final item in note.items) {
          await _record('item.delete', {'id': item.id});
        }
      case NoteType.shopping:
        return;
    }
  }

  Future<String> createFolder(String name, {String? parentId}) async {
    final id = newId();
    final siblings = (await _index()).folders.where((folder) => folder.parentId == parentId);
    await _record('folder.upsert', {
      'id': id,
      'parent_id': parentId,
      'name': name.trim(),
      'position': siblings.fold(-1, (max, folder) => folder.position > max ? folder.position : max) + 1,
    });
    return id;
  }

  Future<void> renameFolder(String id, String name) => _record('folder.upsert', {'id': id, 'name': name.trim()});

  Future<bool> moveFolder(String id, String? parentId) async {
    final index = await _index();
    if (parentId != null && FolderTree(index.folders).descendantsAndSelf(id).contains(parentId)) return false;
    await _record('folder.upsert', {'id': id, 'parent_id': parentId});
    return true;
  }

  Future<void> reorderFolders(List<NoteFolder> ordered) async {
    for (final (position, folder) in ordered.indexed) {
      if (folder.position != position) await _record('folder.upsert', {'id': folder.id, 'position': position});
    }
  }

  Future<void> deleteFolder(String id) => _record('folder.delete', {'id': id});

  Json _itemPayload(NoteItem item) => {
    'id': item.id,
    'note_id': item.noteId,
    'text': item.text,
    'quantity': item.quantity,
    'section_id': item.sectionId,
    'product_id': item.productId,
    'checked': item.checked,
    'position': item.position,
  };

  Future<String> addItem(String noteId, String text, {int? position}) async {
    final note = (await _index()).note(noteId);
    final id = newId();
    final last = note?.items.fold(-1, (max, item) => item.position > max ? item.position : max) ?? -1;
    if (position != null) {
      for (final item in note?.items ?? const <NoteItem>[]) {
        if (item.position >= position) {
          await _record('item.upsert', {..._itemPayload(item), 'position': item.position + 1});
        }
      }
    }
    await _record('item.upsert', {
      'id': id,
      'note_id': noteId,
      'text': text.trim(),
      'checked': false,
      'position': position ?? last + 1,
    });
    return id;
  }

  Future<void> renameItem(NoteItem item, String text) =>
      _record('item.upsert', {..._itemPayload(item), 'text': text.trim()});

  Future<void> setChecked(NoteItem item, bool checked) =>
      _record('item.upsert', {..._itemPayload(item), 'checked': checked});

  Future<void> deleteItem(NoteItem item) => _record('item.delete', {'id': item.id});

  Future<void> restoreItem(NoteItem item) => _record('item.upsert', _itemPayload(item));

  Future<void> reorderItems(List<NoteItem> ordered) async {
    for (final (position, item) in ordered.indexed) {
      if (item.position != position) await _record('item.upsert', {..._itemPayload(item), 'position': position});
    }
  }

  Future<void> uncheckAll(Note note) async {
    for (final item in note.items.where((item) => item.checked)) {
      await setChecked(item, false);
    }
  }

  /// Adds a product to a shopping list, reusing what the list has learnt about it (section and usual quantity).
  Future<void> addProduct(String noteId, String name, {String? quantity}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final index = await _index();
    final note = index.note(noteId);
    if (note == null) return;
    final product = index.productsOf(noteId).where((product) => fold(product.name) == fold(trimmed)).firstOrNull;
    final listed = product == null ? null : note.items.where((item) => item.productId == product.id).firstOrNull;
    if (listed != null) {
      if (listed.checked) await setChecked(listed, false);
      return;
    }
    final productId = product?.id ?? newId();
    final sectionId = product?.sectionId ?? guessSectionId(trimmed, index.sections);
    if (product == null) {
      await _record('product.upsert', {
        'id': productId,
        'note_id': noteId,
        'name': trimmed,
        'section_id': sectionId,
        'default_quantity': quantity,
      });
    }
    await _record('item.upsert', {
      'id': newId(),
      'note_id': noteId,
      'product_id': productId,
      'text': product?.name ?? trimmed,
      'quantity': quantity ?? product?.defaultQuantity,
      'section_id': sectionId,
      'checked': false,
      'position': note.items.fold(-1, (max, item) => item.position > max ? item.position : max) + 1,
    });
  }

  /// Edits a shopping item; the product remembers the section and quantity for next time.
  Future<void> updateShoppingItem(NoteItem item, {required String text, String? quantity, String? sectionId}) async {
    final normalizedQuantity = (quantity?.trim().isEmpty ?? true) ? null : quantity!.trim();
    await _record('item.upsert', {
      ..._itemPayload(item),
      'text': text.trim(),
      'quantity': normalizedQuantity,
      'section_id': sectionId,
    });
    if (item.productId case final productId?) {
      await _record('product.upsert', {
        'id': productId,
        'name': text.trim(),
        'section_id': sectionId,
        'default_quantity': normalizedQuantity,
      });
    }
  }

  Future<void> setRestock(ShoppingProduct product, RestockMode mode, {int? intervalDays}) async {
    await _record('product.upsert', {
      'id': product.id,
      'restock_mode': mode.wire,
      'restock_interval_days': mode == RestockMode.interval ? intervalDays : null,
    });
    await refreshRestock();
  }

  Future<void> forgetProduct(ShoppingProduct product) => _record('product.delete', {'id': product.id});

  /// Empties the cart and stamps each product's purchase date, which restock counts from. Returns an undo.
  Future<Future<void> Function()> finishShopping(Note note) async {
    final cart = note.items.where((item) => item.checked).toList();
    final index = await _index();
    final products = {for (final product in index.productsOf(note.id)) product.id: product};
    final finishedAt = _now();
    await _record('shopping.finish', {
      'note_id': note.id,
      'item_ids': [for (final item in cart) item.id],
      'finished_at': finishedAt.toUtc().toIso8601String(),
    });
    final restocked = {for (final item in (await _index()).note(note.id)?.items ?? const <NoteItem>[]) item.id}
      ..removeAll(note.items.map((item) => item.id));
    return () async {
      for (final id in restocked) {
        await _record('item.delete', {'id': id});
      }
      for (final item in cart) {
        final product = products[item.productId];
        if (product != null) {
          await _record('product.upsert', {
            'id': product.id,
            'last_bought_at': product.lastBoughtAt?.toUtc().toIso8601String(),
            'times_bought': product.timesBought,
            'restocked_for': product.restockedFor,
          });
        }
        await restoreItem(item);
      }
    };
  }

  Future<String> createSection(String name) async {
    final id = newId();
    final sections = (await _index()).sections;
    await _record('section.upsert', {'id': id, 'name': name.trim(), 'position': sections.length});
    return id;
  }

  Future<void> renameSection(String id, String name) => _record('section.upsert', {'id': id, 'name': name.trim()});

  Future<void> reorderSections(List<ShoppingSection> ordered) async {
    for (final (position, section) in ordered.indexed) {
      if (section.position != position) await _record('section.upsert', {'id': section.id, 'position': position});
    }
  }

  Future<void> deleteSection(String id) => _record('section.delete', {'id': id});
}
