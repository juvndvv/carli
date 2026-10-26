import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/dates.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../ui/async_view.dart';
import '../../../ui/card.dart';
import '../../../ui/empty_state.dart';
import '../../../ui/icon_names.dart';
import '../../../ui/list_item.dart';
import '../../../ui/page.dart';
import '../../../ui/sheet.dart';
import '../data/quick_dates.dart';
import '../data/task_actions.dart';
import '../data/tasks_models.dart';
import '../data/tasks_providers.dart';
import '../ui/task_group.dart';
import '../ui/task_row.dart';
import '../ui/tasks_routes.dart';
import '../ui/tasks_skeleton.dart';

String upcomingDayTitle(DateTime date, {DateTime? now}) => switch (daysBetween(today(now), date)) {
  0 => 'Hoy',
  1 => 'Mañana',
  _ => capitalize(weekdaysLong[date.weekday - 1]),
};

class UpcomingScreen extends ConsumerWidget {
  const UpcomingScreen({super.key});

  Future<void> _occurrenceActions(BuildContext context, WidgetRef ref, TaskOccurrence occurrence) async {
    final picked = await showCarliSheet<String>(
      context,
      title: occurrence.title,
      builder: (context) => Padding(
        padding: const EdgeInsets.only(bottom: CarliSpace.s16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CarliListItem(
              title: 'Saltar esta vez',
              subtitle: weekdayShortDate(occurrence.date),
              icon: carliIconNamed('rotate-ccw'),
              onTap: () => Navigator.pop(context, 'skip'),
            ),
            CarliListItem(
              title: 'Editar plantilla',
              subtitle: occurrence.frequencyText,
              icon: carliIconNamed('repeat'),
              onTap: () => Navigator.pop(context, 'edit'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    switch (picked) {
      case 'skip':
        await ref
            .read(taskActionsProvider)
            .skipOccurrence(occurrence.templateId, occurrence.date, title: occurrence.title);
      case 'edit':
        context.push(TasksRoutes.template(occurrence.templateId));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(tasksUpcomingProvider);
    final colors = context.colors;

    return CarliPage(
      title: 'Próximas',
      onRefresh: () async {
        ref.invalidate(tasksUpcomingProvider);
        await ref.read(tasksUpcomingProvider.future).then((_) {}, onError: (_) {});
      },
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16),
          sliver: SliverToBoxAdapter(
            child: AsyncView(
              value: days,
              errorTitle: 'No se ha podido cargar la agenda',
              onRetry: () => ref.invalidate(tasksUpcomingProvider),
              loading: const TasksSkeleton(),
              data: (days) {
                final busy = [
                  for (final day in days)
                    if (!day.isEmpty) day,
                ];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: CarliSpace.s20,
                  children: [
                    Text('Próximos 14 días', style: CarliType.small.copyWith(color: colors.text2)),
                    _WeekStrip(days: days.take(7).toList()),
                    if (busy.isEmpty)
                      CarliCard(
                        child: CarliEmptyState(
                          icon: carliIconNamed('calendar'),
                          title: 'Nada en las próximas dos semanas',
                          message: 'Las tareas con fecha y las plantillas que se repiten aparecerán aquí.',
                        ),
                      ),
                    for (final day in busy)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: CarliSpace.s8,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s4),
                            child: Semantics(
                              header: true,
                              child: Text.rich(
                                TextSpan(
                                  text: upcomingDayTitle(day.date),
                                  style: CarliType.title2.copyWith(fontSize: 20, color: colors.text),
                                  children: [
                                    TextSpan(
                                      text: '  ${formatShortDate(day.date)}',
                                      style: CarliType.body.copyWith(color: colors.text2),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          TaskGroup(
                            children: [
                              for (final task in day.tasks)
                                TaskRow(task: task, onOpen: () => context.push(TasksRoutes.task(task.id))),
                              for (final occurrence in day.occurrences)
                                OccurrenceRow(
                                  occurrence: occurrence,
                                  onOpen: () => _occurrenceActions(context, ref, occurrence),
                                ),
                            ],
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
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.days});

  final List<UpcomingDay> days;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final (index, day) in days.indexed)
          Semantics(
            label: '${formatLongDate(day.date)}${day.isEmpty ? '' : ', con tareas'}',
            excludeSemantics: true,
            child: Container(
              width: 44,
              padding: const EdgeInsets.symmetric(vertical: CarliSpace.s8),
              decoration: BoxDecoration(
                color: index == 0 ? colors.text : null,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                spacing: CarliSpace.s4,
                children: [
                  Text(
                    weekdaysMondayFirstShort[day.date.weekday - 1],
                    style: CarliType.caption.copyWith(color: index == 0 ? colors.bg : colors.text2),
                  ),
                  Text(
                    '${day.date.day}',
                    style: CarliType.money(CarliType.h2).copyWith(color: index == 0 ? colors.bg : colors.text),
                  ),
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: day.isEmpty ? null : (index == 0 ? colors.bg : colors.text3),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
