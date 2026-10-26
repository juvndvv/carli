import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/format/dates.dart';
import 'finance_changes.dart';
import 'json.dart';
import 'models.dart';

const goalIcons = [
  ('piggy-bank', 'Hucha'),
  ('shield', 'Emergencias'),
  ('plane', 'Viaje'),
  ('laptop', 'Tecnología'),
  ('house', 'Casa'),
  ('car', 'Coche'),
  ('gift', 'Regalo'),
  ('graduation-cap', 'Estudios'),
  ('heart', 'Salud'),
  ('smartphone', 'Móvil'),
  ('tree-palm', 'Vacaciones'),
  ('target', 'Otro'),
];

const defaultGoalIcon = 'piggy-bank';

DateTime addMonths(DateTime date, int months) {
  final first = DateTime(date.year, date.month + months);
  final lastDay = DateTime(first.year, first.month + 1, 0).day;
  return DateTime(first.year, first.month, math.min(date.day, lastDay));
}

class SavingsGoal {
  const SavingsGoal({
    required this.id,
    required this.name,
    required this.targetCents,
    required this.targetDate,
    required this.accountId,
    required this.account,
    required this.icon,
    required this.achieved,
    required this.savedCents,
    required this.remainingCents,
    required this.progressBp,
    required this.monthsLeft,
    required this.monthlyNeededCents,
    required this.contributionsCount,
  });

  factory SavingsGoal.fromJson(Json json) => SavingsGoal(
    id: json['id'] as String,
    name: json['name'] as String,
    targetCents: intOf(json['target_cents']),
    targetDate: parseIsoDateOrNull(json['target_date']),
    accountId: json['account_id'] as String?,
    account: json['account'] is Json ? AccountRef.fromJson(json['account'] as Json) : null,
    icon: json['icon'] as String?,
    achieved: json['achieved'] as bool? ?? false,
    savedCents: intOf(json['saved_cents']),
    remainingCents: intOf(json['remaining_cents']),
    progressBp: intOf(json['progress_bp']),
    monthsLeft: intOrNull(json['months_left']),
    monthlyNeededCents: intOrNull(json['monthly_needed_cents']),
    contributionsCount: intOf(json['contributions_count']),
  );

  final String id;
  final String name;
  final Cents targetCents;
  final DateTime? targetDate;
  final String? accountId;
  final AccountRef? account;
  final String? icon;
  final bool achieved;
  final Cents savedCents;
  final Cents remainingCents;
  final BasisPoints progressBp;
  final int? monthsLeft;
  final Cents? monthlyNeededCents;
  final int contributionsCount;

  int get percent => progressBp ~/ 100;

  double get ratio => progressBp / 10000;

  String get iconName => icon ?? defaultGoalIcon;
}

class GoalContribution {
  const GoalContribution({
    required this.id,
    required this.goalId,
    required this.amountCents,
    required this.date,
    required this.note,
  });

  factory GoalContribution.fromJson(Json json) => GoalContribution(
    id: json['id'] as String,
    goalId: json['goal_id'] as String,
    amountCents: intOf(json['amount_cents']),
    date: parseIsoDate(json['date'] as String),
    note: json['note'] as String?,
  );

  final String id;
  final String goalId;
  final Cents amountCents;
  final DateTime date;
  final String? note;

  Json toPayload() => {'amount_cents': amountCents, 'date': isoDate(date), 'note': note};
}

class GoalDraft {
  const GoalDraft({
    required this.name,
    required this.targetCents,
    required this.targetDate,
    required this.accountId,
    required this.icon,
  });

  final String name;
  final Cents targetCents;
  final DateTime? targetDate;
  final String? accountId;
  final String? icon;

  Json toJson() => {
    'name': name,
    'target_cents': targetCents,
    'target_date': targetDate == null ? null : isoDate(targetDate!),
    'account_id': accountId,
    'icon': icon,
  };
}

List<SavingsGoal> sortGoals(List<SavingsGoal> goals) {
  final indexed = goals.indexed.toList()
    ..sort((left, right) {
      final byAchieved = (left.$2.achieved ? 1 : 0) - (right.$2.achieved ? 1 : 0);
      return byAchieved != 0 ? byAchieved : left.$1 - right.$1;
    });
  return [for (final (_, goal) in indexed) goal];
}

String? goalTargetMonthLabel(DateTime? date) => date == null ? null : '${monthsShort[date.month - 1]} ${date.year}';

class GoalsApi {
  GoalsApi(this._dio);

  final Dio _dio;

  static const _base = '/v1/finance/goals';

  Future<List<SavingsGoal>> list() async {
    final response = await _dio.get<Json>(_base);
    return sortGoals(parseList(response.data!['data'], SavingsGoal.fromJson));
  }

  Future<SavingsGoal> get(String id) async {
    final response = await _dio.get<Json>('$_base/$id');
    return SavingsGoal.fromJson(response.data!['data'] as Json);
  }

  Future<SavingsGoal> create(GoalDraft draft) async {
    final response = await _dio.post<Json>(_base, data: draft.toJson());
    return SavingsGoal.fromJson(response.data!['data'] as Json);
  }

  Future<SavingsGoal> update(String id, GoalDraft draft) async {
    final response = await _dio.patch<Json>('$_base/$id', data: draft.toJson());
    return SavingsGoal.fromJson(response.data!['data'] as Json);
  }

  Future<void> remove(String id) => _dio.delete<Object?>('$_base/$id');

  Future<List<GoalContribution>> contributions(String goalId) async {
    final response = await _dio.get<Json>('$_base/$goalId/contributions');
    return parseList(response.data!['data'], GoalContribution.fromJson)
      ..sort((left, right) => right.date.compareTo(left.date));
  }

  Future<({GoalContribution contribution, SavingsGoal goal})> contribute(String goalId, Json payload) async {
    final response = await _dio.post<Json>('$_base/$goalId/contributions', data: payload);
    final body = response.data!;
    return (
      contribution: GoalContribution.fromJson(body['data'] as Json),
      goal: SavingsGoal.fromJson((body['meta'] as Json)['goal'] as Json),
    );
  }

  Future<void> removeContribution(String goalId, String contributionId) =>
      _dio.delete<Object?>('$_base/$goalId/contributions/$contributionId');
}

final goalsApiProvider = Provider<GoalsApi>((ref) => GoalsApi(ref.watch(dioProvider)));

final goalsRevisionProvider = NotifierProvider<GoalsRevision, int>(GoalsRevision.new);

class GoalsRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final goalsProvider = FutureProvider<List<SavingsGoal>>((ref) async {
  ref.watch(goalsRevisionProvider);
  ref.watchFinance(const [FinanceScope.accounts]);
  return ref.watch(goalsApiProvider).list();
});

final goalProvider = FutureProvider.autoDispose.family<SavingsGoal, String>((ref, id) async {
  ref.watch(goalsRevisionProvider);
  ref.watchFinance(const [FinanceScope.accounts]);
  return ref.watch(goalsApiProvider).get(id);
});

final goalContributionsProvider = FutureProvider.autoDispose.family<List<GoalContribution>, String>((ref, id) async {
  ref.watch(goalsRevisionProvider);
  return ref.watch(goalsApiProvider).contributions(id);
});

final goalsRepositoryProvider = Provider<GoalsRepository>(
  (ref) => GoalsRepository(ref.watch(goalsApiProvider), ref.read(goalsRevisionProvider.notifier)),
);

class GoalsRepository {
  GoalsRepository(this._api, this._revision);

  final GoalsApi _api;
  final GoalsRevision _revision;

  Future<T> _mutating<T>(Future<T> Function() action) async {
    final result = await action();
    _revision.bump();
    return result;
  }

  Future<SavingsGoal> create(GoalDraft draft) => _mutating(() => _api.create(draft));

  Future<SavingsGoal> update(String id, GoalDraft draft) => _mutating(() => _api.update(id, draft));

  Future<void> remove(String id) => _mutating(() => _api.remove(id));

  Future<({GoalContribution contribution, SavingsGoal goal})> contribute(String goalId, Json payload) =>
      _mutating(() => _api.contribute(goalId, payload));

  Future<void> removeContribution(String goalId, String contributionId) =>
      _mutating(() => _api.removeContribution(goalId, contributionId));
}
