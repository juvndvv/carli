import 'package:carli/core/format/dates.dart';
import 'package:carli/modules/finance/data/json.dart';

import 'fake_api.dart';

Json periodJson({String id = 'p-oct', bool current = true, String name = 'Octubre', String shortName = 'oct'}) => {
  'id': id,
  'start_date': '2026-09-26',
  'end_date': null,
  'expected_end_date': '2026-10-27',
  'effective_end_date': '2026-10-27',
  'is_current': current,
  'opened_by': 'payroll',
  'name': name,
  'short_name': shortName,
  'range_label': '26 sep – 27 oct',
  'label': name,
  'days_total': 32,
  'days_elapsed': 31,
  'days_remaining': 1,
};

Json accountJson({String id = 'acc-main', String name = 'BBVA', String type = 'checking', bool archived = false}) => {
  'id': id,
  'name': name,
  'type': type,
  'balance_cents': 123456,
  'icon': null,
  'archived': archived,
  'bank': null,
};

Json categoryJson(String id, String name, {String kind = 'expense', String? icon, List<Json> children = const []}) => {
  'id': id,
  'name': name,
  'kind': kind,
  'parent_id': null,
  'icon': icon,
  'color': null,
  'archived': false,
  'children': children,
};

Json transactionJson({
  String id = 'tx-1',
  int amount = -4250,
  String kind = 'expense',
  DateTime? date,
  String? payee = 'Mercadona',
  String? categoryId = 'cat-food',
  String categoryName = 'Comida',
  String status = 'cleared',
  String source = 'manual',
}) => {
  'id': id,
  'account_id': 'acc-main',
  'account': {'id': 'acc-main', 'name': 'BBVA', 'type': 'checking'},
  'kind': kind,
  'amount_cents': amount,
  'own_amount_cents': amount,
  'date': isoDate(date ?? today()),
  'category_id': categoryId,
  'category': categoryId == null
      ? null
      : {
          'id': categoryId,
          'name': categoryName,
          'parent': null,
          'parent_id': null,
          'icon': 'utensils',
          'color': null,
          'kind': 'expense',
        },
  'payee': payee,
  'description': null,
  'notes': null,
  'tags': <String>[],
  'status': status,
  'transfer_group_id': null,
  'transfer_account_id': null,
  'recurring_rule_id': null,
  'debt_id': null,
  'source': source,
  'uncategorized': categoryId == null,
  'bank': null,
  'splits': <Json>[],
  'shares': <Json>[],
  'deleted': false,
};

Json transactionPage(List<Json> items, {bool hasMore = false, String? cursor, int? count}) => {
  'data': items,
  'meta': {
    'per_page': 50,
    'has_more': hasMore,
    'next_cursor': cursor,
    'totals': {
      'count': count ?? items.length,
      'income_cents': items.fold<int>(
        0,
        (sum, item) => item['amount_cents'] as int > 0 ? sum + (item['amount_cents'] as int) : sum,
      ),
      'expense_cents': items.fold<int>(
        0,
        (sum, item) => item['amount_cents'] as int < 0 ? sum + (item['amount_cents'] as int) : sum,
      ),
      'own_expense_cents': 0,
      'net_cents': 0,
    },
  },
};

Json budgetRowJson({
  String id = 'b-1',
  String categoryId = 'cat-food',
  String name = 'Comida',
  int amount = 30000,
  int spent = 9000,
  String status = 'ok',
  int sortKey = 1,
}) => {
  'id': id,
  'period_id': 'p-oct',
  'category_id': categoryId,
  'category': {
    'id': categoryId,
    'name': name,
    'parent': null,
    'parent_id': null,
    'icon': 'utensils',
    'color': null,
    'sort_key': sortKey,
  },
  'amount_cents': amount,
  'rollover': false,
  'rollover_in_cents': 0,
  'available_cents': amount,
  'spent_cents': spent,
  'remaining_cents': amount - spent,
  'percent_bp': amount == 0 ? null : spent * 10000 ~/ amount,
  'status': status,
  'projected_cents': spent,
  'projected_status': status,
};

Json budgetTotals({int budgeted = 0, int spent = 0, int projected = 0}) => {
  'budgeted_cents': budgeted,
  'spent_cents': spent,
  'remaining_cents': budgeted - spent,
  'percent_bp': budgeted == 0 ? null : spent * 10000 ~/ budgeted,
  'projected_cents': projected,
};

Json budgetsJson(List<Json> rows, {Json? previous, Json? uncategorized}) => {
  'data': rows,
  'meta': {
    'period': periodJson(),
    'previous_period': previous,
    'totals': budgetTotals(
      budgeted: rows.fold(0, (sum, row) => sum + (row['amount_cents'] as int)),
      spent: rows.fold(0, (sum, row) => sum + (row['spent_cents'] as int)),
      projected: rows.fold(0, (sum, row) => sum + (row['projected_cents'] as int)),
    ),
    'uncategorized': ?uncategorized,
  },
};

Json dashboardJson({List<Json> recent = const [], List<Json> budgets = const []}) => {
  'period': periodJson(),
  'previous_period': periodJson(id: 'p-sep', current: false, name: 'Septiembre', shortName: 'sep'),
  'income_cents': 269500,
  'expense_cents': 123456,
  'savings_cents': 146044,
  'savings_rate_bp': 5419,
  'net_worth_cents': 1834500,
  'net_worth_previous_cents': 1700000,
  'net_worth_delta_cents': 134500,
  'previous': null,
  'deltas_bp': {'income': 0, 'expense': -1200, 'savings': 900},
  'by_category': [
    {
      'category_id': 'cat-food',
      'name': 'Comida',
      'icon': 'utensils',
      'color': 'c2',
      'amount_cents': 32000,
      'percent_bp': 4000,
      'children': <Json>[],
    },
    {
      'category_id': 'cat-home',
      'name': 'Casa',
      'icon': 'house',
      'color': null,
      'amount_cents': 65000,
      'percent_bp': 6000,
      'children': <Json>[],
    },
  ],
  'history': [
    {
      'period_id': 'p-sep',
      'label': 'sep',
      'name': 'Septiembre',
      'start_date': '2026-08-27',
      'end_date': '2026-09-25',
      'income_cents': 269500,
      'expense_cents': 151000,
      'net_worth_cents': 1700000,
    },
    {
      'period_id': 'p-oct',
      'label': 'oct',
      'name': 'Octubre',
      'start_date': '2026-09-26',
      'end_date': null,
      'income_cents': 269500,
      'expense_cents': 123456,
      'net_worth_cents': 1834500,
    },
  ],
  'budgets': {'top': budgets, 'totals': budgetTotals()},
  'upcoming': <Json>[],
  'recent_transactions': recent,
};

Map<String, FakeRoute> financeBaseRoutes({List<Json>? accounts}) => {
  'GET /v1/finance/accounts': (_) => (
    200,
    {
      'data': accounts ?? [accountJson()],
      'meta': {'net_worth_cents': 123456},
    },
  ),
  'GET /v1/finance/categories': (_) => (
    200,
    {
      'data': [
        categoryJson('cat-food', 'Comida', icon: 'utensils'),
        categoryJson('cat-home', 'Casa', icon: 'house'),
        categoryJson('cat-salary', 'Nómina', kind: 'income', icon: 'wallet'),
      ],
    },
  ),
  'GET /v1/finance/periods': (_) => (
    200,
    {
      'data': [periodJson(), periodJson(id: 'p-sep', current: false, name: 'Septiembre', shortName: 'sep')],
    },
  ),
  'GET /v1/finance/settings': (_) => (
    200,
    {
      'data': {
        'default_account_id': null,
        'last_used_account_id': 'acc-main',
        'budget_warning_threshold': 80,
        'period_min_days': 20,
        'period_mode': 'payroll',
        'remind_days_before': 2,
      },
    },
  ),
};
