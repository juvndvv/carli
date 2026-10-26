import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import 'json.dart';
import 'models.dart';

typedef Query = Map<String, Object?>;

final financeApiProvider = Provider<FinanceApi>((ref) => FinanceApi(ref.watch(dioProvider)));

Map<String, dynamic> toQueryParameters(Query query) {
  final result = <String, dynamic>{};
  for (final MapEntry(:key, :value) in query.entries) {
    if (value == null || value == '') continue;
    if (value is Iterable) {
      final items = [for (final item in value) '$item'];
      if (items.isNotEmpty) result['$key[]'] = items;
      continue;
    }
    result[key] = '$value';
  }
  return result;
}

bool _periodsChanged(Json? body) => (body?['meta'] as Json?)?['periods_changed'] == true;

class FinanceApi {
  FinanceApi(this._dio);

  final Dio _dio;

  static const _base = '/v1/finance';

  Future<Json> _get(String path, [Query query = const {}]) async {
    final response = await _dio.get<Json>('$_base/$path', queryParameters: toQueryParameters(query));
    return response.data!;
  }

  Future<({List<Account> accounts, Cents netWorth})> accounts() async {
    final body = await _get('accounts', {'include_archived': 1});
    return (
      accounts: parseList(body['data'], Account.fromJson),
      netWorth: intOf((body['meta'] as Json?)?['net_worth_cents']),
    );
  }

  Future<List<Category>> categories() async =>
      parseList((await _get('categories', {'include_archived': 1}))['data'], Category.fromJson);

  Future<List<Period>> periods() async => parseList((await _get('periods'))['data'], Period.fromJson);

  Future<FinanceSettings> settings() async => FinanceSettings.fromJson((await _get('settings'))['data'] as Json);

  Future<Dashboard> dashboard(String? periodId) async =>
      Dashboard.fromJson((await _get('dashboard', {'period_id': periodId}))['data'] as Json);

  Future<FinanceSummary> summary() async => FinanceSummary.fromJson((await _get('summary'))['data'] as Json);

  Future<BudgetOverview> budgets(String? periodId) async =>
      BudgetOverview.fromJson(await _get('budgets', {'period_id': periodId}));

  Future<BudgetOverview> copyBudgets({required String from, required String to}) async {
    final response = await _dio.post<Json>('$_base/budgets/copy', data: {'from_period_id': from, 'to_period_id': to});
    return BudgetOverview.fromJson(response.data!);
  }

  Future<TransactionPage> transactions(Query query, {String? cursor, int perPage = 50}) async =>
      TransactionPage.fromJson(await _get('transactions', {...query, 'per_page': perPage, 'cursor': cursor}));

  Future<Saved<Transaction>> createTransaction(Json input) async {
    final response = await _dio.post<Json>('$_base/transactions', data: input);
    return Saved(Transaction.fromJson(response.data!['data'] as Json), periodsChanged: _periodsChanged(response.data));
  }

  Future<Saved<Transaction>> updateTransaction(String id, Json input) async {
    final response = await _dio.patch<Json>('$_base/transactions/$id', data: input);
    return Saved(Transaction.fromJson(response.data!['data'] as Json), periodsChanged: _periodsChanged(response.data));
  }

  Future<bool> deleteTransaction(String id) async {
    final response = await _dio.delete<Json>('$_base/transactions/$id');
    return _periodsChanged(response.data);
  }

  Future<Saved<Transaction>> restoreTransaction(String id) async {
    final response = await _dio.post<Json>('$_base/transactions/$id/restore', data: const <String, Object>{});
    return Saved(Transaction.fromJson(response.data!['data'] as Json), periodsChanged: _periodsChanged(response.data));
  }

  Future<Transaction> transfer(Json input) async {
    final response = await _dio.post<Json>('$_base/transfers', data: input);
    return Transaction.fromJson((response.data!['data'] as Json)['from'] as Json);
  }

  Future<List<Tag>> tags() async => parseList((await _get('tags'))['data'], Tag.fromJson);

  Future<List<ContactOption>> contactOptions() async =>
      parseList((await _get('contacts'))['data'], ContactOption.fromJson);

  Future<int> bulkUpdate(Json input) async {
    final response = await _dio.patch<Json>('$_base/transactions/bulk', data: input);
    return intOf((response.data!['data'] as Json)['updated']);
  }

  Future<List<int>> exportTransactions(Query query) async {
    final response = await _dio.get<List<int>>(
      '$_base/transactions/export.csv',
      queryParameters: toQueryParameters(query),
      options: Options(responseType: ResponseType.bytes, headers: {'Accept': 'text/csv'}),
    );
    return response.data!;
  }

  Future<BudgetOverview> upsertBudgets(String periodId, List<Json> budgets) async {
    final response = await _dio.put<Json>('$_base/budgets', data: {'period_id': periodId, 'budgets': budgets});
    return BudgetOverview.fromJson(response.data!);
  }

  Future<List<PayeeSuggestion>> suggestPayees(String query, CategoryKind kind, {int limit = 8}) async => parseList(
    (await _get('payees/suggest', {'q': query.trim(), 'kind': kind.api, 'limit': limit}))['data'],
    PayeeSuggestion.fromJson,
  );
}
