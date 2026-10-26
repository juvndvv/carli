import 'package:flutter/material.dart';
import 'package:hugeicons/styles/stroke_rounded.dart';

import '../core/format/dates.dart';
import '../core/theme/tokens.dart';
import 'chip.dart';
import 'sheet.dart';

class CarliDatePicker extends StatelessWidget {
  const CarliDatePicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.firstDate,
    this.lastDate,
    this.now,
  });

  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final DateTime? now;

  Future<void> _pick(BuildContext context) async {
    final current = today(now);
    final picked = await showCarliSheet<DateTime>(
      context,
      title: 'Elige una fecha',
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s8),
        child: CalendarDatePicker(
          initialDate: value,
          firstDate: firstDate ?? DateTime(current.year - 10),
          lastDate: lastDate ?? DateTime(current.year + 5, 12, 31),
          currentDate: current,
          onDateChanged: (date) => Navigator.pop(context, date),
        ),
      ),
    );
    if (picked != null) onChanged(dateOnly(picked));
  }

  @override
  Widget build(BuildContext context) {
    final current = today(now);
    final yesterday = current.subtract(const Duration(days: 1));
    final selected = dateOnly(value);
    final otherDay = selected != current && selected != yesterday;
    return Semantics(
      container: true,
      label: 'Fecha',
      child: Wrap(
        spacing: CarliSpace.s8,
        runSpacing: CarliSpace.s8,
        children: [
          CarliChip(label: 'Hoy', selected: selected == current, onTap: () => onChanged(current)),
          CarliChip(label: 'Ayer', selected: selected == yesterday, onTap: () => onChanged(yesterday)),
          CarliChip(
            icon: HugeIconsStrokeRounded.calendar03,
            label: otherDay ? formatFormDate(selected) : null,
            selected: otherDay,
            semanticLabel: otherDay ? 'Fecha: ${formatFormDate(selected)}' : 'Elegir otra fecha',
            onTap: () => _pick(context),
          ),
        ],
      ),
    );
  }
}
