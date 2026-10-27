import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../ui/card.dart';
import '../../../ui/icon.dart';
import '../../../ui/icon_names.dart';
import '../../../ui/pressable.dart';
import '../data/habits_providers.dart';
import '../habits_paths.dart';
import 'habit_ring_strip.dart';

/// The "Hábitos" row in Tareas · Hoy. Habits are not tasks: they never count in "3 de 7" nor go overdue.
class HabitsTasksRow extends ConsumerWidget {
  const HabitsTasksRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(habitsForTasksProvider);
    if (habits.isEmpty) return const SizedBox.shrink();
    final colors = context.colors;
    return CarliCard(
      padding: const EdgeInsets.fromLTRB(CarliSpace.s16, CarliSpace.s12, CarliSpace.s16, CarliSpace.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: CarliSpace.s8,
        children: [
          Semantics(
            button: true,
            hint: 'Abrir Hábitos',
            child: Pressable(
              onTap: () => context.go(HabitsPaths.today),
              pressedOpacity: 0.6,
              child: Row(
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        text: 'Hábitos',
                        style: CarliType.bodyStrong.copyWith(color: colors.text),
                        children: [
                          TextSpan(
                            text: ' · ${habits.length == 1 ? 'queda 1' : 'quedan ${habits.length}'}',
                            style: CarliType.body.copyWith(color: colors.text2),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Text('Ver todos', style: CarliType.small.copyWith(color: colors.brandInk)),
                  CarliIcon(carliIconNamed('chevron-right'), size: 14, color: colors.brandInk),
                ],
              ),
            ),
          ),
          HabitRingStrip(habits: habits),
        ],
      ),
    );
  }
}
