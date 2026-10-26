import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../ui/chip.dart';
import '../../../ui/empty_state.dart';
import '../../../ui/page.dart';
import '../../../ui/search.dart';
import '../data/models.dart';
import '../data/notes_actions.dart';
import '../data/notes_api.dart';
import '../data/notes_store.dart';
import '../data/notes_sync.dart';
import '../data/views.dart';
import '../notes_paths.dart';
import '../ui/note_tiles.dart';
import '../ui/notes_sheets.dart';
import '../ui/notes_widgets.dart';

final _serverSearchProvider = FutureProvider.autoDispose.family<List<NoteSearchHit>, String>(
  (ref, query) => ref.watch(notesApiProvider).search(query),
);

class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

enum _RootMenu { folder, archived, trash, settings }

class _NotesScreenState extends ConsumerState<NotesScreen> {
  final _search = TextEditingController();
  var _query = '';
  var _filter = NotesFilter.all;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onQuery(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _query = value.trim());
    });
  }

  Future<void> _menu() async {
    final choice = await showActionMenu<_RootMenu>(
      context,
      actions: const [
        (_RootMenu.folder, 'Nueva carpeta', false),
        (_RootMenu.archived, 'Archivadas', false),
        (_RootMenu.trash, 'Papelera', false),
        (_RootMenu.settings, 'Ajustes de Notas', false),
      ],
    );
    if (!mounted) return;
    switch (choice) {
      case _RootMenu.folder:
        await _newFolder();
      case _RootMenu.archived:
        context.push(NotesPaths.archived);
      case _RootMenu.trash:
        context.push(NotesPaths.trash);
      case _RootMenu.settings:
        context.push(NotesPaths.settings);
      case null:
        return;
    }
  }

  Future<void> _newFolder() async {
    final name = await promptName(context, title: 'Nueva carpeta', confirmLabel: 'Crear');
    if (name != null) await ref.read(notesActionsProvider).createFolder(name);
  }

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(notesIndexProvider).value;
    final browsing = _query.isEmpty && _filter == NotesFilter.all;
    return CarliPage(
      title: 'Notas',
      trailing: RoundIconButton(icon: moreIcon, label: 'Más opciones', onTap: _menu),
      onRefresh: () => ref.read(notesSyncProvider.notifier).sync(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16),
          sliver: SliverList.list(
            children: [
              const OfflineNotice(),
              CarliSearchField(controller: _search, placeholder: 'Buscar en notas', onChanged: _onQuery),
              const SizedBox(height: CarliSpace.s12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                child: Row(
                  spacing: CarliSpace.s8,
                  children: [
                    for (final filter in NotesFilter.values)
                      CarliChip(
                        label: filter.label,
                        selected: filter == _filter,
                        onTap: () => setState(() => _filter = filter),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (index == null)
          const SliverToBoxAdapter(child: SizedBox(height: CarliSpace.s48))
        else if (browsing)
          ..._browse(index)
        else
          _results(index),
      ],
    );
  }

  List<Widget> _browse(NotesIndex index) {
    final pinned = index.pinnedNotes;
    final folders = index.tree.childrenOf(null);
    final recent = index.recentNotes;
    if (pinned.isEmpty && folders.isEmpty && recent.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: CarliEmptyState(
            icon: noteTypeIcon(NoteType.text),
            title: 'Sin notas todavía',
            message: 'Apuntes, listas que reutilizas y la lista de la compra. Pulsa + para empezar.',
            actionLabel: 'Nueva nota',
            onAction: () => startNewNote(context, ref),
          ),
        ),
      ];
    }
    return [
      if (pinned.isNotEmpty)
        SliverToBoxAdapter(
          child: CarliSection(
            title: 'Fijadas',
            child: _PinnedGrid(notes: pinned, onOpen: _open),
          ),
        ),
      SliverToBoxAdapter(
        child: CarliSection(
          title: 'Carpetas',
          actionLabel: 'Nueva',
          onAction: _newFolder,
          child: folders.isEmpty
              ? Text(
                  'Agrupa notas en carpetas, también unas dentro de otras.',
                  style: CarliType.small.copyWith(color: context.colors.text2),
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  child: Row(
                    spacing: CarliSpace.s8,
                    children: [
                      for (final folder in folders)
                        FolderChip(
                          folder: folder,
                          count: index.recursiveCount(folder.id),
                          onTap: () => context.push(NotesPaths.folder(folder.id)),
                          onLongPress: () => showFolderMenu(context, ref, folder),
                        ),
                    ],
                  ),
                ),
        ),
      ),
      if (recent.isNotEmpty)
        SliverToBoxAdapter(
          child: CarliSection(
            title: 'Recientes',
            child: GroupedRows(
              indent: 60,
              children: [
                for (final note in recent)
                  SwipeToDelete(
                    id: note.id,
                    onDelete: () => deleteNoteWithUndo(ref, note),
                    child: NoteRow(note: note, path: index.folderPathOf(note), onTap: () => _open(note.id)),
                  ),
              ],
            ),
          ),
        ),
    ];
  }

  Widget _results(NotesIndex index) {
    final local = index.searchLocally(_query, _filter);
    final server = _query.isEmpty ? null : ref.watch(_serverSearchProvider(_query)).value;
    final List<(Note, NoteSearchHit?)>? serverNotes = server == null
        ? null
        : [
            for (final hit in server)
              if (index.note(hit.id) case final note? when _filter.accepts(note)) (note, hit),
          ];
    final rows = serverNotes ?? [for (final note in local) (note, null)];
    if (rows.isEmpty) {
      return const SliverToBoxAdapter(
        child: CarliEmptyState(
          icon: searchIcon,
          title: 'Nada por aquí',
          message: 'Prueba con otra palabra o cambia el filtro.',
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(CarliSpace.s16, CarliSpace.s16, CarliSpace.s16, 0),
      sliver: SliverToBoxAdapter(
        child: GroupedRows(
          indent: 60,
          children: [
            for (final (note, hit) in rows)
              NoteRow(note: note, path: index.folderPathOf(note), preview: hit?.snippet, onTap: () => _open(note.id)),
          ],
        ),
      ),
    );
  }

  void _open(String id) => context.push(NotesPaths.note(id));
}

class _PinnedGrid extends StatelessWidget {
  const _PinnedGrid({required this.notes, required this.onOpen});

  final List<Note> notes;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - CarliSpace.s8) / 2;
        return Wrap(
          spacing: CarliSpace.s8,
          runSpacing: CarliSpace.s8,
          children: [
            for (final note in notes)
              SizedBox(
                width: width,
                child: PinnedCard(note: note, onTap: () => onOpen(note.id)),
              ),
          ],
        );
      },
    );
  }
}

class FolderScreen extends ConsumerWidget {
  const FolderScreen({super.key, required this.folderId});

  final String folderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final index = ref.watch(notesIndexProvider).value;
    final folder = index?.folder(folderId);
    if (index == null || folder == null) {
      return CarliPage(
        title: 'Carpeta',
        slivers: [
          if (index != null)
            SliverToBoxAdapter(
              child: CarliEmptyState(
                icon: folderIcon,
                title: 'Esta carpeta ya no existe',
                message: 'Puede que la hayas borrado o movido desde otro sitio.',
              ),
            ),
        ],
      );
    }
    final tree = index.tree;
    final path = tree.pathTo(folder.parentId);
    final subfolders = tree.childrenOf(folder.id);
    final notes = index.notesIn(folder.id);
    return CarliPage(
      title: folder.name,
      trailing: RoundIconButton(
        icon: moreIcon,
        label: 'Opciones de la carpeta',
        onTap: () async {
          final deleted = await showFolderMenu(context, ref, folder);
          if (deleted && context.mounted) context.pop();
        },
      ),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16),
          sliver: SliverList.list(
            children: [
              const OfflineNotice(),
              _Breadcrumbs(path: path),
              if (subfolders.isNotEmpty) ...[
                const SectionLabel('Carpetas'),
                GroupedRows(
                  indent: 60,
                  children: [
                    for (final child in subfolders)
                      FolderRow(
                        folder: child,
                        count: index.recursiveCount(child.id),
                        onTap: () => context.push(NotesPaths.folder(child.id)),
                        onMenu: () => showFolderMenu(context, ref, child),
                      ),
                  ],
                ),
              ],
              const SectionLabel('Notas'),
              if (notes.isEmpty)
                Text(
                  'Pulsa + para crear una nota en esta carpeta.',
                  style: CarliType.small.copyWith(color: colors.text2),
                )
              else
                GroupedRows(
                  indent: 60,
                  children: [
                    for (final note in notes)
                      SwipeToDelete(
                        id: note.id,
                        onDelete: () => deleteNoteWithUndo(ref, note),
                        child: NoteRow(note: note, onTap: () => context.push(NotesPaths.note(note.id))),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Breadcrumbs extends StatelessWidget {
  const _Breadcrumbs({required this.path});

  final List<NoteFolder> path;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = CarliType.small.copyWith(color: colors.brandInk);
    return Semantics(
      label: 'Ruta: ${['Notas', ...path.map((folder) => folder.name)].join(', ')}',
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: CarliSpace.s4,
        children: [
          GestureDetector(
            onTap: () => context.go(NotesPaths.root),
            child: Text('Notas', style: style),
          ),
          for (final folder in path) ...[
            Text('›', style: CarliType.small.copyWith(color: colors.text3)),
            GestureDetector(
              onTap: () => context.go(NotesPaths.folder(folder.id)),
              child: Text(folder.name, style: style),
            ),
          ],
        ],
      ),
    );
  }
}
