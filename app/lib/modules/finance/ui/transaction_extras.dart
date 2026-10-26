import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/format/money.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../ui/button.dart';
import '../../../ui/chip.dart';
import '../../../ui/field.dart';
import '../../../ui/icon.dart';
import '../../../ui/icon_names.dart';
import '../../../ui/money_input.dart';
import '../../../ui/segmented.dart';
import '../../../ui/select.dart';
import '../../../ui/switch.dart';
import '../data/models.dart';
import '../data/transaction_form.dart';

class SwitchRow extends StatelessWidget {
  const SwitchRow({super.key, required this.label, required this.value, required this.onChanged});

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: CarliSpace.s8),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: CarliType.body.copyWith(color: context.colors.text)),
        ),
        CarliSwitch(value: value, semanticLabel: label, onChanged: onChanged),
      ],
    ),
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: CarliSpace.s8),
    padding: const EdgeInsets.all(CarliSpace.s12),
    decoration: BoxDecoration(color: context.colors.surface2, borderRadius: BorderRadius.circular(CarliRadius.md)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: CarliSpace.s12, children: children),
  );
}

class TagEditor extends StatelessWidget {
  const TagEditor({
    super.key,
    required this.tags,
    required this.controller,
    required this.suggestions,
    required this.onAdd,
    required this.onPick,
    required this.onRemove,
  });

  final List<String> tags;
  final TextEditingController controller;
  final List<String> suggestions;
  final VoidCallback onAdd;
  final ValueChanged<String> onPick;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: CarliSpace.s8,
      children: [
        if (tags.isNotEmpty)
          Wrap(
            spacing: CarliSpace.s8,
            runSpacing: CarliSpace.s8,
            children: [
              for (final tag in tags)
                CarliChip(
                  label: '#$tag',
                  icon: carliIconNamed('x'),
                  selected: true,
                  semanticLabel: 'Quitar #$tag',
                  onTap: () => onRemove(tag),
                ),
            ],
          ),
        CarliInput(
          controller: controller,
          placeholder: 'Añadir etiqueta',
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onAdd(),
          onChanged: (text) {
            if (text.endsWith(',') || text.endsWith(' ')) onAdd();
          },
        ),
        if (suggestions.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              spacing: CarliSpace.s8,
              children: [
                for (final name in suggestions.take(12)) CarliChip(label: '#$name', onTap: () => onPick(name)),
              ],
            ),
          ),
        if (tags.isEmpty && suggestions.isEmpty)
          Text('Separa varias con comas.', style: CarliType.caption.copyWith(color: colors.text3)),
      ],
    );
  }
}

class SharesPanel extends StatelessWidget {
  const SharesPanel({
    super.key,
    required this.locked,
    required this.lockedShares,
    required this.contacts,
    required this.mode,
    required this.includeSelf,
    required this.shares,
    required this.preview,
    required this.total,
    required this.onMode,
    required this.onIncludeSelf,
    required this.onToggle,
    required this.onChanged,
  });

  final bool locked;
  final List<TransactionShare> lockedShares;
  final List<ContactOption> contacts;
  final ShareMode mode;
  final bool includeSelf;
  final List<ShareDraft> shares;
  final List<SharePreview> preview;
  final Cents total;
  final ValueChanged<ShareMode> onMode;
  final ValueChanged<bool> onIncludeSelf;
  final ValueChanged<ContactOption> onToggle;
  final VoidCallback onChanged;

  String? get _summary {
    if (preview.isEmpty) return null;
    final shared = preview.fold<int>(0, (sum, item) => sum + item.amount);
    if (shared > total.abs()) return 'La parte compartida supera el importe del gasto.';
    final own = total.abs() - shared;
    return preview.length == 1
        ? '${preview.single.name} te debe ${formatMoney(preview.single.amount)} · tu parte ${formatMoney(own)}'
        : 'Te deben ${formatMoney(shared)} · tu parte ${formatMoney(own)}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (locked) {
      return _Panel(
        children: [
          Text(
            'Este gasto ya tiene partes liquidadas y no se puede cambiar el reparto.',
            style: CarliType.small.copyWith(color: colors.text2),
          ),
          for (final share in lockedShares)
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${share.name}${share.settled ? ' · liquidado' : ''}',
                    style: CarliType.small.copyWith(color: colors.text),
                  ),
                ),
                Text(
                  formatMoney(share.amountCents),
                  style: CarliType.money(CarliType.small).copyWith(color: colors.text),
                ),
              ],
            ),
        ],
      );
    }
    if (contacts.isEmpty) {
      return _Panel(
        children: [
          Text(
            'Aún no tienes contactos. Créalos en Más › Compartidos para repartir gastos.',
            style: CarliType.small.copyWith(color: colors.text2),
          ),
        ],
      );
    }
    final summary = _summary;
    return _Panel(
      children: [
        CarliSegmented<ShareMode>(
          segments: [for (final value in ShareMode.values) CarliSegment(value, value.label)],
          value: mode,
          onChanged: onMode,
        ),
        Wrap(
          spacing: CarliSpace.s8,
          runSpacing: CarliSpace.s8,
          children: [
            for (final contact in contacts)
              CarliChip(
                label: contact.name,
                selected: shares.any((share) => share.contactId == contact.id),
                onTap: () => onToggle(contact),
              ),
          ],
        ),
        if (mode == ShareMode.equal)
          SwitchRow(label: 'Incluirme en el reparto', value: includeSelf, onChanged: onIncludeSelf),
        for (final (index, share) in shares.indexed)
          Row(
            spacing: CarliSpace.s8,
            children: [
              Expanded(
                child: Text(share.name, style: CarliType.body.copyWith(color: colors.text)),
              ),
              if (mode == ShareMode.percentage)
                SizedBox(
                  width: 96,
                  child: _PercentField(
                    key: ValueKey('percent-${share.contactId}'),
                    value: share.percentage,
                    label: 'Porcentaje de ${share.name}',
                    onChanged: (value) {
                      share.percentage = value;
                      onChanged();
                    },
                  ),
                )
              else if (mode == ShareMode.amount)
                SizedBox(
                  width: 140,
                  child: CarliMoneyInput(
                    key: ValueKey('amount-${share.contactId}'),
                    value: share.amount,
                    appearance: MoneyInputAppearance.field,
                    semanticLabel: 'Parte de ${share.name}',
                    onChanged: (value) {
                      share.amount = value;
                      onChanged();
                    },
                  ),
                ),
              SizedBox(
                width: 84,
                child: Text(
                  formatMoney(index < preview.length ? preview[index].amount : 0),
                  textAlign: TextAlign.end,
                  style: CarliType.money(CarliType.small).copyWith(color: colors.text2),
                ),
              ),
            ],
          ),
        if (summary != null)
          Text(
            summary,
            style: CarliType.small.copyWith(color: summary.startsWith('La parte') ? colors.negative : colors.text2),
          ),
      ],
    );
  }
}

class _PercentField extends StatefulWidget {
  const _PercentField({super.key, required this.value, required this.label, required this.onChanged});

  final double? value;
  final String label;
  final ValueChanged<double?> onChanged;

  @override
  State<_PercentField> createState() => _PercentFieldState();
}

class _PercentFieldState extends State<_PercentField> {
  late final _controller = TextEditingController(
    text: widget.value == null ? '' : '${widget.value}'.replaceFirst(RegExp(r'\.0$'), '').replaceAll('.', ','),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.label,
    textField: true,
    child: CarliInput(
      controller: _controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      suffix: Padding(
        padding: const EdgeInsets.only(right: CarliSpace.s12),
        child: Text('%', style: CarliType.body.copyWith(color: context.colors.text3)),
      ),
      onChanged: (text) => widget.onChanged(double.tryParse(text.replaceAll(',', '.'))),
    ),
  );
}

class SplitsPanel extends StatelessWidget {
  const SplitsPanel({
    super.key,
    required this.splits,
    required this.remaining,
    required this.categories,
    required this.onChanged,
    required this.onAdd,
    required this.onRemove,
  });

  final List<SplitDraft> splits;
  final Cents remaining;
  final List<CarliOption<String>> categories;
  final VoidCallback onChanged;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (label, color) = switch (remaining) {
      0 => ('Reparto completo', colors.text2),
      > 0 => ('Quedan ${formatMoney(remaining)} por asignar', colors.negative),
      _ => ('Te pasas en ${formatMoney(-remaining)}', colors.negative),
    };
    return _Panel(
      children: [
        for (final (index, split) in splits.indexed)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: CarliSpace.s8,
            children: [
              CarliSelect<String>(
                title: 'Categoría de la parte ${index + 1}',
                placeholder: 'Categoría',
                options: categories,
                value: split.categoryId,
                onChanged: (id) {
                  split.categoryId = id;
                  onChanged();
                },
              ),
              Row(
                spacing: CarliSpace.s8,
                children: [
                  Expanded(
                    child: CarliMoneyInput(
                      key: ObjectKey(split),
                      value: split.amount,
                      appearance: MoneyInputAppearance.field,
                      semanticLabel: 'Importe de la parte ${index + 1}',
                      onChanged: (value) {
                        split.amount = value;
                        onChanged();
                      },
                    ),
                  ),
                  CarliButton.icon(
                    icon: carliIconNamed('x'),
                    semanticLabel: 'Quitar parte ${index + 1}',
                    size: CarliButtonSize.sm,
                    onPressed: () => onRemove(index),
                  ),
                ],
              ),
            ],
          ),
        Row(
          children: [
            TextButton.icon(
              onPressed: onAdd,
              icon: CarliIcon(carliIconNamed('plus'), size: 18, color: colors.brandInk),
              label: const Text('Añadir parte'),
            ),
            const Spacer(),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.end,
                style: CarliType.small.copyWith(color: color),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
