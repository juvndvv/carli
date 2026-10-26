import 'package:flutter_test/flutter_test.dart';

import 'package:carli/modules/finance/data/categories_admin.dart';
import 'package:carli/modules/finance/data/models.dart';

AdminCategory category(
  String id, {
  String kind = 'expense',
  bool archived = false,
  List<AdminCategory> children = const [],
}) => AdminCategory(
  id: id,
  name: id,
  kind: CategoryKind.of(kind),
  parentId: null,
  icon: null,
  color: null,
  sortOrder: 0,
  opensPeriod: false,
  archived: archived,
  children: children,
);

void main() {
  test('normalizes tag names', () {
    expect(normalizeTagName('  ##Vacaciones-2026 '), 'vacaciones-2026');
    expect(normalizeTagName('#'), '');
  });

  test('changing the kind resets the parent and the period flag', () {
    final draft = CategoryDraft(kind: CategoryKind.income, parentId: 'p', opensPeriod: true)
      ..changeKind(CategoryKind.expense);
    expect(draft.parentId, isNull);
    expect(draft.opensPeriod, isFalse);
  });

  test('builds payloads like the web form', () {
    final child = CategoryDraft(kind: CategoryKind.expense, name: ' Pienso ', parentId: 'p', icon: 'dog', color: 'c4');
    expect(child.toPayload(creating: true, canChangeParent: true), {
      'name': 'Pienso',
      'icon': 'dog',
      'color': null,
      'parent_id': 'p',
    });

    final income = CategoryDraft(kind: CategoryKind.income, name: 'Nómina', color: 'c1', opensPeriod: true);
    expect(income.toPayload(creating: false, canChangeParent: false), {
      'name': 'Nómina',
      'icon': null,
      'color': 'c1',
      'opens_period': true,
    });
  });

  test('offers active categories of the same kind as reassignment targets', () {
    final tree = CategoryTree([
      category('home', children: [category('rent'), category('old', archived: true)]),
      category('gone', archived: true, children: [category('inside')]),
      category('salary', kind: 'income'),
    ]);

    expect([for (final entry in tree.reassignTargets(category('rent'))) entry.label], ['home']);
    expect(tree.archivedCount(CategoryKind.expense), 2);
    expect(tree.visible(CategoryKind.expense, showArchived: false).single.children.map((c) => c.id), ['rent']);
  });
}
