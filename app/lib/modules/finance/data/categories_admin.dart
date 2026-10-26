import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import 'finance_changes.dart';
import 'finance_providers.dart';
import 'json.dart';
import 'models.dart';

const categoryIconChoices = [
  'house',
  'key-round',
  'zap',
  'droplet',
  'flame',
  'wifi',
  'wrench',
  'sofa',
  'bath',
  'utensils',
  'shopping-cart',
  'utensils-crossed',
  'coffee',
  'pizza',
  'wine',
  'beer',
  'croissant',
  'apple',
  'car',
  'fuel',
  'bus',
  'train-front',
  'car-taxi-front',
  'square-parking',
  'bike',
  'plane',
  'hotel',
  'map',
  'party-popper',
  'clapperboard',
  'popcorn',
  'ticket',
  'music',
  'gamepad-2',
  'dices',
  'dumbbell',
  'trophy',
  'mountain',
  'heart-pulse',
  'pill',
  'stethoscope',
  'hospital',
  'syringe',
  'shield-plus',
  'repeat',
  'tv',
  'app-window',
  'smartphone',
  'laptop',
  'headphones',
  'camera',
  'shirt',
  'glasses',
  'scissors',
  'gem',
  'graduation-cap',
  'book-open',
  'school',
  'newspaper',
  'gift',
  'cake',
  'baby',
  'dog',
  'cat',
  'paw-print',
  'landmark',
  'receipt',
  'percent',
  'briefcase',
  'sparkles',
  'rotate-ccw',
  'coins',
  'piggy-bank',
  'hand-coins',
  'tree-palm',
  'circle-ellipsis',
];

const categoryColorChoices = ['c1', 'c2', 'c3', 'c4', 'c5', 'c6', 'c7', 'c8'];

String normalizeTagName(String raw) => raw.trim().replaceFirst(RegExp(r'^#+'), '').trim().toLowerCase();

class AdminCategoryEntry {
  const AdminCategoryEntry({required this.category, required this.parent});

  final Category category;
  final Category? parent;

  String get icon => category.icon ?? parent?.icon ?? fallbackCategoryIcon;

  String get label => parent == null ? category.name : '${parent!.name} › ${category.name}';
}

class CategoryTree {
  CategoryTree(this.roots)
    : entries = [
        for (final parent in roots) ...[
          AdminCategoryEntry(category: parent, parent: null),
          for (final child in parent.children) AdminCategoryEntry(category: child, parent: parent),
        ],
      ];

  final List<Category> roots;
  final List<AdminCategoryEntry> entries;

  List<Category> topLevel(CategoryKind kind) => [
    for (final category in roots)
      if (category.kind == kind && !category.archived) category,
  ];

  List<Category> visible(CategoryKind kind, {required bool showArchived}) => [
    for (final category in roots)
      if (category.kind == kind && (showArchived || !category.archived))
        category.withChildren([
          for (final child in category.children)
            if (showArchived || !child.archived) child,
        ]),
  ];

  int archivedCount(CategoryKind kind) =>
      entries.where((entry) => entry.category.kind == kind && entry.category.archived).length;

  List<AdminCategoryEntry> reassignTargets(Category category) => [
    for (final entry in entries)
      if (entry.category.kind == category.kind &&
          !entry.category.archived &&
          !(entry.parent?.archived ?? false) &&
          entry.category.id != category.id)
        entry,
  ];
}

class CategoryDraft {
  CategoryDraft({required this.kind, this.name = '', this.parentId, this.icon, this.color, this.opensPeriod = false});

  factory CategoryDraft.edit(Category category) => CategoryDraft(
    kind: category.kind,
    name: category.name,
    parentId: category.parentId,
    icon: category.icon,
    color: category.color,
    opensPeriod: category.opensPeriod,
  );

  CategoryKind kind;
  String name;
  String? parentId;
  String? icon;
  String? color;
  bool opensPeriod;

  bool get valid => name.trim().isNotEmpty;

  void changeKind(CategoryKind value) {
    if (value == kind) return;
    kind = value;
    parentId = null;
    opensPeriod = false;
  }

  Json toPayload({required bool creating, required bool canChangeParent}) => {
    'name': name.trim(),
    'icon': icon,
    'color': parentId == null ? color : null,
    if (kind == CategoryKind.income) 'opens_period': opensPeriod,
    if (canChangeParent) 'parent_id': parentId,
    if (creating && parentId == null) 'kind': kind.api,
  };
}

final adminCategoriesProvider = FutureProvider<CategoryTree>(
  (ref) async => CategoryTree((await ref.watch(categoriesProvider.future)).tree),
);

final categoriesAdminRepositoryProvider = Provider<CategoriesAdminRepository>(
  (ref) => CategoriesAdminRepository(ref.watch(dioProvider), ref.read(financeChangesProvider.notifier)),
);

class CategoriesAdminRepository {
  CategoriesAdminRepository(this._dio, this._changes);

  final Dio _dio;
  final FinanceChanges _changes;

  static const _base = '/v1/finance';

  Future<Category> create(Json input) async {
    final response = await _dio.post<Json>('$_base/categories', data: input);
    _changes.notify(const [FinanceScope.categories]);
    return Category.fromJson(response.data!['data'] as Json);
  }

  Future<Category> update(String id, Json input) async {
    final response = await _dio.patch<Json>('$_base/categories/$id', data: input);
    _changes.notify(const [FinanceScope.categories]);
    return Category.fromJson(response.data!['data'] as Json);
  }

  Future<Category> setArchived(String id, bool archived) => update(id, {'archived': archived});

  Future<void> remove(String id, {String? reassignTo}) async {
    await _dio.delete<Object?>('$_base/categories/$id', queryParameters: {'reassign_to': ?reassignTo});
    _changes.notify(const [FinanceScope.categories, FinanceScope.transactions, FinanceScope.budgets]);
  }

  Future<Tag> renameTag(String id, String name) async {
    final response = await _dio.patch<Json>('$_base/tags/$id', data: {'name': normalizeTagName(name)});
    _changes.notify(const [FinanceScope.tags, FinanceScope.transactions]);
    return Tag.fromJson(response.data!['data'] as Json);
  }

  Future<Tag> mergeTag(String id, String intoTagId) async {
    final response = await _dio.post<Json>('$_base/tags/$id/merge', data: {'into_tag_id': intoTagId});
    _changes.notify(const [FinanceScope.tags, FinanceScope.transactions]);
    return Tag.fromJson(response.data!['data'] as Json);
  }

  Future<void> removeTag(String id) async {
    await _dio.delete<Object?>('$_base/tags/$id');
    _changes.notify(const [FinanceScope.tags, FinanceScope.transactions]);
  }
}
