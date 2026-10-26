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
import '../../../ui/toast.dart';
import '../data/models.dart';
import '../data/notes_actions.dart';
import '../data/notes_store.dart';
import '../data/notes_sync.dart';
import '../data/restock.dart';
import '../data/views.dart';
import '../notes_paths.dart';
import '../ui/notes_sheets.dart';
import '../ui/notes_widgets.dart';
import '../ui/shopping_sheets.dart';

final selectedShoppingListProvider = NotifierProvider<SelectedShoppingList, String?>(SelectedShoppingList.new);

class SelectedShoppingList extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? id) => state = id;
}

/// Bumped by the "+" button of the Compra tab to put the cursor in the quick-add field.
final shoppingAddRequestsProvider = NotifierProvider<ShoppingAddRequests, int>(ShoppingAddRequests.new);

class ShoppingAddRequests extends Notifier<int> {
  @override
  int build() => 0;

  void request() => state++;
}

class ShoppingScreen extends ConsumerWidget {
  const ShoppingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(notesIndexProvider).value;
    if (index == null) return const Scaffold(body: SizedBox.expand());
    final selectedId = ref.watch(selectedShoppingListProvider);
    final lists = index.shoppingNotes();
    final note = lists.where((note) => note.id == selectedId).firstOrNull ?? index.primaryShoppingNote;
    if (note == null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: CarliEmptyState(
              icon: noteTypeIcon(NoteType.shopping),
              title: 'Tu lista de la compra',
              message: 'Por secciones del súper, con lo que sueles comprar y productos que vuelven solos.',
              actionLabel: 'Crear lista',
              onAction: () => ref.read(notesActionsProvider).createNote(NoteType.shopping, title: 'Súper'),
            ),
          ),
        ),
      );
    }
    return Scaffold(
      body: ShoppingListView(key: ValueKey(note.id), noteId: note.id, switchable: true),
    );
  }
}

class ShoppingListView extends ConsumerStatefulWidget {
  const ShoppingListView({
    super.key,
    required this.noteId,
    this.showBack = false,
    this.switchable = false,
    this.fresh = false,
  });

  final String noteId;
  final bool showBack;
  final bool switchable;
  final bool fresh;

  @override
  ConsumerState<ShoppingListView> createState() => _ShoppingListViewState();
}

enum _ShoppingMenu { restock, rename, primary, more, settings }

class _ShoppingListViewState extends ConsumerState<ShoppingListView> {
  final _add = TextEditingController();
  final _addFocus = FocusNode();
  var _cartExpanded = false;

  NotesActions get _actions => ref.read(notesActionsProvider);

  @override
  void initState() {
    super.initState();
    _add.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _actions.refreshRestock();
      if (widget.fresh) _addFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _add.dispose();
    _addFocus.dispose();
    super.dispose();
  }

  Future<void> _submit(String value, Note note) async {
    final text = value.trim();
    if (text.isEmpty) return;
    _add.clear();
    await _actions.addProduct(note.id, text);
    _addFocus.requestFocus();
  }

  Future<void> _remove(NoteItem item) async {
    await _actions.deleteItem(item);
    ref
        .read(toastControllerProvider.notifier)
        .withUndo('${item.text} quitado', () => _actions.restoreItem(item), duration: noteUndoWindow);
  }

  Future<void> _finish(Note note, List<ShoppingProduct> products) async {
    final confirmed = await showFinishShoppingSheet(context, note: note, products: products);
    if (confirmed != true) return;
    final undo = await _actions.finishShopping(note);
    final count = note.checkedCount;
    ref
        .read(toastControllerProvider.notifier)
        .withUndo(
          count == 1 ? 'Compra terminada: 1 producto' : 'Compra terminada: $count productos',
          undo,
          duration: noteUndoWindow,
        );
  }

  Future<void> _menu(Note note) async {
    final choice = await showActionMenu<_ShoppingMenu>(
      context,
      title: note.displayTitle,
      actions: [
        (_ShoppingMenu.restock, 'Reposición de productos', false),
        (_ShoppingMenu.rename, 'Renombrar lista', false),
        if (!note.isPrimary) (_ShoppingMenu.primary, 'Usar como lista principal', false),
        (_ShoppingMenu.more, 'Fijar, mover, archivar…', false),
        (_ShoppingMenu.settings, 'Ajustes de Notas', false),
      ],
    );
    if (!mounted) return;
    switch (choice) {
      case _ShoppingMenu.restock:
        await showRestockOverview(context, noteId: note.id);
      case _ShoppingMenu.rename:
        final name = await promptName(context, title: 'Renombrar lista', initial: note.title ?? '');
        if (name != null) await _actions.updateNote(note.id, title: name);
      case _ShoppingMenu.primary:
        await _actions.makePrimary(note.id);
      case _ShoppingMenu.more:
        await showNoteMenu(context, ref, note, leaveOnRemove: widget.showBack);
      case _ShoppingMenu.settings:
        context.push(NotesPaths.settings);
      case null:
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(shoppingAddRequestsProvider, (_, _) => _addFocus.requestFocus());
    final colors = context.colors;
    final index = ref.watch(notesIndexProvider).value ?? NotesIndex.empty;
    final note = index.note(widget.noteId);
    if (note == null) return const SizedBox.shrink();
    final products = index.productsOf(note.id);
    final productsById = {for (final product in products) product.id: product};
    final groups = groupBySection(note, index.sections);
    final cart = note.items.where((item) => item.checked).toList();
    final query = _add.text.trim();
    final suggestions = suggestionsFor(note, products, query: query, limit: query.isEmpty ? 6 : 4);
    final bottom = MediaQuery.paddingOf(context).bottom + (widget.showBack ? CarliSpace.s40 : 120);

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(CarliSpace.s16, widget.showBack ? 0 : CarliSpace.s16, CarliSpace.s16, bottom),
            sliver: SliverList.list(
              children: [
                if (widget.showBack) const _BackRow(),
                _Header(
                  note: note,
                  switchable: widget.switchable,
                  onSwitch: () => showShoppingListSwitcher(context, current: note.id),
                  onMenu: () => _menu(note),
                ),
                const SizedBox(height: CarliSpace.s16),
                const OfflineNotice(),
                _AddField(controller: _add, focusNode: _addFocus, onSubmitted: (value) => _submit(value, note)),
                if (suggestions.isNotEmpty) ...[
                  const SizedBox(height: CarliSpace.s8),
                  _Suggestions(
                    label: query.isEmpty ? 'Sueles comprar' : 'Ya lo compraste',
                    products: suggestions,
                    onPick: (product) => _submit(product.name, note),
                  ),
                ],
                if (groups.isEmpty && cart.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: CarliSpace.s32),
                    child: Text(
                      'La lista está vacía. Añade lo que te falta: se ordena solo por secciones del súper.',
                      textAlign: TextAlign.center,
                      style: CarliType.small.copyWith(color: colors.text2),
                    ),
                  ),
                for (final group in groups) ...[
                  SectionLabel(group.title),
                  GroupedRows(
                    children: [
                      for (final item in group.items)
                        SwipeToDelete(
                          id: item.id,
                          label: 'Quitar',
                          onDelete: () => _remove(item),
                          child: _ShoppingRow(
                            item: item,
                            product: productsById[item.productId],
                            onToggle: () => _actions.setChecked(item, true),
                            onEdit: () => showShoppingItemSheet(context, item: item),
                          ),
                        ),
                    ],
                  ),
                ],
                if (cart.isNotEmpty) ...[
                  SectionLabel(
                    'En el carro · ${cart.length}',
                    trailing: TextButton(
                      onPressed: () => setState(() => _cartExpanded = !_cartExpanded),
                      child: Text(_cartExpanded ? 'Ocultar' : 'Mostrar'),
                    ),
                  ),
                  if (_cartExpanded)
                    GroupedRows(
                      children: [
                        for (final item in cart)
                          _ShoppingRow(
                            item: item,
                            product: productsById[item.productId],
                            onToggle: () => _actions.setChecked(item, false),
                            onEdit: () => showShoppingItemSheet(context, item: item),
                          ),
                      ],
                    ),
                  const SizedBox(height: CarliSpace.s16),
                  Center(
                    child: CarliButton(
                      label: 'Terminar compra',
                      variant: CarliButtonVariant.secondary,
                      size: CarliButtonSize.md,
                      block: false,
                      onPressed: () => _finish(note, products),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BackRow extends StatelessWidget {
  const _BackRow();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Align(
      alignment: Alignment.centerLeft,
      child: Semantics(
        button: true,
        label: 'Volver',
        excludeSemantics: true,
        child: Pressable(
          onTap: () => context.canPop() ? context.pop() : context.go(NotesPaths.root),
          child: SizedBox(
            height: 52,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CarliIcon(carliIconNamed('chevron-left'), size: 22, color: colors.brandInk, strokeWidth: 2),
                Text('Notas', style: CarliType.body.copyWith(fontSize: 17, color: colors.brandInk)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.note, required this.switchable, required this.onSwitch, required this.onMenu});

  final Note note;
  final bool switchable;
  final VoidCallback onSwitch;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final title = Text(
      note.displayTitle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: CarliType.h1.copyWith(color: colors.text),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 2,
            children: [
              Text(
                note.openCount == 0 ? 'NADA POR COMPRAR' : '${note.openCount} POR COMPRAR',
                style: CarliType.eyebrow.copyWith(color: colors.text2),
              ),
              if (switchable)
                Semantics(
                  button: true,
                  hint: 'Cambiar de lista',
                  child: Pressable(
                    onTap: onSwitch,
                    child: Row(
                      spacing: 6,
                      children: [
                        Flexible(child: title),
                        CarliIcon(carliIconNamed('chevron-down'), size: 18, color: colors.text2, strokeWidth: 2.4),
                      ],
                    ),
                  ),
                )
              else
                title,
            ],
          ),
        ),
        RoundIconButton(icon: moreIcon, label: 'Reposición y ajustes de la lista', onTap: onMenu),
      ],
    );
  }
}

class _AddField extends StatelessWidget {
  const _AddField({required this.controller, required this.focusNode, required this.onSubmitted});

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.cardBorder),
      ),
      child: Row(
        spacing: 10,
        children: [
          CarliIcon(carliIconNamed('plus'), size: 20, color: colors.brandInk, strokeWidth: 2.2),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              onSubmitted: onSubmitted,
              style: CarliType.body.copyWith(fontSize: 17, color: colors.text),
              decoration: const InputDecoration.collapsed(hintText: 'Añadir producto'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Suggestions extends StatelessWidget {
  const _Suggestions({required this.label, required this.products, required this.onPick});

  final String label;
  final List<ShoppingProduct> products;
  final ValueChanged<ShoppingProduct> onPick;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        spacing: 6,
        children: [
          Text(label, style: CarliType.small.copyWith(color: colors.text2)),
          for (final product in products)
            Semantics(
              button: true,
              label: 'Añadir ${product.name}',
              excludeSemantics: true,
              child: Pressable(
                onTap: () => onPick(product),
                child: Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.surface2,
                    borderRadius: BorderRadius.circular(CarliRadius.chip),
                  ),
                  child: Text('+ ${product.name}', style: CarliType.small.copyWith(color: colors.text)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ShoppingRow extends StatelessWidget {
  const _ShoppingRow({required this.item, required this.product, required this.onToggle, required this.onEdit});

  final NoteItem item;
  final ShoppingProduct? product;
  final VoidCallback onToggle;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final restocks = (product?.restockMode ?? RestockMode.none) != RestockMode.none;
    return Semantics(
      button: true,
      checked: item.checked,
      label: [item.text, ?item.quantity, if (restocks) 'vuelve sola: ${restockLabel(product!)}'].join(', '),
      hint: item.checked ? 'Devolver a la lista' : 'Al carro',
      excludeSemantics: true,
      child: Pressable(
        onTap: onToggle,
        onLongPress: onEdit,
        pressedOpacity: 0.6,
        child: Container(
          color: colors.surface,
          padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16, vertical: 11),
          child: Row(
            spacing: CarliSpace.s12,
            children: [
              CheckCircle(checked: item.checked),
              Expanded(
                child: Text(
                  item.text,
                  style: CarliType.body.copyWith(
                    fontSize: 17,
                    color: item.checked ? colors.text2 : colors.text,
                    decoration: item.checked ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              if (restocks && !item.checked) CarliIcon(HugeIconsStrokeRounded.repeat, size: 14, color: colors.text2),
              if (item.quantity case final quantity?)
                Text(quantity, style: CarliType.money(CarliType.body).copyWith(color: colors.text2)),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onEdit,
                child: Padding(
                  padding: const EdgeInsets.only(left: CarliSpace.s4),
                  child: CarliIcon(carliIconNamed('info'), size: 18, color: colors.text3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
