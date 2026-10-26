import 'finance_providers.dart';

const quickCategoryCount = 8;

List<CategoryEntry> quickCategoryEntries(
  List<CategoryEntry> entries,
  List<String> recentIds,
  int limit, {
  String? selectedId,
}) {
  final byId = {for (final entry in entries) entry.category.id: entry};
  final chosen = <CategoryEntry>[];
  void push(CategoryEntry? entry) {
    if (entry != null && !chosen.contains(entry)) chosen.add(entry);
  }

  recentIds.map((id) => byId[id]).forEach(push);
  entries.where((entry) => entry.parent == null).forEach(push);
  entries.forEach(push);
  final quick = chosen.take(limit).toList();
  final selected = selectedId == null ? null : byId[selectedId];
  if (selected != null && !quick.contains(selected) && quick.isNotEmpty) quick[quick.length - 1] = selected;
  return quick;
}
