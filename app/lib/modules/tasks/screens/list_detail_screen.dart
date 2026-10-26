import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/dates.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../ui/async_view.dart';
import '../../../ui/button.dart';
import '../../../ui/card.dart';
import '../../../ui/empty_state.dart';
import '../../../ui/icon_names.dart';
import '../../../ui/list_item.dart';
import '../../../ui/page.dart';
import '../../../ui/sheet.dart';
import '../data/task_actions.dart';
import '../data/tasks_models.dart';
import '../data/tasks_providers.dart';
import '../ui/task_group.dart';
import '../ui/task_row.dart';
import '../ui/tasks_routes.dart';
import '../ui/tasks_skeleton.dart';
import 'lists_screen.dart';
import 'new_task_sheet.dart';

const doneLogListId = 'hechas';
const archivedListsId = 'archivadas';

class ListDetailScreen extends ConsumerWidget {
  const ListDetailScreen({super.key, required this.listId});

  final String listId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => switch (listId) {
    doneLogListId => const _DoneLogScreen(),
    archivedListsId => const _ArchivedListsScreen(),
    _ => _ListScreen(listId: listId),
  };
}

enum _ListAction { rename, archive, delete }

class _ListScreen extends ConsumerWidget {
  const _ListScreen({required this.listId});

  final String listId;

  Future<void> _actions(BuildContext context, WidgetRef ref, TaskList list) async {
    final picked = await showCarliSheet<_ListAction>(
      context,
      title: list.name,
      builder: (context) => Padding(
        padding: const EdgeInsets.only(bottom: CarliSpace.s16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CarliListItem(
              title: 'Renombrar',
              icon: carliIconNamed('pencil'),
              onTap: () => Navigator.pop(context, _ListAction.rename),
            ),
            if (!list.isDefault) ...[
              CarliListItem(
                title: 'Archivar',
                icon: carliIconNamed('archive'),
                onTap: () => Navigator.pop(context, _ListAction.archive),
              ),
              CarliListItem(
                title: 'Borrar',
                subtitle: 'Solo si está vacía',
                icon: carliIconNamed('trash'),
                onTap: () => Navigator.pop(context, _ListAction.delete),
              ),
            ],
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    final actions = ref.read(taskActionsProvider);
    switch (picked) {
      case _ListAction.rename:
        final name = await askListName(context, initial: list.name, title: 'Renombrar lista');
        if (name != null && name.isNotEmpty) await actions.updateList(list.id, {'name': name});
      case _ListAction.archive:
        if (await actions.updateList(list.id, {'archived': true}) != null && context.mounted) context.pop();
      case _ListAction.delete:
        if (await actions.deleteList(list) && context.mounted) context.pop();
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(taskListsProvider).value?.where((list) => list.id == listId).firstOrNull;
    final tasks = ref.watch(listTasksProvider(listId));
    final colors = context.colors;
    return CarliPage(
      title: list?.name ?? 'Lista',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CarliButton.icon(
            icon: carliIconNamed('plus'),
            semanticLabel: 'Nueva tarea en esta lista',
            size: CarliButtonSize.sm,
            onPressed: () => showNewTaskSheet(context, listId: listId, date: null),
          ),
          if (list != null)
            CarliButton.icon(
              icon: carliIconNamed('ellipsis'),
              semanticLabel: 'Opciones de la lista',
              size: CarliButtonSize.sm,
              onPressed: () => _actions(context, ref, list),
            ),
        ],
      ),
      onRefresh: () async {
        ref.invalidate(listTasksProvider(listId));
        await ref.read(listTasksProvider(listId).future).then((_) {}, onError: (_) {});
      },
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16),
          sliver: SliverToBoxAdapter(
            child: AsyncView(
              value: tasks,
              errorTitle: 'No se han podido cargar las tareas',
              onRetry: () => ref.invalidate(listTasksProvider(listId)),
              loading: const TasksSkeleton(),
              data: (tasks) {
                if (tasks.isEmpty) {
                  return CarliCard(
                    child: CarliEmptyState(
                      icon: carliIconNamed('list-checks'),
                      title: 'Lista vacía',
                      message: 'Las tareas abiertas de esta lista aparecerán aquí, con o sin fecha.',
                      actionLabel: 'Nueva tarea',
                      onAction: () => showNewTaskSheet(context, listId: listId, date: null),
                    ),
                  );
                }
                final dated = tasks.where((task) => task.dueDate != null).toList();
                final undated = tasks.where((task) => task.dueDate == null).toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: CarliSpace.s16,
                  children: [
                    if (dated.isNotEmpty)
                      TaskGroup(
                        children: [
                          for (final task in dated)
                            TaskRow(
                              task: task,
                              date: TaskRowDate.relative,
                              showList: false,
                              onOpen: () => context.push(TasksRoutes.task(task.id)),
                            ),
                        ],
                      ),
                    if (undated.isNotEmpty) ...[
                      Text('Sin fecha', style: CarliType.eyebrow.copyWith(color: colors.text2)),
                      TaskGroup(
                        children: [
                          for (final task in undated)
                            TaskRow(task: task, showList: false, onOpen: () => context.push(TasksRoutes.task(task.id))),
                        ],
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _DoneLogScreen extends ConsumerWidget {
  const _DoneLogScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final done = ref.watch(doneTasksProvider(null));
    final colors = context.colors;
    return CarliPage(
      title: 'Hechas',
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16),
          sliver: SliverToBoxAdapter(
            child: AsyncView(
              value: done,
              errorTitle: 'No se ha podido cargar el registro',
              onRetry: () => ref.invalidate(doneTasksProvider(null)),
              loading: const TasksSkeleton(),
              data: (tasks) {
                if (tasks.isEmpty) {
                  return CarliCard(
                    child: CarliEmptyState(
                      icon: carliIconNamed('check-circle'),
                      title: 'Aún no has completado nada',
                      message: 'Lo que marques como hecho quedará registrado aquí.',
                    ),
                  );
                }
                final groups = <DateTime, List<TaskItem>>{};
                for (final task in tasks) {
                  groups.putIfAbsent(dateOnly(task.completedAt ?? DateTime.now()), () => []).add(task);
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: CarliSpace.s8,
                  children: [
                    for (final MapEntry(key: day, value: items) in groups.entries) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: CarliSpace.s8, left: CarliSpace.s4),
                        child: Text(
                          formatRelativeDay(day, style: RelativeDateStyle.title),
                          style: CarliType.eyebrow.copyWith(color: colors.text2),
                        ),
                      ),
                      TaskGroup(
                        children: [
                          for (final task in items)
                            TaskRow(
                              task: task,
                              swipeToPostpone: false,
                              onOpen: () => context.push(TasksRoutes.task(task.id)),
                            ),
                        ],
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _ArchivedListsScreen extends ConsumerWidget {
  const _ArchivedListsScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lists = ref.watch(archivedTaskListsProvider);
    return CarliPage(
      title: 'Archivadas',
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16),
          sliver: SliverToBoxAdapter(
            child: AsyncView(
              value: lists,
              errorTitle: 'No se han podido cargar las listas',
              onRetry: () => ref.invalidate(archivedTaskListsProvider),
              loading: const TasksSkeleton(rows: 2),
              data: (lists) => lists.isEmpty
                  ? CarliCard(
                      child: CarliEmptyState(
                        icon: carliIconNamed('archive'),
                        title: 'Nada archivado',
                        message: 'Las listas que archives quedan aquí y puedes recuperarlas.',
                      ),
                    )
                  : TaskGroup(
                      indent: 68,
                      children: [
                        for (final list in lists)
                          CarliListItem(
                            title: list.name,
                            icon: carliIconNamed('archive'),
                            trailing: CarliButton(
                              label: 'Recuperar',
                              size: CarliButtonSize.sm,
                              variant: CarliButtonVariant.secondary,
                              block: false,
                              onPressed: () => ref.read(taskActionsProvider).updateList(list.id, {'archived': false}),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
