import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/styles/stroke_rounded.dart';

import '../../../core/format/dates.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../ui/button.dart';
import '../../../ui/chip.dart';
import '../../../ui/field.dart';
import '../../../ui/icon.dart';
import '../../../ui/icon_names.dart';
import '../../../ui/pressable.dart';
import '../../../ui/segmented.dart';
import '../../../ui/sheet.dart';
import '../data/models.dart';
import '../data/notes_actions.dart';
import '../data/notes_format.dart';
import '../data/notes_store.dart';
import '../data/notes_sync.dart';
import '../data/restock.dart';
import '../data/views.dart';
import '../screens/shopping_view.dart';
import 'notes_widgets.dart';

const restockDisclaimer =
    'Cuando le toca, vuelve a la lista sin marcar. Cuenta desde la última vez que lo compraste. '
    'No crea tareas ni avisos.';

Future<bool?> showFinishShoppingSheet(
  BuildContext context, {
  required Note note,
  required List<ShoppingProduct> products,
}) => showCarliSheet<bool>(
  context,
  title: 'Terminar compra',
  builder: (context) => _FinishShopping(note: note, products: products),
);

class _FinishShopping extends StatelessWidget {
  const _FinishShopping({required this.note, required this.products});

  final Note note;
  final List<ShoppingProduct> products;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final byId = {for (final product in products) product.id: product};
    final cart = note.items.where((item) => item.checked).toList();
    final inCart = [for (final item in cart) ?byId[item.productId]];
    final everyTrip = [
      for (final product in inCart)
        if (product.restockMode == RestockMode.everyTrip) product.name,
    ];
    final interval = [
      for (final product in inCart)
        if (product.restockMode == RestockMode.interval) product.name,
    ];

    Widget line(CarliIconData icon, String title, String subtitle) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16, vertical: CarliSpace.s12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: CarliSpace.s12,
        children: [
          CarliIcon(icon, size: 20, color: colors.text),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(title, style: CarliType.body.copyWith(color: colors.text)),
                Text(subtitle, style: CarliType.small.copyWith(color: colors.text2)),
              ],
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(CarliSpace.s16, 0, CarliSpace.s16, CarliSpace.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: CarliSpace.s16,
        children: [
          Text(
            cart.length == 1 ? '1 producto en el carro' : '${cart.length} productos en el carro',
            style: CarliType.small.copyWith(color: colors.text2),
          ),
          GroupedRows(
            indent: 48,
            children: [
              line(
                HugeIconsStrokeRounded.shoppingCart01,
                'Se vacía el carro',
                'Puedes deshacerlo durante unos segundos',
              ),
              if (everyTrip.isNotEmpty)
                line(
                  HugeIconsStrokeRounded.repeat,
                  '${_names(everyTrip)} ${everyTrip.length == 1 ? 'vuelve' : 'vuelven'} ya',
                  'Se reponen en cada compra',
                ),
              if (interval.isNotEmpty)
                line(HugeIconsStrokeRounded.calendar03, _names(interval), 'Vuelven cuando les toque'),
            ],
          ),
          CarliButton(label: 'Terminar compra', onPressed: () => Navigator.pop(context, true)),
          CarliButton(
            label: 'Cancelar',
            variant: CarliButtonVariant.ghost,
            onPressed: () => Navigator.pop(context, false),
          ),
        ],
      ),
    );
  }

  static String _names(List<String> names) {
    if (names.length == 1) return names.single;
    final shown = names.take(3).toList();
    final rest = names.length - shown.length;
    return rest > 0
        ? '${shown.join(', ')} y $rest más'
        : '${shown.sublist(0, shown.length - 1).join(', ')} y ${shown.last}';
  }
}

Future<void> showShoppingListSwitcher(BuildContext context, {required String current}) => showCarliSheet<void>(
  context,
  title: 'Listas de la compra',
  builder: (context) => _ListSwitcher(current: current),
);

class _ListSwitcher extends ConsumerWidget {
  const _ListSwitcher({required this.current});

  final String current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final lists = (ref.watch(notesIndexProvider).value ?? NotesIndex.empty).shoppingNotes();
    return Padding(
      padding: const EdgeInsets.fromLTRB(CarliSpace.s16, 0, CarliSpace.s16, CarliSpace.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: CarliSpace.s12,
        children: [
          GroupedRows(
            indent: 16,
            children: [
              for (final note in lists)
                Pressable(
                  onTap: () {
                    ref.read(selectedShoppingListProvider.notifier).select(note.id);
                    Navigator.pop(context);
                  },
                  pressedOpacity: 0.5,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16, vertical: 13),
                    child: Row(
                      spacing: CarliSpace.s8,
                      children: [
                        Expanded(
                          child: Text(
                            note.displayTitle,
                            style: CarliType.body.copyWith(fontSize: 17, color: colors.text),
                          ),
                        ),
                        if (note.isPrimary) Text('Principal', style: CarliType.small.copyWith(color: colors.text2)),
                        Text('${note.openCount}', style: CarliType.small.copyWith(color: colors.text2)),
                        if (note.id == current) CarliIcon(carliIconNamed('check'), size: 18, color: colors.brandInk),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          CarliButton(
            label: 'Nueva lista de la compra',
            variant: CarliButtonVariant.secondary,
            icon: carliIconNamed('plus'),
            onPressed: () async {
              final name = await promptName(
                context,
                title: 'Nueva lista',
                placeholder: 'Farmacia, Bricolaje…',
                confirmLabel: 'Crear',
              );
              if (name == null) return;
              final id = await ref.read(notesActionsProvider).createNote(NoteType.shopping, title: name);
              ref.read(selectedShoppingListProvider.notifier).select(id);
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

Future<void> showShoppingItemSheet(BuildContext context, {required NoteItem item}) => showCarliSheet<void>(
  context,
  title: 'Producto',
  builder: (context) => _ShoppingItemSheet(item: item),
);

class _ShoppingItemSheet extends ConsumerStatefulWidget {
  const _ShoppingItemSheet({required this.item});

  final NoteItem item;

  @override
  ConsumerState<_ShoppingItemSheet> createState() => _ShoppingItemSheetState();
}

class _ShoppingItemSheetState extends ConsumerState<_ShoppingItemSheet> {
  late final _name = TextEditingController(text: widget.item.text);
  late final _quantity = TextEditingController(text: widget.item.quantity ?? '');
  late String? _sectionId = widget.item.sectionId;

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    await ref
        .read(notesActionsProvider)
        .updateShoppingItem(widget.item, text: _name.text, quantity: _quantity.text, sectionId: _sectionId);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final index = ref.watch(notesIndexProvider).value ?? NotesIndex.empty;
    final product = index.products.where((product) => product.id == widget.item.productId).firstOrNull;
    return Padding(
      padding: const EdgeInsets.fromLTRB(CarliSpace.s20, 0, CarliSpace.s20, CarliSpace.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: CarliSpace.s16,
        children: [
          CarliField(
            label: 'Nombre',
            child: CarliInput(controller: _name, textInputAction: TextInputAction.next),
          ),
          CarliField(
            label: 'Cantidad',
            hint: 'Texto libre: "2", "1 kg". Se recuerda para la próxima vez.',
            child: CarliInput(controller: _quantity, placeholder: 'Opcional'),
          ),
          CarliField(
            label: 'Sección',
            hint: 'Se recuerda para este producto.',
            child: Wrap(
              spacing: CarliSpace.s8,
              runSpacing: CarliSpace.s8,
              children: [
                for (final section in index.sections)
                  CarliChip(
                    label: section.name,
                    selected: section.id == _sectionId,
                    onTap: () => setState(() => _sectionId = section.id),
                  ),
              ],
            ),
          ),
          if (product != null)
            Pressable(
              onTap: () => showProductRestockSheet(context, productId: product.id),
              child: Container(
                padding: const EdgeInsets.all(CarliSpace.s12),
                decoration: BoxDecoration(color: colors.surface2, borderRadius: BorderRadius.circular(CarliRadius.md)),
                child: Row(
                  spacing: CarliSpace.s12,
                  children: [
                    CarliIcon(HugeIconsStrokeRounded.repeat, size: 18, color: colors.text),
                    Expanded(
                      child: Text('Reposición', style: CarliType.body.copyWith(color: colors.text)),
                    ),
                    Text(restockLabel(product), style: CarliType.small.copyWith(color: colors.text2)),
                    CarliIcon(carliIconNamed('chevron-right'), size: 16, color: colors.text3),
                  ],
                ),
              ),
            ),
          CarliButton(label: 'Guardar', onPressed: _save),
        ],
      ),
    );
  }
}

Future<void> showProductRestockSheet(BuildContext context, {required String productId}) => showCarliSheet<void>(
  context,
  title: 'Reposición',
  builder: (context) => _ProductRestockSheet(productId: productId),
);

enum _Unit { days, weeks }

class _ProductRestockSheet extends ConsumerStatefulWidget {
  const _ProductRestockSheet({required this.productId});

  final String productId;

  @override
  ConsumerState<_ProductRestockSheet> createState() => _ProductRestockSheetState();
}

class _ProductRestockSheetState extends ConsumerState<_ProductRestockSheet> {
  RestockMode? _mode;
  var _amount = 1;
  var _unit = _Unit.weeks;

  void _init(ShoppingProduct product) {
    if (_mode != null) return;
    _mode = product.restockMode;
    final days = product.restockIntervalDays ?? 7;
    if (days % 7 == 0) {
      _amount = days ~/ 7;
      _unit = _Unit.weeks;
    } else {
      _amount = days;
      _unit = _Unit.days;
    }
  }

  int get _days => _unit == _Unit.weeks ? _amount * 7 : _amount;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final index = ref.watch(notesIndexProvider).value ?? NotesIndex.empty;
    final product = index.products.where((product) => product.id == widget.productId).firstOrNull;
    if (product == null) return const SizedBox.shrink();
    _init(product);
    final mode = _mode!;
    final last = product.lastBoughtAt;
    return Padding(
      padding: const EdgeInsets.fromLTRB(CarliSpace.s20, 0, CarliSpace.s20, CarliSpace.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: CarliSpace.s16,
        children: [
          Text(product.name, style: CarliType.h2.copyWith(color: colors.text)),
          CarliSegmented<RestockMode>(
            value: mode,
            segments: const [
              CarliSegment(RestockMode.none, 'Sin repetir'),
              CarliSegment(RestockMode.everyTrip, 'Cada compra'),
              CarliSegment(RestockMode.interval, 'Cada…'),
            ],
            onChanged: (value) => setState(() => _mode = value),
          ),
          if (mode == RestockMode.interval)
            Row(
              spacing: CarliSpace.s12,
              children: [
                CarliButton.icon(
                  icon: carliIconNamed('minus'),
                  semanticLabel: 'Menos',
                  onPressed: _amount > 1 ? () => setState(() => _amount--) : null,
                ),
                Expanded(
                  child: Text(
                    '$_amount',
                    textAlign: TextAlign.center,
                    style: CarliType.money(CarliType.metric).copyWith(color: colors.text),
                  ),
                ),
                CarliButton.icon(
                  icon: carliIconNamed('plus'),
                  semanticLabel: 'Más',
                  onPressed: _amount < 365 ? () => setState(() => _amount++) : null,
                ),
                SizedBox(
                  width: 150,
                  child: CarliSegmented<_Unit>(
                    value: _unit,
                    segments: const [CarliSegment(_Unit.days, 'días'), CarliSegment(_Unit.weeks, 'semanas')],
                    onChanged: (value) => setState(() => _unit = value),
                  ),
                ),
              ],
            ),
          Text(
            [
              if (last != null)
                'Última compra: ${formatShortDate(last.toLocal())}.'
              else
                'Aún no lo has comprado con esta lista.',
              restockDisclaimer,
            ].join(' '),
            style: CarliType.small.copyWith(color: colors.text2),
          ),
          CarliButton(
            label: 'Guardar',
            onPressed: () async {
              await ref.read(notesActionsProvider).setRestock(product, mode, intervalDays: _days);
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

Future<void> showRestockOverview(BuildContext context, {required String noteId}) => showCarliSheet<void>(
  context,
  title: 'Reposición',
  builder: (context) => _RestockOverview(noteId: noteId),
);

class _RestockOverview extends ConsumerWidget {
  const _RestockOverview({required this.noteId});

  final String noteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final index = ref.watch(notesIndexProvider).value ?? NotesIndex.empty;
    final note = index.note(noteId);
    final products = index.productsOf(noteId)..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final listed = {for (final item in note?.items ?? const <NoteItem>[]) ?item.productId};
    final restocking = products.where((product) => product.restockMode != RestockMode.none).toList();
    final others = products.where((product) => product.restockMode == RestockMode.none).toList();

    String next(ShoppingProduct product) {
      if (listed.contains(product.id)) {
        return product.defaultQuantity == null ? 'En la lista' : 'En la lista · ${product.defaultQuantity}';
      }
      final date = restockDate(product);
      return date == null ? 'Cuando lo compres' : restockReturnLabel(date);
    }

    Widget row(ShoppingProduct product, {required bool showNext}) => Pressable(
      onTap: () => showProductRestockSheet(context, productId: product.id),
      pressedOpacity: 0.5,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16, vertical: CarliSpace.s12),
        child: Row(
          spacing: CarliSpace.s12,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 2,
                children: [
                  Text(product.name, style: CarliType.body.copyWith(fontSize: 17, color: colors.text)),
                  if (showNext) Text(next(product), style: CarliType.small.copyWith(color: colors.text2)),
                ],
              ),
            ),
            Text(restockLabel(product), style: CarliType.small.copyWith(color: colors.text2)),
            CarliIcon(carliIconNamed('chevron-right'), size: 16, color: colors.text3),
          ],
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(CarliSpace.s16, 0, CarliSpace.s16, CarliSpace.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (products.isEmpty)
            Text(
              'Aquí aparecerán los productos que añadas a la lista. Elige cuáles vuelven solos y cada cuánto.',
              style: CarliType.small.copyWith(color: colors.text2),
            ),
          if (restocking.isNotEmpty) ...[
            const SectionLabel('Se reponen solos'),
            GroupedRows(indent: 16, children: [for (final product in restocking) row(product, showNext: true)]),
            Padding(
              padding: const EdgeInsets.fromLTRB(CarliSpace.s4, CarliSpace.s8, CarliSpace.s4, 0),
              child: Text(restockDisclaimer, style: CarliType.small.copyWith(color: colors.text2)),
            ),
          ],
          if (others.isNotEmpty) ...[
            const SectionLabel('Sin repetir'),
            GroupedRows(indent: 16, children: [for (final product in others) row(product, showNext: false)]),
          ],
        ],
      ),
    );
  }
}
