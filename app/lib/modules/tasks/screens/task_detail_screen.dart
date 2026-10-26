import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/dates.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../ui/async_view.dart';
import '../../../ui/button.dart';
import '../../../ui/icon.dart';
import '../../../ui/icon_names.dart';
import '../../../ui/pressable.dart';
import '../../../ui/sheet.dart';
import '../../../ui/switch.dart';
import '../../finance/data/json.dart';
import '../data/quick_dates.dart';
import '../data/task_actions.dart';
import '../data/tasks_models.dart';
import '../data/tasks_providers.dart';
import '../ui/form_rows.dart';
import '../ui/pickers.dart';
import '../ui/postpone_sheet.dart';
import '../ui/task_check.dart';
import '../ui/task_group.dart';
import '../ui/tasks_routes.dart';
import '../ui/tasks_skeleton.dart';

class TaskDetailScreen extends ConsumerWidget {
  const TaskDetailScreen({super.key, required this.taskId});

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final task = ref.watch(taskProvider(taskId));
    return Scaffold(
      appBar: AppBar(title: const Text('Tarea')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          CarliSpace.s16,
          CarliSpace.s8,
          CarliSpace.s16,
          CarliSpace.s40 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          AsyncView(
            value: task,
            errorTitle: 'No se ha podido cargar la tarea',
            onRetry: () => ref.invalidate(taskProvider(taskId)),
            loading: const TasksSkeleton(rows: 3),
            data: (task) => _TaskDetail(key: ValueKey(task.id), task: task),
          ),
        ],
      ),
    );
  }
}

class _TaskDetail extends ConsumerStatefulWidget {
  const _TaskDetail({super.key, required this.task});

  final TaskItem task;

  @override
  ConsumerState<_TaskDetail> createState() => _TaskDetailState();
}

class _TaskDetailState extends ConsumerState<_TaskDetail> {
  late final _title = TextEditingController(text: widget.task.title);
  late final _notes = TextEditingController(text: widget.task.notes ?? '');
  final _subtaskDraft = TextEditingController();

  TaskItem get _task => widget.task;

  TaskActions get _actions => ref.read(taskActionsProvider);

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _subtaskDraft.dispose();
    super.dispose();
  }

  Future<void> _update(Json input) => _actions.update(_task.id, input);

  void _saveText() {
    final title = _title.text.trim();
    final notes = _notes.text.trim();
    final input = <String, Object?>{
      if (title.isNotEmpty && title != _task.title) 'title': title,
      if (notes != (_task.notes ?? '')) 'notes': notes.isEmpty ? null : notes,
    };
    if (input.isNotEmpty) _update(input);
  }

  Future<void> _pickDate() async {
    final picked = await showCarliSheet<Object>(
      context,
      title: 'Fecha',
      builder: (context) => Padding(
        padding: const EdgeInsets.only(bottom: CarliSpace.s16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in QuickDate.values)
              FormRow(label: option.label, chevron: false, onTap: () => Navigator.pop(context, option)),
            FormRow(label: 'Elegir fecha', onTap: () => Navigator.pop(context, 'pick')),
          ],
        ),
      ),
    );
    if (!mounted) return;
    final date = switch (picked) {
      QuickDate.none => null,
      final QuickDate option => option.resolve(),
      'pick' => await pickTaskDate(context, initial: _task.dueDate),
      _ => _task.dueDate,
    };
    if (picked == null || (picked == 'pick' && date == null)) return;
    await _update({'due_date': date == null ? null : isoDate(date)});
  }

  Future<void> _pickTime() async {
    final picked = await pickTaskTime(context, initial: _task.dueTime);
    if (picked == null) return;
    await _update({
      if (_task.dueDate == null && picked.$1 != null) 'due_date': isoDate(today()),
      'due_time': picked.$1,
    });
  }

  Future<void> _pickList() async {
    final lists = await ref.read(taskListsProvider.future);
    if (!mounted) return;
    final picked = await pickTaskList(context, lists: lists, current: _task.list.id);
    if (picked != null && picked != _task.list.id) await _update({'list_id': picked});
  }

  Future<void> _postpone() async {
    final date = await showPostponeSheet(context, from: _task.dueDate, includeToday: _task.overdue);
    if (date != null) await _actions.postpone(_task, date);
  }

  Future<void> _skip() async {
    final skipped = await _actions.skip(_task);
    if (skipped && mounted) context.pop();
  }

  Future<void> _delete() async {
    final confirmed = await confirmCarli(
      context,
      title: 'Borrar “${_task.title}”',
      confirmLabel: 'Borrar',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final deleted = await _actions.delete(_task);
    if (deleted && mounted) context.pop();
  }

  void _addSubtask() {
    final title = _subtaskDraft.text.trim();
    if (title.isEmpty) return;
    _subtaskDraft.clear();
    _actions.addSubtask(_task, title);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final task = _task;
    final template = task.template;
    final history = template == null ? null : ref.watch(templateHistoryProvider(template.id)).value;
    final nextDate = template == null
        ? null
        : ref.watch(taskTemplateProvider(template.id)).value?.upcomingDates.firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: CarliSpace.s16,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TaskCheck(done: task.isDone, size: 28, onTap: () => _actions.toggle(task)),
            Expanded(
              child: TextField(
                controller: _title,
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                onEditingComplete: _saveText,
                onTapOutside: (_) => _saveText(),
                style: CarliType.title2.copyWith(
                  color: task.isDone ? colors.text2 : colors.text,
                  decoration: task.isDone ? TextDecoration.lineThrough : null,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                ),
              ),
            ),
          ],
        ),
        if (task.status == TaskStatus.skipped)
          Text(
            'Omitida',
            style: CarliType.small.copyWith(color: colors.text2, fontWeight: FontWeight.w600),
          ),
        TaskGroup(
          indent: CarliSpace.s16,
          children: [
            FormRow(
              label: 'Fecha',
              value: task.dueDate == null
                  ? 'Sin fecha'
                  : '${taskDueLabel(task.dueDate!)}, ${weekdayShortDate(task.dueDate!)}',
              onTap: _pickDate,
            ),
            FormRow(label: 'Hora', value: task.dueTime ?? 'Sin hora', onTap: _pickTime),
            FormRow(label: 'Lista', value: task.list.name, onTap: _pickList),
            FormRow(
              label: 'Importante',
              chevron: false,
              trailing: CarliSwitch(
                value: task.important,
                semanticLabel: 'Importante',
                onChanged: (value) => _update({'important': value}),
              ),
            ),
          ],
        ),
        if (template != null)
          Pressable(
            onTap: () => context.push(TasksRoutes.template(template.id)),
            child: TaskGroup(
              children: [
                Padding(
                  padding: const EdgeInsets.all(CarliSpace.s16),
                  child: Row(
                    spacing: CarliSpace.s12,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: colors.surface2, shape: BoxShape.circle),
                        child: CarliIcon(carliIconNamed('repeat'), size: 18, color: colors.text),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(template.frequencyText, style: CarliType.bodyStrong.copyWith(color: colors.text)),
                            Text(
                              [
                                ?history?.streakLabel,
                                if (nextDate != null) 'siguiente ${weekdayShortDate(nextDate)}',
                                if (template.paused) 'pausada',
                              ].join(' · '),
                              style: CarliType.small.copyWith(color: colors.text2),
                            ),
                          ],
                        ),
                      ),
                      CarliIcon(carliIconNamed('chevron-right'), size: 16, color: colors.text3),
                    ],
                  ),
                ),
              ],
            ),
          ),
        FormEyebrow(
          task.subtasks.isEmpty ? 'Subtareas' : 'Subtareas · ${task.subtasksDone} de ${task.subtasks.length}',
        ),
        TaskGroup(
          children: [
            for (final subtask in task.subtasks)
              Dismissible(
                key: ValueKey(subtask.id),
                direction: DismissDirection.endToStart,
                onDismissed: (_) => _actions.deleteSubtask(task, subtask),
                background: Container(
                  color: colors.negativeSoft,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: CarliSpace.s20),
                  child: CarliIcon(carliIconNamed('trash'), size: 18, color: colors.negative),
                ),
                child: Row(
                  children: [
                    TaskCheck(
                      done: subtask.done,
                      size: 20,
                      label: subtask.done ? 'Desmarcar ${subtask.title}' : 'Marcar ${subtask.title}',
                      onTap: () => _actions.setSubtask(task, subtask, !subtask.done),
                    ),
                    Expanded(
                      child: Text(
                        subtask.title,
                        style: CarliType.body.copyWith(
                          color: subtask.done ? colors.text2 : colors.text,
                          decoration: subtask.done ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(left: 46, right: CarliSpace.s16),
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
        TaskGroup(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16),
              child: TextField(
                controller: _notes,
                maxLines: null,
                minLines: 2,
                textCapitalization: TextCapitalization.sentences,
                onTapOutside: (_) => _saveText(),
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
        if (task.isOpen)
          Row(
            spacing: CarliSpace.s8,
            children: [
              Expanded(
                child: CarliButton(label: 'Posponer', variant: CarliButtonVariant.secondary, onPressed: _postpone),
              ),
              Expanded(
                child: CarliButton(
                  label: template == null ? 'Omitir' : 'Saltar esta vez',
                  variant: CarliButtonVariant.secondary,
                  onPressed: _skip,
                ),
              ),
            ],
          ),
        CarliButton(label: 'Borrar tarea', variant: CarliButtonVariant.ghost, onPressed: _delete),
      ],
    );
  }
}
