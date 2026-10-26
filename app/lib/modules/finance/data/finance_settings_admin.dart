import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import 'finance_changes.dart';
import 'json.dart';

enum PeriodMode {
  payroll('payroll'),
  calendar('calendar');

  const PeriodMode(this.api);

  final String api;

  static PeriodMode of(String? value) => value == 'calendar' ? calendar : payroll;
}

enum PeriodOpenedBy {
  payroll('payroll', 'Por nómina'),
  manual('manual', 'Manual'),
  calendar('calendar', 'Mes natural');

  const PeriodOpenedBy(this.api, this.label);

  final String api;
  final String label;

  static PeriodOpenedBy of(String? value) => values.firstWhere((item) => item.api == value, orElse: () => payroll);
}

class FinanceSettingsValues {
  const FinanceSettingsValues({
    required this.defaultAccountId,
    required this.budgetWarningThreshold,
    required this.remindDaysBefore,
    required this.periodMode,
    required this.periodMinDays,
  });

  factory FinanceSettingsValues.fromJson(Json json) => FinanceSettingsValues(
    defaultAccountId: json['default_account_id'] as String?,
    budgetWarningThreshold: intOrNull(json['budget_warning_threshold']) ?? 80,
    remindDaysBefore: intOrNull(json['remind_days_before']) ?? 2,
    periodMode: PeriodMode.of(json['period_mode'] as String?),
    periodMinDays: intOrNull(json['period_min_days']) ?? 20,
  );

  final String? defaultAccountId;
  final int budgetWarningThreshold;
  final int remindDaysBefore;
  final PeriodMode periodMode;
  final int periodMinDays;

  Json toJson() => {
    'default_account_id': defaultAccountId,
    'budget_warning_threshold': budgetWarningThreshold,
    'remind_days_before': remindDaysBefore,
    'period_mode': periodMode.api,
    'period_min_days': periodMinDays,
  };
}

class ManagedPeriod {
  const ManagedPeriod({
    required this.id,
    required this.startDate,
    required this.isCurrent,
    required this.openedBy,
    required this.name,
    required this.label,
    required this.rangeLabel,
    required this.daysRemaining,
  });

  factory ManagedPeriod.fromJson(Json json) => ManagedPeriod(
    id: json['id'] as String,
    startDate: parseIsoDate(json['start_date'] as String),
    isCurrent: json['is_current'] as bool? ?? false,
    openedBy: PeriodOpenedBy.of(json['opened_by'] as String?),
    name: json['name'] as String? ?? '',
    label: json['label'] as String? ?? json['name'] as String? ?? '',
    rangeLabel: json['range_label'] as String? ?? '',
    daysRemaining: intOf(json['days_remaining']),
  );

  final String id;
  final DateTime startDate;
  final bool isCurrent;
  final PeriodOpenedBy openedBy;
  final String name;
  final String label;
  final String rangeLabel;
  final int daysRemaining;

  String get daysLabel => daysRemaining == 1 ? 'queda 1 día' : 'quedan $daysRemaining días';

  String get subtitle => isCurrent ? '$rangeLabel · $daysLabel' : rangeLabel;
}

class PeriodOpeningCategory {
  const PeriodOpeningCategory({required this.id, required this.name, required this.icon, required this.opensPeriod});

  factory PeriodOpeningCategory.fromJson(Json json) => PeriodOpeningCategory(
    id: json['id'] as String,
    name: json['name'] as String,
    icon: json['icon'] as String?,
    opensPeriod: json['opens_period'] as bool? ?? false,
  );

  final String id;
  final String name;
  final String? icon;
  final bool opensPeriod;
}

final financeSettingsAdminApiProvider = Provider<FinanceSettingsAdminApi>(
  (ref) => FinanceSettingsAdminApi(ref.watch(dioProvider)),
);

class FinanceSettingsAdminApi {
  FinanceSettingsAdminApi(this._dio);

  final Dio _dio;

  static const _base = '/v1/finance';

  Future<FinanceSettingsValues> settings() async =>
      FinanceSettingsValues.fromJson((await _dio.get<Json>('$_base/settings')).data!['data'] as Json);

  Future<({FinanceSettingsValues settings, bool periodsChanged})> updateSettings(FinanceSettingsValues values) async {
    final body = (await _dio.patch<Json>('$_base/settings', data: values.toJson())).data!;
    return (
      settings: FinanceSettingsValues.fromJson(body['data'] as Json),
      periodsChanged: (body['meta'] as Json?)?['periods_changed'] == true,
    );
  }

  Future<List<ManagedPeriod>> periods() async =>
      parseList((await _dio.get<Json>('$_base/periods')).data!['data'], ManagedPeriod.fromJson);

  Future<ManagedPeriod> openPeriod(DateTime startDate) async {
    final response = await _dio.post<Json>('$_base/periods', data: {'start_date': isoDate(startDate)});
    return ManagedPeriod.fromJson(response.data!['data'] as Json);
  }

  Future<ManagedPeriod> movePeriodStart(String id, DateTime startDate) async {
    final response = await _dio.patch<Json>('$_base/periods/$id', data: {'start_date': isoDate(startDate)});
    return ManagedPeriod.fromJson(response.data!['data'] as Json);
  }

  Future<List<PeriodOpeningCategory>> incomeCategories() async {
    final response = await _dio.get<Json>('$_base/categories');
    return [
      for (final json in response.data!['data'] as List? ?? const [])
        if (json is Json && json['kind'] == 'income' && json['archived'] != true && json['parent_id'] == null)
          PeriodOpeningCategory.fromJson(json),
    ];
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

  Future<bool> update(FinanceSettingsValues values) async {
    final result = await _api.updateSettings(values);
    _changes.notify([
      FinanceScope.settings,
      if (result.periodsChanged) ...[FinanceScope.periods, FinanceScope.budgets],
    ]);
    return result.periodsChanged;
  }

  Future<ManagedPeriod> openPeriod(DateTime startDate) async {
    final period = await _api.openPeriod(startDate);
    _changes.notify(const [FinanceScope.periods, FinanceScope.budgets]);
    return period;
  }

  Future<ManagedPeriod> movePeriodStart(String id, DateTime startDate) async {
    final period = await _api.movePeriodStart(id, startDate);
    _changes.notify(const [FinanceScope.periods, FinanceScope.budgets]);
    return period;
  }

  Future<void> setOpensPeriod(String categoryId, bool opensPeriod) async {
    await _api.setOpensPeriod(categoryId, opensPeriod);
    _changes.notify(const [FinanceScope.categories]);
  }
}

final financeSettingsValuesProvider = FutureProvider<FinanceSettingsValues>((ref) async {
  ref.watchFinance(const [FinanceScope.settings, FinanceScope.transactions]);
  return ref.watch(financeSettingsAdminApiProvider).settings();
});

final managedPeriodsProvider = FutureProvider<List<ManagedPeriod>>((ref) async {
  ref.watchFinance(const [FinanceScope.periods]);
  return ref.watch(financeSettingsAdminApiProvider).periods();
});

final periodOpeningCategoriesProvider = FutureProvider<List<PeriodOpeningCategory>>((ref) async {
  ref.watchFinance(const [FinanceScope.categories]);
  return ref.watch(financeSettingsAdminApiProvider).incomeCategories();
});
