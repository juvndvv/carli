import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../../core/pending/pending_providers.dart';
import '../../../ui/toast.dart';
import 'tasks_api.dart';
import 'tasks_models.dart';
import 'tasks_providers.dart';

const completeUndoDuration = Duration(seconds: 4);

final taskActionsProvider = Provider<TaskActions>(TaskActions.new);

/// Every task mutation goes through here so lists, Hoy, Próximas and Pendientes refresh together.
class TaskActions {
  TaskActions(this._ref);

  final Ref _ref;

  TasksApi get _api => _ref.read(tasksApiProvider);

  ToastController get _toasts => _ref.read(toastControllerProvider.notifier);

  void changed() {
    _ref.read(tasksChangesProvider.notifier).notify();
    _ref.read(pendingSummaryProvider.notifier).refresh().ignore();
  }

  Future<T?> _run<T>(Future<T> Function() action, String fallback) async {
    try {
      final result = await action();
      changed();
      return result;
    } catch (error) {
      _toasts.error(apiErrorMessage(error, fallback: fallback));
      return null;
    }
  }

  Future<bool> complete(TaskItem task) async {
    final done = await _run(() => _api.complete(task.id), 'No se ha podido completar la tarea.');
    if (done == null) return false;
    _toasts.show(
      '${task.title} hecha',
      action: ToastAction('Deshacer', () => reopen(task)),
      duration: completeUndoDuration,
    );
    return true;
  }

  Future<bool> reopen(TaskItem task) async =>
      await _run(() => _api.reopen(task.id), 'No se ha podido deshacer.') != null;

  Future<bool> toggle(TaskItem task) => task.isDone ? reopen(task) : complete(task);

  Future<bool> skip(TaskItem task) async {
    final skipped = await _run(() => _api.skip(task.id), 'No se ha podido omitir la tarea.');
    if (skipped == null) return false;
    _toasts.withUndo('${task.title} omitida', () => reopen(task));
    return true;
  }

  Future<bool> postpone(TaskItem task, DateTime date) async =>
      await _run(() => _api.postpone(task.id, date), 'No se ha podido posponer la tarea.') != null;

  Future<TaskItem?> create(Map<String, Object?> input) =>
      _run(() => _api.createTask(input), 'No se ha podido crear la tarea.');

  Future<TaskItem?> update(String id, Map<String, Object?> input) =>
      _run(() => _api.updateTask(id, input), 'No se ha podido guardar la tarea.');

  Future<bool> delete(TaskItem task) async =>
      await _run(() async {
        await _api.deleteTask(task.id);
        return true;
      }, 'No se ha podido borrar la tarea.') ??
      false;

  Future<bool> setSubtask(TaskItem task, Subtask subtask, bool done) async =>
      await _run(
        () => _api.updateSubtask(task.id, subtask.id, {'done': done}),
        'No se ha podido guardar la subtarea.',
      ) !=
      null;

  Future<bool> addSubtask(TaskItem task, String title) async =>
      await _run(() => _api.addSubtask(task.id, title), 'No se ha podido añadir la subtarea.') != null;

  Future<bool> deleteSubtask(TaskItem task, Subtask subtask) async =>
      await _run(() async {
        await _api.deleteSubtask(task.id, subtask.id);
        return true;
      }, 'No se ha podido borrar la subtarea.') ??
      false;

  Future<TaskTemplate?> saveTemplate(String? id, Map<String, Object?> input) => _run(
    () => id == null ? _api.createTemplate(input) : _api.updateTemplate(id, input),
    'No se ha podido guardar la plantilla.',
  );

  Future<TaskTemplate?> setTemplatePaused(TaskTemplate template, bool paused) =>
      _run(() => _api.setPaused(template.id, paused), 'No se ha podido actualizar la plantilla.');

  Future<bool> deleteTemplate(TaskTemplate template, {required bool deleteOpen}) async =>
      await _run(() async {
        await _api.deleteTemplate(template.id, deleteOpen: deleteOpen);
        return true;
      }, 'No se ha podido borrar la plantilla.') ??
      false;

  Future<bool> skipOccurrence(String templateId, DateTime date, {String? title}) async {
    final template = await _run(() => _api.skipOccurrence(templateId, date), 'No se ha podido saltar la fecha.');
    if (template == null) return false;
    _toasts.withUndo('${title ?? template.title}: saltada esta vez', () async {
      await _run(() => _api.unskipOccurrence(templateId, date), 'No se ha podido deshacer.');
    });
    return true;
  }

  Future<TaskList?> createList(String name) => _run(() => _api.createList(name), 'No se ha podido crear la lista.');

  Future<TaskList?> updateList(String id, Map<String, Object?> input) =>
      _run(() => _api.updateList(id, input), 'No se ha podido guardar la lista.');

  Future<bool> reorderLists(List<String> ids) async =>
      await _run(() async {
        await _api.reorderLists(ids);
        return true;
      }, 'No se ha podido reordenar.') ??
      false;

  Future<bool> deleteList(TaskList list) async =>
      await _run(() async {
        await _api.deleteList(list.id);
        return true;
      }, 'No se ha podido borrar la lista.') ??
      false;
}
