import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../ui/async_view.dart';
import '../../../ui/button.dart';
import '../../../ui/field.dart';
import '../../../ui/icon.dart';
import '../../../ui/icon_names.dart';
import '../../../ui/list_item.dart';
import '../../../ui/page.dart';
import '../../../ui/sheet.dart';
import '../data/task_actions.dart';
import '../data/tasks_models.dart';
import '../data/tasks_providers.dart';
import '../ui/task_group.dart';
import '../ui/tasks_routes.dart';
import '../ui/tasks_skeleton.dart';

Future<String?> askListName(BuildContext context, {String initial = '', String title = 'Nueva lista'}) {
  final controller = TextEditingController(text: initial);
  return showCarliSheet<String>(
    context,
    title: title,
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(CarliSpace.s16, 0, CarliSpace.s16, CarliSpace.s16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: CarliSpace.s12,
        children: [
          CarliInput(
            controller: controller,
            placeholder: 'Casa, Personal, Compra…',
            autofocus: true,
            onSubmitted: (value) => Navigator.pop(context, value.trim()),
          ),
          CarliButton(label: 'Guardar', onPressed: () => Navigator.pop(context, controller.text.trim())),
        ],
      ),
    ),
  ).whenComplete(controller.dispose);
}

class ListsScreen extends ConsumerWidget {
  const ListsScreen({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final name = await askListName(context);
    if (name != null && name.isNotEmpty) await ref.read(taskActionsProvider).createList(name);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lists = ref.watch(taskListsProvider);
    final colors = context.colors;
    return CarliPage(
      title: 'Listas',
      trailing: CarliButton.icon(
        icon: carliIconNamed('plus'),
        semanticLabel: 'Nueva lista',
        size: CarliButtonSize.sm,
        onPressed: () => _create(context, ref),
      ),
      onRefresh: () async {
        ref.invalidate(taskListsProvider);
        await ref.read(taskListsProvider.future).then((_) {}, onError: (_) {});
      },
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16),
          sliver: SliverToBoxAdapter(
            child: AsyncView(
              value: lists,
              errorTitle: 'No se han podido cargar las listas',
              onRetry: () => ref.invalidate(taskListsProvider),
              loading: const TasksSkeleton(),
              data: (lists) {
                final inbox = lists.where((list) => list.isDefault).toList();
                final own = lists.where((list) => !list.isDefault).toList();
                final open = lists.fold(0, (total, list) => total + list.openCount);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: CarliSpace.s20,
                  children: [
                    Text(
                      open == 1 ? '1 abierta' : '$open abiertas',
                      style: CarliType.small.copyWith(color: colors.text2),
                    ),
                    if (inbox.isNotEmpty)
                      TaskGroup(
                        indent: 68,
                        children: [for (final list in inbox) _ListRow(list: list, subtitle: 'Lo apuntado sin lista')],
                      ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: CarliSpace.s8,
                      children: [
                        CarliSectionHeader(
                          title: 'Mis listas',
                          actionLabel: own.length > 1 ? 'Ordenar' : null,
                          onAction: () => _reorder(context, ref, own),
                        ),
                        if (own.isEmpty)
                          TaskGroup(
                            children: [
                              CarliListItem(
                                title: 'Crear una lista',
                                subtitle: 'Agrupa tareas de casa, trabajo o la compra',
                                icon: carliIconNamed('plus'),
                                onTap: () => _create(context, ref),
                              ),
                            ],
                          )
                        else
                          TaskGroup(indent: 68, children: [for (final list in own) _ListRow(list: list)]),
                      ],
                    ),
                    TaskGroup(
                      indent: 68,
                      children: [
                        CarliListItem(
                          title: 'Hechas',
                          subtitle: 'Registro de lo completado',
                          icon: carliIconNamed('check-circle'),
                          trailing: CarliIcon(carliIconNamed('chevron-right'), size: 16, color: colors.text3),
                          onTap: () => context.push(TasksRoutes.list('hechas')),
                        ),
                        CarliListItem(
                          title: 'Archivadas',
                          icon: carliIconNamed('archive'),
                          trailing: CarliIcon(carliIconNamed('chevron-right'), size: 16, color: colors.text3),
                          onTap: () => context.push(TasksRoutes.list('archivadas')),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _reorder(BuildContext context, WidgetRef ref, List<TaskList> lists) async {
    final order = await showCarliSheet<List<String>>(
      context,
      title: 'Ordenar listas',
      scrollable: true,
      builder: (context) => _ReorderLists(lists: lists),
    );
    if (order != null) await ref.read(taskActionsProvider).reorderLists(order);
  }
}

class _ListRow extends StatelessWidget {
  const _ListRow({required this.list, this.subtitle});

  final TaskList list;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return CarliListItem(
      title: list.name,
      subtitle: subtitle,
      icon: carliIconNamed(list.icon ?? (list.isDefault ? 'inbox' : 'list')),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: CarliSpace.s8,
        children: [
          Text('${list.openCount}', style: CarliType.money(CarliType.body).copyWith(color: colors.text2)),
          CarliIcon(carliIconNamed('chevron-right'), size: 16, color: colors.text3),
        ],
      ),
      onTap: () => context.push(TasksRoutes.list(list.id)),
    );
  }
}

class _ReorderLists extends StatefulWidget {
  const _ReorderLists({required this.lists});

  final List<TaskList> lists;

  @override
  State<_ReorderLists> createState() => _ReorderListsState();
}

class _ReorderListsState extends State<_ReorderLists> {
  late final _lists = [...widget.lists];

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Flexible(
        child: ReorderableListView(
          shrinkWrap: true,
          buildDefaultDragHandles: true,
          onReorderItem: (from, to) => setState(() => _lists.insert(to, _lists.removeAt(from))),
          children: [
            for (final list in _lists)
              CarliListItem(key: ValueKey(list.id), title: list.name, icon: carliIconNamed('menu')),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(CarliSpace.s16),
        child: CarliButton(
          label: 'Guardar orden',
          onPressed: () => Navigator.pop(context, [for (final list in _lists) list.id]),
        ),
      ),
    ],
  );
}
