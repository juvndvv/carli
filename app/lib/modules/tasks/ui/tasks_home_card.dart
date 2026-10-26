import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../ui/card.dart';
import '../../../ui/icon.dart';
import '../../../ui/icon_names.dart';
import '../../../ui/pressable.dart';
import '../../../ui/skeleton.dart';
import '../data/quick_dates.dart';
import '../data/task_actions.dart';
import '../data/tasks_models.dart';
import '../data/tasks_providers.dart';
import 'task_check.dart';

String tasksHomeHeadline(TodayView view) {
  final open = view.today.length;
  final parts = [
    switch (open) {
      0 when view.doneCount > 0 => 'Todo hecho por hoy',
      0 => 'Nada para hoy',
      1 => '1 tarea para hoy',
      _ => '$open tareas para hoy',
    },
    if (view.overdue.isNotEmpty) view.overdue.length == 1 ? '1 vencida' : '${view.overdue.length} vencidas',
  ];
  return parts.join(' · ');
}

class TasksHomeCard extends ConsumerWidget {
  const TasksHomeCard({super.key, required this.onOpen, required this.onOpenTask});

  final VoidCallback onOpen;
  final ValueChanged<TaskItem> onOpenTask;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final view = ref.watch(tasksTodayProvider);
    final value = view.value;
    final first = value == null ? const <TaskItem>[] : [...value.overdue, ...value.today].take(3).toList();

    return CarliCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            hint: 'Abrir Tareas',
            child: Pressable(
              onTap: onOpen,
              pressedOpacity: 0.7,
              child: Padding(
                padding: const EdgeInsets.all(CarliSpace.s16),
                child: Row(
                  spacing: CarliSpace.s12,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: colors.surface2, shape: BoxShape.circle),
                      child: CarliIcon(carliIconNamed('list-checks'), size: 18, color: colors.text),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Tareas', style: CarliType.h2.copyWith(color: colors.text)),
                          if (value != null)
                            Text(tasksHomeHeadline(value), style: CarliType.small.copyWith(color: colors.text2))
                          else if (view.hasError)
                            Text('No se han podido cargar', style: CarliType.small.copyWith(color: colors.text2))
                          else
                            const CarliSkeleton(width: 140, height: 12),
                        ],
                      ),
                    ),
                    CarliIcon(carliIconNamed('chevron-right'), size: 18, color: colors.text3),
                  ],
                ),
              ),
            ),
          ),
          if (first.isNotEmpty) ...[
            Divider(height: 1, color: colors.border),
            for (final task in first)
              Pressable(
                onTap: () => onOpenTask(task),
                pressedOpacity: 0.6,
                child: Padding(
                  padding: const EdgeInsets.only(left: CarliSpace.s8, right: CarliSpace.s16),
                  child: Row(
                    children: [
                      TaskCheck(
                        done: task.isDone,
                        label: 'Marcar ${task.title} como hecha',
                        onTap: () => ref.read(taskActionsProvider).complete(task),
                      ),
                      Expanded(
                        child: Text(
                          task.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: CarliType.body.copyWith(color: colors.text),
                        ),
                      ),
                      if (task.overdue && task.dueDate != null)
                        Text(
                          taskDueLabel(task.dueDate!),
                          style: CarliType.small.copyWith(color: colors.negative, fontWeight: FontWeight.w600),
                        )
                      else if (task.dueTime != null)
                        Text(task.dueTime!, style: CarliType.money(CarliType.small).copyWith(color: colors.text2)),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: CarliSpace.s4),
          ],
        ],
      ),
    );
  }
}
