import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../dev/catalog_screen.dart';
import '../../modules/finance/screens/accounts/account_detail_screen.dart';
import '../../modules/finance/screens/accounts/accounts_screen.dart';
import '../../modules/finance/screens/bank/bank_connections_screen.dart';
import '../../modules/finance/screens/bank/bank_link_screen.dart';
import '../../modules/finance/data/finance_providers.dart';
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
import '../../shell/home/coming_soon_module_screen.dart';
import '../../shell/home/home_screen.dart';
import '../../shell/launch/launch_screen.dart';
import '../../shell/login/login_screen.dart';
import '../../shell/more/more_screen.dart';
import '../../shell/notifications/notifications_screen.dart';
import '../../shell/pending/pending_screen.dart';
import '../../shell/search/global_search_screen.dart';
import '../../shell/settings/appearance_settings_screen.dart';
import '../../shell/settings/module_settings_screen.dart';
import '../../shell/settings/notifications/notification_settings_screen.dart';
import '../../shell/settings/profile_settings_screen.dart';
import '../../shell/settings/security/security_settings_screen.dart';
import '../../shell/settings/settings_screen.dart';
import '../auth/auth_controller.dart';
import 'route_query_handler.dart';

abstract final class Routes {
  static const launch = '/arranque';
  static const login = '/login';
  static const home = '/';
  static const pending = '/pendientes';
  static const notifications = '/notificaciones';
  static const search = '/buscar';
  static const comingSoon = '/proximamente';
  static const summary = '/finanzas';
  static const transactions = '/finanzas/movimientos';
  static const budgets = '/finanzas/presupuestos';
  static const newTransaction = '/finanzas/movimientos/nuevo';
  static const more = '/mas';
  static const accounts = '/mas/cuentas';
  static const categories = '/mas/categorias';
  static const recurring = '/mas/recurrentes';
  static const goals = '/mas/objetivos';
  static const debts = '/mas/deudas';
  static const shared = '/mas/compartidos';
  static const financeSettings = '/mas/ajustes-finanzas';
  static const banks = '/mas/ajustes-finanzas/bancos';
  static const settings = SettingsPaths.root;
  static const notificationSettings = SettingsPaths.notifications;

  static String pendingFor(Map<String, String> query) =>
      Uri(path: pending, queryParameters: query.isEmpty ? null : query).toString();
  static String comingSoonModule(String moduleId) => '$comingSoon/$moduleId';
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

  String? returnTo;
  final router = GoRouter(
    initialLocation: Routes.home,
    refreshListenable: auth,
    redirect: (context, state) {
      final current = auth.value;
      if (current is SignedOut && current.expired && state.matchedLocation != Routes.login) {
        returnTo = state.uri.toString();
      }
      final target = authRedirect(current, state.matchedLocation, returnTo: returnTo);
      if (current is SignedIn && target != null) returnTo = null;
      return target;
    },
    routes: [
      GoRoute(path: Routes.launch, builder: (context, state) => const LaunchScreen()),
      GoRoute(path: Routes.login, builder: (context, state) => const LoginScreen()),
      if (kDebugMode) GoRoute(path: Routes.catalog, builder: (context, state) => const CatalogScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell, location: state.uri.path),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.home,
                builder: (context, state) => const HomeScreen(),
                routes: [
                  GoRoute(
                    path: 'pendientes',
                    builder: (context, state) => PendingScreen(
                      module: state.uri.queryParameters['modulo'],
                      type: state.uri.queryParameters['tipo'],
                    ),
                  ),
                  GoRoute(path: 'notificaciones', builder: (context, state) => const NotificationsScreen()),
                  GoRoute(path: 'buscar', builder: (context, state) => const GlobalSearchScreen()),
                  GoRoute(
                    path: 'proximamente/:id',
                    builder: (context, state) => ComingSoonModuleScreen(moduleId: state.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          _branch(Routes.summary, const SummaryScreen()),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.transactions,
                builder: (context, state) => TransactionsScreen(query: state.uri.queryParametersAll),
                routes: [
                  GoRoute(
                    path: 'nuevo',
                    redirect: (context, state) => Uri(
                      path: Routes.transactions,
                      queryParameters: {...state.uri.queryParameters, 'nuevo': '1'},
                    ).toString(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.budgets,
                builder: (context, state) => RouteQueryHandler(
                  query: state.uri.queryParametersAll,
                  onQuery: (context, ref, query) =>
                      ref.read(budgetsPeriodProvider.notifier).selectId(switch (query['periodo']?.firstOrNull) {
                        'actual' || null => null,
                        final id => id,
                      }),
                  child: const BudgetsScreen(),
                ),
              ),
            ],
          ),
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
                  GoRoute(
                    path: 'ajustes',
                    builder: (context, state) => const SettingsScreen(),
                    routes: [
                      GoRoute(path: 'perfil', builder: (context, state) => const ProfileSettingsScreen()),
                      GoRoute(path: 'seguridad', builder: (context, state) => const SecuritySettingsScreen()),
                      GoRoute(path: 'avisos', builder: (context, state) => const NotificationSettingsScreen()),
                      GoRoute(path: 'modulos', builder: (context, state) => const ModuleSettingsScreen()),
                      GoRoute(path: 'apariencia', builder: (context, state) => const AppearanceSettingsScreen()),
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

String? authRedirect(AuthState auth, String location, {String? returnTo, bool debug = kDebugMode}) {
  if (debug && location == Routes.catalog && auth is! AuthUnknown) return null;
  return switch (auth) {
    AuthUnknown() => location == Routes.launch ? null : Routes.launch,
    SignedOut() => location == Routes.login ? null : Routes.login,
    SignedIn() => location == Routes.login || location == Routes.launch ? returnTo ?? Routes.home : null,
  };
}
