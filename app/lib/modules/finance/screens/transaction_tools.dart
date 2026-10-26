import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/api/api_error.dart';
import '../../../core/format/dates.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../ui/button.dart';
import '../../../ui/field.dart';
import '../../../ui/icon.dart';
import '../../../ui/icon_names.dart';
import '../../../ui/money_input.dart';
import '../../../ui/pressable.dart';
import '../../../ui/segmented.dart';
import '../../../ui/select.dart';
import '../../../ui/sheet.dart';
import '../../../ui/toast.dart';
import '../data/finance_api.dart';
import '../data/finance_providers.dart';
import '../data/json.dart';
import '../data/models.dart';
import '../data/transaction_filters.dart';
import '../data/transaction_form.dart';
import '../data/transactions_repository.dart';
import 'transaction_sheet.dart';

typedef MoreFilters = ({TransactionStatus? status, Cents? min, Cents? max, DateTime? from, DateTime? to});

Future<MoreFilters?> showMoreFiltersSheet(BuildContext context, TransactionFilters filters) =>
    showCarliSheet<MoreFilters>(
      context,
      title: 'Más filtros',
      builder: (context) => _MoreFiltersSheet(
        initial: (status: filters.status, min: filters.min, max: filters.max, from: filters.from, to: filters.to),
      ),
    );

class _MoreFiltersSheet extends StatefulWidget {
  const _MoreFiltersSheet({required this.initial});

  final MoreFilters initial;

  @override
  State<_MoreFiltersSheet> createState() => _MoreFiltersSheetState();
}

enum _StatusChoice { all, pending, cleared }

class _MoreFiltersSheetState extends State<_MoreFiltersSheet> {
  late var _status = switch (widget.initial.status) {
    TransactionStatus.pending => _StatusChoice.pending,
    TransactionStatus.cleared => _StatusChoice.cleared,
    null => _StatusChoice.all,
  };
  late Cents? _min = widget.initial.min;
  late Cents? _max = widget.initial.max;
  late DateTime? _from = widget.initial.from;
  late DateTime? _to = widget.initial.to;
  var _generation = 0;

  void _clear() => setState(() {
    _status = _StatusChoice.all;
    _min = null;
    _max = null;
    _from = null;
    _to = null;
    _generation++;
  });

  void _apply() => Navigator.pop<MoreFilters>(context, (
    status: switch (_status) {
      _StatusChoice.all => null,
      _StatusChoice.pending => TransactionStatus.pending,
      _StatusChoice.cleared => TransactionStatus.cleared,
    },
    min: _min,
    max: _max,
    from: _from,
    to: _to,
  ));

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      key: ValueKey(_generation),
      padding: const EdgeInsets.fromLTRB(CarliSpace.s20, 0, CarliSpace.s20, CarliSpace.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: CarliSpace.s16,
        children: [
          CarliField(
            label: 'Estado',
            child: CarliSegmented<_StatusChoice>(
              value: _status,
              onChanged: (value) => setState(() => _status = value),
              segments: const [
                CarliSegment(_StatusChoice.all, 'Todos'),
                CarliSegment(_StatusChoice.pending, 'Pendientes'),
                CarliSegment(_StatusChoice.cleared, 'Confirmados'),
              ],
            ),
          ),
          Row(
            spacing: CarliSpace.s12,
            children: [
              Expanded(
                child: CarliField(
                  label: 'Importe mínimo',
                  child: CarliMoneyInput(
                    value: _min,
                    appearance: MoneyInputAppearance.field,
                    semanticLabel: 'Importe mínimo',
                    onChanged: (value) => _min = value,
                  ),
                ),
              ),
              Expanded(
                child: CarliField(
                  label: 'Importe máximo',
                  child: CarliMoneyInput(
                    value: _max,
                    appearance: MoneyInputAppearance.field,
                    semanticLabel: 'Importe máximo',
                    onChanged: (value) => _max = value,
                  ),
                ),
              ),
            ],
          ),
          Text(
            'El importe se compara sin signo: sirve igual para gastos e ingresos.',
            style: CarliType.caption.copyWith(color: colors.text3),
          ),
          Row(
            spacing: CarliSpace.s12,
            children: [
              Expanded(
                child: CarliField(
                  label: 'Desde',
                  hint: 'Sustituye al periodo',
                  child: DateField(value: _from, onChanged: (value) => setState(() => _from = value)),
                ),
              ),
              Expanded(
                child: CarliField(
                  label: 'Hasta',
                  hint: ' ',
                  child: DateField(value: _to, onChanged: (value) => setState(() => _to = value)),
                ),
              ),
            ],
          ),
          Row(
            spacing: CarliSpace.s12,
            children: [
              Expanded(
                child: CarliButton(
                  label: 'Limpiar',
                  variant: CarliButtonVariant.ghost,
                  size: CarliButtonSize.md,
                  onPressed: _clear,
                ),
              ),
              Expanded(
                child: CarliButton(label: 'Aplicar', size: CarliButtonSize.md, onPressed: _apply),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class DateField extends StatelessWidget {
  const DateField({super.key, required this.value, required this.onChanged, this.placeholder = 'dd/mm/aaaa'});

  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final String placeholder;

  Future<void> _pick(BuildContext context) async {
    final current = today();
    final picked = await showCarliSheet<DateTime>(
      context,
      title: 'Elige una fecha',
      builder: (context) => CalendarDatePicker(
        initialDate: value ?? current,
        firstDate: DateTime(current.year - 10),
        lastDate: DateTime(current.year + 5, 12, 31),
        currentDate: current,
        onDateChanged: (date) => Navigator.pop(context, date),
      ),
    );
    if (picked != null) onChanged(dateOnly(picked));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final value = this.value;
    return Semantics(
      button: true,
      value: value == null ? null : formatFormDate(value),
      child: Pressable(
        onTap: () => _pick(context),
        child: Container(
          height: 50,
          padding: const EdgeInsets.only(left: CarliSpace.s16, right: CarliSpace.s8),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(CarliRadius.md),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value == null ? placeholder : formatFormDate(value),
                  style: CarliType.body.copyWith(color: value == null ? colors.text3 : colors.text),
                ),
              ),
              if (value != null)
                Semantics(
                  button: true,
                  label: 'Quitar fecha',
                  child: Pressable(
                    onTap: () => onChanged(null),
                    child: Padding(
                      padding: const EdgeInsets.all(CarliSpace.s8),
                      child: CarliIcon(carliIconNamed('x'), size: 16, color: colors.text3),
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.all(CarliSpace.s8),
                  child: CarliIcon(carliIconNamed('calendar'), size: 16, color: colors.text3),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _BulkField {
  category('Categoría'),
  account('Cuenta'),
  tags('Etiquetas'),
  status('Estado');

  const _BulkField(this.label);

  final String label;
}

Future<Json?> showBulkEditSheet(BuildContext context, int count) => showCarliSheet<Json>(
  context,
  title: 'Editar en bloque',
  builder: (context) => _BulkEditSheet(count: count),
);

class _BulkEditSheet extends ConsumerStatefulWidget {
  const _BulkEditSheet({required this.count});

  final int count;

  @override
  ConsumerState<_BulkEditSheet> createState() => _BulkEditSheetState();
}

class _BulkEditSheetState extends ConsumerState<_BulkEditSheet> {
  var _field = _BulkField.category;
  String? _category;
  String? _account;
  final _add = TextEditingController();
  final _remove = TextEditingController();
  var _status = TransactionStatus.cleared;

  @override
  void dispose() {
    _add.dispose();
    _remove.dispose();
    super.dispose();
  }

  Json? get _result {
    switch (_field) {
      case _BulkField.category:
        return _category == null ? null : {'category_id': _category};
      case _BulkField.account:
        return _account == null ? null : {'account_id': _account};
      case _BulkField.tags:
        final add = parseTagInput(_add.text);
        final remove = parseTagInput(_remove.text);
        return add.isEmpty && remove.isEmpty
            ? null
            : {if (add.isNotEmpty) 'add_tags': add, if (remove.isNotEmpty) 'remove_tags': remove};
      case _BulkField.status:
        return {'status': _status.api};
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final categories = ref.watch(categoriesProvider).value;
    final accounts = ref.watch(accountsProvider).value;
    final result = _result;
    return Padding(
      padding: const EdgeInsets.fromLTRB(CarliSpace.s20, 0, CarliSpace.s20, CarliSpace.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: CarliSpace.s16,
        children: [
          Text(
            widget.count == 1 ? '1 movimiento seleccionado' : '${widget.count} movimientos seleccionados',
            style: CarliType.small.copyWith(color: colors.text2),
          ),
          CarliSegmented<_BulkField>(
            value: _field,
            onChanged: (value) => setState(() => _field = value),
            segments: [for (final field in _BulkField.values) CarliSegment(field, field.label)],
          ),
          switch (_field) {
            _BulkField.category => CarliField(
              label: 'Nueva categoría',
              hint: 'Las transferencias no cambian de categoría.',
              child: CarliSelect<String>(
                title: 'Nueva categoría',
                placeholder: 'Elige una categoría',
                value: _category,
                onChanged: (id) => setState(() => _category = id),
                options: [
                  for (final entry in categories?.entries ?? const <CategoryEntry>[])
                    if (!entry.category.archived)
                      CarliOption(
                        entry.category.id,
                        entry.label,
                        icon: carliIconNamed(entry.icon),
                        subtitle: entry.category.kind == CategoryKind.income ? 'Ingreso' : null,
                      ),
                ],
              ),
            ),
            _BulkField.account => CarliField(
              label: 'Nueva cuenta',
              hint: 'Las transferencias no cambian de cuenta.',
              child: CarliSelect<String>(
                title: 'Nueva cuenta',
                placeholder: 'Elige una cuenta',
                value: _account,
                onChanged: (id) => setState(() => _account = id),
                options: [
                  for (final account in accounts?.active ?? const <Account>[])
                    CarliOption(
                      account.id,
                      account.name,
                      icon: carliIconNamed(account.icon ?? accountTypeIconName(account.type)),
                    ),
                ],
              ),
            ),
            _BulkField.tags => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: CarliSpace.s16,
              children: [
                CarliField(
                  label: 'Añadir etiquetas',
                  hint: 'Separa varias con comas.',
                  child: CarliInput(
                    controller: _add,
                    placeholder: 'vacaciones, casa',
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                CarliField(
                  label: 'Quitar etiquetas',
                  child: CarliInput(controller: _remove, placeholder: 'Opcional', onChanged: (_) => setState(() {})),
                ),
              ],
            ),
            _BulkField.status => CarliSegmented<TransactionStatus>(
              value: _status,
              onChanged: (value) => setState(() => _status = value),
              segments: const [
                CarliSegment(TransactionStatus.cleared, 'Confirmado'),
                CarliSegment(TransactionStatus.pending, 'Pendiente'),
              ],
            ),
          },
          CarliButton(
            label: 'Aplicar',
            size: CarliButtonSize.md,
            onPressed: result == null ? null : () => Navigator.pop(context, result),
          ),
        ],
      ),
    );
  }
}

Future<void> exportTransactionsCsv(WidgetRef ref, Query query, {Rect? origin}) async {
  final toasts = ref.read(toastControllerProvider.notifier);
  try {
    final bytes = await ref.read(transactionsRepositoryProvider).exportCsv(query);
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/movimientos-${isoDate(today())}.csv');
    await file.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'text/csv')],
        sharePositionOrigin: origin,
      ),
    );
  } catch (error) {
    toasts.error(apiErrorMessage(error, fallback: 'No se ha podido exportar el CSV.'));
  }
}
