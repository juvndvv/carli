import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/dates.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../ui/button.dart';
import '../../../ui/field.dart';
import '../../../ui/icon.dart';
import '../../../ui/icon_names.dart';
import '../../../ui/pressable.dart';
import '../../../ui/ring.dart';
import '../../../ui/sheet.dart';
import '../../tasks/ui/postpone_sheet.dart';
import '../data/habit_actions.dart';
import '../data/habits_format.dart';
import '../data/habits_models.dart';
import 'habit_ring.dart';

/// Long press on a ring, or a day of the calendar: − / + around a big ring, the exact value, the day and a note.
Future<void> showHabitLogSheet(
  BuildContext context, {
  required Habit habit,
  required DateTime date,
  required double value,
  required double target,
  String? note,
  bool canChangeDay = true,
}) => showCarliSheet<void>(
  context,
  builder: (context) =>
      _HabitLogSheet(habit: habit, date: date, value: value, target: target, note: note, canChangeDay: canChangeDay),
);

class _HabitLogSheet extends ConsumerStatefulWidget {
  const _HabitLogSheet({
    required this.habit,
    required this.date,
    required this.value,
    required this.target,
    required this.canChangeDay,
    this.note,
  });

  final Habit habit;
  final DateTime date;
  final double value;
  final double target;
  final String? note;
  final bool canChangeDay;

  @override
  ConsumerState<_HabitLogSheet> createState() => _HabitLogSheetState();
}

class _HabitLogSheetState extends ConsumerState<_HabitLogSheet> {
  late double _value = widget.value;
  late DateTime _date = widget.date;
  late final _note = TextEditingController(text: widget.note ?? '');
  late final _exact = TextEditingController(text: habitNumber(widget.value));
  var _saving = false;

  Habit get _habit => widget.habit;

  bool get _check => _habit.kind == HabitKind.check;

  @override
  void dispose() {
    _note.dispose();
    _exact.dispose();
    super.dispose();
  }

  void _set(double value) => setState(() {
    _value = value < 0 ? 0 : value;
    _exact.text = habitNumber(_value);
  });

  Future<void> _pickDay() async {
    final picked = await pickTaskDate(context, initial: _date);
    if (picked == null || !mounted) return;
    final day = dateOnly(picked);
    if (day.isAfter(today()) || day.isBefore(_habit.startDate)) return;
    setState(() => _date = day);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final note = _note.text.trim();
    final saved = await ref
        .read(habitActionsProvider)
        .log(_habit, widget.value, _value, date: _date, note: note.isEmpty ? null : note);
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final target = widget.target;
    final progress = switch (_habit.kind) {
      HabitKind.avoid => target <= 0 ? (_value > 0 ? 1.0 : 0.0) : _value / target,
      _ => target <= 0 ? 1.0 : _value / target,
    };
    final unit = _habit.unit?.trim() ?? '';
    final caption = switch (_habit.kind) {
      HabitKind.check => _value > 0 ? 'hecho' : 'sin hacer',
      HabitKind.quantity => 'de ${habitAmount(target, unit)}',
      HabitKind.avoid => target <= 0 ? (unit.isEmpty ? 'veces' : unit) : 'de ${habitAmount(target, unit)} como máximo',
    };
    final isToday = dateOnly(_date) == today();
    Widget stepButton(String icon, String label, VoidCallback? onTap) => Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        child: Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: colors.surface2, shape: BoxShape.circle),
          child: CarliIcon(carliIconNamed(icon), size: 24, color: onTap == null ? colors.text3 : colors.text),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(CarliSpace.s20, 0, CarliSpace.s20, CarliSpace.s20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: CarliSpace.s20,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(_habit.name, style: CarliType.title2.copyWith(color: colors.text)),
                ),
              ),
              CarliButton(
                label: isToday ? 'Hoy' : '${_date.day} ${monthsShort[_date.month - 1]}',
                icon: carliIconNamed('chevron-down'),
                variant: CarliButtonVariant.ghost,
                size: CarliButtonSize.sm,
                block: false,
                onPressed: widget.canChangeDay ? _pickDay : null,
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              stepButton('minus', 'Quitar uno', _value > 0 ? () => _set(_check ? 0 : _value - 1) : null),
              Stack(
                alignment: Alignment.center,
                children: [
                  CarliRings(
                    rings: [CarliRingValue(progress, habitRingColor(context))],
                    size: 150,
                    stroke: 16,
                    semanticLabel: '${habitNumber(_value)} $caption',
                  ),
                  ExcludeSemantics(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(habitNumber(_value), style: CarliType.display.copyWith(color: colors.text)),
                        Text(caption, style: CarliType.small.copyWith(color: colors.text2)),
                      ],
                    ),
                  ),
                ],
              ),
              stepButton('plus', 'Añadir uno', _check && _value >= 1 ? null : () => _set(_value + 1)),
            ],
          ),
          if (!_check)
            CarliField(
              label: 'Valor exacto',
              child: CarliInput(
                controller: _exact,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (text) {
                  final parsed = double.tryParse(text.replaceAll(',', '.'));
                  if (parsed != null && parsed >= 0) setState(() => _value = parsed);
                },
              ),
            ),
          CarliField(
            label: 'Nota (opcional)',
            child: CarliInput(controller: _note, placeholder: 'Añade una nota'),
          ),
          CarliButton(label: 'Guardar', loading: _saving, onPressed: _save),
        ],
      ),
    );
  }
}
