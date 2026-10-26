import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:carli/modules/notes/data/models.dart';
import 'package:carli/modules/notes/data/restock.dart';

/// The backend writes the same cases in backend/app/Modules/Notes/tests/Fixtures and checks PHP against them.
void main() {
  final fixture = jsonDecode(File('../backend/app/Modules/Notes/tests/Fixtures/restock_cases.json').readAsStringSync());
  final madrid = DateTime(2026, 1, 15).timeZoneOffset == const Duration(hours: 1) &&
      DateTime(2026, 7, 15).timeZoneOffset == const Duration(hours: 2);

  test('uses the namespace the server uses', () => expect(restockNamespace, fixture['namespace']));

  for (final testCase in fixture['cases'] as List) {
    test(testCase['name'], () {
      final lastBought = testCase['last_bought_at'] == null ? null : DateTime.parse(testCase['last_bought_at']);
      final product = ShoppingProduct(
        id: testCase['product_id'],
        noteId: 'note',
        name: 'Leche',
        restockMode: RestockMode.parse(testCase['restock_mode']),
        restockIntervalDays: testCase['restock_interval_days'],
        lastBoughtAt: lastBought,
        updatedAt: DateTime(2026),
      );
      final today = DateTime.parse(testCase['today']);
      expect(isRestockDue(product, today), testCase['due']);
      if (lastBought != null) {
        final key = restockCycleKey(product.id, lastBought);
        expect(key, testCase['cycle_key']);
        expect(restockItemId(key), testCase['item_id']);
      }
    }, skip: madrid ? false : 'Due dates are checked in the Europe/Madrid time zone');
  }

  test('a product already on the list or brought back in this cycle is left alone', () {
    final boughtAt = DateTime.utc(2026, 10, 1, 10);
    ShoppingProduct product(String id, {String? restockedFor}) => ShoppingProduct(
      id: id,
      noteId: 'note',
      name: id,
      restockMode: RestockMode.everyTrip,
      lastBoughtAt: boughtAt,
      restockedFor: restockedFor,
      updatedAt: boughtAt,
    );
    final listed = NoteItem(id: 'i', noteId: 'note', productId: 'listed', text: 'x', position: 0, updatedAt: boughtAt);
    final due = productsToRestock(
      products: [product('listed'), product('done', restockedFor: restockCycleKey('done', boughtAt)), product('due')],
      items: [listed],
      today: DateTime(2026, 10, 2),
    );
    expect(due.map((product) => product.id), ['due']);
  });

  test('labels the frequency in words', () {
    expect(intervalLabel(7), 'Cada semana');
    expect(intervalLabel(21), 'Cada 3 semanas');
    expect(intervalLabel(30), 'Cada mes');
    expect(intervalLabel(10), 'Cada 10 días');
  });
}
