import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shell/app_shell.dart';
import 'data/models.dart';
import 'notes_paths.dart';
import 'screens/shopping_view.dart';
import 'ui/notes_sheets.dart';
import 'ui/notes_widgets.dart';

/// Notas' own bar: Inicio · Notas · Compra, with "+" picking a note type or, in Compra, adding a product.
List<ShellTab> notesShellTabs(StatefulNavigationShell shell, String location) {
  int branchOf(String path) => shell.route.branches.indexWhere((branch) => branch.defaultRoute?.path == path);
  ShellTab tab(String label, NoteType type, String path) {
    final branch = branchOf(path);
    return ShellTab(
      label: label,
      icon: noteTypeIcon(type),
      selected: branch == shell.currentIndex,
      onTap: () => shell.goBranch(branch, initialLocation: branch == shell.currentIndex),
    );
  }

  return [tab('Notas', NoteType.text, NotesPaths.root), tab('Compra', NoteType.shopping, NotesPaths.shopping)];
}

String notesAddLabel(String location) => location.startsWith(NotesPaths.shopping) ? 'Añadir producto' : 'Nueva nota';

void onNotesAdd(BuildContext context, WidgetRef ref, String location) {
  if (location.startsWith(NotesPaths.shopping)) {
    ref.read(shoppingAddRequestsProvider.notifier).request();
    return;
  }
  final folder = RegExp('^${NotesPaths.root}/carpeta/([^/]+)').firstMatch(location)?.group(1);
  startNewNote(context, ref, folderId: folder);
}
