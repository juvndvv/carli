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

class AdminCategory {
  const AdminCategory({
    required this.id,
    required this.name,
    required this.kind,
    required this.parentId,
    required this.icon,
    required this.color,
    required this.sortOrder,
    required this.opensPeriod,
    required this.archived,
    this.children = const [],
  });

  factory AdminCategory.fromJson(Json json) => AdminCategory(
    id: json['id'] as String,
    name: json['name'] as String,
    kind: CategoryKind.of(json['kind'] as String?),
    parentId: json['parent_id'] as String?,
    icon: json['icon'] as String?,
    color: json['color'] as String?,
    sortOrder: intOf(json['sort_order']),
    opensPeriod: json['opens_period'] as bool? ?? false,
    archived: json['archived'] as bool? ?? false,
    children: parseList(json['children'], AdminCategory.fromJson),
  );

  final String id;
  final String name;
  final CategoryKind kind;
  final String? parentId;
  final String? icon;
  final String? color;
  final int sortOrder;
  final bool opensPeriod;
  final bool archived;
  final List<AdminCategory> children;

  bool get hasChildren => children.isNotEmpty;
}

class AdminCategoryEntry {
  const AdminCategoryEntry({required this.category, required this.parent});

  final AdminCategory category;
  final AdminCategory? parent;

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

  final List<AdminCategory> roots;
  final List<AdminCategoryEntry> entries;

  List<AdminCategory> topLevel(CategoryKind kind) => [
    for (final category in roots)
      if (category.kind == kind && !category.archived) category,
  ];

  List<AdminCategory> visible(CategoryKind kind, {required bool showArchived}) => [
    for (final category in roots)
      if (category.kind == kind && (showArchived || !category.archived))
        AdminCategory(
          id: category.id,
          name: category.name,
          kind: category.kind,
          parentId: category.parentId,
          icon: category.icon,
          color: category.color,
          sortOrder: category.sortOrder,
          opensPeriod: category.opensPeriod,
          archived: category.archived,
          children: [
            for (final child in category.children)
              if (showArchived || !child.archived) child,
          ],
        ),
  ];

  int archivedCount(CategoryKind kind) =>
      entries.where((entry) => entry.category.kind == kind && entry.category.archived).length;

  List<AdminCategoryEntry> reassignTargets(AdminCategory category) => [
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

  factory CategoryDraft.edit(AdminCategory category) => CategoryDraft(
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

final adminCategoriesProvider = FutureProvider<CategoryTree>((ref) async {
  ref.watchFinance(const [FinanceScope.categories]);
  return ref.watch(categoriesAdminRepositoryProvider).categories();
});

final categoriesAdminRepositoryProvider = Provider<CategoriesAdminRepository>(
  (ref) => CategoriesAdminRepository(ref.watch(dioProvider), ref.read(financeChangesProvider.notifier)),
);

class CategoriesAdminRepository {
  CategoriesAdminRepository(this._dio, this._changes);

  final Dio _dio;
  final FinanceChanges _changes;

  static const _base = '/v1/finance';

  Future<CategoryTree> categories() async {
    final response = await _dio.get<Json>('$_base/categories', queryParameters: {'include_archived': '1'});
    return CategoryTree(parseList(response.data!['data'], AdminCategory.fromJson));
  }

  Future<AdminCategory> create(Json input) async {
    final response = await _dio.post<Json>('$_base/categories', data: input);
    _changes.notify(const [FinanceScope.categories]);
    return AdminCategory.fromJson(response.data!['data'] as Json);
  }

  Future<AdminCategory> update(String id, Json input) async {
    final response = await _dio.patch<Json>('$_base/categories/$id', data: input);
    _changes.notify(const [FinanceScope.categories]);
    return AdminCategory.fromJson(response.data!['data'] as Json);
  }

  Future<AdminCategory> setArchived(String id, bool archived) => update(id, {'archived': archived});

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
