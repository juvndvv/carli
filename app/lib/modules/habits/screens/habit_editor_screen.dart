import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/dates.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../ui/async_view.dart';
import '../../../ui/chip.dart';
import '../../../ui/field.dart';
import '../../../ui/full_sheet.dart';
import '../../../ui/icon.dart';
import '../../../ui/icon_names.dart';
import '../../../ui/pressable.dart';
import '../../../ui/segmented.dart';
import '../../../ui/switch.dart';
import '../../finance/data/json.dart';
import '../../tasks/ui/form_rows.dart';
import '../../tasks/ui/pickers.dart';
import '../../tasks/ui/postpone_sheet.dart';
import '../../tasks/ui/stepper.dart';
import '../../tasks/ui/task_group.dart';
import '../../tasks/ui/tasks_skeleton.dart';
import '../data/habit_actions.dart';
import '../data/habits_format.dart';
import '../data/habits_models.dart';
import '../data/habits_providers.dart';
import '../habits_paths.dart';

const habitIcons = [
  'check', 'book-open', 'droplet', 'dumbbell', 'running', 'bike', 'heart-pulse', 'leaf', //
  'moon', 'sun', 'bed', 'apple', 'utensils', 'pill', 'coffee', 'cigarette',
  'beer', 'wine', 'smartphone', 'tv', 'music', 'pencil', 'graduation-cap', 'globe',
  'phone', 'users', 'wallet', 'target', 'flame', 'sparkles', 'paw-print', 'mountain',
];

/// What the objective selector offers; each kind maps to a period and, for yes/no, an optional day list.
enum GoalMode {
  everyDay('Cada día'),
  someDays('Días concretos'),
  timesPerWeek('Veces por semana'),
  perDay('Al día'),
  perWeek('A la semana');

  const GoalMode(this.label);

  final String label;

  static List<GoalMode> forKind(HabitKind kind) =>
      kind == HabitKind.check ? const [everyDay, someDays, timesPerWeek] : const [perDay, perWeek];

  GoalPeriod get period => this == timesPerWeek || this == perWeek ? GoalPeriod.week : GoalPeriod.day;
}

GoalMode goalModeOf(Habit habit) => switch ((habit.kind, habit.goal.period)) {
  (HabitKind.check, GoalPeriod.week) => GoalMode.timesPerWeek,
  (HabitKind.check, _) when habit.goal.daysOfWeek != null => GoalMode.someDays,
  (HabitKind.check, _) => GoalMode.everyDay,
  (_, GoalPeriod.week) => GoalMode.perWeek,
  _ => GoalMode.perDay,
};

class HabitEditorScreen extends ConsumerWidget {
  const HabitEditorScreen({super.key, this.habitId});

  final String? habitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = habitId;
    if (id == null) return const HabitEditor();
    final detail = ref.watch(habitDetailProvider(id));
    return switch (detail) {
      AsyncValue(hasValue: true, :final value?) => HabitEditor(key: ValueKey(value.habit.id), habit: value.habit),
      _ => Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              FullSheetHeader(title: 'Hábito', onLeading: () => context.pop()),
              Padding(
                padding: const EdgeInsets.all(CarliSpace.s16),
                child: AsyncView(
                  value: detail,
                  errorTitle: 'No se ha podido cargar el hábito',
                  onRetry: () => ref.invalidate(habitDetailProvider(id)),
                  loading: const TasksSkeleton(),
                  data: (_) => const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ),
    };
  }
}

class HabitEditor extends ConsumerStatefulWidget {
  const HabitEditor({super.key, this.habit});

  final Habit? habit;

  @override
  ConsumerState<HabitEditor> createState() => _HabitEditorState();
}

class _HabitEditorState extends ConsumerState<HabitEditor> {
  late final _name = TextEditingController(text: widget.habit?.name ?? '');
  late final _unit = TextEditingController(text: widget.habit?.unit ?? '');
  late final _amount = TextEditingController(
    text: widget.habit == null || widget.habit!.kind == HabitKind.check ? '' : habitNumber(widget.habit!.goal.target),
  );
  late String _icon = widget.habit?.icon ?? 'check';
  late HabitKind _kind = widget.habit?.kind ?? HabitKind.check;
  late GoalMode _mode = widget.habit == null ? GoalMode.everyDay : goalModeOf(widget.habit!);
  late Set<int> _days = {...?widget.habit?.goal.daysOfWeek};
  late int _times = widget.habit?.goal.period == GoalPeriod.week && widget.habit?.kind == HabitKind.check
      ? widget.habit!.goal.target.round()
      : 3;
  late DateTime _start = widget.habit?.startDate ?? today();
  late String? _time = widget.habit?.preferredTime;
  late bool _showInTasks = widget.habit?.showInTasks ?? true;
  var _saving = false;
  String? _error;

  bool get _editing => widget.habit != null;

  @override
  void dispose() {
    _name.dispose();
    _unit.dispose();
    _amount.dispose();
    super.dispose();
  }

  double? get _target => switch (_kind) {
    HabitKind.check => _mode == GoalMode.timesPerWeek ? _times.toDouble() : 1,
    _ => double.tryParse(_amount.text.trim().replaceAll(',', '.')) ?? (_kind == HabitKind.avoid ? 0 : null),
  };

  void _setKind(HabitKind kind) => setState(() {
    _kind = kind;
    _mode = GoalMode.forKind(kind).first;
    if (kind == HabitKind.avoid && _amount.text.isEmpty) _amount.text = '0';
  });

  String get _summary {
    final target = _target;
    final unit = _unit.text.trim();
    return switch ((_kind, _mode)) {
      (HabitKind.check, GoalMode.everyDay) => 'Cada día',
      (HabitKind.check, GoalMode.someDays) =>
        _days.isEmpty
            ? 'Elige los días'
            : capitalize([for (final day in (_days.toList()..sort())) weekdaysLong[day - 1]].join(', ')),
      (HabitKind.check, _) =>
        _times == 1 ? '1 vez por semana, cualquier día' : '$_times veces por semana, cualquier día',
      (_, _) when target == null => 'Indica la cantidad',
      (HabitKind.quantity, _) =>
        '${habitAmount(target, unit)} ${_mode.period == GoalPeriod.week ? 'a la semana' : 'al día'}',
      (_, _) when target <= 0 => _mode.period == GoalPeriod.week ? 'Nada en toda la semana' : 'Nada',
      _ => 'Máximo ${habitAmount(target, unit)} ${_mode.period == GoalPeriod.week ? 'por semana' : 'al día'}',
    };
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final target = _target;
    final error = switch (()) {
      _ when name.isEmpty => 'Ponle un nombre.',
      _ when _kind == HabitKind.quantity && (target == null || target <= 0) => 'Indica la cantidad objetivo.',
      _ when _mode == GoalMode.someDays && _days.isEmpty => 'Elige al menos un día.',
      _ => null,
    };
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final Json input = {
      'name': name,
      'icon': _icon,
      if (!_editing) 'kind': _kind.name,
      'unit': _kind == HabitKind.check ? null : _unit.text.trim(),
      'period': _mode.period.name,
      'target': target,
      'days_of_week': _mode == GoalMode.someDays ? (_days.toList()..sort()) : null,
      'start_date': isoDate(_start),
      'preferred_time': _time,
      'show_in_tasks': _showInTasks,
    };
    final saved = await ref.read(habitActionsProvider).save(widget.habit?.id, input);
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved == null) return;
    if (_editing) {
      context.pop();
    } else {
      context.pushReplacement(HabitsPaths.habit(saved.habit.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            FullSheetHeader(
              title: _editing ? 'Editar hábito' : 'Nuevo hábito',
              onLeading: () => context.pop(),
              trailing: SaveHeaderAction(saving: _saving, onSave: _save, label: _editing ? 'Guardar' : 'Añadir'),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(CarliSpace.s16, CarliSpace.s16, CarliSpace.s16, CarliSpace.s48),
                children: [
                  if (_error case final error?) ...[FormError(error), const SizedBox(height: CarliSpace.s12)],
                  CarliField(
                    label: 'Nombre',
                    child: CarliInput(
                      controller: _name,
                      placeholder: 'Meditar, beber agua, no fumar…',
                      autofocus: !_editing,
                    ),
                  ),
                  const SizedBox(height: CarliSpace.s20),
                  const FormEyebrow('Icono'),
                  const SizedBox(height: CarliSpace.s8),
                  Wrap(
                    spacing: CarliSpace.s8,
                    runSpacing: CarliSpace.s8,
                    children: [
                      for (final icon in habitIcons)
                        Semantics(
                          button: true,
                          selected: icon == _icon,
                          label: 'Icono $icon',
                          excludeSemantics: true,
                          child: Pressable(
                            onTap: () => setState(() => _icon = icon),
                            child: Container(
                              width: 44,
                              height: 44,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: icon == _icon ? colors.text : colors.surface2,
                                shape: BoxShape.circle,
                              ),
                              child: CarliIcon(
                                carliIconNamed(icon),
                                size: 20,
                                color: icon == _icon ? colors.surface : colors.text,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: CarliSpace.s20),
                  const FormEyebrow('Tipo'),
                  const SizedBox(height: CarliSpace.s8),
                  if (_editing)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s4),
                      child: Text(
                        '${_kind.label} · el tipo no se puede cambiar',
                        style: CarliType.body.copyWith(color: colors.text2),
                      ),
                    )
                  else
                    CarliSegmented<HabitKind>(
                      segments: [for (final kind in HabitKind.values) CarliSegment(kind, kind.label)],
                      value: _kind,
                      onChanged: _setKind,
                    ),
                  if (_kind != HabitKind.check) ...[
                    const SizedBox(height: CarliSpace.s12),
                    Row(
                      spacing: CarliSpace.s12,
                      children: [
                        Expanded(
                          child: CarliField(
                            label: _kind == HabitKind.avoid ? 'Máximo' : 'Cantidad',
                            child: CarliInput(
                              controller: _amount,
                              placeholder: _kind == HabitKind.avoid ? '0' : '8',
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ),
                        Expanded(
                          child: CarliField(
                            label: 'Unidad',
                            child: CarliInput(
                              controller: _unit,
                              placeholder: _kind == HabitKind.avoid ? 'cafés' : 'vasos',
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_kind == HabitKind.avoid) ...[
                      const SizedBox(height: CarliSpace.s8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s4),
                        child: Text(
                          'Registras las recaídas o lo que tomas. Un día sin registro cuenta como cumplido.',
                          style: CarliType.small.copyWith(color: colors.text2),
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: CarliSpace.s20),
                  const FormEyebrow('Objetivo'),
                  const SizedBox(height: CarliSpace.s8),
                  Wrap(
                    spacing: CarliSpace.s8,
                    runSpacing: CarliSpace.s8,
                    children: [
                      for (final mode in GoalMode.forKind(_kind))
                        CarliChip(
                          label: mode.label,
                          selected: mode == _mode,
                          onTap: () => setState(() => _mode = mode),
                        ),
                    ],
                  ),
                  if (_mode == GoalMode.someDays) ...[
                    const SizedBox(height: CarliSpace.s12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (var day = 1; day <= 7; day++)
                          RoundToggle(
                            label: weekdaysMondayFirstShort[day - 1],
                            semanticLabel: weekdaysLong[day - 1],
                            selected: _days.contains(day),
                            onTap: () => setState(
                              () => _days = _days.contains(day) ? ({..._days}..remove(day)) : {..._days, day},
                            ),
                          ),
                      ],
                    ),
                  ],
                  if (_mode == GoalMode.timesPerWeek) ...[
                    const SizedBox(height: CarliSpace.s12),
                    Row(
                      children: [
                        Expanded(
                          child: Text('Veces por semana', style: CarliType.body.copyWith(color: colors.text)),
                        ),
                        CountStepper(
                          value: _times,
                          label: '$_times',
                          semanticName: 'veces por semana',
                          max: 7,
                          onChanged: (times) => setState(() => _times = times),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: CarliSpace.s8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s4),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(_summary, style: CarliType.bodyStrong.copyWith(color: colors.text)),
                    ),
                  ),
                  if (_editing)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(CarliSpace.s4, CarliSpace.s4, CarliSpace.s4, 0),
                      child: Text(
                        'Si cambias el objetivo, se aplica desde hoy. Los días pasados se evalúan con el que tenían.',
                        style: CarliType.small.copyWith(color: colors.text2),
                      ),
                    ),
                  const SizedBox(height: CarliSpace.s20),
                  TaskGroup(
                    indent: CarliSpace.s16,
                    children: [
                      FormRow(
                        label: 'Empieza',
                        value: dateOnly(_start) == today()
                            ? 'Hoy'
                            : formatShortDate(_start, withYear: _start.year != today().year),
                        onTap: () async {
                          final picked = await pickTaskDate(context, initial: _start);
                          if (picked != null) setState(() => _start = dateOnly(picked));
                        },
                      ),
                      FormRow(
                        label: 'Momento del día',
                        value: _time ?? 'Sin hora',
                        onTap: () async {
                          final picked = await pickTaskTime(context, initial: _time);
                          if (picked != null) setState(() => _time = picked.$1);
                        },
                      ),
                      if (_kind != HabitKind.avoid)
                        FormRow(
                          label: 'Mostrar en Hoy de Tareas',
                          chevron: false,
                          trailing: CarliSwitch(
                            value: _showInTasks,
                            semanticLabel: 'Mostrar en Hoy de Tareas',
                            onChanged: (value) => setState(() => _showInTasks = value),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: CarliSpace.s8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s4),
                    child: Text(
                      'El momento del día solo ordena la lista; en esta versión no hay avisos por hábito.',
                      style: CarliType.small.copyWith(color: colors.text2),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
