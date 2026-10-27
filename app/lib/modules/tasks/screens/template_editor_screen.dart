import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/dates.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../ui/async_view.dart';
import '../../../ui/button.dart';
import '../../../ui/chip.dart';
import '../../../ui/full_sheet.dart';
import '../../../ui/icon_names.dart';
import '../../../ui/segmented.dart';
import '../../../ui/select.dart';
import '../../../ui/sheet.dart';
import '../../../ui/switch.dart';
import '../../../ui/toast.dart';
import '../../finance/data/json.dart';
import '../../habits/data/habits_providers.dart';
import '../../habits/ui/convert_template_sheet.dart';
import '../data/frequency.dart';
import '../data/quick_dates.dart';
import '../data/task_actions.dart';
import '../data/tasks_api.dart';
import '../data/tasks_models.dart';
import '../data/tasks_providers.dart';
import '../ui/form_rows.dart';
import '../ui/pickers.dart';
import '../ui/postpone_sheet.dart';
import '../ui/stepper.dart';
import '../ui/task_group.dart';
import '../ui/tasks_skeleton.dart';

@immutable
class TemplateSeed {
  const TemplateSeed({this.title = '', this.notes = '', this.listId, this.dueTime, this.important = false, this.start});

  final String title;
  final String notes;
  final String? listId;
  final String? dueTime;
  final bool important;
  final DateTime? start;
}

enum TemplateEnding { never, until, count }

class TemplateEditorScreen extends ConsumerWidget {
  const TemplateEditorScreen({super.key, this.templateId, this.seed = const TemplateSeed()});

  final String? templateId;
  final TemplateSeed seed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = templateId;
    if (id == null) return TemplateEditor(seed: seed);
    final template = ref.watch(taskTemplateProvider(id));
    return switch (template) {
      AsyncValue(hasValue: true, :final value?) => TemplateEditor(key: ValueKey(value.id), template: value),
      _ => Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              FullSheetHeader(title: 'Plantilla', onLeading: () => context.pop()),
              Padding(
                padding: const EdgeInsets.all(CarliSpace.s16),
                child: AsyncView(
                  value: template,
                  errorTitle: 'No se ha podido cargar la plantilla',
                  onRetry: () => ref.invalidate(taskTemplateProvider(id)),
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

class TemplateEditor extends ConsumerStatefulWidget {
  const TemplateEditor({super.key, this.template, this.seed = const TemplateSeed()});

  final TaskTemplate? template;
  final TemplateSeed seed;

  @override
  ConsumerState<TemplateEditor> createState() => _TemplateEditorState();
}

class _TemplateEditorState extends ConsumerState<TemplateEditor> {
  late final TextEditingController _title;
  late final TextEditingController _notes;
  final _subtaskDraft = TextEditingController();
  late List<String> _subtasks;
  late FrequencyDraft _frequency;
  late DateTime _start;
  late TemplateEnding _ending;
  DateTime? _until;
  late int _count;
  late TemplatePolicy _policy;
  late int _leadDays;
  String? _time;
  String? _listId;
  late bool _important;
  var _saving = false;

  FrequencyPreview? _preview;
  String? _previewError;
  Timer? _debounce;
  var _previewRequest = 0;

  TaskTemplate? get _template => widget.template;

  @override
  void initState() {
    super.initState();
    final template = _template;
    final seed = widget.seed;
    _title = TextEditingController(text: template?.title ?? seed.title);
    _notes = TextEditingController(text: template?.notes ?? seed.notes);
    _subtasks = [...?template?.subtasks];
    _start = template?.dtstart ?? seed.start ?? today();
    _frequency = template == null
        ? FrequencyDraft.initial(_start)
        : FrequencyDraft.parse(rrule: template.rrule, afterDoneDays: template.afterDoneIntervalDays, start: _start);
    _until = template?.until;
    _count = template?.count ?? 10;
    _ending = template?.until != null
        ? TemplateEnding.until
        : template?.count != null
        ? TemplateEnding.count
        : TemplateEnding.never;
    _policy = template?.policy ?? ref.read(tasksSettingsProvider).defaultPolicy;
    _leadDays = template?.leadDays ?? 0;
    _time = template?.dueTime ?? seed.dueTime;
    _listId = template?.list.id ?? seed.listId;
    _important = template?.important ?? seed.important;
    _schedulePreview(immediate: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _title.dispose();
    _notes.dispose();
    _subtaskDraft.dispose();
    super.dispose();
  }

  Json get _frequencyJson => {
    ..._frequency.toJson(),
    'dtstart': isoDate(_start),
    'until': _ending == TemplateEnding.until && _until != null ? isoDate(_until!) : null,
    'count': _ending == TemplateEnding.count ? _count : null,
  };

  void _updateFrequency(FrequencyDraft next) {
    setState(() => _frequency = next);
    _schedulePreview();
  }

  void _schedulePreview({bool immediate = false}) {
    _debounce?.cancel();
    _debounce = Timer(immediate ? Duration.zero : const Duration(milliseconds: 300), () async {
      final request = ++_previewRequest;
      final payload = {for (final MapEntry(:key, :value) in _frequencyJson.entries) key: ?value};
      try {
        final preview = await ref.read(tasksApiProvider).preview(payload);
        if (!mounted || request != _previewRequest) return;
        setState(() {
          _preview = preview;
          _previewError = null;
        });
      } catch (_) {
        if (!mounted || request != _previewRequest) return;
        setState(() => _previewError = 'No se ha podido calcular la frecuencia.');
      }
    });
  }

  bool get _canSave => _title.text.trim().isNotEmpty && !_saving;

  Future<void> _save() async {
    if (!_canSave) return;
    final template = _template;
    var applyToOpen = false;
    if (template?.openTaskId != null) {
      applyToOpen = await confirmCarli(
        context,
        title: '¿Aplicar también a la tarea abierta?',
        message: 'Los cambios se aplican a las próximas. La tarea que ya está abierta puede quedarse como está.',
        confirmLabel: 'Aplicar también',
      );
      if (!mounted) return;
    }
    setState(() => _saving = true);
    final saved = await ref.read(taskActionsProvider).saveTemplate(template?.id, {
      'title': _title.text.trim(),
      'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      'list_id': ?_listId,
      'subtasks': _subtasks,
      'due_time': _time,
      'important': _important,
      'policy': _policy.api,
      'lead_days': _leadDays,
      ..._frequencyJson,
      if (template != null) 'apply_to_open': applyToOpen,
    });
    if (!mounted) return;
    if (saved == null) {
      setState(() => _saving = false);
      return;
    }
    ref.read(toastControllerProvider.notifier).show(template == null ? 'Plantilla creada' : 'Plantilla guardada');
    context.pop();
  }

  Future<void> _pickList() async {
    final lists = await ref.read(taskListsProvider.future);
    if (!mounted) return;
    final picked = await pickTaskList(context, lists: lists, current: _listId);
    if (picked != null) setState(() => _listId = picked);
  }

  Future<void> _pickTime() async {
    final picked = await pickTaskTime(context, initial: _time);
    if (picked != null) setState(() => _time = picked.$1);
  }

  Future<void> _pickStart() async {
    final picked = await pickTaskDate(context, initial: _start);
    if (picked == null) return;
    setState(() => _start = picked);
    _schedulePreview();
  }

  Future<void> _pickEnding() async {
    final picked = await pickCarliOption<TemplateEnding>(
      context,
      title: 'Termina',
      value: _ending,
      options: const [
        CarliOption(TemplateEnding.never, 'Nunca'),
        CarliOption(TemplateEnding.until, 'En una fecha'),
        CarliOption(TemplateEnding.count, 'Tras un número de veces'),
      ],
    );
    if (picked == null || !mounted) return;
    if (picked.$1 == TemplateEnding.until) {
      final date = await pickTaskDate(context, initial: _until ?? _start.add(const Duration(days: 30)));
      if (date == null) return;
      _until = date;
    }
    setState(() => _ending = picked.$1);
    _schedulePreview();
  }

  Future<void> _pickLead() async {
    final picked = await pickCarliOption<int>(
      context,
      title: 'Aparece',
      value: _leadDays,
      options: [
        for (final days in const [0, 1, 2, 3, 7, 14, 30]) CarliOption(days, _leadLabel(days)),
      ],
    );
    if (picked != null) setState(() => _leadDays = picked.$1);
  }

  static String _leadLabel(int days) => switch (days) {
    0 => 'El mismo día',
    1 => '1 día antes',
    _ => '$days días antes',
  };

  String get _endingLabel => switch (_ending) {
    TemplateEnding.never => 'Nunca',
    TemplateEnding.until => _until == null ? 'En una fecha' : 'El ${formatShortDate(_until!, withYear: true)}',
    TemplateEnding.count => _count == 1 ? 'Tras 1 vez' : 'Tras $_count veces',
  };

  Future<void> _togglePaused() async {
    final template = _template!;
    final updated = await ref.read(taskActionsProvider).setTemplatePaused(template, !template.paused);
    if (updated != null) {
      ref.read(toastControllerProvider.notifier).show(updated.paused ? 'Plantilla pausada' : 'Plantilla reanudada');
    }
  }

  Future<void> _delete() async {
    final template = _template!;
    final confirmed = await confirmCarli(
      context,
      title: 'Borrar “${template.title}”',
      message: 'Las tareas que ya se generaron se quedan. No se crearán más.',
      confirmLabel: 'Borrar',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    var deleteOpen = false;
    if (template.openTaskId != null) {
      deleteOpen = await confirmCarli(
        context,
        title: '¿Borrar también la tarea abierta?',
        confirmLabel: 'Borrar también',
        destructive: true,
      );
      if (!mounted) return;
    }
    final deleted = await ref.read(taskActionsProvider).deleteTemplate(template, deleteOpen: deleteOpen);
    if (!deleted || !mounted) return;
    ref.read(toastControllerProvider.notifier).show('Plantilla borrada');
    context.pop();
  }

  void _addSubtask() {
    final title = _subtaskDraft.text.trim();
    if (title.isEmpty) return;
    setState(() {
      _subtasks = [..._subtasks, title];
      _subtaskDraft.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final lists = ref.watch(taskListsProvider).value ?? const <TaskList>[];
    final listName =
        lists.where((list) => list.id == _listId).firstOrNull?.name ??
        _template?.list.name ??
        lists.where((list) => list.isDefault).firstOrNull?.name ??
        'Bandeja';
    final template = _template;
    final summary = [
      _preview?.description ?? '',
      if (_time != null) 'a las $_time',
    ].where((part) => part.isNotEmpty).join(' ');

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            FullSheetHeader(
              title: 'Plantilla',
              onLeading: () => context.pop(),
              trailing: TextButton(
                onPressed: _canSave ? _save : null,
                style: TextButton.styleFrom(foregroundColor: colors.brandInk, textStyle: CarliType.bodyStrong),
                child: const Text('Guardar'),
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  CarliSpace.s16,
                  CarliSpace.s16,
                  CarliSpace.s16,
                  CarliSpace.s40 + MediaQuery.paddingOf(context).bottom,
                ),
                children: [
                  TaskGroup(
                    indent: CarliSpace.s16,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16, vertical: CarliSpace.s4),
                        child: TextField(
                          controller: _title,
                          autofocus: template == null && widget.seed.title.isEmpty,
                          textCapitalization: TextCapitalization.sentences,
                          onChanged: (_) => setState(() {}),
                          style: CarliType.title2.copyWith(fontSize: 20, color: colors.text),
                          decoration: const InputDecoration(
                            hintText: 'Título',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                          ),
                        ),
                      ),
                      FormRow(label: 'Lista', value: listName, onTap: _pickList),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16),
                        child: TextField(
                          controller: _notes,
                          maxLines: null,
                          textCapitalization: TextCapitalization.sentences,
                          style: CarliType.body.copyWith(color: colors.text),
                          decoration: const InputDecoration(
                            hintText: 'Notas',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: CarliSpace.s20),
                  const FormEyebrow('Frecuencia'),
                  const SizedBox(height: CarliSpace.s8),
                  CarliSegmented<FrequencyKind>(
                    segments: const [
                      CarliSegment(FrequencyKind.schedule, 'En fechas fijas'),
                      CarliSegment(FrequencyKind.afterDone, 'Tras completarla'),
                    ],
                    value: _frequency.kind,
                    onChanged: (kind) => _updateFrequency(_frequency.copyWith(kind: kind)),
                  ),
                  const SizedBox(height: CarliSpace.s8),
                  TaskGroup(
                    indent: CarliSpace.s16,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(CarliSpace.s16),
                        child: _frequency.afterDone
                            ? Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Días después de hacerla',
                                      style: CarliType.body.copyWith(color: colors.text),
                                    ),
                                  ),
                                  CountStepper(
                                    value: _frequency.afterDoneDays,
                                    label: '${_frequency.afterDoneDays}',
                                    semanticName: 'días',
                                    max: 3650,
                                    onChanged: (days) => _updateFrequency(_frequency.copyWith(afterDoneDays: days)),
                                  ),
                                ],
                              )
                            : _ScheduleEditor(frequency: _frequency, onChanged: _updateFrequency),
                      ),
                      FormRow(label: 'Hora', value: _time ?? 'Sin hora', onTap: _pickTime),
                    ],
                  ),
                  const SizedBox(height: CarliSpace.s8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s4),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        _previewError ?? (summary.isEmpty ? ' ' : capitalize(summary)),
                        style: CarliType.bodyStrong.copyWith(
                          color: _previewError == null ? colors.text : colors.negative,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: CarliSpace.s20),
                  FormEyebrow(_frequency.afterDone ? 'Si la haces hoy' : 'Próximas fechas'),
                  const SizedBox(height: CarliSpace.s8),
                  TaskGroup(
                    indent: CarliSpace.s16,
                    children: [
                      if (_preview == null)
                        const Padding(padding: EdgeInsets.all(CarliSpace.s16), child: TasksSkeleton(rows: 1))
                      else if (_preview!.dates.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(CarliSpace.s16),
                          child: Text('No hay fechas próximas.', style: CarliType.body.copyWith(color: colors.text2)),
                        )
                      else
                        for (final date in _preview!.dates)
                          FormRow(label: weekdayShortDate(date), value: relativeDistance(date)),
                    ],
                  ),
                  const SizedBox(height: CarliSpace.s20),
                  const FormEyebrow('Si no la completas'),
                  const SizedBox(height: CarliSpace.s8),
                  if (_frequency.afterDone)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s4),
                      child: Text(
                        'Con “Tras completarla” nunca hay dos abiertas: la siguiente se calcula al hacerla u omitirla.',
                        style: CarliType.small.copyWith(color: colors.text2),
                      ),
                    )
                  else
                    TaskGroup(
                      indent: CarliSpace.s16,
                      children: [
                        for (final policy in TemplatePolicy.values)
                          _PolicyOption(
                            policy: policy,
                            selected: policy == _policy,
                            onTap: () => setState(() => _policy = policy),
                          ),
                      ],
                    ),
                  const SizedBox(height: CarliSpace.s20),
                  const FormEyebrow('Subtareas'),
                  const SizedBox(height: CarliSpace.s8),
                  TaskGroup(
                    indent: CarliSpace.s16,
                    children: [
                      for (final (index, subtask) in _subtasks.indexed)
                        FormRow(
                          label: subtask,
                          chevron: false,
                          trailing: CarliButton.icon(
                            icon: carliIconNamed('x'),
                            semanticLabel: 'Quitar $subtask',
                            size: CarliButtonSize.sm,
                            onPressed: () => setState(() => _subtasks = [..._subtasks]..removeAt(index)),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16),
                        child: TextField(
                          controller: _subtaskDraft,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _addSubtask(),
                          style: CarliType.body.copyWith(color: colors.text),
                          decoration: const InputDecoration(
                            hintText: 'Añadir subtarea',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: CarliSpace.s20),
                  TaskGroup(
                    indent: CarliSpace.s16,
                    children: [
                      FormRow(label: 'Aparece', value: _leadLabel(_leadDays), onTap: _pickLead),
                      FormRow(label: 'Empieza', value: taskDueLabel(_start), onTap: _pickStart),
                      FormRow(label: 'Termina', value: _endingLabel, onTap: _pickEnding),
                      if (_ending == TemplateEnding.count)
                        FormRow(
                          label: 'Veces',
                          chevron: false,
                          trailing: CountStepper(
                            value: _count,
                            label: '$_count',
                            semanticName: 'veces',
                            max: 10000,
                            onChanged: (count) {
                              setState(() => _count = count);
                              _schedulePreview();
                            },
                          ),
                        ),
                      FormRow(
                        label: 'Importante',
                        chevron: false,
                        trailing: CarliSwitch(
                          value: _important,
                          semanticLabel: 'Importante',
                          onChanged: (value) => setState(() => _important = value),
                        ),
                      ),
                      const FormRow(label: 'Aviso a la hora', value: 'Próximamente', chevron: false),
                    ],
                  ),
                  if (template != null) ...[
                    const SizedBox(height: CarliSpace.s20),
                    _TemplateHistoryCard(templateId: template.id),
                    const SizedBox(height: CarliSpace.s20),
                    if (ref.watch(habitsEnabledProvider) && canConvertToHabit(rrule: template.rrule)) ...[
                      CarliButton(
                        label: 'Convertir en hábito',
                        variant: CarliButtonVariant.secondary,
                        icon: carliIconNamed('repeat'),
                        onPressed: () => showConvertTemplateSheet(context, templateId: template.id),
                      ),
                      const SizedBox(height: CarliSpace.s8),
                    ],
                    CarliButton(
                      label: template.paused ? 'Reanudar plantilla' : 'Pausar plantilla',
                      variant: CarliButtonVariant.secondary,
                      onPressed: _togglePaused,
                    ),
                    const SizedBox(height: CarliSpace.s8),
                    CarliButton(label: 'Borrar plantilla', variant: CarliButtonVariant.danger, onPressed: _delete),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleEditor extends StatelessWidget {
  const _ScheduleEditor({required this.frequency, required this.onChanged});

  final FrequencyDraft frequency;
  final ValueChanged<FrequencyDraft> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: CarliSpace.s16,
      children: [
        Wrap(
          spacing: CarliSpace.s8,
          runSpacing: CarliSpace.s8,
          children: [
            for (final unit in FrequencyUnit.values)
              CarliChip(
                label: unit.label,
                selected: unit == frequency.unit,
                onTap: () => onChanged(frequency.copyWith(unit: unit)),
              ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: Text('Cada', style: CarliType.body.copyWith(color: colors.text)),
            ),
            CountStepper(
              value: frequency.interval,
              label: frequency.intervalLabel,
              semanticName: 'intervalo',
              max: 99,
              onChanged: (interval) => onChanged(frequency.copyWith(interval: interval)),
            ),
          ],
        ),
        if (frequency.unit != FrequencyUnit.daily)
          switch (frequency.unit) {
            FrequencyUnit.daily => const SizedBox.shrink(),
            FrequencyUnit.weekly => _WeekdayPicker(
              selected: frequency.weekdays,
              onToggle: (day) => onChanged(frequency.toggleWeekday(day)),
            ),
            FrequencyUnit.monthly => _MonthlyEditor(frequency: frequency, onChanged: onChanged),
            FrequencyUnit.yearly => _YearlyEditor(frequency: frequency, onChanged: onChanged),
          },
      ],
    );
  }
}

class _WeekdayPicker extends StatelessWidget {
  const _WeekdayPicker({required this.selected, required this.onToggle});

  final Set<int> selected;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      for (var day = 1; day <= 7; day++)
        RoundToggle(
          label: weekdaysMondayFirstShort[day - 1],
          semanticLabel: weekdaysLong[day - 1],
          selected: selected.contains(day),
          onTap: () => onToggle(day),
        ),
    ],
  );
}

class _MonthlyEditor extends StatelessWidget {
  const _MonthlyEditor({required this.frequency, required this.onChanged});

  final FrequencyDraft frequency;
  final ValueChanged<FrequencyDraft> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: CarliSpace.s12,
      children: [
        CarliSegmented<MonthlyMode>(
          segments: const [
            CarliSegment(MonthlyMode.dayOfMonth, 'Día del mes'),
            CarliSegment(MonthlyMode.lastDay, 'Último día'),
            CarliSegment(MonthlyMode.weekdayPosition, 'Día de semana'),
          ],
          value: frequency.monthlyMode,
          onChanged: (mode) => onChanged(frequency.copyWith(monthlyMode: mode)),
        ),
        switch (frequency.monthlyMode) {
          MonthlyMode.dayOfMonth => Row(
            children: [
              Expanded(
                child: Text('Día', style: CarliType.body.copyWith(color: colors.text)),
              ),
              CountStepper(
                value: frequency.monthDay,
                label: '${frequency.monthDay}',
                semanticName: 'día',
                max: 31,
                onChanged: (day) => onChanged(frequency.copyWith(monthDay: day)),
              ),
            ],
          ),
          MonthlyMode.lastDay => const SizedBox.shrink(),
          MonthlyMode.weekdayPosition => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: CarliSpace.s12,
            children: [
              Wrap(
                spacing: CarliSpace.s8,
                runSpacing: CarliSpace.s8,
                children: [
                  for (final (position, label) in monthPositions)
                    CarliChip(
                      label: label,
                      selected: frequency.position == position,
                      onTap: () => onChanged(frequency.copyWith(position: position)),
                    ),
                ],
              ),
              _WeekdayPicker(
                selected: {frequency.positionWeekday},
                onToggle: (day) => onChanged(frequency.copyWith(positionWeekday: day)),
              ),
            ],
          ),
        },
      ],
    );
  }
}

class _YearlyEditor extends StatelessWidget {
  const _YearlyEditor({required this.frequency, required this.onChanged});

  final FrequencyDraft frequency;
  final ValueChanged<FrequencyDraft> onChanged;

  Future<void> _pickMonth(BuildContext context) async {
    final picked = await pickCarliOption<int>(
      context,
      title: 'Mes',
      value: frequency.yearMonth,
      options: [for (var month = 1; month <= 12; month++) CarliOption(month, capitalize(monthsLong[month - 1]))],
    );
    if (picked != null) onChanged(frequency.copyWith(yearMonth: picked.$1));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      spacing: CarliSpace.s12,
      children: [
        CarliChip(
          icon: carliIconNamed('calendar'),
          label: capitalize(monthsLong[frequency.yearMonth - 1]),
          onTap: () => _pickMonth(context),
        ),
        const Spacer(),
        Text('Día', style: CarliType.body.copyWith(color: colors.text)),
        CountStepper(
          value: frequency.monthDay,
          label: '${frequency.monthDay}',
          semanticName: 'día',
          max: 31,
          onChanged: (day) => onChanged(frequency.copyWith(monthDay: day)),
        ),
      ],
    );
  }
}

class _PolicyOption extends StatelessWidget {
  const _PolicyOption({required this.policy, required this.selected, required this.onTap});

  final TemplatePolicy policy;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16, vertical: CarliSpace.s12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: CarliSpace.s12,
            children: [
              Container(
                width: 20,
                height: 20,
                margin: const EdgeInsets.only(top: 1),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: selected ? colors.text : colors.text3, width: selected ? 6 : 1.5),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Text(policy.label, style: CarliType.bodyStrong.copyWith(color: colors.text)),
                    Text(policy.hint, style: CarliType.small.copyWith(color: colors.text2)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TemplateHistoryCard extends ConsumerWidget {
  const _TemplateHistoryCard({required this.templateId});

  final String templateId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final history = ref.watch(templateHistoryProvider(templateId)).value;
    if (history == null || history.items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: CarliSpace.s8,
      children: [
        FormEyebrow(history.streakLabel ?? 'Historial'),
        TaskGroup(
          indent: CarliSpace.s16,
          children: [
            for (final entry in history.items.take(10))
              FormRow(
                label: weekdayShortDate(entry.date),
                value: switch ((entry.status, entry.skipReason)) {
                  (TaskStatus.done, _) => 'Hecha',
                  (TaskStatus.open, _) => 'Abierta',
                  (_, 'manual') => 'Saltada',
                  (_, 'replaced') => 'Sustituida',
                  _ => 'No hecha',
                },
                trailing: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: entry.status == TaskStatus.done ? colors.positive : colors.border,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
