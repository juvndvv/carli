import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/dates.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../data/habit_actions.dart';
import '../data/habits_format.dart';
import '../data/habits_models.dart';
import 'habit_log_sheet.dart';
import 'habit_ring.dart';

void openHabitLogSheet(BuildContext context, HabitToday habit) => showHabitLogSheet(
  context,
  habit: habit.habit,
  date: today(),
  value: habit.todayValue,
  target: habit.weekly && habit.habit.kind != HabitKind.check ? habit.target : habit.habit.goal.target,
  note: habit.todayNote,
);

/// Compact rings to log without opening Hábitos: a tap marks or adds one, a long press opens the log sheet.
class HabitRingStrip extends ConsumerWidget {
  const HabitRingStrip({super.key, required this.habits});

  final List<HabitToday> habits;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: CarliSpace.s8,
        children: [
          for (final habit in habits)
            SizedBox(
              width: 72,
              child: Column(
                spacing: CarliSpace.s4,
                children: [
                  HabitRingButton(
                    icon: habit.habit.icon,
                    progress: habit.progress,
                    size: 52,
                    label: '${habit.habit.name}, ${habitValueLabel(habit)}. Registrar',
                    onTap: () => ref.read(habitActionsProvider).tap(habit),
                    onLongPress: () => openHabitLogSheet(context, habit),
                  ),
                  ExcludeSemantics(
                    child: Text(
                      habit.habit.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: CarliType.caption.copyWith(color: colors.text),
                    ),
                  ),
                  ExcludeSemantics(
                    child: Text(
                      habitValueLabel(habit),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: CarliType.caption.copyWith(color: colors.text2, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
