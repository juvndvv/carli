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
import '../../tasks/ui/tasks_skeleton.dart';
import '../data/habit_actions.dart';
import '../data/habits_format.dart';
import '../data/habits_models.dart';
import '../data/habits_providers.dart';
import '../habits_paths.dart';
import '../ui/day_dot.dart';
import '../ui/habit_break_sheet.dart';

const _manyHabits = 7;
const _dotColumn = 18.0;
const _pctColumn = 44.0;

class HabitsListScreen extends ConsumerStatefulWidget {
  const HabitsListScreen({super.key});

  @override
  ConsumerState<HabitsListScreen> createState() => _HabitsListScreenState();
}

class _HabitsListScreenState extends ConsumerState<HabitsListScreen> {
  var _showPaused = false;
  var _showArchived = false;
  var _reordering = false;

  @override
  Widget build(BuildContext context) {
    final habits = ref.watch(habitsListProvider);
    final now = today();
    return CarliPage(
      title: 'Hábitos',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CarliButton.icon(
            icon: carliIconNamed(_reordering ? 'check' : 'arrow-left-right'),
            semanticLabel: _reordering ? 'Terminar de ordenar' : 'Ordenar hábitos',
            size: CarliButtonSize.sm,
            onPressed: () => setState(() => _reordering = !_reordering),
          ),
          CarliButton.icon(
            icon: carliIconNamed('moon'),
            semanticLabel: 'Modo descanso',
            size: CarliButtonSize.sm,
            onPressed: () => showHabitBreakSheet(context),
          ),
        ],
      ),
      onRefresh: () async {
        ref.invalidate(habitsListProvider);
        await ref.read(habitsListProvider.future).then((_) {}, onError: (_) {});
      },
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16),
          sliver: SliverToBoxAdapter(
            child: AsyncView(
              value: habits,
              errorTitle: 'No se han podido cargar los hábitos',
              onRetry: () => ref.invalidate(habitsListProvider),
              loading: const TasksSkeleton(),
              data: (items) {
                final active = [
                  for (final item in items)
                    if (item.habit.status == HabitStatus.active) item,
                ];
                final paused = [
                  for (final item in items)
                    if (item.habit.status == HabitStatus.paused) item,
                ];
                final archived = [
                  for (final item in items)
                    if (item.habit.status == HabitStatus.archived) item,
                ];
                final colors = context.colors;
                if (items.isEmpty) {
                  return CarliCard(
                    child: CarliEmptyState(
                      icon: carliIconNamed('repeat'),
                      title: 'Sin hábitos todavía',
                      message: 'Lo que importa aquí es la constancia, no la fecha. Empieza por uno o dos.',
                      actionLabel: 'Nuevo hábito',
                      onAction: () => context.push(HabitsPaths.create),
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: CarliSpace.s16,
                  children: [
                    Text(
                      '${active.length == 1 ? '1 ACTIVO' : '${active.length} ACTIVOS'} · SEMANA ${isoWeek(now)}',
                      style: CarliType.eyebrow.copyWith(color: colors.text2),
                    ),
                    if (active.isNotEmpty)
                      _reordering
                          ? _ReorderList(items: active)
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              spacing: CarliSpace.s4,
                              children: [
                                const _WeekHeader(),
                                _HabitTable(items: active),
                              ],
                            ),
                    if (active.length >= _manyHabits)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s4),
                        child: Text(
                          'Tienes ${active.length} hábitos activos. Con menos es más fácil mantenerlos: pausa alguno si te pesan.',
                          style: CarliType.small.copyWith(color: colors.text2),
                        ),
                      ),
                    if (paused.isNotEmpty || archived.isNotEmpty)
                      CarliCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (paused.isNotEmpty) ...[
                              _Fold(
                                label: 'Pausados · ${paused.length}',
                                open: _showPaused,
                                onTap: () => setState(() => _showPaused = !_showPaused),
                              ),
                              if (_showPaused) _HabitTable(items: paused, flat: true),
                            ],
                            if (paused.isNotEmpty && archived.isNotEmpty)
                              Divider(height: 1, indent: 16, color: colors.border),
                            if (archived.isNotEmpty) ...[
                              _Fold(
                                label: 'Archivados · ${archived.length}',
                                open: _showArchived,
                                onTap: () => setState(() => _showArchived = !_showArchived),
                              ),
                              if (_showArchived) _HabitTable(items: archived, flat: true),
                            ],
                          ],
                        ),
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

class _WeekHeader extends StatelessWidget {
  const _WeekHeader();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final weekday = DateTime.now().weekday;
    return ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16),
        child: Row(
          spacing: 6,
          children: [
            const Spacer(),
            for (var day = 1; day <= 7; day++)
              SizedBox(
                width: _dotColumn,
                child: Text(
                  weekdaysMondayFirstShort[day - 1],
                  textAlign: TextAlign.center,
                  style: CarliType.caption.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: day == weekday ? colors.brandInk : colors.text2,
                  ),
                ),
              ),
            SizedBox(
              width: _pctColumn,
              child: Text(
                '4 sem',
                textAlign: TextAlign.right,
                style: CarliType.caption.copyWith(fontSize: 11, fontWeight: FontWeight.w600, color: colors.text2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HabitTable extends StatelessWidget {
  const _HabitTable({required this.items, this.flat = false});

  final List<HabitListItem> items;
  final bool flat;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final rows = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, item) in items.indexed) ...[
          if (index > 0 || flat) Divider(height: 1, indent: 16, color: colors.border),
          _HabitRow(item: item),
        ],
      ],
    );
    return flat ? rows : CarliCard(padding: EdgeInsets.zero, child: rows);
  }
}

class _HabitRow extends StatelessWidget {
  const _HabitRow({required this.item});

  final HabitListItem item;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final habit = item.habit;
    final goal = habit.isAvoid ? 'Evitar · ${habit.goalText.toLowerCase()}' : habit.goalText;
    return Semantics(
      button: true,
      label: '${habit.name}, $goal, constancia ${habitPercent(item.consistency)}',
      excludeSemantics: true,
      child: Pressable(
        onTap: () => context.push(HabitsPaths.habit(habit.id)),
        pressedOpacity: 0.6,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16, vertical: CarliSpace.s12),
          child: Row(
            spacing: 6,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Text(
                      habit.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CarliType.bodyStrong.copyWith(color: colors.text),
                    ),
                    Text(
                      goal,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CarliType.caption.copyWith(color: colors.text2),
                    ),
                  ],
                ),
              ),
              for (final cell in item.week)
                SizedBox(
                  width: _dotColumn,
                  child: DayDot(state: cell.state),
                ),
              SizedBox(
                width: _pctColumn,
                child: Text(
                  habitPercent(item.consistency),
                  textAlign: TextAlign.right,
                  style: CarliType.money(CarliType.bodyStrong).copyWith(color: colors.text),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReorderList extends ConsumerStatefulWidget {
  const _ReorderList({required this.items});

  final List<HabitListItem> items;

  @override
  ConsumerState<_ReorderList> createState() => _ReorderListState();
}

class _ReorderListState extends ConsumerState<_ReorderList> {
  late var _items = [...widget.items];

  @override
  void didUpdateWidget(_ReorderList oldWidget) {
    super.didUpdateWidget(oldWidget);
    _items = [...widget.items];
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return CarliCard(
      padding: EdgeInsets.zero,
      child: ReorderableListView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        onReorderItem: (from, to) {
          setState(() => _items.insert(to, _items.removeAt(from)));
          ref.read(habitActionsProvider).reorder([for (final item in _items) item.habit.id]);
        },
        children: [
          for (final (index, item) in _items.indexed)
            ReorderableDragStartListener(
              key: ValueKey(item.habit.id),
              index: index,
              child: Container(
                color: colors.surface,
                padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16, vertical: CarliSpace.s12),
                child: Row(
                  spacing: CarliSpace.s12,
                  children: [
                    CarliIcon(carliIconNamed(item.habit.icon), size: 18, color: colors.text),
                    Expanded(
                      child: Text(item.habit.name, style: CarliType.body.copyWith(color: colors.text)),
                    ),
                    CarliIcon(carliIconNamed('menu'), size: 18, color: colors.text3),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Fold extends StatelessWidget {
  const _Fold({required this.label, required this.open, required this.onTap});

  final String label;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      expanded: open,
      child: Pressable(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16, vertical: CarliSpace.s12),
          child: Row(
            children: [
              Expanded(
                child: Text(label, style: CarliType.body.copyWith(color: colors.text2)),
              ),
              CarliIcon(carliIconNamed(open ? 'chevron-up' : 'chevron-down'), size: 16, color: colors.text2),
            ],
          ),
        ),
      ),
    );
  }
}
