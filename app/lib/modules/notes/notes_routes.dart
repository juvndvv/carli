import 'package:go_router/go_router.dart';

import 'notes_paths.dart';
import 'screens/note_screen.dart';
import 'screens/notes_screen.dart';
import 'screens/notes_settings_screen.dart';
import 'screens/shopping_view.dart';

final notesBranches = [
  StatefulShellBranch(
    routes: [
      GoRoute(
        path: NotesPaths.root,
        builder: (context, state) => const NotesScreen(),
        routes: [
          GoRoute(
            path: 'n/:id',
            builder: (context, state) =>
                NoteScreen(noteId: state.pathParameters['id']!, fresh: state.uri.queryParameters['nueva'] == '1'),
          ),
          GoRoute(
            path: 'carpeta/:id',
            builder: (context, state) => FolderScreen(folderId: state.pathParameters['id']!),
          ),
          GoRoute(path: 'archivadas', builder: (context, state) => const NotesCollectionScreen(trash: false)),
          GoRoute(path: 'papelera', builder: (context, state) => const NotesCollectionScreen(trash: true)),
          GoRoute(path: 'ajustes', builder: (context, state) => const NotesSettingsScreen()),
        ],
      ),
    ],
  ),
  StatefulShellBranch(
    routes: [GoRoute(path: NotesPaths.shopping, builder: (context, state) => const ShoppingScreen())],
  ),
];
