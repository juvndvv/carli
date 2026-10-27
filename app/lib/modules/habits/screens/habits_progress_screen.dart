import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/dates.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../ui/async_view.dart';
import '../../../ui/card.dart';
import '../../../ui/page.dart';
import '../../../ui/pressable.dart';
import '../../../ui/ring.dart';
import '../../../ui/segmented.dart';
import '../../tasks/ui/tasks_skeleton.dart';
import '../data/habits_format.dart';
import '../data/habits_models.dart';
import '../data/habits_providers.dart';
import '../habits_paths.dart';
import '../ui/day_dot.dart';
import '../ui/habit_ring.dart';

class HabitsProgressScreen extends ConsumerStatefulWidget {
  const HabitsProgressScreen({super.key});

  @override
  ConsumerState<HabitsProgressScreen> createState() => _HabitsProgressScreenState();
}

class _HabitsProgressScreenState extends ConsumerState<HabitsProgressScreen> {
  var _range = ProgressRange.week;

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(habitsProgressProvider(_range));
    return CarliPage(
      title: 'Progreso',
      onRefresh: () async {
        ref.invalidate(habitsProgressProvider(_range));
        await ref.read(habitsProgressProvider(_range).future).then((_) {}, onError: (_) {});
      },
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: CarliSpace.s16,
              children: [
                CarliSegmented<ProgressRange>(
                  segments: [for (final range in ProgressRange.values) CarliSegment(range, range.label)],
                  value: _range,
                  onChanged: (range) => setState(() => _range = range),
                ),
                AsyncView(
                  value: progress,
                  errorTitle: 'No se ha podido cargar el progreso',
                  onRetry: () => ref.invalidate(habitsProgressProvider(_range)),
                  loading: const TasksSkeleton(),
                  data: (progress) => _ProgressBody(progress: progress),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

String _eyebrow(HabitsProgress progress) => switch (progress.range) {
  ProgressRange.week =>
    'SEMANA ${isoWeek(progress.from)} · ${formatShortDate(progress.from)} – ${formatShortDate(progress.to)}'
        .toUpperCase(),
  ProgressRange.month => '${monthsLong[progress.from.month - 1]} ${progress.from.year}'.toUpperCase(),
  ProgressRange.year => '${progress.from.year}',
};

String _previousLabel(ProgressRange range) => switch (range) {
  ProgressRange.week => 'la semana anterior',
  ProgressRange.month => 'el mes anterior',
  ProgressRange.year => 'el año anterior',
};

class _ProgressBody extends StatelessWidget {
  const _ProgressBody({required this.progress});

  final HabitsProgress progress;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ranking = [...progress.rows.where((row) => row.consistency != null)]
      ..sort((a, b) => b.consistency!.compareTo(a.consistency!));
    final trend = progress.trend;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: CarliSpace.s16,
      children: [
        Text(_eyebrow(progress), style: CarliType.eyebrow.copyWith(color: colors.text2)),
        CarliCard(
          child: Row(
            spacing: CarliSpace.s16,
            children: [
              CarliRings(
                rings: [CarliRingValue((progress.consistency ?? 0) / 100, habitRingColor(context))],
                size: 88,
                stroke: 14,
                semanticLabel: 'Constancia global ${habitPercent(progress.consistency)}',
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Text('Constancia global', style: CarliType.eyebrow.copyWith(color: colors.text2)),
                    Text(habitPercent(progress.consistency), style: CarliType.display.copyWith(color: colors.text)),
                    if (trend != null)
                      Text(
                        trend == 0
                            ? 'Igual que ${_previousLabel(progress.range)}'
                            : '${trend > 0 ? '↑' : '↓'} ${trend.abs()} puntos frente a ${_previousLabel(progress.range)}',
                        style: CarliType.small.copyWith(color: colors.text2),
                      ),
                    Text(
                      '${progress.met} de ${progress.total} periodos cumplidos',
                      style: CarliType.small.copyWith(color: colors.text2),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (progress.rows.isNotEmpty) _Grid(progress: progress),
        if (ranking.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s4),
            child: Semantics(
              header: true,
              child: Text('Por constancia', style: CarliType.title2.copyWith(fontSize: 20, color: colors.text)),
            ),
          ),
          CarliCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final (index, row) in ranking.indexed) ...[
                  if (index > 0) Divider(height: 1, indent: 16, color: colors.border),
                  Semantics(
                    button: true,
                    label:
                        '${row.name}, ${habitPercent(row.consistency)}${row.trend == null ? '' : ', ${habitTrend(row.trend)}'}',
                    excludeSemantics: true,
                    child: Pressable(
                      onTap: () => context.push(HabitsPaths.habit(row.id)),
                      pressedOpacity: 0.6,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16, vertical: 11),
                        child: Row(
                          spacing: CarliSpace.s12,
                          children: [
                            Expanded(
                              child: Text(row.name, style: CarliType.body.copyWith(color: colors.text)),
                            ),
                            Text(
                              habitTrend(row.trend),
                              style: CarliType.money(CarliType.small).copyWith(color: colors.text2),
                            ),
                            SizedBox(
                              width: 52,
                              child: Text(
                                habitPercent(row.consistency),
                                textAlign: TextAlign.right,
                                style: CarliType.money(CarliType.bodyStrong).copyWith(color: colors.text),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.progress});

  final HabitsProgress progress;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final year = progress.range == ProgressRange.year;
    final columns = year ? 12 : progress.rows.first.cells.length;
    final cell = switch (progress.range) {
      ProgressRange.week => 18.0,
      _ => 8.0,
    };
    final headers = switch (progress.range) {
      ProgressRange.week => weekdaysMondayFirstShort,
      ProgressRange.month => [for (var day = 1; day <= columns; day++) day == 1 || day % 5 == 0 ? '$day' : ''],
      ProgressRange.year => [for (final month in monthsShort) month.substring(0, 1).toUpperCase()],
    };
    final title = switch (progress.range) {
      ProgressRange.week => 'Esta semana',
      ProgressRange.month => 'Este mes',
      ProgressRange.year => 'Por meses',
    };
    final week = progress.range == ProgressRange.week;
    Widget gridRow(Widget leading, List<Widget> cells) => Row(
      children: [
        if (week) Expanded(child: leading) else SizedBox(width: 84, child: leading),
        for (final cellWidget in cells)
          week ? SizedBox(width: 26, child: Center(child: cellWidget)) : Expanded(child: Center(child: cellWidget)),
      ],
    );
    return CarliCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: CarliSpace.s8,
        children: [
          Text(title, style: CarliType.bodyStrong.copyWith(color: colors.text)),
          ExcludeSemantics(
            child: gridRow(const SizedBox.shrink(), [
              for (final header in headers)
                Text(
                  header,
                  style: CarliType.caption.copyWith(fontSize: 10, color: colors.text2),
                  maxLines: 1,
                  softWrap: false,
                ),
            ]),
          ),
          for (final row in progress.rows)
            Semantics(
              label: '${row.name}: ${row.met} de ${row.total} cumplidos',
              excludeSemantics: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: gridRow(
                  Padding(
                    padding: const EdgeInsets.only(right: CarliSpace.s8),
                    child: Text(
                      row.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CarliType.small.copyWith(color: colors.text),
                    ),
                  ),
                  year
                      ? [
                          for (final value in row.monthCells)
                            Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: value == null
                                    ? colors.surface2
                                    : habitRingColor(context).withValues(alpha: 0.15 + 0.85 * value / 100),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                        ]
                      : [for (final day in row.cells) DayDot(state: day.state, size: cell, square: true)],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
