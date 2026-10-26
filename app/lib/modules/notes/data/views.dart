import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/modules/modules_provider.dart';
import 'models.dart';
import 'notes_store.dart';
import 'text_fold.dart';

const notesModuleId = 'notes';

final notesDefaultCheckedBehaviorProvider = Provider<CheckedBehavior>((ref) {
  final module = ref.watch(modulesProvider).value?.where((module) => module.id == notesModuleId).firstOrNull;
  return CheckedBehavior.parse(module?.settings['checked_behavior'] as String?);
});

class FolderTree {
  FolderTree(this.folders);

  final List<NoteFolder> folders;

  late final Map<String, NoteFolder> _byId = {for (final folder in folders) folder.id: folder};
  late final Map<String?, List<NoteFolder>> _children = () {
    final children = <String?, List<NoteFolder>>{};
    for (final folder in folders) {
      (children[_byId.containsKey(folder.parentId) ? folder.parentId : null] ??= []).add(folder);
    }
    for (final list in children.values) {
      list.sort((a, b) => a.position != b.position ? a.position.compareTo(b.position) : a.name.compareTo(b.name));
    }
    return children;
  }();

  NoteFolder? find(String? id) => id == null ? null : _byId[id];

  List<NoteFolder> childrenOf(String? parentId) => _children[parentId] ?? const [];

  /// From the top folder down to [id], both included.
  List<NoteFolder> pathTo(String? id) {
    final path = <NoteFolder>[];
    final seen = <String>{};
    var current = find(id);
    while (current != null && seen.add(current.id)) {
      path.insert(0, current);
      current = find(current.parentId);
    }
    return path;
  }

  Set<String> descendantsAndSelf(String id) {
    final result = <String>{id};
    final pending = [id];
    while (pending.isNotEmpty) {
      for (final child in childrenOf(pending.removeLast())) {
        if (result.add(child.id)) pending.add(child.id);
      }
    }
    return result;
  }

  /// Depth-first order for the tree picker, with each folder's depth.
  List<(NoteFolder, int)> flatten({String? excluding}) {
    final result = <(NoteFolder, int)>[];
    void visit(String? parentId, int depth) {
      for (final folder in childrenOf(parentId)) {
        if (folder.id == excluding) continue;
        result.add((folder, depth));
        visit(folder.id, depth + 1);
      }
    }

    visit(null, 0);
    return result;
  }
}

enum NotesFilter {
  all('Todas'),
  text('Texto'),
  list('Listas'),
  shopping('Compra');

  const NotesFilter(this.label);

  final String label;

  bool accepts(Note note) => switch (this) {
    NotesFilter.all => true,
    NotesFilter.text => note.type == NoteType.text,
    NotesFilter.list => note.type == NoteType.list,
    NotesFilter.shopping => note.type == NoteType.shopping,
  };
}

int compareNotes(Note a, Note b) {
  if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
  return b.updatedAt.compareTo(a.updatedAt);
}

extension NotesIndexViews on NotesIndex {
  FolderTree get tree => FolderTree(folders);

  List<Note> get activeNotes => [
    for (final note in notes)
      if (note.active) note,
  ]..sort(compareNotes);

  List<Note> get archivedNotes => [
    for (final note in notes)
      if (note.archived && !note.deleted) note,
  ]..sort(compareNotes);

  List<Note> get trashedNotes => [
    for (final note in notes)
      if (note.deleted) note,
  ]..sort((a, b) => b.deletedAt!.compareTo(a.deletedAt!));

  List<Note> get pinnedNotes => [
    for (final note in activeNotes)
      if (note.pinned) note,
  ];

  List<Note> get recentNotes => [
    for (final note in activeNotes)
      if (!note.pinned) note,
  ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  List<Note> notesIn(String folderId) => [
    for (final note in activeNotes)
      if (note.folderId == folderId) note,
  ];

  /// Notes inside a folder and all of its subfolders.
  int recursiveCount(String folderId) {
    final ids = tree.descendantsAndSelf(folderId);
    return activeNotes.where((note) => ids.contains(note.folderId)).length;
  }

  List<String> folderPathOf(Note note) => [for (final folder in tree.pathTo(note.folderId)) folder.name];

  List<Note> shoppingNotes() => [
    for (final note in activeNotes)
      if (note.type == NoteType.shopping) note,
  ];

  Note? get primaryShoppingNote {
    final lists = shoppingNotes();
    return lists.where((note) => note.isPrimary).firstOrNull ?? lists.firstOrNull;
  }

  /// Offline search: accent-insensitive over title, body and items, across every folder.
  List<Note> searchLocally(String query, NotesFilter filter) {
    final trimmed = query.trim();
    return [
      for (final note in [...activeNotes, ...archivedNotes])
        if (filter.accepts(note) &&
            (trimmed.isEmpty ||
                foldedContains(
                  [note.title ?? '', note.body ?? '', for (final item in note.items) item.text].join('\n'),
                  trimmed,
                )))
          note,
    ];
  }
}

String notePreview(Note note) => switch (note.type) {
  NoteType.text => (note.body ?? '').trim().replaceAll(RegExp(r'\s*\n\s*'), ' · '),
  NoteType.list => note.items.isEmpty ? 'Sin elementos' : '${note.checkedCount} de ${note.items.length}',
  NoteType.shopping => note.openCount == 0 ? 'Nada por comprar' : '${note.openCount} por comprar',
};

class ShoppingGroup {
  const ShoppingGroup({required this.section, required this.items});

  final ShoppingSection? section;
  final List<NoteItem> items;

  String get title => section?.name ?? 'Sin sección';
}

/// Open items grouped by supermarket section, in the order the user walks the shop.
List<ShoppingGroup> groupBySection(Note note, List<ShoppingSection> sections) {
  final open = note.items.where((item) => !item.checked);
  return [
    for (final section in sections)
      if (open.where((item) => item.sectionId == section.id).toList() case final items when items.isNotEmpty)
        ShoppingGroup(section: section, items: items),
    if (open.where((item) => !sections.any((section) => section.id == item.sectionId)).toList() case final items
        when items.isNotEmpty)
      ShoppingGroup(section: null, items: items),
  ];
}

/// What the list usually buys and is not on it now, most bought first.
List<ShoppingProduct> suggestionsFor(Note note, List<ShoppingProduct> products, {String query = '', int limit = 6}) {
  final listed = {for (final item in note.items) ?item.productId};
  final candidates = [
    for (final product in products)
      if (!listed.contains(product.id) && (query.isEmpty || foldedContains(product.name, query))) product,
  ];
  candidates.sort((a, b) {
    final byCount = b.timesBought.compareTo(a.timesBought);
    if (byCount != 0) return byCount;
    return (b.lastBoughtAt ?? DateTime(0)).compareTo(a.lastBoughtAt ?? DateTime(0));
  });
  return candidates.take(limit).toList();
}
