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
import '../../tasks/ui/task_group.dart';
import '../../tasks/ui/tasks_skeleton.dart';
import '../data/habit_actions.dart';
import '../data/habits_format.dart';
import '../data/habits_models.dart';
import '../data/habits_providers.dart';
import '../habits_paths.dart';
import '../ui/habit_break_sheet.dart';
import '../ui/habit_ring.dart';
import '../ui/habit_ring_strip.dart';

class HabitsTodayScreen extends ConsumerWidget {
  const HabitsTodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayView = ref.watch(habitsTodayProvider);
    return CarliPage(
      title: 'Hoy',
      trailing: CarliButton.icon(
        icon: carliIconNamed('settings'),
        semanticLabel: 'Ajustes de Hábitos',
        size: CarliButtonSize.sm,
        onPressed: () => context.push(HabitsPaths.settings),
      ),
      onRefresh: () async {
        ref.invalidate(habitsTodayProvider);
        await ref.read(habitsTodayProvider.future).then((_) {}, onError: (_) {});
      },
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16),
          sliver: SliverToBoxAdapter(
            child: AsyncView(
              value: todayView,
              errorTitle: 'No se han podido cargar los hábitos',
              onRetry: () => ref.invalidate(habitsTodayProvider),
              loading: const TasksSkeleton(),
              data: (view) => _TodayBody(view: view),
            ),
          ),
        ),
      ],
    );
  }
}

class _TodayBody extends StatelessWidget {
  const _TodayBody({required this.view});

  final HabitsTodayView view;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final pending = view.pending;
    final avoid = view.avoid;
    final done = view.completed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: CarliSpace.s20,
      children: [
        Text(formatLongDate(view.date), style: CarliType.small.copyWith(color: colors.text2)),
        if (view.onBreak) const _BreakBanner(),
        if (view.habits.isEmpty && !view.onBreak)
          CarliCard(
            child: CarliEmptyState(
              icon: carliIconNamed('repeat'),
              title: 'Nada para hoy',
              message: 'Crea un hábito con el botón + y lo verás aquí cada día que toque.',
              actionLabel: 'Nuevo hábito',
              onAction: () => context.push(HabitsPaths.create),
            ),
          ),
        if (view.total > 0) _SummaryCard(view: view),
        if (pending.isNotEmpty)
          _Section(
            title: 'Por hacer',
            child: Column(
              spacing: CarliSpace.s8,
              children: [for (final habit in pending) _HabitCard(habit: habit)],
            ),
          ),
        if (avoid.isNotEmpty)
          _Section(
            title: 'Evitar',
            child: TaskGroup(indent: 56, children: [for (final habit in avoid) _AvoidRow(habit: habit)]),
          ),
        if (done.isNotEmpty)
          _Section(
            title: 'Hechos',
            child: TaskGroup(indent: 56, children: [for (final habit in done) _DoneRow(habit: habit)]),
          ),
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

class _BreakBanner extends ConsumerWidget {
  const _BreakBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final current = ref.watch(habitBreaksProvider).value?.where((pause) => pause.global && pause.active).firstOrNull;
    return CarliCard(
      onTap: () => showHabitBreakSheet(context),
      child: Row(
        spacing: CarliSpace.s12,
        children: [
          CarliIcon(carliIconNamed('moon'), size: 22, color: colors.text),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Modo descanso', style: CarliType.bodyStrong.copyWith(color: colors.text)),
                Text(
                  current == null
                      ? 'Hoy no se evalúa ningún hábito.'
                      : 'Hasta el ${current.to.day} de ${monthsLong[current.to.month - 1]}. No se evalúa nada.',
                  style: CarliType.small.copyWith(color: colors.text2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.view});

  final HabitsTodayView view;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return CarliCard(
      child: Row(
        spacing: CarliSpace.s16,
        children: [
          CarliRings(
            rings: [CarliRingValue(view.total == 0 ? 0 : view.done / view.total, habitRingColor(context))],
            size: 64,
            stroke: 10,
            semanticLabel: '${view.done} de ${view.total} hábitos cumplidos hoy',
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${view.done} de ${view.total}', style: CarliType.metric.copyWith(color: colors.text)),
                Text('hábitos cumplidos hoy', style: CarliType.small.copyWith(color: colors.text2)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(habitPercent(view.consistency), style: CarliType.money(CarliType.h2).copyWith(color: colors.text)),
              Text('constancia', style: CarliType.caption.copyWith(color: colors.text2)),
            ],
          ),
        ],
      ),
    );
  }
}

class _HabitCard extends ConsumerWidget {
  const _HabitCard({required this.habit});

  final HabitToday habit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    return CarliCard(
      padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s12, vertical: CarliSpace.s12),
      child: Row(
        spacing: CarliSpace.s12,
        children: [
          HabitRingButton(
            icon: habit.habit.icon,
            progress: habit.progress,
            label: 'Registrar ${habit.habit.name}, ${habitValueLabel(habit)}',
            onTap: () => ref.read(habitActionsProvider).tap(habit),
            onLongPress: () => openHabitLogSheet(context, habit),
          ),
          Expanded(
            child: Pressable(
              onTap: () => context.push(HabitsPaths.habit(habit.id)),
              pressedOpacity: 0.6,
              child: Row(
                spacing: CarliSpace.s8,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 2,
                      children: [
                        Text(habit.habit.name, style: CarliType.h2.copyWith(color: colors.text)),
                        Text(habitGoalLine(habit), style: CarliType.small.copyWith(color: colors.text2)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    spacing: 2,
                    children: [
                      Text(
                        habitValueLabel(habit),
                        style: CarliType.money(CarliType.bodyStrong).copyWith(color: colors.text),
                      ),
                      Text(
                        habitStreakLabel(habit.streak, habit.period),
                        style: CarliType.caption.copyWith(color: colors.text2),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvoidRow extends ConsumerWidget {
  const _AvoidRow({required this.habit});

  final HabitToday habit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final unit = habit.habit.unit?.trim() ?? '';
    final singular = unit.endsWith('s') ? unit.substring(0, unit.length - 1) : unit;
    final relapse = habit.target <= 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s12, vertical: CarliSpace.s8),
      child: Row(
        spacing: CarliSpace.s12,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: colors.surface2, shape: BoxShape.circle),
            child: CarliIcon(carliIconNamed(habit.habit.icon), size: 16, color: colors.text),
          ),
          Expanded(
            child: Pressable(
              onTap: () => context.push(HabitsPaths.habit(habit.id)),
              pressedOpacity: 0.6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(habit.habit.name, style: CarliType.body.copyWith(color: colors.text)),
                  Text(habit.habit.goalText, style: CarliType.small.copyWith(color: colors.text2)),
                ],
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            spacing: CarliSpace.s4,
            children: [
              Text(
                habitValueLabel(habit),
                style: CarliType.money(CarliType.bodyStrong)
                    .copyWith(color: habit.over ? colors.negative : colors.text),
              ),
              CarliButton(
                label: relapse ? 'Registrar recaída' : (singular.isEmpty ? '+1' : '+1 $singular'),
                size: CarliButtonSize.sm,
                variant: CarliButtonVariant.ghost,
                block: false,
                onPressed: () => ref.read(habitActionsProvider).tap(habit),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DoneRow extends ConsumerWidget {
  const _DoneRow({required this.habit});

  final HabitToday habit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final canUndo = habit.todayValue > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s12, vertical: CarliSpace.s8),
      child: Row(
        spacing: CarliSpace.s12,
        children: [
          Semantics(
            button: canUndo,
            label: canUndo ? 'Desmarcar ${habit.habit.name}' : '${habit.habit.name}, hecho',
            excludeSemantics: true,
            child: Pressable(
              onTap: canUndo
                  ? () => habit.habit.kind == HabitKind.check
                        ? ref.read(habitActionsProvider).tap(habit)
                        : openHabitLogSheet(context, habit)
                  : null,
              child: Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: habitRingColor(context), shape: BoxShape.circle),
                child: CarliIcon(carliIconNamed('check'), size: 16, color: colors.onPrimary, strokeWidth: 2.4),
              ),
            ),
          ),
          Expanded(
            child: Pressable(
              onTap: () => context.push(HabitsPaths.habit(habit.id)),
              pressedOpacity: 0.6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(habit.habit.name, style: CarliType.body.copyWith(color: colors.text)),
                  Text(habitGoalLine(habit), style: CarliType.small.copyWith(color: colors.text2)),
                ],
              ),
            ),
          ),
          Text(habitStreakLabel(habit.streak, habit.period), style: CarliType.small.copyWith(color: colors.text2)),
        ],
      ),
    );
  }
}
