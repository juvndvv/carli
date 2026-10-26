import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../ui/icon.dart';
import '../../../ui/icon_names.dart';
import '../../../ui/pressable.dart';
import '../data/quick_dates.dart';
import '../data/task_actions.dart';
import '../data/tasks_models.dart';
import 'postpone_sheet.dart';
import 'task_check.dart';

enum TaskRowDate { hidden, relative }

String taskMeta(TaskItem task, {TaskRowDate date = TaskRowDate.hidden, bool showList = true}) => [
  if (date == TaskRowDate.relative && task.dueDate != null && !task.overdue) taskDueLabel(task.dueDate!),
  if (showList) task.list.name,
  ?task.dueTime,
  if (task.subtasks.isNotEmpty) '${task.subtasksDone}/${task.subtasks.length}',
].join(' · ');

class TaskRow extends ConsumerWidget {
  const TaskRow({
    super.key,
    required this.task,
    this.onOpen,
    this.date = TaskRowDate.hidden,
    this.showList = true,
    this.swipeToPostpone = true,
  });

  final TaskItem task;
  final VoidCallback? onOpen;
  final TaskRowDate date;
  final bool showList;
  final bool swipeToPostpone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final actions = ref.read(taskActionsProvider);
    final meta = taskMeta(task, date: date, showList: showList);
    final row = Pressable(
      onTap: onOpen,
      pressedOpacity: 0.6,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(CarliSpace.s8, CarliSpace.s4, CarliSpace.s16, CarliSpace.s4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TaskCheck(done: task.isDone, onTap: () => actions.toggle(task), label: _checkLabel),
            const SizedBox(width: CarliSpace.s4),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: CarliSpace.s8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Text(
                      task.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: CarliType.body.copyWith(
                        color: task.isDone ? colors.text2 : colors.text,
                        decoration: task.isDone ? TextDecoration.lineThrough : null,
                        decorationColor: colors.text3,
                      ),
                    ),
                    if (meta.isNotEmpty || task.overdue || task.repeats)
                      Row(
                        spacing: CarliSpace.s4,
                        children: [
                          if (task.repeats)
                            Semantics(
                              label: 'Se repite',
                              child: CarliIcon(carliIconNamed('repeat'), size: 13, color: colors.text2),
                            ),
                          if (task.overdue && task.dueDate != null)
                            Text(
                              taskDueLabel(task.dueDate!),
                              style: CarliType.small.copyWith(color: colors.negative, fontWeight: FontWeight.w600),
                            ),
                          if (task.overdue && meta.isNotEmpty)
                            Text('·', style: CarliType.small.copyWith(color: colors.text2)),
                          Flexible(
                            child: Text(
                              meta,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: CarliType.small.copyWith(color: colors.text2),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            if (task.important)
              Padding(
                padding: const EdgeInsets.only(top: CarliSpace.s12, left: CarliSpace.s8),
                child: Semantics(
                  label: 'Importante',
                  child: CarliIcon(carliIconNamed('flag'), size: 16, color: colors.brandInk),
                ),
              ),
          ],
        ),
      ),
    );
    if (!swipeToPostpone || !task.isOpen) return row;
    return Dismissible(
      key: ValueKey('swipe-${task.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        final date = await showPostponeSheet(context, from: task.dueDate, includeToday: task.overdue);
        if (date != null) await actions.postpone(task, date);
        return false;
      },
      background: Container(
        color: colors.warningSoft,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: CarliSpace.s20),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: CarliSpace.s8,
          children: [
            CarliIcon(carliIconNamed('calendar'), size: 18, color: colors.warning),
            Text(
              'Posponer',
              style: CarliType.small.copyWith(color: colors.warning, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
      child: row,
    );
  }

  String get _checkLabel => task.isDone ? 'Desmarcar ${task.title}' : 'Marcar ${task.title} como hecha';
}

class OccurrenceRow extends ConsumerWidget {
  const OccurrenceRow({super.key, required this.occurrence, this.onOpen});

  final TaskOccurrence occurrence;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final meta = [occurrence.frequencyText, occurrence.list.name, ?occurrence.dueTime].join(' · ');
    return Semantics(
      label: '${occurrence.title}, programada',
      child: Pressable(
        onTap: onOpen,
        pressedOpacity: 0.6,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(CarliSpace.s16, CarliSpace.s12, CarliSpace.s16, CarliSpace.s12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: CarliSpace.s12,
            children: [
              const Padding(padding: EdgeInsets.only(top: 1), child: TaskCheck(done: false, planned: true)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Text(occurrence.title, style: CarliType.body.copyWith(color: colors.text2)),
                    Row(
                      spacing: CarliSpace.s4,
                      children: [
                        CarliIcon(carliIconNamed('repeat'), size: 13, color: colors.text2),
                        Flexible(
                          child: Text(
                            meta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: CarliType.small.copyWith(color: colors.text2),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s8, vertical: 3),
                decoration: BoxDecoration(
                  color: colors.surface2,
                  borderRadius: BorderRadius.circular(CarliRadius.chip),
                ),
                child: Text('Programada', style: CarliType.caption.copyWith(color: colors.text2)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
