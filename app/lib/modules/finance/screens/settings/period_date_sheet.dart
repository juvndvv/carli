import 'package:flutter/material.dart';

import '../../../../core/format/dates.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../../../ui/button.dart';
import '../../../../ui/sheet.dart';

Future<DateTime?> showPeriodDateSheet(
  BuildContext context, {
  required String title,
  required String description,
  required String confirmLabel,
  DateTime? initial,
  DateTime? now,
}) => showCarliSheet<DateTime>(
  context,
  title: title,
  builder: (context) =>
      PeriodDatePicker(description: description, confirmLabel: confirmLabel, initial: initial, now: now),
);

class PeriodDatePicker extends StatefulWidget {
  const PeriodDatePicker({super.key, required this.description, required this.confirmLabel, this.initial, this.now});

  final String description;
  final String confirmLabel;
  final DateTime? initial;
  final DateTime? now;

  @override
  State<PeriodDatePicker> createState() => _PeriodDatePickerState();
}

class _PeriodDatePickerState extends State<PeriodDatePicker> {
  late final _today = today(widget.now);
  late final _last = _today.add(const Duration(days: 31));
  late var _date = _clamp(widget.initial ?? _today);

  DateTime _clamp(DateTime value) {
    final day = dateOnly(value);
    return day.isAfter(_last) ? _last : day;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(CarliSpace.s20, 0, CarliSpace.s20, CarliSpace.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: CarliSpace.s12,
        children: [
          Text(widget.description, style: CarliType.small.copyWith(color: colors.text2)),
          CalendarDatePicker(
            initialDate: _date,
            firstDate: DateTime(_today.year - 10),
            lastDate: _last,
            currentDate: _today,
            onDateChanged: (value) => setState(() => _date = dateOnly(value)),
          ),
          Text(
            'Fecha de inicio: ${formatLongDate(_date)}${_date.year == _today.year ? '' : ' de ${_date.year}'}',
            textAlign: TextAlign.center,
            style: CarliType.small.copyWith(color: colors.text),
          ),
          Row(
            spacing: CarliSpace.s12,
            children: [
              Expanded(
                child: CarliButton(
                  label: 'Cancelar',
                  variant: CarliButtonVariant.ghost,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Expanded(
                child: CarliButton(label: widget.confirmLabel, onPressed: () => Navigator.pop(context, _date)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
