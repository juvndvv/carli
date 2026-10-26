import 'package:flutter/foundation.dart';

enum NoteType {
  text('text', 'Texto'),
  list('list', 'Lista'),
  shopping('shopping', 'Compra');

  const NoteType(this.wire, this.label);

  final String wire;
  final String label;

  static NoteType parse(String? value) => values.firstWhere((type) => type.wire == value, orElse: () => text);
}

enum CheckedBehavior {
  move('move'),
  inline('inline');

  const CheckedBehavior(this.wire);

  final String wire;

  static CheckedBehavior parse(String? value) => value == inline.wire ? inline : move;
}

enum RestockMode {
  everyTrip('every_trip'),
  interval('interval'),
  none('none');

  const RestockMode(this.wire);

  final String wire;

  static RestockMode parse(String? value) => values.firstWhere((mode) => mode.wire == value, orElse: () => none);
}

@immutable
class NoteFolder {
  const NoteFolder({
    required this.id,
    required this.parentId,
    required this.name,
    required this.position,
    required this.updatedAt,
  });

  final String id;
  final String? parentId;
  final String name;
  final int position;
  final DateTime updatedAt;
}

@immutable
class NoteItem {
  const NoteItem({
    required this.id,
    required this.noteId,
    required this.text,
    this.productId,
    this.quantity,
    this.sectionId,
    this.checkedAt,
    required this.position,
    required this.updatedAt,
  });

  final String id;
  final String noteId;
  final String? productId;
  final String text;
  final String? quantity;
  final String? sectionId;
  final DateTime? checkedAt;
  final int position;
  final DateTime updatedAt;

  bool get checked => checkedAt != null;
}

@immutable
class Note {
  const Note({
    required this.id,
    required this.type,
    this.folderId,
    this.title,
    this.body,
    this.pinnedAt,
    this.archivedAt,
    this.deletedAt,
    this.checkedBehavior = CheckedBehavior.move,
    this.isPrimary = false,
    this.sort = 0,
    required this.createdAt,
    required this.updatedAt,
    this.items = const [],
  });

  final String id;
  final NoteType type;
  final String? folderId;
  final String? title;
  final String? body;
  final DateTime? pinnedAt;
  final DateTime? archivedAt;
  final DateTime? deletedAt;
  final CheckedBehavior checkedBehavior;
  final bool isPrimary;
  final int sort;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<NoteItem> items;

  bool get pinned => pinnedAt != null;
  bool get archived => archivedAt != null;
  bool get deleted => deletedAt != null;
  bool get active => !archived && !deleted;

  int get checkedCount => items.where((item) => item.checked).length;
  int get openCount => items.length - checkedCount;

  String get displayTitle {
    final trimmed = title?.trim() ?? '';
    if (trimmed.isNotEmpty) return trimmed;
    final firstLine = (body ?? '').trim().split('\n').first.trim();
    if (firstLine.isNotEmpty) return firstLine;
    return switch (type) {
      NoteType.text => 'Nota sin título',
      NoteType.list => 'Lista sin título',
      NoteType.shopping => 'Lista de la compra',
    };
  }

  bool get isEmpty => (title?.trim() ?? '').isEmpty && (body?.trim() ?? '').isEmpty && items.isEmpty;
}

@immutable
class ShoppingSection {
  const ShoppingSection({required this.id, required this.name, required this.position});

  final String id;
  final String name;
  final int position;
}

@immutable
class ShoppingProduct {
  const ShoppingProduct({
    required this.id,
    required this.noteId,
    required this.name,
    this.sectionId,
    this.defaultQuantity,
    this.restockMode = RestockMode.none,
    this.restockIntervalDays,
    this.lastBoughtAt,
    this.timesBought = 0,
    this.restockedFor,
    required this.updatedAt,
  });

  final String id;
  final String noteId;
  final String name;
  final String? sectionId;
  final String? defaultQuantity;
  final RestockMode restockMode;
  final int? restockIntervalDays;
  final DateTime? lastBoughtAt;
  final int timesBought;
  final String? restockedFor;
  final DateTime updatedAt;
}
