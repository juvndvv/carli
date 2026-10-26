import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import 'finance_changes.dart';
import 'finance_providers.dart';
import 'json.dart';
import 'models.dart';

final financeSettingsAdminApiProvider = Provider<FinanceSettingsAdminApi>(
  (ref) => FinanceSettingsAdminApi(ref.watch(dioProvider)),
);

class FinanceSettingsAdminApi {
  FinanceSettingsAdminApi(this._dio);

  final Dio _dio;

  static const _base = '/v1/finance';

  Future<({FinanceSettings settings, bool periodsChanged})> updateSettings(FinanceSettings values) async {
    final body = (await _dio.patch<Json>('$_base/settings', data: values.toJson())).data!;
    return (
      settings: FinanceSettings.fromJson(body['data'] as Json),
      periodsChanged: (body['meta'] as Json?)?['periods_changed'] == true,
    );
  }

  Future<Period> openPeriod(DateTime startDate) async {
    final response = await _dio.post<Json>('$_base/periods', data: {'start_date': isoDate(startDate)});
    return Period.fromJson(response.data!['data'] as Json);
  }

  Future<Period> movePeriodStart(String id, DateTime startDate) async {
    final response = await _dio.patch<Json>('$_base/periods/$id', data: {'start_date': isoDate(startDate)});
    return Period.fromJson(response.data!['data'] as Json);
  }

  Future<void> setOpensPeriod(String categoryId, bool opensPeriod) =>
      _dio.patch<Json>('$_base/categories/$categoryId', data: {'opens_period': opensPeriod});
}

final financeSettingsAdminRepositoryProvider = Provider<FinanceSettingsAdminRepository>(
  (ref) => FinanceSettingsAdminRepository(
    ref.watch(financeSettingsAdminApiProvider),
    ref.read(financeChangesProvider.notifier),
  ),
);

class FinanceSettingsAdminRepository {
  FinanceSettingsAdminRepository(this._api, this._changes);

  final FinanceSettingsAdminApi _api;
  final FinanceChanges _changes;

  Future<bool> update(FinanceSettings values) async {
    final result = await _api.updateSettings(values);
    _changes.notify([
      FinanceScope.settings,
      if (result.periodsChanged) ...[FinanceScope.periods, FinanceScope.budgets],
    ]);
    return result.periodsChanged;
  }

  Future<Period> openPeriod(DateTime startDate) async {
    final period = await _api.openPeriod(startDate);
    _changes.notify(const [FinanceScope.periods, FinanceScope.budgets]);
    return period;
  }

  Future<Period> movePeriodStart(String id, DateTime startDate) async {
    final period = await _api.movePeriodStart(id, startDate);
    _changes.notify(const [FinanceScope.periods, FinanceScope.budgets]);
    return period;
  }

  Future<void> setOpensPeriod(String categoryId, bool opensPeriod) async {
    await _api.setOpensPeriod(categoryId, opensPeriod);
    _changes.notify(const [FinanceScope.categories]);
  }
}

final periodOpeningCategoriesProvider = FutureProvider<List<Category>>((ref) async {
  final categories = await ref.watch(categoriesProvider.future);
  return [
    for (final category in categories.tree)
      if (category.kind == CategoryKind.income && !category.archived) category,
  ];
});
