import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../dev/catalog_screen.dart';
import '../../modules/finance/screens/budgets_screen.dart';
import '../../modules/finance/screens/summary_screen.dart';
import '../../modules/finance/screens/transactions_screen.dart';
import '../../shell/app_shell.dart';
import '../../shell/home/home_screen.dart';
import '../../shell/launch/launch_screen.dart';
import '../../shell/login/login_screen.dart';
import '../../shell/more/more_screen.dart';
import '../auth/auth_controller.dart';

abstract final class Routes {
  static const launch = '/arranque';
  static const login = '/login';
  static const home = '/';
  static const summary = '/finanzas';
  static const transactions = '/finanzas/movimientos';
  static const budgets = '/finanzas/presupuestos';
  static const more = '/mas';
  static const catalog = '/dev/catalogo';
}

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ValueNotifier<AuthState>(ref.read(authControllerProvider));
  ref.listen(authControllerProvider, (_, next) => auth.value = next);
  ref.onDispose(auth.dispose);

  final router = GoRouter(
    initialLocation: Routes.home,
    refreshListenable: auth,
    redirect: (context, state) => authRedirect(auth.value, state.matchedLocation),
    routes: [
      GoRoute(path: Routes.launch, builder: (context, state) => const LaunchScreen()),
      GoRoute(path: Routes.login, builder: (context, state) => const LoginScreen()),
      if (kDebugMode) GoRoute(path: Routes.catalog, builder: (context, state) => const CatalogScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
        branches: [
          _branch(Routes.home, const HomeScreen()),
          _branch(Routes.summary, const SummaryScreen()),
          _branch(Routes.transactions, const TransactionsScreen()),
          _branch(Routes.budgets, const BudgetsScreen()),
          _branch(Routes.more, const MoreScreen()),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

StatefulShellBranch _branch(String path, Widget screen) => StatefulShellBranch(
  routes: [GoRoute(path: path, builder: (context, state) => screen)],
);

String? authRedirect(AuthState auth, String location, {bool debug = kDebugMode}) {
  if (debug && location == Routes.catalog && auth is! AuthUnknown) return null;
  return switch (auth) {
    AuthUnknown() => location == Routes.launch ? null : Routes.launch,
    SignedOut() => location == Routes.login ? null : Routes.login,
    SignedIn() => location == Routes.login || location == Routes.launch ? Routes.home : null,
  };
}
