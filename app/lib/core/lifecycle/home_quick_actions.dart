import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quick_actions/quick_actions.dart';

import '../auth/auth_controller.dart';
import '../router/router.dart';

enum HomeQuickAction {
  newTransaction('new_transaction', 'Nuevo movimiento', Routes.newTransaction),
  transactions('transactions', 'Movimientos', Routes.transactions),
  pending('pending', 'Pendientes', Routes.pending);

  const HomeQuickAction(this.type, this.title, this.location);

  final String type;
  final String title;
  final String location;

  static HomeQuickAction? of(String type) => values.where((action) => action.type == type).firstOrNull;
}

abstract interface class QuickActionsPlatform {
  Future<void> initialize(void Function(String type) onAction);

  Future<void> publish(List<HomeQuickAction> actions);
}

class NativeQuickActions implements QuickActionsPlatform {
  final _plugin = const QuickActions();

  @override
  Future<void> initialize(void Function(String type) onAction) => _plugin.initialize(onAction);

  @override
  Future<void> publish(List<HomeQuickAction> actions) => _plugin.setShortcutItems([
    for (final action in actions) ShortcutItem(type: action.type, localizedTitle: action.title),
  ]);
}

final quickActionsPlatformProvider = Provider<QuickActionsPlatform>((ref) => NativeQuickActions());

final homeQuickActionsProvider = Provider<void>((ref) {
  final platform = ref.watch(quickActionsPlatformProvider);
  HomeQuickAction? waiting;

  void open(HomeQuickAction action) {
    if (ref.read(authControllerProvider) is SignedIn) {
      ref.read(routerProvider).go(action.location);
    } else {
      waiting = action;
    }
  }

  ref.listen(authControllerProvider, (_, next) {
    final action = waiting;
    if (next is SignedIn && action != null) {
      waiting = null;
      ref.read(routerProvider).go(action.location);
    }
  });

  Future<void> setUp() async {
    try {
      await platform.initialize((type) {
        if (HomeQuickAction.of(type) case final action?) open(action);
      });
      await platform.publish(HomeQuickAction.values);
    } on Object {
      return;
    }
  }

  setUp();
});
