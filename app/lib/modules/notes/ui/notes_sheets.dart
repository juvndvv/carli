import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/styles/stroke_rounded.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../ui/icon.dart';
import '../../../ui/icon_names.dart';
import '../../../ui/pressable.dart';
import '../../../ui/sheet.dart';
import '../../../ui/toast.dart';
import '../data/models.dart';
import '../data/notes_actions.dart';
import '../data/notes_store.dart';
import '../data/notes_sync.dart';
import '../data/views.dart';
import '../notes_paths.dart';
import 'notes_widgets.dart';

const noteUndoWindow = Duration(seconds: 4);

Future<NoteType?> showNoteTypeSheet(BuildContext context) =>
    showCarliSheet<NoteType>(context, title: 'Nueva', builder: (context) => const _NoteTypeSheet());

class _NoteTypeSheet extends StatelessWidget {
  const _NoteTypeSheet();

  static const _descriptions = {
    NoteType.text: ('Texto', 'Apuntes, datos, ideas'),
    NoteType.list: ('Lista', 'Elementos que marcas. Reutilizable con "Empezar de nuevo"'),
    NoteType.shopping: ('Lista de la compra', 'Por secciones, con habituales y sugerencias'),
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(CarliSpace.s16, 0, CarliSpace.s16, CarliSpace.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: CarliSpace.s12,
        children: [
          GroupedRows(
            indent: 60,
            children: [
              for (final MapEntry(key: type, value: (label, description)) in _descriptions.entries)
                Semantics(
                  button: true,
                  child: Pressable(
                    onTap: () => Navigator.pop(context, type),
                    pressedOpacity: 0.5,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16, vertical: 14),
                      child: Row(
                        spacing: CarliSpace.s12,
                        children: [
                          NoteTypeBadge(type),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              spacing: 2,
                              children: [
                                Text(label, style: CarliType.bodyStrong.copyWith(color: colors.text)),
                                Text(description, style: CarliType.small.copyWith(color: colors.text2)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Text(
            '¿Tiene fecha y quieres que te lo recuerde? Mejor una tarea.',
            textAlign: TextAlign.center,
            style: CarliType.small.copyWith(color: colors.text2),
          ),
        ],
      ),
    );
  }
}

class FolderChoice {
  const FolderChoice(this.folderId);

  final String? folderId;
}

/// Tree picker for moving a note or a folder. A folder can't move into itself or its subfolders.
Future<FolderChoice?> showFolderPicker(
  BuildContext context, {
  required String title,
  String? current,
  String? movingFolderId,
}) => showCarliSheet<FolderChoice>(
  context,
  title: title,
  builder: (context) => _FolderPicker(current: current, movingFolderId: movingFolderId),
);

class _FolderPicker extends ConsumerWidget {
  const _FolderPicker({required this.current, required this.movingFolderId});

  final String? current;
  final String? movingFolderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final index = ref.watch(notesIndexProvider).value ?? NotesIndex.empty;
    final entries = index.tree.flatten(excluding: movingFolderId);

    Widget row({required String? id, required String label, required int depth, required CarliIconData icon}) {
      final selected = id == current;
      return Semantics(
        button: true,
        selected: selected,
        child: Pressable(
          onTap: selected ? null : () => Navigator.pop(context, FolderChoice(id)),
          pressedOpacity: 0.5,
          child: Padding(
            padding: EdgeInsets.fromLTRB(CarliSpace.s16 + depth * 20.0, 13, CarliSpace.s16, 13),
            child: Row(
              spacing: CarliSpace.s12,
              children: [
                CarliIcon(icon, size: 18, color: selected ? colors.text3 : colors.text),
                Expanded(
                  child: Text(label, style: CarliType.body.copyWith(color: selected ? colors.text3 : colors.text)),
                ),
                if (selected) CarliIcon(carliIconNamed('check'), size: 18, color: colors.brandInk),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(CarliSpace.s16, 0, CarliSpace.s16, CarliSpace.s24),
      child: GroupedRows(
        indent: 46,
        children: [
          row(id: null, label: 'Notas (sin carpeta)', depth: 0, icon: HugeIconsStrokeRounded.home01),
          for (final (folder, depth) in entries) row(id: folder.id, label: folder.name, depth: depth, icon: folderIcon),
        ],
      ),
    );
  }
}

Future<void> startNewNote(BuildContext context, WidgetRef ref, {String? folderId}) async {
  final type = await showNoteTypeSheet(context);
  if (type == null || !context.mounted) return;
  final id = await ref.read(notesActionsProvider).createNote(type, folderId: folderId);
  if (context.mounted) context.push(NotesPaths.note(id, fresh: true));
}

Future<void> deleteNoteWithUndo(WidgetRef ref, Note note) async {
  final actions = ref.read(notesActionsProvider);
  await actions.setDeleted(note.id, true);
  ref
      .read(toastControllerProvider.notifier)
      .withUndo('Nota en la papelera', () => actions.setDeleted(note.id, false), duration: noteUndoWindow);
}

Future<void> moveNote(BuildContext context, WidgetRef ref, Note note) async {
  final choice = await showFolderPicker(context, title: 'Mover a', current: note.folderId);
  if (choice == null) return;
  await ref.read(notesActionsProvider).moveNote(note.id, choice.folderId);
  final index = ref.read(notesIndexProvider).value;
  final name = index?.folder(choice.folderId)?.name ?? 'Notas';
  ref.read(toastControllerProvider.notifier).show('Movida a $name');
}

enum _NoteMenu { pin, move, duplicate, convert, archive, delete }

Future<void> showNoteMenu(BuildContext context, WidgetRef ref, Note note, {bool leaveOnRemove = false}) async {
  final choice = await showActionMenu<_NoteMenu>(
    context,
    title: note.displayTitle,
    actions: [
      (_NoteMenu.pin, note.pinned ? 'Quitar de fijadas' : 'Fijar', false),
      (_NoteMenu.move, 'Mover a carpeta', false),
      (_NoteMenu.duplicate, 'Duplicar', false),
      if (note.type == NoteType.text) (_NoteMenu.convert, 'Convertir en lista', false),
      if (note.type == NoteType.list) (_NoteMenu.convert, 'Convertir en texto', false),
      (_NoteMenu.archive, note.archived ? 'Sacar del archivo' : 'Archivar', false),
      (_NoteMenu.delete, 'Borrar', true),
    ],
  );
  if (choice == null || !context.mounted) return;
  final actions = ref.read(notesActionsProvider);
  switch (choice) {
    case _NoteMenu.pin:
      await actions.setPinned(note.id, !note.pinned);
    case _NoteMenu.move:
      await moveNote(context, ref, note);
    case _NoteMenu.duplicate:
      final id = await actions.duplicate(note);
      if (context.mounted) context.push(NotesPaths.note(id));
    case _NoteMenu.convert:
      await actions.convert(note);
    case _NoteMenu.archive:
      await actions.setArchived(note.id, !note.archived);
      ref
          .read(toastControllerProvider.notifier)
          .withUndo(
            note.archived ? 'Nota fuera del archivo' : 'Nota archivada',
            () => actions.setArchived(note.id, note.archived),
            duration: noteUndoWindow,
          );
      if (leaveOnRemove && !note.archived && context.mounted) context.pop();
    case _NoteMenu.delete:
      await deleteNoteWithUndo(ref, note);
      if (leaveOnRemove && context.mounted) context.pop();
  }
}

enum _FolderMenu { subfolder, rename, move, delete }

/// Returns true when the folder was deleted.
Future<bool> showFolderMenu(BuildContext context, WidgetRef ref, NoteFolder folder) async {
  final choice = await showActionMenu<_FolderMenu>(
    context,
    title: folder.name,
    actions: const [
      (_FolderMenu.subfolder, 'Nueva subcarpeta', false),
      (_FolderMenu.rename, 'Renombrar', false),
      (_FolderMenu.move, 'Mover', false),
      (_FolderMenu.delete, 'Borrar carpeta', true),
    ],
  );
  if (choice == null || !context.mounted) return false;
  final actions = ref.read(notesActionsProvider);
  switch (choice) {
    case _FolderMenu.subfolder:
      final name = await promptName(context, title: 'Nueva subcarpeta', confirmLabel: 'Crear');
      if (name != null) await actions.createFolder(name, parentId: folder.id);
    case _FolderMenu.rename:
      final name = await promptName(context, title: 'Renombrar carpeta', initial: folder.name);
      if (name != null) await actions.renameFolder(folder.id, name);
    case _FolderMenu.move:
      final choice = await showFolderPicker(
        context,
        title: 'Mover carpeta a',
        current: folder.parentId,
        movingFolderId: folder.id,
      );
      if (choice != null) await actions.moveFolder(folder.id, choice.folderId);
    case _FolderMenu.delete:
      final parent = ref.read(notesIndexProvider).value?.folder(folder.parentId)?.name ?? 'Notas';
      final confirmed = await confirmCarli(
        context,
        title: 'Borrar "${folder.name}"',
        message: 'Sus notas y subcarpetas pasan a $parent. No se borra ninguna nota.',
        confirmLabel: 'Borrar carpeta',
        destructive: true,
      );
      if (!confirmed) return false;
      await actions.deleteFolder(folder.id);
      return true;
  }
  return false;
}
