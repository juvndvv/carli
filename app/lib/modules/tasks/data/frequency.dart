import 'package:flutter/foundation.dart';

enum FrequencyKind { schedule, afterDone }

enum FrequencyUnit {
  daily('DAILY', 'Diaria'),
  weekly('WEEKLY', 'Semanal'),
  monthly('MONTHLY', 'Mensual'),
  yearly('YEARLY', 'Anual');

  const FrequencyUnit(this.rrule, this.label);

  final String rrule;
  final String label;

  static FrequencyUnit of(String? value) => values.firstWhere((unit) => unit.rrule == value, orElse: () => weekly);
}

enum MonthlyMode { dayOfMonth, lastDay, weekdayPosition }

const rruleWeekdays = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];

const monthPositions = [(1, 'Primer'), (2, 'Segundo'), (3, 'Tercer'), (4, 'Cuarto'), (-1, 'Último')];

@immutable
class FrequencyDraft {
  const FrequencyDraft({
    this.kind = FrequencyKind.schedule,
    this.unit = FrequencyUnit.weekly,
    this.interval = 1,
    this.weekdays = const {1},
    this.monthlyMode = MonthlyMode.dayOfMonth,
    this.monthDay = 1,
    this.position = 1,
    this.positionWeekday = 1,
    this.yearMonth = 1,
    this.afterDoneDays = 7,
  });

  factory FrequencyDraft.initial(DateTime start) => FrequencyDraft(
    weekdays: {start.weekday},
    monthDay: start.day,
    positionWeekday: start.weekday,
    yearMonth: start.month,
  );

  factory FrequencyDraft.parse({String? rrule, int? afterDoneDays, required DateTime start}) {
    final initial = FrequencyDraft.initial(start);
    if (afterDoneDays != null) return initial.copyWith(kind: FrequencyKind.afterDone, afterDoneDays: afterDoneDays);
    if (rrule == null || rrule.isEmpty) return initial;

    final parts = {
      for (final segment in rrule.split(';'))
        if (segment.contains('=')) segment.split('=').first.toUpperCase(): segment.split('=').last.toUpperCase(),
    };
    final unit = FrequencyUnit.of(parts['FREQ']);
    final interval = int.tryParse(parts['INTERVAL'] ?? '') ?? 1;
    final byDay = (parts['BYDAY'] ?? '').split(',').where((day) => day.isNotEmpty).toList();
    final weekdays = {
      for (final day in byDay)
        if (rruleWeekdays.contains(day.substring(day.length - 2)))
          rruleWeekdays.indexOf(day.substring(day.length - 2)) + 1,
    };
    final monthDay = int.tryParse(parts['BYMONTHDAY'] ?? '');
    final position =
        int.tryParse(parts['BYSETPOS'] ?? '') ??
        (byDay.length == 1 && byDay.first.length > 2
            ? int.tryParse(byDay.first.substring(0, byDay.first.length - 2))
            : null);

    final monthlyMode = switch ((monthDay, position)) {
      (-1, _) => MonthlyMode.lastDay,
      (null, final int _) when weekdays.length == 1 => MonthlyMode.weekdayPosition,
      _ => MonthlyMode.dayOfMonth,
    };

    return initial.copyWith(
      unit: unit,
      interval: interval,
      weekdays: unit == FrequencyUnit.weekly && weekdays.isNotEmpty ? weekdays : initial.weekdays,
      monthlyMode: unit == FrequencyUnit.monthly ? monthlyMode : MonthlyMode.dayOfMonth,
      monthDay: monthDay != null && monthDay > 0 ? monthDay : initial.monthDay,
      position: position ?? initial.position,
      positionWeekday: weekdays.length == 1 ? weekdays.first : initial.positionWeekday,
      yearMonth: int.tryParse(parts['BYMONTH'] ?? '') ?? initial.yearMonth,
    );
  }

  final FrequencyKind kind;
  final FrequencyUnit unit;
  final int interval;
  final Set<int> weekdays;
  final MonthlyMode monthlyMode;
  final int monthDay;
  final int position;
  final int positionWeekday;
  final int yearMonth;
  final int afterDoneDays;

  bool get afterDone => kind == FrequencyKind.afterDone;

  String? get rrule {
    if (afterDone) return null;
    final parts = <String>['FREQ=${unit.rrule}', if (interval > 1) 'INTERVAL=$interval'];
    switch (unit) {
      case FrequencyUnit.daily:
        break;
      case FrequencyUnit.weekly:
        parts.add('BYDAY=${([...weekdays]..sort()).map((day) => rruleWeekdays[day - 1]).join(',')}');
      case FrequencyUnit.monthly:
        parts.addAll(switch (monthlyMode) {
          MonthlyMode.dayOfMonth => ['BYMONTHDAY=$monthDay'],
          MonthlyMode.lastDay => ['BYMONTHDAY=-1'],
          MonthlyMode.weekdayPosition => ['BYDAY=${rruleWeekdays[positionWeekday - 1]}', 'BYSETPOS=$position'],
        });
      case FrequencyUnit.yearly:
        parts.addAll(['BYMONTH=$yearMonth', 'BYMONTHDAY=$monthDay']);
    }
    return parts.join(';');
  }

  Map<String, Object?> toJson() => afterDone
      ? {'after_done_interval_days': afterDoneDays, 'rrule': null}
      : {'rrule': rrule, 'after_done_interval_days': null};

  String get intervalLabel => switch (unit) {
    FrequencyUnit.daily => interval == 1 ? '1 día' : '$interval días',
    FrequencyUnit.weekly => interval == 1 ? '1 semana' : '$interval semanas',
    FrequencyUnit.monthly => interval == 1 ? '1 mes' : '$interval meses',
    FrequencyUnit.yearly => interval == 1 ? '1 año' : '$interval años',
  };

  FrequencyDraft copyWith({
    FrequencyKind? kind,
    FrequencyUnit? unit,
    int? interval,
    Set<int>? weekdays,
    MonthlyMode? monthlyMode,
    int? monthDay,
    int? position,
    int? positionWeekday,
    int? yearMonth,
    int? afterDoneDays,
  }) => FrequencyDraft(
    kind: kind ?? this.kind,
    unit: unit ?? this.unit,
    interval: interval ?? this.interval,
    weekdays: weekdays ?? this.weekdays,
    monthlyMode: monthlyMode ?? this.monthlyMode,
    monthDay: monthDay ?? this.monthDay,
    position: position ?? this.position,
    positionWeekday: positionWeekday ?? this.positionWeekday,
    yearMonth: yearMonth ?? this.yearMonth,
    afterDoneDays: afterDoneDays ?? this.afterDoneDays,
  );

  FrequencyDraft toggleWeekday(int day) {
    final next = {...weekdays};
    if (!next.remove(day)) next.add(day);
    return copyWith(weekdays: next.isEmpty ? {day} : next);
  }

  @override
  bool operator ==(Object other) =>
      other is FrequencyDraft &&
      other.rrule == rrule &&
      other.afterDone == afterDone &&
      other.afterDoneDays == afterDoneDays;

  @override
  int get hashCode => Object.hash(rrule, afterDone, afterDoneDays);
}
