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
import '../../../ui/icon.dart';
import '../../../ui/icon_names.dart';
import '../../../ui/page.dart';
import '../../../ui/pressable.dart';
import '../../../ui/ring.dart';
import '../data/tasks_models.dart';
import '../data/tasks_providers.dart';
import '../ui/task_group.dart';
import '../ui/task_row.dart';
import '../ui/tasks_routes.dart';
import '../ui/tasks_skeleton.dart';
import 'new_task_sheet.dart';

class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  var _showDone = false;

  @override
  Widget build(BuildContext context) {
    final todayView = ref.watch(tasksTodayProvider);
    final showDoneSection = ref.watch(tasksSettingsProvider).showDoneInToday;

    return CarliPage(
      title: 'Hoy',
      trailing: CarliButton.icon(
        icon: carliIconNamed('settings'),
        semanticLabel: 'Ajustes de Tareas',
        size: CarliButtonSize.sm,
        onPressed: () => context.push(TasksRoutes.settings),
      ),
      onRefresh: () async {
        ref.invalidate(tasksTodayProvider);
        await ref.read(tasksTodayProvider.future).then((_) {}, onError: (_) {});
      },
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16),
          sliver: SliverToBoxAdapter(
            child: AsyncView(
              value: todayView,
              errorTitle: 'No se han podido cargar las tareas',
              onRetry: () => ref.invalidate(tasksTodayProvider),
              loading: const TasksSkeleton(),
              data: (view) => _TodayBody(
                view: view,
                showDone: _showDone,
                showDoneSection: showDoneSection,
                onToggleDone: () => setState(() => _showDone = !_showDone),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TodayBody extends StatelessWidget {
  const _TodayBody({
    required this.view,
    required this.showDone,
    required this.showDoneSection,
    required this.onToggleDone,
  });

  final TodayView view;
  final bool showDone;
  final bool showDoneSection;
  final VoidCallback onToggleDone;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    void open(TaskItem task) => context.push(TasksRoutes.task(task.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: CarliSpace.s20,
      children: [
        Text(formatLongDate(view.date), style: CarliType.small.copyWith(color: colors.text2)),
        if (view.total > 0 || view.overdue.isNotEmpty) TodayProgressCard(view: view),
        if (view.overdue.isNotEmpty)
          _Section(
            title: 'Vencidas',
            child: TaskGroup(
              children: [for (final task in view.overdue) TaskRow(task: task, onOpen: () => open(task))],
            ),
          ),
        _Section(
          title: 'Hoy',
          child: view.today.isEmpty
              ? CarliCard(
                  child: CarliEmptyState(
                    icon: carliIconNamed('check-circle'),
                    title: view.doneCount > 0 ? 'Todo hecho por hoy' : 'Nada para hoy',
                    message: view.doneCount > 0
                        ? 'Has terminado lo que tenías para hoy.'
                        : 'Apunta algo con el botón + o mira lo que viene en Próximas.',
                    actionLabel: 'Nueva tarea',
                    onAction: () => showNewTaskSheet(context),
                  ),
                )
              : TaskGroup(
                  children: [for (final task in view.today) TaskRow(task: task, onOpen: () => open(task))],
                ),
        ),
        if (showDoneSection && view.done.isNotEmpty) ...[
          Semantics(
            button: true,
            expanded: showDone,
            child: Pressable(
              onTap: onToggleDone,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Hechas hoy · ${view.done.length}',
                        style: CarliType.body.copyWith(color: colors.text2),
                      ),
                    ),
                    CarliIcon(carliIconNamed(showDone ? 'chevron-up' : 'chevron-down'), size: 16, color: colors.text2),
                  ],
                ),
              ),
            ),
          ),
          if (showDone)
            TaskGroup(
              children: [
                for (final task in view.done) TaskRow(task: task, onOpen: () => open(task), swipeToPostpone: false),
              ],
            ),
        ],
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: CarliSpace.s8,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s4),
        child: Semantics(
          header: true,
          child: Text(title, style: CarliType.title2.copyWith(fontSize: 20, color: context.colors.text)),
        ),
      ),
      child,
    ],
  );
}

class TodayProgressCard extends StatelessWidget {
  const TodayProgressCard({super.key, required this.view});

  final TodayView view;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final progress = view.total == 0 ? 0.0 : view.doneCount / view.total;
    final overdue = view.overdue.length;
    return CarliCard(
      child: Row(
        spacing: CarliSpace.s16,
        children: [
          CarliRings(
            rings: [CarliRingValue(progress, colors.rings.first)],
            size: 64,
            stroke: 10,
            semanticLabel: '${view.doneCount} de ${view.total} hechas hoy',
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${view.doneCount} de ${view.total}', style: CarliType.metric.copyWith(color: colors.text)),
                Text('hechas hoy', style: CarliType.small.copyWith(color: colors.text2)),
              ],
            ),
          ),
          if (overdue > 0)
            Text(
              overdue == 1 ? '1 vencida' : '$overdue vencidas',
              style: CarliType.small.copyWith(color: colors.negative, fontWeight: FontWeight.w600),
            ),
        ],
      ),
    );
  }
}
