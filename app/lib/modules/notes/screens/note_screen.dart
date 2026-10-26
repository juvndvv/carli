import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/styles/stroke_rounded.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../ui/button.dart';
import '../../../ui/empty_state.dart';
import '../../../ui/icon.dart';
import '../../../ui/icon_names.dart';
import '../../../ui/pressable.dart';
import '../../../ui/sheet.dart';
import '../../../ui/toast.dart';
import '../data/models.dart';
import '../data/notes_actions.dart';
import '../data/notes_format.dart';
import '../data/notes_store.dart';
import '../data/notes_sync.dart';
import '../data/views.dart';
import '../notes_paths.dart';
import '../ui/notes_sheets.dart';
import '../ui/notes_widgets.dart';
import 'shopping_view.dart';

class NoteScreen extends ConsumerWidget {
  const NoteScreen({super.key, required this.noteId, this.fresh = false});

  final String noteId;
  final bool fresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(notesIndexProvider).value;
    final note = index?.note(noteId);
    if (index == null) return const Scaffold(body: SizedBox.expand());
    if (note == null) {
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              const NoteTopBar(),
              CarliEmptyState(
                icon: noteTypeIcon(NoteType.text),
                title: 'Esta nota ya no existe',
                message: 'Puede que la hayas borrado definitivamente.',
              ),
            ],
          ),
        ),
      );
    }
    return switch (note.type) {
      NoteType.text => TextNoteEditor(key: ValueKey(note.id), note: note, fresh: fresh),
      NoteType.list => ListNoteView(key: ValueKey(note.id), note: note, fresh: fresh),
      NoteType.shopping => Scaffold(
        body: ShoppingListView(noteId: note.id, showBack: true, fresh: fresh),
      ),
    };
  }
}

class NoteTopBar extends StatelessWidget {
  const NoteTopBar({super.key, this.trailing = const [], this.status});

  final List<Widget> trailing;
  final String? status;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      height: 52,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s8),
        child: Row(
          children: [
            Semantics(
              button: true,
              label: 'Volver',
              excludeSemantics: true,
              child: Pressable(
                onTap: () => context.canPop() ? context.pop() : context.go(NotesPaths.root),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: CarliSpace.s8, horizontal: CarliSpace.s4),
                  child: Row(
                    children: [
                      CarliIcon(carliIconNamed('chevron-left'), size: 22, color: colors.brandInk, strokeWidth: 2),
                      Text('Notas', style: CarliType.body.copyWith(fontSize: 17, color: colors.brandInk)),
                    ],
                  ),
                ),
              ),
            ),
            const Spacer(),
            if (status case final status?)
              Padding(
                padding: const EdgeInsets.only(right: CarliSpace.s8),
                child: Text(status, style: CarliType.small.copyWith(color: colors.text2)),
              ),
            ...trailing,
          ],
        ),
      ),
    );
  }
}

class _TrashBanner extends ConsumerWidget {
  const _TrashBanner({required this.note});

  final Note note;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!note.deleted && !note.archived) return const SizedBox.shrink();
    final colors = context.colors;
    final actions = ref.read(notesActionsProvider);
    return Container(
      margin: const EdgeInsets.only(bottom: CarliSpace.s12),
      padding: const EdgeInsets.fromLTRB(CarliSpace.s12, CarliSpace.s8, CarliSpace.s4, CarliSpace.s8),
      decoration: BoxDecoration(color: colors.surface2, borderRadius: BorderRadius.circular(CarliRadius.md)),
      child: Row(
        children: [
          Expanded(
            child: Text(
              note.deleted ? 'Está en la papelera.' : 'Está archivada.',
              style: CarliType.small.copyWith(color: colors.text),
            ),
          ),
          TextButton(
            onPressed: () => note.deleted ? actions.setDeleted(note.id, false) : actions.setArchived(note.id, false),
            child: Text(note.deleted ? 'Restaurar' : 'Sacar del archivo'),
          ),
        ],
      ),
    );
  }
}

/// Plain-text note with autosave: there is no Save button, and a note left empty is discarded on the way out.
class TextNoteEditor extends ConsumerStatefulWidget {
  const TextNoteEditor({super.key, required this.note, this.fresh = false});

  final Note note;
  final bool fresh;

  @override
  ConsumerState<TextNoteEditor> createState() => _TextNoteEditorState();
}

class _TextNoteEditorState extends ConsumerState<TextNoteEditor> {
  static const _saveDelay = Duration(milliseconds: 500);

  late final _title = TextEditingController(text: widget.note.title ?? '');
  late final _body = TextEditingController(text: widget.note.body ?? '');
  late final NotesActions _actions = ref.read(notesActionsProvider);
  Timer? _save;
  var _dirty = false;

  @override
  void initState() {
    super.initState();
    _title.addListener(_changed);
    _body.addListener(_changed);
  }

  @override
  void dispose() {
    _save?.cancel();
    final id = widget.note.id;
    final flush = _dirty ? _actions.updateNote(id, title: _title.text, body: _body.text) : Future<void>.value();
    flush.then((_) => _actions.discardIfEmpty(id));
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  void _changed() {
    if (_title.text == (widget.note.title ?? '') && _body.text == (widget.note.body ?? '') && !_dirty) return;
    if (!_dirty) setState(() => _dirty = true);
    _save?.cancel();
    _save = Timer(_saveDelay, _flush);
  }

  Future<void> _flush() async {
    _save?.cancel();
    if (!_dirty) return;
    await _actions.updateNote(widget.note.id, title: _title.text, body: _body.text);
    if (mounted) setState(() => _dirty = false);
  }

  Future<void> _convert() async {
    await _flush();
    final note = ref.read(notesIndexProvider).value?.note(widget.note.id);
    if (note != null) await _actions.convert(note);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final note = widget.note;
    final path = ref.watch(notesIndexProvider.select((index) => index.value?.folderPathOf(note) ?? const []));
    final meta = [editedLabel(note.updatedAt), if (note.pinned) 'Fijada', if (path.isNotEmpty) path.join(' › ')];
    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            NoteTopBar(
              status: _dirty ? 'Guardando…' : 'Guardado',
              trailing: [
                RoundIconButton(
                  icon: moreIcon,
                  label: 'Más opciones',
                  onTap: () async {
                    await _flush();
                    if (context.mounted) await showNoteMenu(context, ref, note, leaveOnRemove: true);
                  },
                ),
              ],
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  CarliSpace.s20,
                  CarliSpace.s4,
                  CarliSpace.s20,
                  120 + MediaQuery.paddingOf(context).bottom,
                ),
                children: [
                  _TrashBanner(note: note),
                  TextField(
                    controller: _title,
                    autofocus: widget.fresh,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    style: CarliType.title2.copyWith(fontSize: 28, height: 34 / 28, color: colors.text),
                    decoration: const InputDecoration.collapsed(hintText: 'Título'),
                    maxLines: null,
                  ),
                  const SizedBox(height: CarliSpace.s8),
                  Text(meta.join(' · '), style: CarliType.small.copyWith(color: colors.text2)),
                  const SizedBox(height: CarliSpace.s12),
                  TextField(
                    controller: _body,
                    textCapitalization: TextCapitalization.sentences,
                    keyboardType: TextInputType.multiline,
                    maxLines: null,
                    minLines: 12,
                    style: CarliType.body.copyWith(fontSize: 17, height: 25 / 17, color: colors.text),
                    decoration: const InputDecoration.collapsed(hintText: 'Escribe aquí'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _NoteToolbar(note: note, onConvert: _convert, onBeforeAction: _flush),
    );
  }
}

class _NoteToolbar extends ConsumerWidget {
  const _NoteToolbar({required this.note, required this.onConvert, required this.onBeforeAction});

  final Note note;
  final Future<void> Function() onConvert;
  final Future<void> Function() onBeforeAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final actions = ref.read(notesActionsProvider);
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: CarliSpace.s8),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: CarliSpace.s16),
        padding: const EdgeInsets.symmetric(vertical: CarliSpace.s4),
        decoration: BoxDecoration(
          color: colors.surface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(CarliRadius.full),
          border: Border.all(color: colors.border),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, 8)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            RoundIconButton(icon: noteTypeIcon(NoteType.list), label: 'Convertir en lista', onTap: onConvert),
            RoundIconButton(
              icon: pinIcon,
              label: note.pinned ? 'Quitar de fijadas' : 'Fijar',
              active: note.pinned,
              onTap: () => actions.setPinned(note.id, !note.pinned),
            ),
            RoundIconButton(
              icon: HugeIconsStrokeRounded.copy01,
              label: 'Duplicar',
              onTap: () async {
                await onBeforeAction();
                final id = await actions.duplicate(note);
                if (context.mounted) context.pushReplacement(NotesPaths.note(id));
              },
            ),
            RoundIconButton(
              icon: HugeIconsStrokeRounded.archive,
              label: note.archived ? 'Sacar del archivo' : 'Archivar',
              active: note.archived,
              onTap: () async {
                await onBeforeAction();
                await actions.setArchived(note.id, !note.archived);
                if (!note.archived && context.mounted) {
                  ref
                      .read(toastControllerProvider.notifier)
                      .withUndo('Nota archivada', () => actions.setArchived(note.id, false), duration: noteUndoWindow);
                  context.pop();
                }
              },
            ),
            RoundIconButton(
              icon: HugeIconsStrokeRounded.delete02,
              label: 'Borrar',
              onTap: () async {
                await onBeforeAction();
                await deleteNoteWithUndo(ref, note);
                if (context.mounted) context.pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Reusable checklist: tap to tick, Enter chains the next item, long-press to drag, swipe to delete.
class ListNoteView extends ConsumerStatefulWidget {
  const ListNoteView({super.key, required this.note, this.fresh = false});

  final Note note;
  final bool fresh;

  @override
  ConsumerState<ListNoteView> createState() => _ListNoteViewState();
}

class _ListNoteViewState extends ConsumerState<ListNoteView> {
  late final _title = TextEditingController(text: widget.note.title ?? '');
  final _newItem = TextEditingController();
  final _newItemFocus = FocusNode();
  final _editors = <String, TextEditingController>{};
  final _focusNodes = <String, FocusNode>{};
  late final NotesActions _actions = ref.read(notesActionsProvider);
  String? _focusOnBuild;
  var _doneExpanded = false;

  @override
  void dispose() {
    final id = widget.note.id;
    final title = _title.text;
    final titleChanged = title != (widget.note.title ?? '');
    (titleChanged ? _actions.updateNote(id, title: title) : Future<void>.value()).then(
      (_) => _actions.discardIfEmpty(id),
    );
    _title.dispose();
    _newItem.dispose();
    _newItemFocus.dispose();
    for (final controller in _editors.values) {
      controller.dispose();
    }
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  TextEditingController _editor(NoteItem item) {
    final controller = _editors.putIfAbsent(item.id, () => TextEditingController(text: item.text));
    final focus = _focusNodes[item.id];
    if (!(focus?.hasFocus ?? false) && controller.text != item.text) controller.text = item.text;
    return controller;
  }

  FocusNode _focus(NoteItem item) => _focusNodes.putIfAbsent(item.id, () {
    final node = FocusNode();
    node.addListener(() {
      if (!node.hasFocus) _commit(item.id);
    });
    return node;
  });

  void _commit(String itemId) {
    final item = widget.note.items.where((item) => item.id == itemId).firstOrNull;
    final text = _editors[itemId]?.text.trim();
    if (item == null || text == null) return;
    if (text.isEmpty) {
      _actions.deleteItem(item);
    } else if (text != item.text) {
      _actions.renameItem(item, text);
    }
  }

  Future<void> _addAfter(NoteItem item) async {
    _commit(item.id);
    final id = await _actions.addItem(widget.note.id, '', position: item.position + 1);
    setState(() => _focusOnBuild = id);
  }

  Future<void> _addFromField(String value) async {
    if (value.trim().isEmpty) return;
    _newItem.clear();
    await _actions.addItem(widget.note.id, value);
    _newItemFocus.requestFocus();
  }

  Future<void> _delete(NoteItem item) async {
    await _actions.deleteItem(item);
    ref
        .read(toastControllerProvider.notifier)
        .withUndo('Elemento borrado', () => _actions.restoreItem(item), duration: noteUndoWindow);
  }

  Future<void> _startOver() async {
    final confirmed = await confirmCarli(
      context,
      title: 'Empezar de nuevo',
      message: 'Se desmarcan todos los elementos de la lista.',
      confirmLabel: 'Desmarcar todo',
    );
    if (confirmed) await _actions.uncheckAll(widget.note);
  }

  Future<void> _menu() async {
    final note = widget.note;
    final choice = await showActionMenu<String>(
      context,
      title: note.displayTitle,
      actions: [
        ('start-over', 'Empezar de nuevo', false),
        if (note.checkedBehavior == CheckedBehavior.move)
          ('inline', 'Dejar los marcados en su sitio', false)
        else
          ('move', 'Bajar los marcados a "Hechos"', false),
        ('more', 'Mover, duplicar, archivar…', false),
      ],
    );
    if (!mounted) return;
    switch (choice) {
      case 'start-over':
        await _startOver();
      case 'inline':
        await _actions.setCheckedBehavior(note.id, CheckedBehavior.inline);
      case 'move':
        await _actions.setCheckedBehavior(note.id, CheckedBehavior.move);
      case 'more':
        await showNoteMenu(context, ref, note, leaveOnRemove: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final note = widget.note;
    if (_focusOnBuild case final id?) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNodes[id]?.requestFocus();
        _focusOnBuild = null;
      });
    }
    final moveChecked = note.checkedBehavior == CheckedBehavior.move;
    final visible = moveChecked ? note.items.where((item) => !item.checked).toList() : note.items;
    final done = moveChecked ? note.items.where((item) => item.checked).toList() : const <NoteItem>[];
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            NoteTopBar(
              trailing: [
                RoundIconButton(
                  icon: pinIcon,
                  label: note.pinned ? 'Quitar de fijadas' : 'Fijar',
                  active: note.pinned,
                  onTap: () => _actions.setPinned(note.id, !note.pinned),
                ),
                RoundIconButton(icon: moreIcon, label: 'Más opciones', onTap: _menu),
              ],
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  CarliSpace.s16,
                  CarliSpace.s4,
                  CarliSpace.s16,
                  CarliSpace.s40 + MediaQuery.paddingOf(context).bottom,
                ),
                children: [
                  _TrashBanner(note: note),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    spacing: CarliSpace.s12,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _title,
                          autofocus: widget.fresh,
                          textCapitalization: TextCapitalization.sentences,
                          style: CarliType.h1.copyWith(color: colors.text),
                          decoration: const InputDecoration.collapsed(hintText: 'Título'),
                          maxLines: null,
                          onSubmitted: (_) => _newItemFocus.requestFocus(),
                          onTapOutside: (_) {
                            if (_title.text != (note.title ?? '')) _actions.updateNote(note.id, title: _title.text);
                          },
                        ),
                      ),
                      if (note.items.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            '${note.checkedCount} de ${note.items.length}',
                            style: CarliType.money(CarliType.h2).copyWith(color: colors.text),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: CarliSpace.s16),
                  Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(CarliRadius.lg),
                      border: Border.all(color: colors.cardBorder),
                    ),
                    child: Column(
                      children: [
                        ReorderableListView(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          buildDefaultDragHandles: false,
                          onReorderItem: (from, to) {
                            final ordered = [...visible];
                            ordered.insert(to, ordered.removeAt(from));
                            _actions.reorderItems([...ordered, ...done]);
                          },
                          children: [
                            for (final (position, item) in visible.indexed)
                              ReorderableDelayedDragStartListener(
                                key: ValueKey(item.id),
                                index: position,
                                child: SwipeToDelete(
                                  id: item.id,
                                  onDelete: () => _delete(item),
                                  child: _ItemRow(
                                    item: item,
                                    controller: _editor(item),
                                    focusNode: _focus(item),
                                    separated: position > 0,
                                    onToggle: () => _actions.setChecked(item, !item.checked),
                                    onSubmitted: () => _addAfter(item),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (visible.isNotEmpty) Divider(height: 1, thickness: 0.5, indent: 50, color: colors.border),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16, vertical: 11),
                          child: Row(
                            spacing: CarliSpace.s12,
                            children: [
                              CarliIcon(carliIconNamed('plus'), size: 22, color: colors.text2),
                              Expanded(
                                child: TextField(
                                  controller: _newItem,
                                  focusNode: _newItemFocus,
                                  autofocus: widget.fresh && note.items.isEmpty && (note.title ?? '').isNotEmpty,
                                  textCapitalization: TextCapitalization.sentences,
                                  textInputAction: TextInputAction.next,
                                  style: CarliType.body.copyWith(fontSize: 17, color: colors.text),
                                  decoration: const InputDecoration.collapsed(hintText: 'Nuevo elemento'),
                                  onSubmitted: _addFromField,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (done.isNotEmpty) ...[
                    SectionLabel(
                      'Hechos · ${done.length}',
                      trailing: TextButton(
                        onPressed: () => setState(() => _doneExpanded = !_doneExpanded),
                        child: Text(_doneExpanded ? 'Ocultar' : 'Mostrar'),
                      ),
                    ),
                    if (_doneExpanded)
                      GroupedRows(
                        children: [
                          for (final item in done)
                            SwipeToDelete(
                              id: item.id,
                              onDelete: () => _delete(item),
                              child: _ItemRow(
                                item: item,
                                controller: _editor(item),
                                focusNode: _focus(item),
                                onToggle: () => _actions.setChecked(item, false),
                              ),
                            ),
                        ],
                      ),
                  ],
                  const SizedBox(height: CarliSpace.s16),
                  GroupedRows(
                    indent: 48,
                    children: [
                      _ActionRow(
                        icon: HugeIconsStrokeRounded.arrowReloadHorizontal,
                        title: 'Empezar de nuevo',
                        subtitle: 'Desmarca todo. Se reinicia a mano.',
                        onTap: note.checkedCount == 0 ? null : _startOver,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.controller,
    required this.focusNode,
    required this.onToggle,
    this.onSubmitted,
    this.separated = false,
  });

  final NoteItem item;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onToggle;
  final VoidCallback? onSubmitted;
  final bool separated;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      color: colors.surface,
      child: Column(
        children: [
          if (separated) Divider(height: 1, thickness: 0.5, indent: 50, color: colors.border),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16, vertical: 11),
            child: Row(
              spacing: CarliSpace.s12,
              children: [
                Semantics(
                  checked: item.checked,
                  label: item.text,
                  button: true,
                  excludeSemantics: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onToggle,
                    child: CheckCircle(checked: item.checked),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: onSubmitted == null ? TextInputAction.done : TextInputAction.next,
                    onSubmitted: (_) => onSubmitted?.call(),
                    maxLines: null,
                    style: CarliType.body.copyWith(
                      fontSize: 17,
                      color: item.checked ? colors.text2 : colors.text,
                      decoration: item.checked ? TextDecoration.lineThrough : null,
                    ),
                    decoration: const InputDecoration.collapsed(hintText: ''),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.icon, required this.title, this.subtitle, this.onTap});

  final CarliIconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      enabled: onTap != null,
      child: Pressable(
        onTap: onTap,
        pressedOpacity: 0.5,
        child: Opacity(
          opacity: onTap == null ? 0.5 : 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16, vertical: CarliSpace.s12),
            child: Row(
              spacing: CarliSpace.s12,
              children: [
                CarliIcon(icon, size: 20, color: colors.text),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: CarliType.body.copyWith(fontSize: 17, color: colors.text)),
                      if (subtitle case final subtitle?)
                        Text(subtitle, style: CarliType.small.copyWith(color: colors.text2)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class NotesCollectionScreen extends ConsumerWidget {
  const NotesCollectionScreen({super.key, required this.trash});

  final bool trash;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final index = ref.watch(notesIndexProvider).value ?? NotesIndex.empty;
    final notes = trash ? index.trashedNotes : index.archivedNotes;
    final actions = ref.read(notesActionsProvider);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(CarliSpace.s16, 0, CarliSpace.s16, CarliSpace.s48),
          children: [
            const NoteTopBar(),
            Text(trash ? 'Papelera' : 'Archivadas', style: CarliType.h1.copyWith(color: colors.text)),
            const SizedBox(height: CarliSpace.s4),
            Text(
              trash
                  ? 'Las notas se borran definitivamente a los 30 días.'
                  : 'Fuera de la vista principal, pero siguen apareciendo en la búsqueda.',
              style: CarliType.small.copyWith(color: colors.text2),
            ),
            const SizedBox(height: CarliSpace.s16),
            if (notes.isEmpty)
              CarliEmptyState(
                icon: trash ? HugeIconsStrokeRounded.delete02 : HugeIconsStrokeRounded.archive,
                title: trash ? 'La papelera está vacía' : 'No hay notas archivadas',
                message: trash ? 'Lo que borres aparecerá aquí 30 días.' : 'Archiva lo que ya no usas a diario.',
              )
            else
              GroupedRows(
                indent: 60,
                children: [
                  for (final note in notes)
                    _CollectionRow(
                      note: note,
                      trash: trash,
                      onOpen: () => context.push(NotesPaths.note(note.id)),
                      onRestore: () => trash ? actions.setDeleted(note.id, false) : actions.setArchived(note.id, false),
                      onPurge: trash
                          ? () async {
                              final confirmed = await confirmCarli(
                                context,
                                title: 'Borrar definitivamente',
                                message: '"${note.displayTitle}" no se podrá recuperar.',
                                confirmLabel: 'Borrar',
                                destructive: true,
                              );
                              if (confirmed) await actions.purge(note.id);
                            }
                          : null,
                    ),
                ],
              ),
            if (trash && notes.isNotEmpty) ...[
              const SizedBox(height: CarliSpace.s16),
              CarliButton(
                label: 'Vaciar papelera',
                variant: CarliButtonVariant.secondary,
                onPressed: () async {
                  final confirmed = await confirmCarli(
                    context,
                    title: 'Vaciar papelera',
                    message: 'Se borran definitivamente ${notes.length} notas.',
                    confirmLabel: 'Vaciar',
                    destructive: true,
                  );
                  if (!confirmed) return;
                  for (final note in notes) {
                    await actions.purge(note.id);
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CollectionRow extends StatelessWidget {
  const _CollectionRow({
    required this.note,
    required this.trash,
    required this.onOpen,
    required this.onRestore,
    this.onPurge,
  });

  final Note note;
  final bool trash;
  final VoidCallback onOpen;
  final VoidCallback onRestore;
  final VoidCallback? onPurge;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final when = trash ? note.deletedAt! : note.archivedAt ?? note.updatedAt;
    return Pressable(
      onTap: onOpen,
      pressedOpacity: 0.5,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(CarliSpace.s16, CarliSpace.s8, CarliSpace.s4, CarliSpace.s8),
        child: Row(
          spacing: CarliSpace.s12,
          children: [
            NoteTypeBadge(note.type),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    note.displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: CarliType.bodyStrong.copyWith(color: colors.text),
                  ),
                  Text(
                    '${trash ? 'Borrada' : 'Archivada'} ${noteWhen(when).toLowerCase()}',
                    style: CarliType.small.copyWith(color: colors.text2),
                  ),
                ],
              ),
            ),
            TextButton(onPressed: onRestore, child: Text(trash ? 'Restaurar' : 'Sacar')),
            if (onPurge case final purge?)
              IconButton(
                tooltip: 'Borrar definitivamente',
                onPressed: purge,
                icon: CarliIcon(HugeIconsStrokeRounded.delete02, size: 18, color: colors.negative),
              ),
          ],
        ),
      ),
    );
  }
}
