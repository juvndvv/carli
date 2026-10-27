import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/styles/stroke_rounded.dart';

import '../../shell/app_shell.dart';
import '../../ui/icon.dart';
import 'habits_paths.dart';

/// Hábitos' own bar: Inicio · Hoy · Hábitos · Progreso, with "+" creating a habit.
List<ShellTab> habitsShellTabs(StatefulNavigationShell shell) {
  int branchOf(String path) => shell.route.branches.indexWhere((branch) => branch.defaultRoute?.path == path);
  ShellTab tab(String label, CarliIconData icon, String path) {
    final branch = branchOf(path);
    return ShellTab(
      label: label,
      icon: icon,
      selected: branch == shell.currentIndex,
      onTap: () => shell.goBranch(branch, initialLocation: branch == shell.currentIndex),
    );
  }

  return [
    tab('Hoy', HugeIconsStrokeRounded.target02, HabitsPaths.today),
    tab('Hábitos', HugeIconsStrokeRounded.leftToRightListBullet, HabitsPaths.list),
    tab('Progreso', HugeIconsStrokeRounded.chartColumn, HabitsPaths.progress),
  ];
}

void onHabitsAdd(BuildContext context) => context.push(HabitsPaths.create);
