import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/pending/pending_models.dart';
import '../../core/pending/pending_types.dart';
import '../../core/router/router.dart';
import '../../modules/finance/data/transaction_filters.dart';
import 'finance_pending_actions.dart';

typedef PendingActionBuilder = Widget Function(PendingItem item, ValueChanged<PendingItem> onResolved);

typedef PendingRouteOpener = void Function(BuildContext context, WidgetRef ref, String route);

class PendingModuleActions {
  const PendingModuleActions({this.actions = const {}, this.open});

  final Map<String, PendingActionBuilder> actions;
  final PendingRouteOpener? open;
}

class PendingActionRegistry {
  const PendingActionRegistry(this.modules);

  final Map<String, PendingModuleActions> modules;

  PendingActionBuilder? action(String module, String type) => modules[module]?.actions[type];

  bool hasAction(String module, String type) => action(module, type) != null;

  bool canOpen(String module) => modules[module]?.open != null;

  void open(BuildContext context, WidgetRef ref, String module, String route) =>
      modules[module]?.open?.call(context, ref, route);
}

void openFinancePendingRoute(BuildContext context, WidgetRef ref, String route) {
  final uri = Uri.parse(route);
  if (uri.path == '/finanzas/recurrentes' || uri.path == Routes.recurring) {
    context.go(Routes.recurring);
    return;
  }
  if (uri.path == Routes.transactions) {
    final allPeriods = uri.queryParameters['periodo'] == 'todos';
    final filters = TransactionFilters(
      uncategorized: uri.queryParameters['sin_categoria'] == '1',
      periodScope: allPeriods ? PeriodScope.all : PeriodScope.current,
    );
    ref.read(transactionFiltersProvider.notifier).replace(filters);
    context.go(Routes.transactions);
    return;
  }
  context.go(route);
}

final financePendingActions = PendingModuleActions(
  actions: {
    FinancePendingTypes.uncategorized: (item, onResolved) =>
        CategorizePendingAction(key: ValueKey(item.key), item: item, onResolved: onResolved),
    FinancePendingTypes.recurring: (item, onResolved) =>
        ConfirmRecurringPendingAction(key: ValueKey(item.key), item: item, onResolved: onResolved),
    FinancePendingTypes.transferSuggestion: (item, onResolved) =>
        TransferSuggestionPendingAction(key: ValueKey(item.key), item: item, onResolved: onResolved),
  },
  open: openFinancePendingRoute,
);

final pendingActionRegistryProvider = Provider<PendingActionRegistry>(
  (ref) => PendingActionRegistry({FinancePendingTypes.module: financePendingActions}),
);
