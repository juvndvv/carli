import 'package:flutter/cupertino.dart';

import '../../../core/theme/tokens.dart';
import '../../../ui/button.dart';
import '../../../ui/icon_names.dart';
import '../../../ui/select.dart';
import '../../../ui/sheet.dart';
import '../data/tasks_models.dart';

String formatTaskTime(DateTime time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

DateTime _timeOf(String? value) {
  final parts = (value ?? '09:00').split(':').map(int.tryParse).toList();
  return DateTime(2000, 1, 1, parts.firstOrNull ?? 9, parts.length > 1 ? parts[1] ?? 0 : 0);
}

/// Returns `(null,)` when the time is cleared and `null` when the sheet is dismissed.
Future<(String?,)?> pickTaskTime(BuildContext context, {String? initial}) {
  var selected = _timeOf(initial);
  return showCarliSheet<(String?,)>(
    context,
    title: 'Hora',
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(CarliSpace.s16, 0, CarliSpace.s16, CarliSpace.s16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: CarliSpace.s12,
        children: [
          SizedBox(
            height: 180,
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.time,
              use24hFormat: true,
              minuteInterval: 5,
              initialDateTime: selected.copyWith(minute: selected.minute - selected.minute % 5),
              onDateTimeChanged: (value) => selected = value,
            ),
          ),
          CarliButton(label: 'Guardar hora', onPressed: () => Navigator.pop(context, (formatTaskTime(selected),))),
          if (initial != null)
            CarliButton(
              label: 'Quitar hora',
              variant: CarliButtonVariant.secondary,
              onPressed: () => Navigator.pop(context, (null,)),
            ),
        ],
      ),
    ),
  );
}

Future<String?> pickTaskList(BuildContext context, {required List<TaskList> lists, String? current}) async {
  final picked = await pickCarliOption<String>(
    context,
    title: 'Lista',
    value: current,
    options: [
      for (final list in lists)
        CarliOption(list.id, list.name, icon: carliIconNamed(list.icon ?? (list.isDefault ? 'inbox' : 'list'))),
    ],
  );
  return picked?.$1;
}
