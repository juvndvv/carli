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

/// Inicio card: "Hábitos · 3 de 5" and the rings still to do today, loggable in place.
class HabitsHomeCard extends ConsumerWidget {
  const HabitsHomeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(habitsEnabledProvider)) return const SizedBox.shrink();
    final view = ref.watch(habitsTodayProvider).value;
    if (view == null || view.habits.isEmpty) return const SizedBox.shrink();
    final colors = context.colors;
    final pending = view.pending;
    return Padding(
      padding: const EdgeInsets.only(top: CarliSpace.s16),
      child: CarliCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: CarliSpace.s12,
          children: [
            Semantics(
              button: true,
              hint: 'Abrir Hábitos',
              child: Pressable(
                onTap: () => context.go(HabitsPaths.today),
                pressedOpacity: 0.7,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 2,
                        children: [
                          Text('Hábitos', style: CarliType.small.copyWith(color: colors.text2)),
                          Text(
                            view.total == 0
                                ? 'Nada que hacer hoy'
                                : pending.isEmpty
                                ? 'Todo hecho · ${view.done} de ${view.total}'
                                : '${view.done} de ${view.total}',
                            style: CarliType.metric.copyWith(color: colors.text),
                          ),
                        ],
                      ),
                    ),
                    CarliIcon(carliIconNamed('chevron-right'), size: 16, color: colors.text3),
                  ],
                ),
              ),
            ),
            if (pending.isNotEmpty) HabitRingStrip(habits: pending),
          ],
        ),
      ),
    );
  }
}
