import 'package:go_router/go_router.dart';

import 'habits_paths.dart';
import 'screens/habit_detail_screen.dart';
import 'screens/habit_editor_screen.dart';
import 'screens/habits_list_screen.dart';
import 'screens/habits_progress_screen.dart';
import 'screens/habits_settings_screen.dart';
import 'screens/habits_today_screen.dart';

/// Full-screen routes that cover the tab bar: the detail, the editor and the settings.
final habitsRoutes = [
  GoRoute(path: HabitsPaths.root, redirect: (context, state) => HabitsPaths.today),
  GoRoute(path: HabitsPaths.create, builder: (context, state) => const HabitEditorScreen()),
  GoRoute(path: HabitsPaths.settings, builder: (context, state) => const HabitsSettingsScreen()),
  GoRoute(
    path: '/habitos/habito/:id',
    builder: (context, state) => HabitDetailScreen(habitId: state.pathParameters['id']!),
    routes: [
      GoRoute(
        path: 'editar',
        builder: (context, state) => HabitEditorScreen(habitId: state.pathParameters['id']),
      ),
    ],
  ),
];

final habitsBranches = [
  StatefulShellBranch(
    routes: [GoRoute(path: HabitsPaths.today, builder: (context, state) => const HabitsTodayScreen())],
  ),
  StatefulShellBranch(
    routes: [GoRoute(path: HabitsPaths.list, builder: (context, state) => const HabitsListScreen())],
  ),
  StatefulShellBranch(
    routes: [GoRoute(path: HabitsPaths.progress, builder: (context, state) => const HabitsProgressScreen())],
  ),
];
