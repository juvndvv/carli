import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../../core/format/dates.dart';
import '../../../ui/toast.dart';
import '../../tasks/data/tasks_providers.dart';
import 'habits_api.dart';
import 'habits_format.dart';
import 'habits_models.dart';
import 'habits_providers.dart';

const habitUndoDuration = Duration(seconds: 4);

final habitActionsProvider = Provider<HabitActions>(HabitActions.new);

/// Every habit mutation goes through here so Hoy, the list, the detail, Inicio and Tareas refresh together.
class HabitActions {
  HabitActions(this._ref);

  final Ref _ref;

  HabitsApi get _api => _ref.read(habitsApiProvider);

  ToastController get _toasts => _ref.read(toastControllerProvider.notifier);

  void changed() => _ref.read(habitsChangesProvider.notifier).notify();

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

  /// One tap on a ring: marks a yes/no habit (or unmarks it) and adds one to a quantity or an avoid habit.
  Future<bool> tap(HabitToday today) {
    final next = switch (today.habit.kind) {
      HabitKind.check => today.todayValue > 0 ? 0.0 : 1.0,
      HabitKind.quantity || HabitKind.avoid => today.todayValue + 1,
    };
    return log(today.habit, today.todayValue, next, note: today.todayNote);
  }

  Future<bool> log(Habit habit, double previous, double value, {DateTime? date, String? note}) async {
    final day = date ?? today();
    final logged = await _run(() async {
      await _api.log(habit.id, day, value, note: note);
      return true;
    }, 'No se ha podido registrar ${habit.name}.');
    if (logged == null) return false;
    _toasts.show(
      _message(habit, previous, value, day),
      action: ToastAction(
        'Deshacer',
        () => _run(() => _api.log(habit.id, day, previous, note: note), 'No se ha podido deshacer.'),
      ),
      duration: habitUndoDuration,
    );
    return true;
  }

  String _message(Habit habit, double previous, double value, DateTime day) {
    final when = dateOnly(day) == today() ? '' : ' el ${day.day} de ${monthsLong[day.month - 1]}';
    return switch (habit.kind) {
      HabitKind.check => value > 0 ? '${habit.name}: hecho$when' : '${habit.name}: desmarcado$when',
      HabitKind.avoid when value > previous => '${habit.name}: registrado$when',
      _ => '${habit.name}: ${habitAmount(value, habit.unit)}$when',
    };
  }

  Future<HabitDetail?> save(String? id, Map<String, Object?> input) =>
      _run(() => id == null ? _api.create(input) : _api.update(id, input), 'No se ha podido guardar el hábito.');

  Future<HabitDetail?> setShowInTasks(Habit habit, bool value) =>
      _run(() => _api.update(habit.id, {'show_in_tasks': value}), 'No se ha podido guardar el hábito.');

  Future<HabitDetail?> transition(Habit habit, String action) =>
      _run(() => _api.transition(habit.id, action), 'No se ha podido actualizar el hábito.');

  Future<bool> delete(Habit habit) async =>
      await _run(() async {
        await _api.delete(habit.id);
        return true;
      }, 'No se ha podido borrar el hábito.') ??
      false;

  Future<bool> reorder(List<String> ids) async =>
      await _run(() async {
        await _api.reorder(ids);
        return true;
      }, 'No se ha podido reordenar.') ??
      false;

  Future<bool> startBreak(DateTime from, DateTime to, {String? habitId}) async =>
      await _run(() => _api.createBreak(from, to, habitId: habitId), 'No se ha podido guardar el descanso.') != null;

  Future<bool> endBreak(HabitBreak pause) async =>
      await _run(() async {
        await _api.endBreak(pause.id);
        return true;
      }, 'No se ha podido terminar el descanso.') ??
      false;

  Future<HabitDetail?> convertTemplate(String templateId) async {
    final habit = await _run(() => _api.convert(templateId), 'No se ha podido convertir la plantilla.');
    if (habit != null) _ref.read(tasksChangesProvider.notifier).notify();
    return habit;
  }
}
