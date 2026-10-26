import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_error.dart';
import '../../../core/format/dates.dart';
import '../../../core/pending/pending_models.dart';
import '../../../core/pending/pending_types.dart';
import '../../../core/theme/tokens.dart';
import '../../../ui/button.dart';
import '../../../ui/toast.dart';
import '../data/tasks_api.dart';
import '../data/tasks_providers.dart';
import 'tasks_routes.dart';

abstract final class TasksPendingTypes {
  static const module = 'tasks';
  static const overdue = 'overdue_task';
}

final tasksPendingModule = PendingModuleInfo(
  name: 'Tareas',
  icon: 'list-checks',
  types: {
    TasksPendingTypes.overdue: PendingTypeDescriptor(
      label: 'Tareas vencidas',
      icon: 'list-checks',
      countLabel: (count) => count == 1 ? '1 tarea vencida' : '$count tareas vencidas',
    ),
  },
);

void openTasksPendingRoute(BuildContext context, WidgetRef ref, String route) =>
    context.go(route.startsWith(TasksRoutes.root) ? route : TasksRoutes.today);

enum _OverdueAction { done, today, skip }

class OverdueTaskPendingAction extends ConsumerStatefulWidget {
  const OverdueTaskPendingAction({super.key, required this.item, required this.onResolved});

  final PendingItem item;
  final ValueChanged<PendingItem> onResolved;

  @override
  ConsumerState<OverdueTaskPendingAction> createState() => _OverdueTaskPendingActionState();
}

class _OverdueTaskPendingActionState extends ConsumerState<OverdueTaskPendingAction> {
  _OverdueAction? _busy;

  String get _taskId => widget.item.metaString('task_id') ?? widget.item.id;

  Future<void> _run(_OverdueAction action) async {
    if (_busy != null) return;
    final api = ref.read(tasksApiProvider);
    final toasts = ref.read(toastControllerProvider.notifier);
    final changes = ref.read(tasksChangesProvider.notifier);
    setState(() => _busy = action);
    try {
      switch (action) {
        case _OverdueAction.done:
          await api.complete(_taskId);
        case _OverdueAction.today:
          await api.postpone(_taskId, today());
        case _OverdueAction.skip:
          await api.skip(_taskId);
      }
    } catch (error) {
      if (mounted) setState(() => _busy = null);
      toasts.error(apiErrorMessage(error, fallback: 'No se ha podido actualizar la tarea.'));
      return;
    }
    changes.notify();
    widget.onResolved(widget.item);
    final title = widget.item.title;
    final undo = switch (action) {
      _OverdueAction.done || _OverdueAction.skip => () async {
        await api.reopen(_taskId);
        changes.notify();
      },
      _OverdueAction.today => () async {
        await api.postpone(_taskId, widget.item.date);
        changes.notify();
      },
    };
    toasts.withUndo(switch (action) {
      _OverdueAction.done => '$title hecha',
      _OverdueAction.today => '$title pasa a hoy',
      _OverdueAction.skip => '$title omitida',
    }, undo);
  }

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: CarliSpace.s8,
    runSpacing: CarliSpace.s8,
    children: [
      for (final (action, label) in const [
        (_OverdueAction.done, 'Hecha'),
        (_OverdueAction.today, 'Pasar a hoy'),
        (_OverdueAction.skip, 'Omitir'),
      ])
        CarliButton(
          label: label,
          variant: action == _OverdueAction.done ? CarliButtonVariant.primary : CarliButtonVariant.secondary,
          size: CarliButtonSize.sm,
          block: false,
          loading: _busy == action,
          onPressed: _busy == null ? () => _run(action) : null,
        ),
    ],
  );
}
