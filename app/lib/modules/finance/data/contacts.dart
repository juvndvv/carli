import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/format/money.dart';
import 'finance_changes.dart';
import 'json.dart';
import 'models.dart';

class FinanceContact {
  const FinanceContact({
    required this.id,
    required this.name,
    required this.notes,
    required this.archived,
    required this.balanceCents,
    required this.sharesPendingCents,
    required this.owedToMeCents,
    required this.iOweCents,
  });

  factory FinanceContact.fromJson(Json json) => FinanceContact(
    id: json['id'] as String,
    name: json['name'] as String,
    notes: json['notes'] as String?,
    archived: json['archived'] as bool? ?? false,
    balanceCents: intOf(json['balance_cents']),
    sharesPendingCents: intOf(json['shares_pending_cents']),
    owedToMeCents: intOf(json['owed_to_me_cents']),
    iOweCents: intOf(json['i_owe_cents']),
  );

  final String id;
  final String name;
  final String? notes;
  final bool archived;
  final Cents balanceCents;
  final Cents sharesPendingCents;
  final Cents owedToMeCents;
  final Cents iOweCents;
}

class ContactShare {
  const ContactShare({
    required this.id,
    required this.transactionId,
    required this.date,
    required this.payee,
    required this.description,
    required this.transactionAmountCents,
    required this.amountCents,
    required this.settled,
  });

  factory ContactShare.fromJson(Json json) => ContactShare(
    id: json['id'] as String,
    transactionId: json['transaction_id'] as String? ?? '',
    date: parseIsoDate(json['date'] as String),
    payee: json['payee'] as String?,
    description: json['description'] as String?,
    transactionAmountCents: intOf(json['transaction_amount_cents']),
    amountCents: intOf(json['amount_cents']),
    settled: json['settled'] as bool? ?? false,
  );

  final String id;
  final String transactionId;
  final DateTime date;
  final String? payee;
  final String? description;
  final Cents transactionAmountCents;
  final Cents amountCents;
  final bool settled;

  String get title {
    if (payee case final payee? when payee.isNotEmpty) return payee;
    if (description case final description? when description.isNotEmpty) return description;
    return 'Gasto compartido';
  }
}

enum DebtDirection {
  iOwe('i_owe', 'Debes'),
  owedToMe('owed_to_me', 'Te deben');

  const DebtDirection(this.api, this.label);

  final String api;
  final String label;

  static DebtDirection of(String? value) => value == 'owed_to_me' ? owedToMe : iOwe;
}

class ContactDebt {
  const ContactDebt({
    required this.id,
    required this.name,
    required this.direction,
    required this.pendingCents,
    required this.dueDate,
    required this.closed,
  });

  factory ContactDebt.fromJson(Json json) => ContactDebt(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    direction: DebtDirection.of(json['direction'] as String?),
    pendingCents: intOf(json['pending_cents']),
    dueDate: parseIsoDateOrNull(json['due_date']),
    closed: json['closed'] as bool? ?? false,
  );

  final String id;
  final String name;
  final DebtDirection direction;
  final Cents pendingCents;
  final DateTime? dueDate;
  final bool closed;
}

class FinanceContactDetail {
  const FinanceContactDetail({required this.contact, required this.shares, required this.debts});

  factory FinanceContactDetail.fromJson(Json json) => FinanceContactDetail(
    contact: FinanceContact.fromJson(json),
    shares: parseList(json['shares'], ContactShare.fromJson),
    debts: parseList(json['debts'], ContactDebt.fromJson),
  );

  final FinanceContact contact;
  final List<ContactShare> shares;
  final List<ContactDebt> debts;

  bool get deletable => shares.isEmpty && debts.isEmpty;
}

class ContactsOverview {
  const ContactsOverview({required this.contacts, required this.owedToMeCents, required this.iOweCents});

  factory ContactsOverview.fromJson(Json json) {
    final meta = json['meta'] as Json?;
    return ContactsOverview(
      contacts: parseList(json['data'], FinanceContact.fromJson),
      owedToMeCents: intOf(meta?['owed_to_me_cents']),
      iOweCents: intOf(meta?['i_owe_cents']),
    );
  }

  final List<FinanceContact> contacts;
  final Cents owedToMeCents;
  final Cents iOweCents;

  int get owingMeCount => contacts.where((contact) => contact.balanceCents > 0).length;

  int get owedByMeCount => contacts.where((contact) => contact.balanceCents < 0).length;
}

class Settlement {
  const Settlement({required this.transactionIds, required this.netCents});

  factory Settlement.fromJson(Json json) {
    final transactions = json['transactions'] as List? ?? [json['transaction']];
    return Settlement(
      transactionIds: [
        for (final transaction in transactions)
          if (transaction is Json) transaction['id'] as String,
      ],
      netCents: intOf(json['net_cents']),
    );
  }

  final List<String> transactionIds;
  final Cents netCents;
}

String contactBalanceLabel(Cents balanceCents) {
  if (balanceCents > 0) return 'Te debe ${formatMoney(balanceCents)}';
  if (balanceCents < 0) return 'Le debes ${formatMoney(-balanceCents)}';
  return 'En paz';
}

String contactSubtitle(FinanceContact contact) {
  final parts = [
    if (contact.sharesPendingCents > 0) '${formatMoney(contact.sharesPendingCents)} en gastos sin liquidar',
    if (contact.owedToMeCents > 0) 'te debe ${formatMoney(contact.owedToMeCents)} en préstamos',
    if (contact.iOweCents > 0) 'le debes ${formatMoney(contact.iOweCents)} en préstamos',
  ];
  if (parts.isEmpty) return 'Sin nada pendiente';
  final text = parts.join(' · ');
  return text[0].toUpperCase() + text.substring(1);
}

String peopleLabel(int count) => switch (count) {
  0 => 'Nadie',
  1 => '1 persona',
  _ => '$count personas',
};

String? preferredSettleAccountId(List<Account> accounts) {
  final active = accounts.where((account) => !account.archived);
  return (active.where((account) => account.type == AccountType.checking).firstOrNull ?? active.firstOrNull)?.id;
}

final contactsApiProvider = Provider<ContactsApi>((ref) => ContactsApi(ref.watch(dioProvider)));

class ContactsApi {
  ContactsApi(this._dio);

  final Dio _dio;

  static const _base = '/v1/finance/contacts';

  Future<ContactsOverview> list() async => ContactsOverview.fromJson((await _dio.get<Json>(_base)).data!);

  Future<FinanceContactDetail> get(String id) async =>
      FinanceContactDetail.fromJson((await _dio.get<Json>('$_base/$id')).data!['data'] as Json);

  Future<FinanceContactDetail> create(Json input) async =>
      FinanceContactDetail.fromJson((await _dio.post<Json>(_base, data: input)).data!['data'] as Json);

  Future<FinanceContactDetail> update(String id, Json input) async =>
      FinanceContactDetail.fromJson((await _dio.patch<Json>('$_base/$id', data: input)).data!['data'] as Json);

  Future<void> remove(String id) => _dio.delete<Object?>('$_base/$id');

  Future<Settlement> settle(String id, {required String accountId, required DateTime date}) async {
    final response = await _dio.post<Json>('$_base/$id/settle', data: {'account_id': accountId, 'date': isoDate(date)});
    return Settlement.fromJson(response.data!['data'] as Json);
  }
}

final contactsRepositoryProvider = Provider<ContactsRepository>(
  (ref) => ContactsRepository(ref.watch(contactsApiProvider), ref.read(financeChangesProvider.notifier)),
);

class ContactsRepository {
  ContactsRepository(this._api, this._changes);

  final ContactsApi _api;
  final FinanceChanges _changes;

  Future<T> _mutating<T>(
    Future<T> Function() action, [
    List<FinanceScope> scopes = const [FinanceScope.contacts],
  ]) async {
    final result = await action();
    _changes.notify(scopes);
    return result;
  }

  Future<FinanceContactDetail> create({required String name, String? notes}) =>
      _mutating(() => _api.create({'name': name, 'notes': notes}));

  Future<FinanceContactDetail> update(String id, {required String name, String? notes}) =>
      _mutating(() => _api.update(id, {'name': name, 'notes': notes}));

  Future<FinanceContactDetail> setArchived(String id, bool archived) =>
      _mutating(() => _api.update(id, {'archived': archived}));

  Future<void> remove(String id) => _mutating(() => _api.remove(id));

  Future<Settlement> settle(String id, {required String accountId, required DateTime date}) =>
      _mutating(() => _api.settle(id, accountId: accountId, date: date), transactionSideEffects);
}

final contactsProvider = FutureProvider<ContactsOverview>((ref) async {
  ref.watchFinance(const [FinanceScope.contacts]);
  return ref.watch(contactsApiProvider).list();
});

final contactDetailProvider = FutureProvider.family<FinanceContactDetail, String>((ref, id) async {
  ref.watchFinance(const [FinanceScope.contacts]);
  return ref.watch(contactsApiProvider).get(id);
});
