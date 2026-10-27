import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../ui/async_view.dart';
import '../../../ui/button.dart';
import '../../../ui/icon.dart';
import '../../../ui/icon_names.dart';
import '../../../ui/sheet.dart';
import '../../tasks/ui/form_rows.dart';
import '../../tasks/ui/task_group.dart';
import '../../tasks/ui/tasks_skeleton.dart';
import '../data/habit_actions.dart';
import '../data/habits_format.dart';
import '../data/habits_models.dart';
import '../data/habits_providers.dart';
import '../habits_paths.dart';
import 'day_dot.dart';

/// Daily or weekly templates (every week, no interval) are the only ones that read as habits.
bool canConvertToHabit({required String? rrule}) {
  if (rrule == null) return false;
  final parts = {
    for (final part in rrule.split(';'))
      if (part.contains('=')) part.split('=').first: part.split('=').last,
  };
  final interval = int.tryParse(parts['INTERVAL'] ?? '1') ?? 1;
  final days = parts['BYDAY']?.split(',') ?? const [];
  return interval == 1 &&
      (parts['FREQ'] == 'DAILY' || parts['FREQ'] == 'WEEKLY') &&
      !parts.containsKey('BYMONTHDAY') &&
      !parts.containsKey('BYSETPOS') &&
      days.every((day) => day.length == 2);
}

Future<void> showConvertTemplateSheet(BuildContext context, {required String templateId}) => showCarliSheet<void>(
  context,
  title: 'Convertir en hábito',
  builder: (context) => _ConvertSheet(templateId: templateId),
);

class _ConvertSheet extends ConsumerStatefulWidget {
  const _ConvertSheet({required this.templateId});

  final String templateId;

  @override
  ConsumerState<_ConvertSheet> createState() => _ConvertSheetState();
}

class _ConvertSheetState extends ConsumerState<_ConvertSheet> {
  var _saving = false;

  Future<void> _convert() async {
    setState(() => _saving = true);
    final habit = await ref.read(habitActionsProvider).convertTemplate(widget.templateId);
    if (!mounted) return;
    setState(() => _saving = false);
    if (habit == null) return;
    final router = GoRouter.of(context);
    Navigator.pop(context);
    router.go(HabitsPaths.today);
    router.push(HabitsPaths.habit(habit.habit.id));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final preview = ref.watch(conversionPreviewProvider(widget.templateId));
    return Padding(
      padding: const EdgeInsets.fromLTRB(CarliSpace.s16, 0, CarliSpace.s16, CarliSpace.s20),
      child: AsyncView(
        value: preview,
        errorTitle: 'No se puede convertir esta plantilla',
        onRetry: () => ref.invalidate(conversionPreviewProvider(widget.templateId)),
        loading: const TasksSkeleton(),
        data: (preview) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: CarliSpace.s16,
          children: [
            Text(
              'Dejará de generar tareas. Lo seguirás en Hábitos y como anillo en Hoy.',
              style: CarliType.small.copyWith(color: colors.text2),
            ),
            TaskGroup(
              indent: CarliSpace.s16,
              children: [
                FormRow(label: 'Objetivo', value: preview.goalText, chevron: false),
                const FormRow(label: 'Tipo', value: 'Sí / No', chevron: false),
              ],
            ),
            const FormEyebrow('Historial que se importa · 8 semanas'),
            _HistoryGrid(cells: preview.cells),
            Wrap(
              spacing: CarliSpace.s16,
              runSpacing: CarliSpace.s4,
              children: [
                Text('${preview.done} hechas', style: CarliType.small.copyWith(color: colors.text)),
                Text('${preview.skipped} saltadas → descanso', style: CarliType.small.copyWith(color: colors.text)),
                Text('${preview.missed} sin hacer', style: CarliType.small.copyWith(color: colors.text)),
              ],
            ),
            Text(
              'Empiezas con constancia del ${habitPercent(preview.consistency)} y racha de '
              '${habitStreakLength(preview.streak, GoalPeriod.day)}.',
              style: CarliType.small.copyWith(color: colors.text2),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: CarliSpace.s8,
              children: [
                CarliIcon(carliIconNamed('info'), size: 16, color: colors.text2),
                Expanded(
                  child: Text(
                    'La plantilla queda pausada y se borra la tarea abierta de hoy. Subtareas, lista y notas no pasan al hábito.',
                    style: CarliType.small.copyWith(color: colors.text2),
                  ),
                ),
              ],
            ),
            CarliButton(label: 'Convertir en hábito', loading: _saving, onPressed: _convert),
            CarliButton(
              label: 'Cancelar',
              variant: CarliButtonVariant.secondary,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryGrid extends StatelessWidget {
  const _HistoryGrid({required this.cells});

  final List<DayCell> cells;

  @override
  Widget build(BuildContext context) => Column(
    spacing: 4,
    children: [
      for (var row = 0; row * 7 < cells.length; row++)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [for (final cell in cells.skip(row * 7).take(7)) DayDot(state: cell.state, size: 22, square: true)],
        ),
    ],
  );
}
