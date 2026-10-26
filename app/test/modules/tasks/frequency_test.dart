import 'package:flutter_test/flutter_test.dart';

import 'package:carli/modules/tasks/data/frequency.dart';
import 'package:carli/modules/tasks/data/quick_dates.dart';

void main() {
  final monday = DateTime(2026, 10, 26);

  group('FrequencyDraft', () {
    test('starts weekly on the start weekday', () {
      expect(FrequencyDraft.initial(monday).rrule, 'FREQ=WEEKLY;BYDAY=MO');
    });

    test('builds every rule the editor offers', () {
      final draft = FrequencyDraft.initial(monday);
      expect(draft.copyWith(unit: FrequencyUnit.daily, interval: 3).rrule, 'FREQ=DAILY;INTERVAL=3');
      expect(draft.toggleWeekday(4).rrule, 'FREQ=WEEKLY;BYDAY=MO,TH');
      expect(draft.copyWith(interval: 2, weekdays: {6}).rrule, 'FREQ=WEEKLY;INTERVAL=2;BYDAY=SA');
      expect(draft.copyWith(unit: FrequencyUnit.monthly, monthDay: 1).rrule, 'FREQ=MONTHLY;BYMONTHDAY=1');
      expect(
        draft.copyWith(unit: FrequencyUnit.monthly, monthlyMode: MonthlyMode.lastDay).rrule,
        'FREQ=MONTHLY;BYMONTHDAY=-1',
      );
      expect(
        draft
            .copyWith(
              unit: FrequencyUnit.monthly,
              monthlyMode: MonthlyMode.weekdayPosition,
              position: -1,
              positionWeekday: 5,
            )
            .rrule,
        'FREQ=MONTHLY;BYDAY=FR;BYSETPOS=-1',
      );
      expect(
        draft.copyWith(unit: FrequencyUnit.yearly, yearMonth: 3, monthDay: 15).rrule,
        'FREQ=YEARLY;BYMONTH=3;BYMONTHDAY=15',
      );
      expect(draft.copyWith(kind: FrequencyKind.afterDone, afterDoneDays: 10).toJson(), {
        'after_done_interval_days': 10,
        'rrule': null,
      });
    });

    test('never leaves a weekly rule without days', () {
      expect(FrequencyDraft.initial(monday).toggleWeekday(1).weekdays, {1});
    });

    test('parses the rules it builds back into the editor', () {
      for (final rule in [
        'FREQ=DAILY;INTERVAL=3',
        'FREQ=WEEKLY;BYDAY=MO,TH',
        'FREQ=WEEKLY;INTERVAL=2;BYDAY=SA',
        'FREQ=MONTHLY;BYMONTHDAY=1',
        'FREQ=MONTHLY;BYMONTHDAY=-1',
        'FREQ=MONTHLY;BYDAY=FR;BYSETPOS=-1',
        'FREQ=YEARLY;BYMONTH=3;BYMONTHDAY=15',
      ]) {
        expect(FrequencyDraft.parse(rrule: rule, start: monday).rrule, rule);
      }
      expect(FrequencyDraft.parse(afterDoneDays: 4, start: monday).afterDone, isTrue);
    });
  });

  group('QuickDate', () {
    test('resolves the quick add shortcuts', () {
      expect(QuickDate.today.resolve(monday), monday);
      expect(QuickDate.tomorrow.resolve(monday), DateTime(2026, 10, 27));
      expect(QuickDate.weekend.resolve(monday), DateTime(2026, 10, 31));
      expect(QuickDate.weekend.resolve(DateTime(2026, 10, 31)), DateTime(2026, 11, 7));
      expect(QuickDate.nextWeek.resolve(monday), DateTime(2026, 11, 2));
      expect(QuickDate.none.resolve(monday), isNull);
    });

    test('labels due dates relative to today', () {
      expect(taskDueLabel(DateTime(2026, 10, 25), now: monday), 'Ayer');
      expect(taskDueLabel(DateTime(2026, 10, 22), now: monday), 'Hace 4 días');
      expect(taskDueLabel(DateTime(2026, 10, 29), now: monday), 'Jueves');
      expect(taskDueLabel(DateTime(2026, 11, 20), now: monday), '20 nov');
    });
  });
}
