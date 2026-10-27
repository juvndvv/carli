import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/modules/modules_provider.dart';
import 'habits_api.dart';
import 'habits_models.dart';

const habitsModuleId = 'habits';

final habitsChangesProvider = NotifierProvider<HabitsChanges, int>(HabitsChanges.new);

class HabitsChanges extends Notifier<int> {
  @override
  int build() => 0;

  void notify() => state++;
}

extension WatchHabitsChanges on Ref {
  void watchHabits() => watch(habitsChangesProvider);
}

final habitsEnabledProvider = Provider<bool>(
  (ref) => ref.watch(enabledModuleIdsProvider)?.contains(habitsModuleId) ?? false,
);

final habitsSettingsProvider = Provider<HabitsSettings>((ref) {
  final module = ref.watch(modulesProvider).value?.where((module) => module.id == habitsModuleId).firstOrNull;
  return HabitsSettings.fromJson(module?.settings ?? const {});
});

final habitsTodayProvider = FutureProvider<HabitsTodayView>((ref) async {
  ref.watchHabits();
  return ref.watch(habitsApiProvider).today();
});

final habitsListProvider = FutureProvider<List<HabitListItem>>((ref) async {
  ref.watchHabits();
  return ref.watch(habitsApiProvider).list();
});

final habitDetailProvider = FutureProvider.family<HabitDetail, String>((ref, id) async {
  ref.watchHabits();
  return ref.watch(habitsApiProvider).habit(id);
});

final habitCalendarProvider = FutureProvider.family<List<CalendarDay>, (String, DateTime)>((ref, key) async {
  ref.watchHabits();
  return ref.watch(habitsApiProvider).calendar(key.$1, key.$2);
});

final habitsProgressProvider = FutureProvider.family<HabitsProgress, ProgressRange>((ref, range) async {
  ref.watchHabits();
  return ref.watch(habitsApiProvider).progress(range);
});

final habitBreaksProvider = FutureProvider<List<HabitBreak>>((ref) async {
  ref.watchHabits();
  return ref.watch(habitsApiProvider).breaks();
});

final conversionPreviewProvider = FutureProvider.autoDispose.family<ConversionPreview, String>(
  (ref, templateId) => ref.watch(habitsApiProvider).conversionPreview(templateId),
);

/// Habits shown as rings in Tareas · Hoy: due today, not met yet, never the avoid ones.
final habitsForTasksProvider = Provider<List<HabitToday>>((ref) {
  if (!ref.watch(habitsEnabledProvider) || !ref.watch(habitsSettingsProvider).showInTasks) return const [];
  final view = ref.watch(habitsTodayProvider).value;
  if (view == null) return const [];
  return [
    for (final habit in view.pending)
      if (habit.habit.showInTasks) habit,
  ];
});
