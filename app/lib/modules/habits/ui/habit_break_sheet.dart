import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/dates.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../ui/button.dart';
import '../../../ui/chip.dart';
import '../../../ui/sheet.dart';
import '../../tasks/ui/form_rows.dart';
import '../../tasks/ui/postpone_sheet.dart';
import '../../tasks/ui/task_group.dart';
import '../data/habit_actions.dart';
import '../data/habits_models.dart';
import '../data/habits_providers.dart';

String breakRange(HabitBreak pause) => pause.from == pause.to
    ? '${pause.from.day} ${monthsShort[pause.from.month - 1]}'
    : '${pause.from.day} ${monthsShort[pause.from.month - 1]} – ${pause.to.day} ${monthsShort[pause.to.month - 1]}';

/// "Modo descanso": the breaks in course with "Terminar", and a new one from today (or from a habit, only for it).
Future<void> showHabitBreakSheet(BuildContext context, {Habit? habit}) => showCarliSheet<void>(
  context,
  title: habit == null ? 'Modo descanso' : 'Descanso de ${habit.name}',
  builder: (context) => _BreakSheet(habit: habit),
);

class _BreakSheet extends ConsumerStatefulWidget {
  const _BreakSheet({this.habit});

  final Habit? habit;

  @override
  ConsumerState<_BreakSheet> createState() => _BreakSheetState();
}

class _BreakSheetState extends ConsumerState<_BreakSheet> {
  late DateTime _from = today();
  late DateTime _to = today().add(const Duration(days: 6));
  var _saving = false;

  Future<void> _start() async {
    setState(() => _saving = true);
    final saved = await ref.read(habitActionsProvider).startBreak(_from, _to, habitId: widget.habit?.id);
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final breaks = [
      for (final pause in ref.watch(habitBreaksProvider).value ?? const <HabitBreak>[])
        if ((pause.active || pause.upcoming) && pause.habitId == widget.habit?.id) pause,
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(CarliSpace.s16, 0, CarliSpace.s16, CarliSpace.s20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: CarliSpace.s16,
        children: [
          Text(
            widget.habit == null
                ? 'Vacaciones, enfermo… Mientras dure no se evalúa ningún hábito: ni rompe rachas ni baja la constancia.'
                : 'Mientras dure no se evalúa este hábito: ni rompe la racha ni baja la constancia.',
            style: CarliType.small.copyWith(color: colors.text2),
          ),
          if (breaks.isNotEmpty)
            TaskGroup(
              indent: CarliSpace.s16,
              children: [
                for (final pause in breaks)
                  FormRow(
                    label: pause.active ? 'En curso · ${breakRange(pause)}' : 'Programado · ${breakRange(pause)}',
                    chevron: false,
                    trailing: CarliButton(
                      label: pause.active ? 'Terminar' : 'Quitar',
                      size: CarliButtonSize.sm,
                      variant: CarliButtonVariant.ghost,
                      block: false,
                      onPressed: () => ref.read(habitActionsProvider).endBreak(pause),
                    ),
                  ),
              ],
            ),
          Wrap(
            spacing: CarliSpace.s8,
            runSpacing: CarliSpace.s8,
            children: [
              for (final (days, label) in const [(3, '3 días'), (7, '1 semana'), (14, '2 semanas')])
                CarliChip(
                  label: label,
                  selected: _from == today() && _to == today().add(Duration(days: days - 1)),
                  onTap: () => setState(() {
                    _from = today();
                    _to = today().add(Duration(days: days - 1));
                  }),
                ),
            ],
          ),
          TaskGroup(
            indent: CarliSpace.s16,
            children: [
              FormRow(
                label: 'Desde',
                value: formatShortDate(_from),
                onTap: () async {
                  final picked = await pickTaskDate(context, initial: _from);
                  if (picked != null) {
                    setState(() {
                      _from = dateOnly(picked);
                      if (_to.isBefore(_from)) _to = _from;
                    });
                  }
                },
              ),
              FormRow(
                label: 'Hasta',
                value: formatShortDate(_to),
                onTap: () async {
                  final picked = await pickTaskDate(context, initial: _to);
                  if (picked != null && !dateOnly(picked).isBefore(_from)) setState(() => _to = dateOnly(picked));
                },
              ),
            ],
          ),
          CarliButton(label: 'Empezar descanso', loading: _saving, onPressed: _start),
        ],
      ),
    );
  }
}
