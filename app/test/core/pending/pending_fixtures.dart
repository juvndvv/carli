import 'package:carli/core/pending/pending_models.dart';

PendingJson pendingItemJson({
  String module = 'finance',
  String type = 'uncategorized_transaction',
  String id = 'tx-1',
  String title = 'Mercadona',
  String? subtitle = 'BBVA · Importado del banco',
  int? amount = -4250,
  String date = '2026-10-24',
  String route = '/finanzas/movimientos?sin_categoria=1&periodo=todos',
  PendingJson? meta,
}) => {
  'module': module,
  'type': type,
  'id': id,
  'title': title,
  'subtitle': subtitle,
  'amount_cents': amount,
  'date': date,
  'route': route,
  'meta': meta ?? {'transaction_id': id, 'kind': 'expense', 'source': 'bank'},
};

PendingJson recurringPendingJson({String id = 'tx-r', String title = 'Netflix', String ruleId = 'netflix'}) =>
    pendingItemJson(
      type: 'recurring_to_confirm',
      id: id,
      title: title,
      subtitle: 'Cuenta corriente · Por confirmar',
      amount: -1399,
      route: '/finanzas/recurrentes',
      meta: {'transaction_id': id, 'rule_id': ruleId, 'kind': 'expense'},
    );

PendingJson pendingSummaryJson({int uncategorized = 2, int recurring = 1}) => {
  'data': {
    'total': uncategorized + recurring,
    'by_module': [
      if (uncategorized > 0)
        {'module': 'finance', 'module_name': 'Finanzas', 'type': 'uncategorized_transaction', 'count': uncategorized},
      if (recurring > 0)
        {'module': 'finance', 'module_name': 'Finanzas', 'type': 'recurring_to_confirm', 'count': recurring},
    ],
  },
};

PendingJson pendingPageJson(List<PendingJson> items, {String? cursor}) => {
  'data': items,
  'meta': {'has_more': cursor != null, 'next_cursor': cursor},
};

PendingItem pendingItem({String id = 'tx-1', String type = 'uncategorized_transaction'}) =>
    PendingItem.fromJson(pendingItemJson(id: id, type: type));
