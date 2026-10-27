import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/dates.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../ui/async_view.dart';
import '../../../ui/button.dart';
import '../../../ui/card.dart';
import '../../../ui/icon.dart';
import '../../../ui/icon_names.dart';
import '../../../ui/page.dart';
import '../../../ui/pressable.dart';
import '../../../ui/sheet.dart';
import '../../../ui/switch.dart';
import '../../tasks/ui/form_rows.dart';
import '../../tasks/ui/task_group.dart';
import '../../tasks/ui/tasks_skeleton.dart';
import '../data/habit_actions.dart';
import '../data/habits_format.dart';
import '../data/habits_models.dart';
import '../data/habits_providers.dart';
import '../habits_paths.dart';
import '../ui/habit_break_sheet.dart';
import '../ui/habit_log_sheet.dart';
import '../ui/habit_ring.dart';

class HabitDetailScreen extends ConsumerWidget {
  const HabitDetailScreen({super.key, required this.habitId});

  final String habitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(habitDetailProvider(habitId));
    return CarliPage(
      title: detail.value?.habit.name ?? 'Hábito',
      bottomInset: CarliSpace.s32,
      trailing: detail.value == null
          ? null
          : TextButton(onPressed: () => context.push(HabitsPaths.edit(habitId)), child: const Text('Editar')),
      onRefresh: () async {
        ref.read(habitActionsProvider).changed();
        await ref.read(habitDetailProvider(habitId).future).then((_) {}, onError: (_) {});
      },
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16),
          sliver: SliverToBoxAdapter(
            child: AsyncView(
              value: detail,
              errorTitle: 'No se ha podido cargar el hábito',
              onRetry: () => ref.invalidate(habitDetailProvider(habitId)),
              loading: const TasksSkeleton(),
              data: (detail) => _DetailBody(detail: detail),
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.detail});

  final HabitDetail detail;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmCarli(
      context,
      title: 'Borrar ${detail.habit.name}',
      message: 'Se borra el hábito con todo su historial. Si solo quieres dejarlo, archívalo.',
      confirmLabel: 'Borrar',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    if (await ref.read(habitActionsProvider).delete(detail.habit) && context.mounted) context.pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final habit = detail.habit;
    final actions = ref.read(habitActionsProvider);
    final period = habit.goal.period;
    final best = detail.bestStreakEnd;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: CarliSpace.s16,
      children: [
        Row(
          spacing: CarliSpace.s12,
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: colors.surface2, borderRadius: BorderRadius.circular(CarliRadius.md)),
              child: CarliIcon(carliIconNamed(habit.icon), size: 22, color: colors.text),
            ),
            Expanded(
              child: Text(
                '${habit.isAvoid ? 'Evitar · ' : ''}${habit.goalText} · ${habitSince(habit.startDate)}'
                '${habit.status == HabitStatus.paused
                    ? ' · pausado'
                    : habit.status == HabitStatus.archived
                    ? ' · archivado'
                    : ''}',
                style: CarliType.small.copyWith(color: colors.text2),
              ),
            ),
          ],
        ),
        CarliCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 13,
                child: _Stat(
                  label: 'Constancia',
                  value: habitPercent(detail.consistency),
                  caption: 'últimas 4 semanas',
                  large: true,
                ),
              ),
              Expanded(
                flex: 10,
                child: _Stat(
                  label: habit.isAvoid ? 'Sin pasarte' : 'Racha',
                  value: habitStreakLength(detail.streak, period),
                  caption: 'en curso',
                ),
              ),
              Expanded(
                flex: 10,
                child: _Stat(
                  label: 'Mejor',
                  value: habitStreakLength(detail.bestStreak, period),
                  caption: best == null ? '—' : monthsLong[best.month - 1],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s4),
          child: Text(
            'Desde el inicio: ${habitPercent(detail.consistencyAll)}',
            style: CarliType.small.copyWith(color: colors.text2),
          ),
        ),
        _MonthCalendar(habit: habit, today: detail.today),
        if (habit.goal.period == GoalPeriod.week || habit.kind == HabitKind.quantity || detail.weeks.isNotEmpty)
          _WeekBars(detail: detail),
        TaskGroup(
          indent: CarliSpace.s16,
          children: [
            if (!habit.isAvoid)
              FormRow(
                label: 'Mostrar en Hoy de Tareas',
                chevron: false,
                trailing: CarliSwitch(
                  value: habit.showInTasks,
                  semanticLabel: 'Mostrar en Hoy de Tareas',
                  onChanged: (value) => actions.setShowInTasks(habit, value),
                ),
              ),
            FormRow(
              label: 'Descanso de este hábito',
              onTap: () => showHabitBreakSheet(context, habit: habit),
            ),
            if (habit.status != HabitStatus.archived)
              FormRow(
                label: habit.status == HabitStatus.paused ? 'Reanudar' : 'Pausar',
                chevron: false,
                onTap: () => actions.transition(habit, habit.status == HabitStatus.paused ? 'resume' : 'pause'),
              ),
            FormRow(
              label: habit.status == HabitStatus.archived ? 'Desarchivar' : 'Archivar',
              chevron: false,
              onTap: () => actions.transition(habit, habit.status == HabitStatus.archived ? 'unarchive' : 'archive'),
            ),
          ],
        ),
        CarliButton(label: 'Borrar hábito', variant: CarliButtonVariant.danger, onPressed: () => _delete(context, ref)),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.caption, this.large = false});

  final String label;
  final String value;
  final String caption;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 2,
      children: [
        Text(label, style: CarliType.eyebrow.copyWith(color: colors.text2)),
        SizedBox(
          height: 40,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style:
                  (large ? CarliType.display : CarliType.money(CarliType.title2.copyWith(fontWeight: FontWeight.w600)))
                      .copyWith(color: colors.text),
            ),
          ),
        ),
        Text(caption, style: CarliType.caption.copyWith(color: colors.text2)),
      ],
    );
  }
}

class _MonthCalendar extends ConsumerStatefulWidget {
  const _MonthCalendar({required this.habit, this.today});

  final Habit habit;
  final HabitToday? today;

  @override
  ConsumerState<_MonthCalendar> createState() => _MonthCalendarState();
}

class _MonthCalendarState extends ConsumerState<_MonthCalendar> {
  late DateTime _month = DateTime(today().year, today().month);

  Habit get _habit => widget.habit;

  void _open(CalendarDay day) {
    if (day.state == DayState.future || day.state == DayState.none) return;
    if (_habit.kind == HabitKind.check) {
      ref.read(habitActionsProvider).log(_habit, day.value, day.value > 0 ? 0 : 1, date: day.date, note: day.note);
      return;
    }
    showHabitLogSheet(
      context,
      habit: _habit,
      date: day.date,
      value: day.value,
      target: _habit.goal.target,
      note: day.note,
      canChangeDay: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final days = ref.watch(habitCalendarProvider((_habit.id, _month)));
    final current = DateTime(today().year, today().month);
    final first = DateTime(_habit.startDate.year, _habit.startDate.month);
    final blanks = _month.weekday - 1;
    Widget arrow(String icon, String label, DateTime? target) => CarliButton.icon(
      icon: carliIconNamed(icon),
      semanticLabel: label,
      size: CarliButtonSize.sm,
      onPressed: target == null ? null : () => setState(() => _month = target),
    );

    return CarliCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: CarliSpace.s12,
        children: [
          Row(
            children: [
              arrow('chevron-left', 'Mes anterior', _month.isAfter(first) ? addMonths(_month, -1) : null),
              Expanded(
                child: Text(
                  '${capitalize(monthsLong[_month.month - 1])} ${_month.year}',
                  textAlign: TextAlign.center,
                  style: CarliType.h2.copyWith(color: colors.text),
                ),
              ),
              arrow('chevron-right', 'Mes siguiente', _month.isBefore(current) ? addMonths(_month, 1) : null),
            ],
          ),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 6,
            childAspectRatio: 1,
            children: [
              for (final label in weekdaysMondayFirstShort)
                Center(
                  child: ExcludeSemantics(
                    child: Text(label, style: CarliType.caption.copyWith(fontSize: 11, color: colors.text2)),
                  ),
                ),
              for (var blank = 0; blank < blanks; blank++) const SizedBox.shrink(),
              for (final day in days.value ?? const <CalendarDay>[]) _CalendarCell(day: day, onTap: () => _open(day)),
            ],
          ),
          ExcludeSemantics(
            child: Wrap(
              spacing: CarliSpace.s16,
              runSpacing: CarliSpace.s4,
              children: [
                _Legend(color: habitRingColor(context), label: 'Hecho'),
                _Legend(border: colors.text3, label: 'No hecho'),
                _Legend(color: colors.surface2, label: 'Descanso'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarCell extends StatelessWidget {
  const _CalendarCell({required this.day, required this.onTap});

  final CalendarDay day;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ember = habitRingColor(context);
    final (background, border, foreground) = switch (day.state) {
      DayState.done => (ember, null, colors.onPrimary),
      DayState.miss => (null, Border.all(color: colors.text3, width: 1.5), colors.text),
      DayState.today => (null, Border.all(color: ember, width: 2), colors.text),
      DayState.rest => (colors.surface2, null, colors.text2),
      _ => (null, null, colors.text3),
    };
    final tappable = day.state != DayState.future && day.state != DayState.none;
    return Semantics(
      button: tappable,
      label:
          '${day.date.day} de ${monthsLong[day.date.month - 1]}, ${day.state.label}'
          '${day.value > 0 ? ', ${habitNumber(day.value)}' : ''}',
      excludeSemantics: true,
      child: Pressable(
        onTap: tappable ? onTap : null,
        child: Center(
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: background, border: border, shape: BoxShape.circle),
            child: Text(
              '${day.date.day}',
              style: CarliType.small.copyWith(
                color: foreground,
                fontWeight: day.state == DayState.today || day.state == DayState.done ? FontWeight.w700 : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.label, this.color, this.border});

  final String label;
  final Color? color;
  final Color? border;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    spacing: 5,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: border == null ? null : Border.all(color: border!, width: 1.5),
        ),
      ),
      Text(label, style: CarliType.caption.copyWith(color: context.colors.text2)),
    ],
  );
}

class _WeekBars extends StatelessWidget {
  const _WeekBars({required this.detail});

  final HabitDetail detail;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final habit = detail.habit;
    final weekly = habit.goal.period == GoalPeriod.week;
    final title = switch (habit.kind) {
      HabitKind.quantity =>
        habit.unit == null || habit.unit!.isEmpty ? 'Por semana' : '${capitalize(habit.unit!)} por semana',
      HabitKind.check when weekly => 'Veces por semana',
      _ => 'Días por semana',
    };
    final top = detail.weeks.fold<double>(
      1,
      (max, week) => [max, week.value, week.target].reduce((a, b) => a > b ? a : b),
    );
    final first = detail.weeks.firstOrNull?.start;
    return CarliCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: CarliSpace.s12,
        children: [
          Text(title, style: CarliType.bodyStrong.copyWith(color: colors.text)),
          SizedBox(
            height: 96,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              spacing: CarliSpace.s8,
              children: [
                for (final week in detail.weeks)
                  Expanded(
                    child: Semantics(
                      label:
                          'Semana del ${week.start.day} de ${monthsLong[week.start.month - 1]}: '
                          '${habitNumber(week.value)} de ${habitNumber(week.target)}',
                      excludeSemantics: true,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        spacing: CarliSpace.s4,
                        children: [
                          Text(
                            habitNumber(week.value),
                            style: CarliType.caption.copyWith(fontSize: 11, color: colors.text2),
                          ),
                          Container(
                            height: (week.value / top * 64).clamp(4, 64).toDouble(),
                            decoration: BoxDecoration(
                              color: week.target > 0 && week.value + 0.001 >= week.target
                                  ? habitRingColor(context)
                                  : colors.text,
                              borderRadius: BorderRadius.circular(CarliRadius.sm),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (first != null)
            ExcludeSemantics(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(formatShortDate(first), style: CarliType.caption.copyWith(fontSize: 11, color: colors.text2)),
                  Text('esta semana', style: CarliType.caption.copyWith(fontSize: 11, color: colors.text2)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
