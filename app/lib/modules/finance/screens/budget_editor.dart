import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../ui/icon.dart';
import '../../../ui/icon_names.dart';
import '../../../ui/money_input.dart';
import '../../../ui/switch.dart';
import '../data/finance_providers.dart';
import '../data/json.dart';
import '../data/models.dart';
import '../data/transactions_repository.dart';

class BudgetEditorLine {
  BudgetEditorLine({
    required this.categoryId,
    required this.name,
    required this.icon,
    required this.child,
    required this.initialAmount,
    required this.initialRollover,
  }) : amount = initialAmount,
       rollover = initialRollover;

  final String categoryId;
  final String name;
  final String icon;
  final bool child;
  final Cents? initialAmount;
  final bool initialRollover;
  Cents? amount;
  bool rollover;

  bool get changed => amount != initialAmount || rollover != initialRollover;
}

List<BudgetEditorLine> buildBudgetLines(CategoryIndex categories, List<BudgetRow> rows) {
  final existing = {for (final row in rows) row.categoryId: row};
  final lines = <BudgetEditorLine>[];
  void add(String id, String name, String icon, bool child) {
    final row = existing.remove(id);
    lines.add(
      BudgetEditorLine(
        categoryId: id,
        name: name,
        icon: icon,
        child: child,
        initialAmount: row?.amountCents,
        initialRollover: row?.rollover ?? false,
      ),
    );
  }

  for (final parent in categories.topLevel(CategoryKind.expense)) {
    add(parent.id, parent.name, parent.icon ?? fallbackCategoryIcon, false);
    for (final child in parent.children) {
      add(child.id, child.name, child.icon ?? parent.icon ?? fallbackCategoryIcon, true);
    }
  }
  for (final row in existing.values) {
    add(row.categoryId, row.category.name, row.category.icon ?? fallbackCategoryIcon, row.category.parent != null);
  }
  return lines;
}

List<Json> budgetChanges(List<BudgetEditorLine> lines) => [
  for (final line in lines)
    if (line.changed && !(line.amount == null && line.initialAmount == null))
      {'category_id': line.categoryId, 'amount_cents': line.amount, 'rollover': line.rollover},
];

Future<bool> showBudgetEditor(BuildContext context, BudgetOverview overview) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    builder: (context) => FractionallySizedBox(heightFactor: 0.94, child: BudgetEditor(overview: overview)),
  );
  return saved ?? false;
}

class BudgetEditor extends ConsumerStatefulWidget {
  const BudgetEditor({super.key, required this.overview});

  final BudgetOverview overview;

  @override
  ConsumerState<BudgetEditor> createState() => _BudgetEditorState();
}

class _BudgetEditorState extends ConsumerState<BudgetEditor> {
  List<BudgetEditorLine>? _lines;
  var _saving = false;
  String? _error;

  Future<void> _save(List<BudgetEditorLine> lines) async {
    final changes = budgetChanges(lines);
    if (changes.isEmpty) {
      Navigator.pop(context, false);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(budgetsRepositoryProvider).upsert(widget.overview.period.id, changes);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() => _error = apiErrorMessage(error, fallback: 'No se han podido guardar los presupuestos.'));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final categories = ref.watch(categoriesProvider).value;
    final lines = _lines ??= categories == null ? null : buildBudgetLines(categories, widget.overview.rows);

    return Column(
      children: [
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s8),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colors.border)),
          ),
          child: Row(
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                style: TextButton.styleFrom(foregroundColor: colors.text2, textStyle: CarliType.body),
                child: const Text('Cancelar'),
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Editar presupuestos', style: CarliType.h2.copyWith(color: colors.text)),
                    Text(widget.overview.period.name, style: CarliType.caption.copyWith(color: colors.text3)),
                  ],
                ),
              ),
              SizedBox(
                width: 88,
                child: _saving
                    ? const Center(
                        child: SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : TextButton(onPressed: lines == null ? null : () => _save(lines), child: const Text('Guardar')),
              ),
            ],
          ),
        ),
        Expanded(
          child: lines == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(CarliSpace.s16, CarliSpace.s12, CarliSpace.s16, CarliSpace.s32),
                  children: [
                    Text(
                      'Deja el importe vacío para quitar el presupuesto. Un presupuesto de categoría principal incluye sus subcategorías. Activa "Arrastrar" para pasar el sobrante o el exceso al siguiente periodo.',
                      style: CarliType.small.copyWith(color: colors.text2),
                    ),
                    if (_error case final error?)
                      Padding(
                        padding: const EdgeInsets.only(top: CarliSpace.s12),
                        child: Text(error, style: CarliType.small.copyWith(color: colors.negative)),
                      ),
                    const SizedBox(height: CarliSpace.s12),
                    for (final line in lines) _EditorRow(line: line, onChanged: () => setState(() {})),
                  ],
                ),
        ),
      ],
    );
  }
}

class _EditorRow extends StatelessWidget {
  const _EditorRow({required this.line, required this.onChanged});

  final BudgetEditorLine line;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: EdgeInsets.only(left: line.child ? CarliSpace.s24 : 0, top: CarliSpace.s8, bottom: CarliSpace.s8),
      child: Row(
        spacing: CarliSpace.s8,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: colors.surface2, shape: BoxShape.circle),
            child: CarliIcon(carliIconNamed(line.icon), size: 16, color: colors.text),
          ),
          Expanded(
            child: Text(
              line.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: CarliType.body.copyWith(
                color: colors.text,
                fontWeight: line.child ? FontWeight.w400 : FontWeight.w500,
              ),
            ),
          ),
          SizedBox(
            width: 128,
            child: CarliMoneyInput(
              value: line.amount,
              appearance: MoneyInputAppearance.field,
              placeholder: 'Sin límite',
              semanticLabel: 'Límite de ${line.name}',
              onChanged: (value) {
                line.amount = value;
                onChanged();
              },
            ),
          ),
          CarliSwitch(
            value: line.rollover,
            semanticLabel: 'Arrastrar sobrante o exceso de ${line.name}',
            onChanged: (value) {
              line.rollover = value;
              onChanged();
            },
          ),
        ],
      ),
    );
  }
}
