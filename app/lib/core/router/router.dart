import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../dev/catalog_screen.dart';
import '../../modules/finance/screens/accounts/account_detail_screen.dart';
import '../../modules/finance/screens/accounts/accounts_screen.dart';
import '../../modules/finance/screens/bank/bank_connections_screen.dart';
import '../../modules/finance/screens/bank/bank_link_screen.dart';
import '../../modules/finance/screens/budgets_screen.dart';
import '../../modules/finance/screens/categories/categories_screen.dart';
import '../../modules/finance/screens/debts/debts_screen.dart';
import '../../modules/finance/screens/goals/goal_detail_screen.dart';
import '../../modules/finance/screens/goals/goals_screen.dart';
import '../../modules/finance/screens/recurring/recurring_screen.dart';
import '../../modules/finance/screens/settings/finance_settings_screen.dart';
import '../../modules/finance/screens/shared/contact_detail_screen.dart';
import '../../modules/finance/screens/shared/shared_screen.dart';
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
  static const accounts = '/mas/cuentas';
  static const categories = '/mas/categorias';
  static const recurring = '/mas/recurrentes';
  static const goals = '/mas/objetivos';
  static const debts = '/mas/deudas';
  static const shared = '/mas/compartidos';
  static const financeSettings = '/mas/ajustes-finanzas';
  static const banks = '/mas/ajustes-finanzas/bancos';

  static String account(String id) => '$accounts/$id';
  static String goal(String id) => '$goals/$id';
  static String contact(String id) => '$shared/$id';
  static String bankLink(String connectionId, {bool renewed = false}) =>
      '$banks/$connectionId/vincular${renewed ? '?renovado=1' : ''}';
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
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.more,
                builder: (context, state) => const MoreScreen(),
                routes: [
                  GoRoute(
                    path: 'cuentas',
                    builder: (context, state) => const AccountsScreen(),
                    routes: [
                      GoRoute(
                        path: ':id',
                        builder: (context, state) => AccountDetailScreen(accountId: state.pathParameters['id']!),
                      ),
                    ],
                  ),
                  GoRoute(path: 'categorias', builder: (context, state) => const CategoriesScreen()),
                  GoRoute(path: 'recurrentes', builder: (context, state) => const RecurringScreen()),
                  GoRoute(
                    path: 'objetivos',
                    builder: (context, state) => const GoalsScreen(),
                    routes: [
                      GoRoute(
                        path: ':id',
                        builder: (context, state) => GoalDetailScreen(goalId: state.pathParameters['id']!),
                      ),
                    ],
                  ),
                  GoRoute(path: 'deudas', builder: (context, state) => const DebtsScreen()),
                  GoRoute(
                    path: 'compartidos',
                    builder: (context, state) => const SharedScreen(),
                    routes: [
                      GoRoute(
                        path: ':id',
                        builder: (context, state) => ContactDetailScreen(contactId: state.pathParameters['id']!),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'ajustes-finanzas',
                    builder: (context, state) => const FinanceSettingsScreen(),
                    routes: [
                      GoRoute(
                        path: 'bancos',
                        builder: (context, state) => const BankConnectionsScreen(),
                        routes: [
                          GoRoute(
                            path: ':id/vincular',
                            builder: (context, state) => BankLinkScreen(
                              connectionId: state.pathParameters['id']!,
                              renewed: state.uri.queryParameters['renovado'] == '1',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
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
