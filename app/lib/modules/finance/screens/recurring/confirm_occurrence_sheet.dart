import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_error.dart';
import '../../../../core/format/dates.dart';
import '../../../../core/format/money.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../../../ui/button.dart';
import '../../../../ui/date_picker.dart';
import '../../../../ui/field.dart';
import '../../../../ui/icon.dart';
import '../../../../ui/icon_names.dart';
import '../../../../ui/money_input.dart';
import '../../../../ui/sheet.dart';
import '../../../../ui/switch.dart';
import '../../../../ui/toast.dart';
import '../../data/models.dart';
import '../../data/recurring.dart';

Future<ConfirmRecurringResult?> showConfirmOccurrenceSheet(BuildContext context, {required RecurringRule rule}) =>
    showCarliSheet<ConfirmRecurringResult>(
      context,
      title: 'Confirmar ${rule.name}',
      builder: (context) => ConfirmOccurrenceSheet(rule: rule),
    );

class ConfirmOccurrenceSheet extends ConsumerStatefulWidget {
  const ConfirmOccurrenceSheet({super.key, required this.rule});

  final RecurringRule rule;

  @override
  ConsumerState<ConfirmOccurrenceSheet> createState() => _ConfirmOccurrenceSheetState();
}

class _ConfirmOccurrenceSheetState extends ConsumerState<ConfirmOccurrenceSheet> {
  late Cents? _amount = expectedAmountOf(widget.rule).abs();
  late DateTime _date = occurrenceDateOf(widget.rule);
  var _updateRuleAmount = true;
  var _saving = false;
  String? _error;

  RecurringRule get rule => widget.rule;

  Future<void> _submit() async {
    final amount = _amount;
    if (amount == null || amount < 1) {
      setState(() => _error = 'Indica un importe mayor que cero.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final toasts = ref.read(toastControllerProvider.notifier);
    try {
      final result = await ref
          .read(recurringRepositoryProvider)
          .confirm(
            rule.id,
            confirmOccurrencePayload(rule: rule, amount: amount, date: _date, updateRuleAmount: _updateRuleAmount),
          );
      toasts.show(confirmedToast(rule, result, updateRuleAmount: _updateRuleAmount));
      if (mounted) Navigator.of(context).pop(result);
    } catch (error) {
      if (mounted) setState(() => _error = apiErrorMessage(error, fallback: 'No se ha podido confirmar el cargo.'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final change = detectPriceChange(rule.amountCents, _amount);
    final subtitle =
        '${ruleFrequencyLabel(rule)} · cargo del ${formatShortDate(occurrenceDateOf(rule))} · ${rule.account.name}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(CarliSpace.s20, 0, CarliSpace.s20, CarliSpace.s24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: CarliSpace.s16,
        children: [
          Text(subtitle, style: CarliType.small.copyWith(color: colors.text2)),
          Column(
            spacing: CarliSpace.s4,
            children: [
              CarliMoneyInput(
                value: _amount,
                semanticLabel: 'Importe cobrado',
                sign: rule.kind == TransactionKind.income ? MoneyInputSign.positive : MoneyInputSign.negative,
                onChanged: (value) => setState(() => _amount = value),
              ),
              Text(
                'Previsto: ${formatMoney(rule.amountCents, display: MoneyDisplay.signed)}',
                textAlign: TextAlign.center,
                style: CarliType.small.copyWith(color: colors.text2),
              ),
            ],
          ),
          if (change != null)
            Semantics(
              liveRegion: true,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: CarliSpace.s12),
                decoration: BoxDecoration(
                  color: colors.warningSoft,
                  borderRadius: BorderRadius.circular(CarliRadius.md),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: CarliSpace.s12,
                  children: [
                    CarliIcon(
                      carliIconNamed(change.direction == PriceDirection.up ? 'trending-up' : 'trending-down'),
                      size: 18,
                      color: colors.warning,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: CarliSpace.s8,
                        children: [
                          Text(change.title, style: CarliType.bodyStrong.copyWith(color: colors.warning)),
                          Row(
                            spacing: 10,
                            children: [
                              CarliSwitch(
                                value: _updateRuleAmount,
                                semanticLabel: 'Usar este importe en los próximos cargos',
                                onChanged: (value) => setState(() => _updateRuleAmount = value),
                              ),
                              Expanded(
                                child: Text(
                                  'Usar este importe en los próximos cargos',
                                  style: CarliType.small.copyWith(color: colors.text),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          CarliField(
            label: 'Fecha del cargo',
            child: CarliDatePicker(value: _date, onChanged: (date) => setState(() => _date = date)),
          ),
          if (_error case final error?)
            Semantics(
              liveRegion: true,
              child: Text(error, style: CarliType.small.copyWith(color: colors.negative)),
            ),
          CarliButton(label: 'Confirmar cargo', icon: carliIconNamed('check'), loading: _saving, onPressed: _submit),
        ],
      ),
    );
  }
}
