import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_error.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../../../ui/button.dart';
import '../../../../ui/date_picker.dart';
import '../../../../ui/field.dart';
import '../../../../ui/icon_names.dart';
import '../../../../ui/money_input.dart';
import '../../../../ui/segmented.dart';
import '../../../../ui/select.dart';
import '../../../../ui/sheet.dart';
import '../../../../ui/toast.dart';
import '../../data/finance_providers.dart';
import '../../data/models.dart';
import '../../data/recurring.dart';
import '../../ui/transaction_extras.dart';
import '../transaction_tools.dart';

enum RecurringRuleSheetResult { saved, deleted }

Future<RecurringRuleSheetResult?> showRecurringRuleSheet(
  BuildContext context, {
  RecurringRule? rule,
  bool isSubscription = false,
}) => showModalBottomSheet<RecurringRuleSheetResult>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: false,
  builder: (context) => FractionallySizedBox(
    heightFactor: 0.94,
    child: RecurringRuleSheet(rule: rule, isSubscription: isSubscription),
  ),
);

class RecurringRuleSheet extends ConsumerStatefulWidget {
  const RecurringRuleSheet({super.key, this.rule, this.isSubscription = false});

  final RecurringRule? rule;
  final bool isSubscription;

  @override
  ConsumerState<RecurringRuleSheet> createState() => _RecurringRuleSheetState();
}

class _RecurringRuleSheetState extends ConsumerState<RecurringRuleSheet> {
  late final RecurringDraft _draft = RecurringDraft.from(widget.rule, isSubscription: widget.isSubscription);
  late final _payee = TextEditingController(text: _draft.payee);
  late final _interval = TextEditingController(text: '${_draft.interval}');
  late final _remind = TextEditingController(text: '${_draft.remindDaysBefore}');
  var _submitted = false;
  var _saving = false;
  var _deleting = false;
  String? _error;

  bool get _editing => widget.rule != null;

  @override
  void dispose() {
    _payee.dispose();
    _interval.dispose();
    _remind.dispose();
    super.dispose();
  }

  void _setKind(TransactionKind kind) {
    final categories = ref.read(categoriesProvider).value;
    final selected = categories?.find(_draft.categoryId);
    setState(() {
      _draft.kind = kind;
      final categoryKind = kind == TransactionKind.income ? CategoryKind.income : CategoryKind.expense;
      if (selected != null && selected.category.kind != categoryKind) _draft.categoryId = null;
    });
  }

  Future<void> _save() async {
    setState(() {
      _submitted = true;
      _error = null;
    });
    if (!_draft.valid) return;
    setState(() => _saving = true);
    final repository = ref.read(recurringRepositoryProvider);
    final toasts = ref.read(toastControllerProvider.notifier);
    try {
      if (widget.rule case final rule?) {
        await repository.update(rule.id, _draft.toPayload());
        toasts.show('Recurrente actualizado');
      } else {
        await repository.create(_draft.toPayload());
        toasts.show('Recurrente creado');
      }
      if (mounted) Navigator.of(context).pop(RecurringRuleSheetResult.saved);
    } catch (error) {
      if (mounted) setState(() => _error = apiErrorMessage(error, fallback: 'No se ha podido guardar el recurrente.'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final rule = widget.rule;
    if (rule == null) return;
    final confirmed = await confirmCarli(
      context,
      title: '¿Eliminar ${rule.name}?',
      message: 'Se borrarán también los cargos pendientes de confirmar. Los movimientos ya registrados se mantienen.',
      confirmLabel: 'Eliminar',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _deleting = true;
      _error = null;
    });
    final toasts = ref.read(toastControllerProvider.notifier);
    try {
      await ref.read(recurringRepositoryProvider).remove(rule.id);
      toasts.show('${rule.name} eliminado');
      if (mounted) Navigator.of(context).pop(RecurringRuleSheetResult.deleted);
    } catch (error) {
      if (mounted) setState(() => _error = apiErrorMessage(error, fallback: 'No se ha podido eliminar el recurrente.'));
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accounts = ref.watch(accountsProvider).value;
    final categories = ref.watch(categoriesProvider).value;

    if (_draft.accountId == null && accounts != null) {
      _draft.accountId = preferredAccountId(accounts.all);
    }

    final categoryKind = _draft.kind == TransactionKind.income ? CategoryKind.income : CategoryKind.expense;
    final accountOptions = [
      for (final option in recurringAccountOptions(accounts?.all ?? const []))
        CarliOption<String>(option.id, option.label, icon: carliIconNamed(option.icon)),
    ];
    final categoryOptions = [
      CarliOption<String?>(null, 'Sin categoría', icon: carliIconNamed('circle')),
      if (categories != null)
        for (final option in recurringCategoryOptions(categories, categoryKind))
          CarliOption<String?>(option.id, option.label, icon: carliIconNamed(option.icon)),
    ];

    return Column(
      children: [
        _Header(
          title: _editing ? 'Editar recurrente' : 'Nuevo recurrente',
          saving: _saving,
          onCancel: () => Navigator.of(context).pop(),
          onSave: _save,
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              CarliSpace.s16,
              CarliSpace.s8,
              CarliSpace.s16,
              CarliSpace.s32 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            children: [
              CarliSegmented<TransactionKind>(
                segments: const [
                  CarliSegment(TransactionKind.expense, 'Gasto'),
                  CarliSegment(TransactionKind.income, 'Ingreso'),
                ],
                value: _draft.kind,
                onChanged: _setKind,
              ),
              const SizedBox(height: CarliSpace.s8),
              CarliMoneyInput(
                key: ValueKey(_draft.kind),
                value: _draft.amount,
                autofocus: !_editing,
                semanticLabel: 'Importe de cada cargo',
                sign: _draft.kind == TransactionKind.income ? MoneyInputSign.positive : MoneyInputSign.negative,
                onChanged: (value) => setState(() => _draft.amount = value),
              ),
              if (_submitted && _draft.amountInvalid)
                Text(
                  'Indica un importe mayor que cero.',
                  textAlign: TextAlign.center,
                  style: CarliType.small.copyWith(color: colors.negative),
                ),
              const SizedBox(height: CarliSpace.s16),
              CarliField(
                label: 'Nombre',
                error: _submitted && _draft.payeeInvalid ? 'Ponle un nombre, por ejemplo Netflix.' : null,
                child: CarliInput(
                  controller: _payee,
                  placeholder: 'Netflix, Alquiler, Nómina…',
                  invalid: _submitted && _draft.payeeInvalid,
                  inputFormatters: [LengthLimitingTextInputFormatter(160)],
                  textInputAction: TextInputAction.done,
                  onChanged: (value) => setState(() => _draft.payee = value),
                ),
              ),
              const SizedBox(height: CarliSpace.s16),
              CarliField(
                label: 'Cuenta',
                error: _submitted && _draft.accountInvalid ? 'Elige una cuenta.' : null,
                child: CarliSelect<String>(
                  title: 'Cuenta',
                  placeholder: 'Elige una cuenta',
                  options: accountOptions,
                  value: _draft.accountId,
                  invalid: _submitted && _draft.accountInvalid,
                  onChanged: (id) => setState(() => _draft.accountId = id),
                ),
              ),
              const SizedBox(height: CarliSpace.s16),
              CarliField(
                label: 'Categoría',
                child: CarliSelect<String?>(
                  title: 'Categoría',
                  placeholder: 'Sin categoría',
                  options: categoryOptions,
                  value: _draft.categoryId,
                  onChanged: (id) => setState(() => _draft.categoryId = id),
                ),
              ),
              const SizedBox(height: CarliSpace.s16),
              CarliField(
                label: 'Frecuencia',
                child: CarliSelect<FrequencyPreset>(
                  title: 'Frecuencia',
                  options: [for (final preset in FrequencyPreset.values) CarliOption(preset, preset.label)],
                  value: _draft.preset,
                  onChanged: (preset) => setState(() => _draft.preset = preset),
                ),
              ),
              if (_draft.preset.custom) ...[
                const SizedBox(height: CarliSpace.s16),
                CarliField(
                  label: _draft.preset == FrequencyPreset.everyDays ? 'Cada cuántos días' : 'Cada cuántos meses',
                  error: _submitted && _draft.intervalInvalid ? 'Indica un número entre 1 y 365.' : null,
                  child: CarliInput(
                    controller: _interval,
                    keyboardType: TextInputType.number,
                    invalid: _submitted && _draft.intervalInvalid,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (value) => setState(() => _draft.interval = int.tryParse(value)),
                  ),
                ),
              ],
              const SizedBox(height: CarliSpace.s16),
              CarliField(
                label: 'Primer cargo',
                child: CarliDatePicker(
                  value: _draft.startDate,
                  onChanged: (date) => setState(() => _draft.startDate = date),
                ),
              ),
              SwitchRow(
                label: 'Tiene fecha de fin',
                value: _draft.hasEnd,
                onChanged: (value) => setState(() => _draft.setHasEnd(value)),
              ),
              if (_draft.hasEnd) ...[
                const SizedBox(height: CarliSpace.s16),
                CarliField(
                  label: 'Último cargo',
                  error: _submitted && _draft.endBeforeStart ? 'Debe ser posterior al primer cargo.' : null,
                  child: DateField(value: _draft.endDate, onChanged: (date) => setState(() => _draft.endDate = date)),
                ),
              ],
              const SizedBox(height: CarliSpace.s16),
              CarliField(
                label: 'Al llegar la fecha',
                hint: _draft.mode == RecurringMode.auto
                    ? 'Se registra solo, ya confirmado.'
                    : 'Se crea pendiente y te avisamos para que lo confirmes.',
                child: CarliSegmented<RecurringMode>(
                  segments: [for (final mode in RecurringMode.values) CarliSegment(mode, mode.label)],
                  value: _draft.mode,
                  onChanged: (mode) => setState(() => _draft.mode = mode),
                ),
              ),
              const SizedBox(height: CarliSpace.s16),
              CarliField(
                label: 'Avisarme antes (días)',
                hint: 'Push a las 09:00',
                error: _submitted && _draft.remindInvalid ? 'Indica un número entre 0 y 30.' : null,
                child: CarliInput(
                  controller: _remind,
                  keyboardType: TextInputType.number,
                  invalid: _submitted && _draft.remindInvalid,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (value) => setState(() => _draft.remindDaysBefore = int.tryParse(value)),
                ),
              ),
              SwitchRow(
                label: 'Es una suscripción',
                value: _draft.isSubscription,
                onChanged: (value) => setState(() => _draft.isSubscription = value),
              ),
              if (_error case final error?)
                Padding(
                  padding: const EdgeInsets.only(top: CarliSpace.s12),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(error, style: CarliType.small.copyWith(color: colors.negative)),
                  ),
                ),
              if (_editing) ...[
                const SizedBox(height: CarliSpace.s24),
                CarliButton(
                  label: 'Eliminar',
                  icon: carliIconNamed('trash'),
                  variant: CarliButtonVariant.danger,
                  size: CarliButtonSize.md,
                  loading: _deleting,
                  onPressed: _saving ? null : _delete,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.saving, required this.onCancel, required this.onSave});

  final String title;
  final bool saving;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          TextButton(
            onPressed: onCancel,
            style: TextButton.styleFrom(foregroundColor: colors.text2, textStyle: CarliType.body),
            child: const Text('Cancelar'),
          ),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: CarliType.h2.copyWith(color: colors.text),
              ),
            ),
          ),
          SizedBox(
            width: 88,
            child: saving
                ? const Center(child: SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)))
                : TextButton(onPressed: onSave, child: const Text('Guardar')),
          ),
        ],
      ),
    );
  }
}
