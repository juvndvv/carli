import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/format/money.dart';
import 'finance_changes.dart';
import 'json.dart';
import 'models.dart';

enum DebtDirection {
  iOwe('i_owe', 'Debes'),
  owedToMe('owed_to_me', 'Te deben');

  const DebtDirection(this.api, this.label);

  final String api;
  final String label;

  static DebtDirection of(String? value) => value == 'owed_to_me' ? owedToMe : iOwe;
}

class Debt {
  const Debt({
    required this.id,
    required this.name,
    required this.direction,
    required this.contactId,
    required this.contactName,
    required this.principalCents,
    required this.paidCents,
    required this.pendingCents,
    required this.progressBp,
    required this.startDate,
    required this.dueDate,
    required this.installmentCents,
    required this.installmentsCount,
    required this.installmentsPaid,
    required this.recurringRuleId,
    required this.nextPaymentDate,
    required this.notes,
    required this.closed,
  });

  factory Debt.fromJson(Json json) => Debt(
    id: json['id'] as String,
    name: json['name'] as String,
    direction: DebtDirection.of(json['direction'] as String?),
    contactId: json['contact_id'] as String?,
    contactName: (json['contact'] as Json?)?['name'] as String?,
    principalCents: intOf(json['principal_cents']),
    paidCents: intOf(json['paid_cents']),
    pendingCents: intOf(json['pending_cents']),
    progressBp: intOf(json['progress_bp']),
    startDate: parseIsoDate(json['start_date'] as String),
    dueDate: parseIsoDateOrNull(json['due_date']),
    installmentCents: intOrNull(json['installment_cents']),
    installmentsCount: intOrNull(json['installments_count']),
    installmentsPaid: intOf(json['installments_paid']),
    recurringRuleId: json['recurring_rule_id'] as String?,
    nextPaymentDate: parseIsoDateOrNull(json['next_payment_date']),
    notes: json['notes'] as String?,
    closed: json['closed'] as bool? ?? false,
  );

  final String id;
  final String name;
  final DebtDirection direction;
  final String? contactId;
  final String? contactName;
  final Cents principalCents;
  final Cents paidCents;
  final Cents pendingCents;
  final BasisPoints progressBp;
  final DateTime startDate;
  final DateTime? dueDate;
  final Cents? installmentCents;
  final int? installmentsCount;
  final int installmentsPaid;
  final String? recurringRuleId;
  final DateTime? nextPaymentDate;
  final String? notes;
  final bool closed;

  int get percent => progressBp ~/ 100;

  double get ratio => progressBp / 10000;

  bool get owesMe => direction == DebtDirection.owedToMe;

  String get installmentsLabel {
    final installment = installmentCents;
    final count = installmentsCount;
    if (installment == null || installment == 0 || count == null || count == 0) return 'Sin plan de pagos';
    final paid = installmentsPaid < count ? installmentsPaid : count;
    return '${formatMoney(installment)} / mes · $paid de $count cuotas';
  }

  String get subtitle => [?contactName, installmentsLabel].join(' · ');
}

class DebtsOverview {
  const DebtsOverview({required this.debts, required this.owedToMeCents, required this.iOweCents});

  factory DebtsOverview.fromJson(Json json) {
    final meta = json['meta'] as Json? ?? const {};
    return DebtsOverview(
      debts: parseList(json['data'], Debt.fromJson),
      owedToMeCents: intOf(meta['owed_to_me_cents']),
      iOweCents: intOf(meta['i_owe_cents']),
    );
  }

  final List<Debt> debts;
  final Cents owedToMeCents;
  final Cents iOweCents;

  List<Debt> get open => [
    for (final debt in debts)
      if (!debt.closed) debt,
  ];

  List<Debt> get closed => [
    for (final debt in debts)
      if (debt.closed) debt,
  ];

  int openCount(DebtDirection direction) => open.where((debt) => debt.direction == direction).length;

  Debt? find(String id) => debts.where((debt) => debt.id == id).firstOrNull;
}

class DebtPlanDraft {
  const DebtPlanDraft({
    required this.accountId,
    required this.installmentCents,
    required this.installmentsCount,
    required this.firstPaymentDate,
    required this.categoryId,
  });

  final String accountId;
  final Cents installmentCents;
  final int installmentsCount;
  final DateTime firstPaymentDate;
  final String? categoryId;

  Json toJson() => {
    'account_id': accountId,
    'installment_cents': installmentCents,
    'installments_count': installmentsCount,
    'first_payment_date': isoDate(firstPaymentDate),
    'category_id': categoryId,
  };
}

class DebtDraft {
  const DebtDraft({
    required this.name,
    required this.direction,
    required this.principalCents,
    required this.startDate,
    required this.contactId,
    required this.dueDate,
    required this.notes,
    this.plan,
  });

  final String name;
  final DebtDirection direction;
  final Cents principalCents;
  final DateTime startDate;
  final String? contactId;
  final DateTime? dueDate;
  final String? notes;
  final DebtPlanDraft? plan;

  Json toJson() => {
    'name': name,
    'direction': direction.api,
    'principal_cents': principalCents,
    'start_date': isoDate(startDate),
    'contact_id': contactId,
    'due_date': dueDate == null ? null : isoDate(dueDate!),
    'notes': notes,
    if (plan case final plan?) 'plan': plan.toJson(),
  };
}

class DebtsApi {
  DebtsApi(this._dio);

  final Dio _dio;

  static const _base = '/v1/finance/debts';

  Future<DebtsOverview> list() async {
    final response = await _dio.get<Json>(_base, queryParameters: {'include_closed': '1'});
    return DebtsOverview.fromJson(response.data!);
  }

  Future<Debt> create(DebtDraft draft) async {
    final response = await _dio.post<Json>(_base, data: draft.toJson());
    return Debt.fromJson(response.data!['data'] as Json);
  }

  Future<Debt> update(String id, Json patch) async {
    final response = await _dio.patch<Json>('$_base/$id', data: patch);
    return Debt.fromJson(response.data!['data'] as Json);
  }

  Future<void> remove(String id) => _dio.delete<Object?>('$_base/$id');

  Future<List<Transaction>> payments(String id) async {
    final response = await _dio.get<Json>('$_base/$id/payments');
    return parseList(response.data!['data'], Transaction.fromJson);
  }

  Future<({Transaction payment, Debt debt})> addPayment(String id, Json payload) async {
    final response = await _dio.post<Json>('$_base/$id/payments', data: payload);
    final body = response.data!;
    return (
      payment: Transaction.fromJson(body['data'] as Json),
      debt: Debt.fromJson((body['meta'] as Json)['debt'] as Json),
    );
  }

  Future<ContactOption> createContact(String name) async {
    final response = await _dio.post<Json>('/v1/finance/contacts', data: {'name': name, 'notes': null});
    return ContactOption.fromJson(response.data!['data'] as Json);
  }
}

final debtsApiProvider = Provider<DebtsApi>((ref) => DebtsApi(ref.watch(dioProvider)));

final debtsRevisionProvider = NotifierProvider<DebtsRevision, int>(DebtsRevision.new);

class DebtsRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final debtsProvider = FutureProvider<DebtsOverview>((ref) async {
  ref.watch(debtsRevisionProvider);
  ref.watchFinance(const [FinanceScope.transactions, FinanceScope.contacts]);
  return ref.watch(debtsApiProvider).list();
});

final debtPaymentsProvider = FutureProvider.autoDispose.family<List<Transaction>, String>((ref, id) async {
  ref.watch(debtsRevisionProvider);
  ref.watchFinance(const [FinanceScope.transactions]);
  return ref.watch(debtsApiProvider).payments(id);
});

final debtsRepositoryProvider = Provider<DebtsRepository>(
  (ref) => DebtsRepository(
    ref.watch(debtsApiProvider),
    ref.read(debtsRevisionProvider.notifier),
    ref.read(financeChangesProvider.notifier),
  ),
);

class DebtsRepository {
  DebtsRepository(this._api, this._revision, this._changes);

  final DebtsApi _api;
  final DebtsRevision _revision;
  final FinanceChanges _changes;

  Future<T> _mutating<T>(Future<T> Function() action) async {
    final result = await action();
    _revision.bump();
    return result;
  }

  Future<Debt> create(DebtDraft draft) async {
    final debt = await _mutating(() => _api.create(draft));
    if (draft.plan != null) _changes.notify(const [FinanceScope.recurring]);
    return debt;
  }

  Future<Debt> update(String id, DebtDraft draft) async {
    final debt = await _mutating(() => _api.update(id, draft.toJson()));
    if (draft.plan != null) _changes.notify(const [FinanceScope.recurring]);
    return debt;
  }

  Future<Debt> setClosed(String id, bool closed) => _mutating(() => _api.update(id, {'closed': closed}));

  Future<void> remove(String id) => _mutating(() => _api.remove(id));

  Future<({Transaction payment, Debt debt})> addPayment(String id, Json payload) async {
    final result = await _mutating(() => _api.addPayment(id, payload));
    _changes.notifyTransactions();
    return result;
  }

  Future<ContactOption> createContact(String name) async {
    final contact = await _api.createContact(name);
    _changes.notify(const [FinanceScope.contacts]);
    return contact;
  }
}
