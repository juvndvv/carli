import 'package:flutter/material.dart';

import '../../../core/format/dates.dart';
import '../../../core/theme/tokens.dart';
import '../../../ui/icon_names.dart';
import '../../../ui/list_item.dart';
import '../../../ui/sheet.dart';
import '../data/quick_dates.dart';

const _postponeOptions = [QuickDate.today, QuickDate.tomorrow, QuickDate.weekend, QuickDate.nextWeek];

Future<DateTime?> pickTaskDate(BuildContext context, {DateTime? initial}) async {
  final current = today();
  final picked = await showCarliSheet<DateTime>(
    context,
    title: 'Elige una fecha',
    builder: (context) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s8),
      child: CalendarDatePicker(
        initialDate: initial ?? current,
        firstDate: DateTime(current.year - 1),
        lastDate: DateTime(current.year + 5, 12, 31),
        currentDate: current,
        onDateChanged: (date) => Navigator.pop(context, date),
      ),
    ),
  );
  return picked == null ? null : dateOnly(picked);
}

Future<DateTime?> showPostponeSheet(BuildContext context, {DateTime? from, bool includeToday = false}) async {
  final options = [
    for (final option in _postponeOptions)
      if (option != QuickDate.today || includeToday) option,
  ];
  final choice = await showCarliSheet<Object>(
    context,
    title: 'Posponer',
    builder: (context) => Padding(
      padding: const EdgeInsets.only(bottom: CarliSpace.s16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final option in options)
            CarliListItem(
              title: option.label,
              subtitle: weekdayShortDate(option.resolve()!),
              icon: carliIconNamed(option == QuickDate.today ? 'sun' : 'calendar'),
              onTap: () => Navigator.pop(context, option),
            ),
          CarliListItem(
            title: 'Elegir fecha',
            icon: carliIconNamed('calendar-days'),
            onTap: () => Navigator.pop(context, 'pick'),
          ),
        ],
      ),
    ),
  );
  if (!context.mounted) return null;
  return switch (choice) {
    final QuickDate option => option.resolve(),
    'pick' => pickTaskDate(context, initial: from),
    _ => null,
  };
}
