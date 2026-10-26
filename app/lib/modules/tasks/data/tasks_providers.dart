import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/modules/modules_provider.dart';
import 'tasks_api.dart';
import 'tasks_models.dart';

const tasksModuleId = 'tasks';

final tasksChangesProvider = NotifierProvider<TasksChanges, int>(TasksChanges.new);

class TasksChanges extends Notifier<int> {
  @override
  int build() => 0;

  void notify() => state++;
}

extension WatchTasksChanges on Ref {
  void watchTasks() => watch(tasksChangesProvider);
}

final tasksTodayProvider = FutureProvider<TodayView>((ref) async {
  ref.watchTasks();
  return ref.watch(tasksApiProvider).today();
});

final tasksUpcomingProvider = FutureProvider<List<UpcomingDay>>((ref) async {
  ref.watchTasks();
  return ref.watch(tasksApiProvider).upcoming();
});

final taskListsProvider = FutureProvider<List<TaskList>>((ref) async {
  ref.watchTasks();
  return ref.watch(tasksApiProvider).lists();
});

final archivedTaskListsProvider = FutureProvider<List<TaskList>>((ref) async {
  ref.watchTasks();
  final lists = await ref.watch(tasksApiProvider).lists(archived: true);
  return [
    for (final list in lists)
      if (list.archived) list,
  ];
});

final listTasksProvider = FutureProvider.family<List<TaskItem>, String>((ref, listId) async {
  ref.watchTasks();
  return ref.watch(tasksApiProvider).tasks(listId: listId);
});

final doneTasksProvider = FutureProvider.family<List<TaskItem>, String?>((ref, listId) async {
  ref.watchTasks();
  return ref.watch(tasksApiProvider).tasks(listId: listId, status: 'done');
});

final taskProvider = FutureProvider.family<TaskItem, String>((ref, id) async {
  ref.watchTasks();
  return ref.watch(tasksApiProvider).task(id);
});

final taskTemplatesProvider = FutureProvider<List<TaskTemplate>>((ref) async {
  ref.watchTasks();
  return ref.watch(tasksApiProvider).templates();
});

final taskTemplateProvider = FutureProvider.family<TaskTemplate, String>((ref, id) async {
  ref.watchTasks();
  return ref.watch(tasksApiProvider).template(id);
});

final templateHistoryProvider = FutureProvider.family<TemplateHistory, String>((ref, id) async {
  ref.watchTasks();
  return ref.watch(tasksApiProvider).history(id);
});

final tasksSettingsProvider = Provider<TasksSettings>((ref) {
  final module = ref.watch(modulesProvider).value?.where((module) => module.id == tasksModuleId).firstOrNull;
  return TasksSettings.fromJson(module?.settings ?? const {});
});
