import 'package:carli/modules/finance/data/json.dart';

Json bankLinkJson({int? balance = 343365, int? difference = 500, String? balanceAt}) => {
  'connection_id': 'conn-1',
  'aspsp_name': 'BBVA',
  'status': 'active',
  'sync_from_date': '2026-01-01',
  'last_synced_at': balanceAt,
  'balance_cents': balance,
  'balance_at': balanceAt,
  'difference_cents': difference,
};

Json fullAccountJson({
  String id = 'acc-main',
  String name = 'BBVA',
  String type = 'checking',
  int balance = 342865,
  int pending = 0,
  int? creditLimit,
  int? statementDay,
  int? paymentDay,
  bool includeInNetWorth = true,
  bool archived = false,
  String? icon,
  String? color,
  Json? bank,
}) {
  final card = type == 'credit_card';
  return {
    'id': id,
    'name': name,
    'type': type,
    'initial_balance_cents': 100000,
    'initial_balance_date': '2026-01-01',
    'balance_cents': balance,
    'cleared_balance_cents': balance - pending,
    'pending_cents': pending,
    'credit_limit_cents': creditLimit,
    'statement_day': statementDay,
    'payment_day': paymentDay,
    'used_credit_cents': card ? (balance < 0 ? -balance : 0) : null,
    'available_credit_cents': card && creditLimit != null ? creditLimit + balance : null,
    'color': color,
    'icon': icon,
    'include_in_net_worth': includeInNetWorth,
    'sort_order': 0,
    'bank': bank,
    'archived': archived,
    'archived_at': archived ? '2026-10-01T10:00:00+02:00' : null,
    'created_at': '2026-01-01T10:00:00+01:00',
    'updated_at': '2026-10-01T10:00:00+02:00',
  };
}

Json accountsBody(List<Json> accounts, {int netWorth = 342865}) => {
  'data': accounts,
  'meta': {'net_worth_cents': netWorth},
};
