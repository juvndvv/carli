import 'package:flutter_test/flutter_test.dart';

import 'package:carli/modules/finance/data/finance_providers.dart';
import 'package:carli/modules/finance/data/models.dart';
import 'package:carli/modules/finance/data/transaction_filters.dart';
import 'package:carli/modules/finance/data/transaction_form.dart';
import 'package:carli/modules/finance/screens/budget_editor.dart';

import '../../support/finance_fixtures.dart';

ShareDraft share(String id, {double? percentage, int? amount}) =>
    ShareDraft(contactId: id, name: id, percentage: percentage, amount: amount);

void main() {
  group('shares', () {
    test('split equally, giving the remainder to the first contacts when I am not included', () {
      final items = [share('ana'), share('luis')];
      expect(previewShares(-1001, ShareMode.equal, true, items).map((item) => item.amount), [333, 333]);
      expect(previewShares(-1001, ShareMode.equal, false, items).map((item) => item.amount), [501, 500]);
    });

    test('split by percentage and by amount', () {
      expect(previewShares(-1000, ShareMode.percentage, true, [share('ana', percentage: 12.5)]).single.amount, 125);
      expect(previewShares(-1000, ShareMode.amount, true, [share('ana', amount: 300)]).single.amount, 300);
      expect(previewShares(0, ShareMode.equal, true, [share('ana')]).single.amount, 0);
    });

    test('build the API input for each mode', () {
      expect(toSharesInput(ShareMode.equal, false, [share('ana')]), {
        'mode': 'equal',
        'include_self': false,
        'items': [
          {'contact_id': 'ana'},
        ],
      });
      expect(toSharesInput(ShareMode.percentage, true, [share('ana', percentage: 40)])['items'], [
        {'contact_id': 'ana', 'percentage': 40.0},
      ]);
      expect(toSharesInput(ShareMode.amount, true, [share('ana', amount: 250)])['items'], [
        {'contact_id': 'ana', 'amount_cents': 250},
      ]);
    });
  });

  group('splits', () {
    test('track what is left to assign', () {
      final splits = [SplitDraft(categoryId: 'a', amount: 600), SplitDraft(categoryId: 'b', amount: 300)];
      expect(splitRemaining(-1000, splits), 100);
      expect(splitRemaining(-800, splits), -100);
    });

    test('sign the parts by kind and drop incomplete lines', () {
      final splits = [SplitDraft(categoryId: 'a', amount: 600), SplitDraft(amount: 400), SplitDraft(categoryId: 'c')];
      expect(toSplitInputs(TransactionKind.expense, splits), [
        {'category_id': 'a', 'amount_cents': -600},
      ]);
      expect(toSplitInputs(TransactionKind.income, splits).single['amount_cents'], 600);
    });
  });

  test('parses tags like Angular', () {
    expect(parseTagInput(' #Viaje, casa  #Casa'), ['viaje', 'casa', 'casa']);
    expect(parseTagInput(' , '), isEmpty);
  });

  test('a date range replaces the period in the query', () {
    final filters = TransactionFilters(
      from: DateTime(2026, 10, 1),
      to: DateTime(2026, 10, 15),
      tags: const {'viaje'},
      min: 1000,
      max: 5000,
    );
    final query = filters.toApiQuery('p-oct');

    expect(query['period_id'], isNull);
    expect(query['from'], '2026-10-01');
    expect(query['to'], '2026-10-15');
    expect(query['tag'], ['viaje']);
    expect(query['min'], 1000);
    expect(filters.activeCount, 3);
    expect(filters.moreFiltersActive, isTrue);
    expect(filters.withPeriod(null).hasDateRange, isFalse);
  });

  group('budget editor', () {
    final categories = CategoryIndex([
      Category.fromJson(categoryJson('home', 'Casa', icon: 'house', children: [categoryJson('rent', 'Alquiler')])),
      Category.fromJson(categoryJson('salary', 'Nómina', kind: 'income')),
    ]);

    test('lists expense categories with their children and current limits', () {
      final lines = buildBudgetLines(categories, [
        BudgetRow.fromJson(budgetRowJson(categoryId: 'rent', name: 'Alquiler', amount: 80000)..['rollover'] = true),
      ]);

      expect(lines.map((line) => line.name), ['Casa', 'Alquiler']);
      expect(lines.last.child, isTrue);
      expect(lines.last.icon, 'house');
      expect(lines.last.initialAmount, 80000);
      expect(lines.last.rollover, isTrue);
    });

    test('sends only what changed, with null to remove a limit', () {
      final lines = buildBudgetLines(categories, [
        BudgetRow.fromJson(budgetRowJson(categoryId: 'rent', name: 'Alquiler', amount: 80000)),
      ]);
      lines.first.amount = 30000;
      lines.last.amount = null;

      expect(budgetChanges(lines), [
        {'category_id': 'home', 'amount_cents': 30000, 'rollover': false},
        {'category_id': 'rent', 'amount_cents': null, 'rollover': false},
      ]);
    });
  });
}
