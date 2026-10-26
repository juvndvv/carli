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
import '../../../../ui/money_input.dart';
import '../../../../ui/segmented.dart';
import '../../../../ui/sheet.dart';
import '../../../../ui/toast.dart';
import '../../data/goals.dart';
import '../../data/json.dart';
import '../../data/models.dart';
import '../../../../ui/full_sheet.dart';

enum ContributionDirection { add, withdraw }

Future<bool> showContributionSheet(BuildContext context, SavingsGoal goal) async =>
    await showCarliSheet<bool>(
      context,
      title: 'Aportar',
      builder: (context) => ContributionSheet(goal: goal),
    ) ??
    false;

String contributionToast(SavingsGoal before, SavingsGoal after, Cents amount) => after.achieved && !before.achieved
    ? '¡Objetivo conseguido! ${after.name} al 100 %'
    : '${formatMoney(amount, display: MoneyDisplay.signed)} · ${after.name} al ${after.percent} %';

class ContributionSheet extends ConsumerStatefulWidget {
  const ContributionSheet({super.key, required this.goal});

  final SavingsGoal goal;

  @override
  ConsumerState<ContributionSheet> createState() => _ContributionSheetState();
}

class _ContributionSheetState extends ConsumerState<ContributionSheet> {
  final _note = TextEditingController();
  var _direction = ContributionDirection.add;
  late int? _amount = (widget.goal.monthlyNeededCents ?? 0) > 0 ? widget.goal.monthlyNeededCents : null;
  var _date = today();
  var _saving = false;
  String? _error;

  bool get _adding => _direction == ContributionDirection.add;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final magnitude = _amount;
    if (magnitude == null || magnitude <= 0) {
      setState(() => _error = 'Indica un importe mayor que cero.');
      return;
    }
    final amount = _adding ? magnitude : -magnitude;
    final note = _note.text.trim();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await ref.read(goalsRepositoryProvider).contribute(widget.goal.id, <String, Object?>{
        'amount_cents': amount,
        'date': isoDate(_date),
        'note': note.isEmpty ? null : note,
      });
      ref.read(toastControllerProvider.notifier).show(contributionToast(widget.goal, result.goal, amount));
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() => _error = apiErrorMessage(error, fallback: 'No se ha podido registrar la aportación.'));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final goal = widget.goal;
    return Padding(
      padding: const EdgeInsets.fromLTRB(CarliSpace.s20, 0, CarliSpace.s20, CarliSpace.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: CarliSpace.s16,
        children: [
          Text(
            '${goal.name} · ${formatMoney(goal.savedCents)} de ${formatMoney(goal.targetCents)}',
            style: CarliType.small.copyWith(color: colors.text2),
          ),
          CarliSegmented<ContributionDirection>(
            segments: const [
              CarliSegment(ContributionDirection.add, 'Aportar'),
              CarliSegment(ContributionDirection.withdraw, 'Retirar'),
            ],
            value: _direction,
            onChanged: (direction) => setState(() => _direction = direction),
          ),
          CarliMoneyInput(
            value: _amount,
            sign: _adding ? MoneyInputSign.positive : MoneyInputSign.negative,
            semanticLabel: 'Importe de la aportación',
            onChanged: (value) => setState(() => _amount = value),
          ),
          CarliField(
            label: 'Fecha',
            child: CarliDatePicker(value: _date, lastDate: today(), onChanged: (date) => setState(() => _date = date)),
          ),
          CarliField(
            label: 'Nota',
            child: CarliInput(controller: _note, placeholder: 'Opcional'),
          ),
          if (_error case final error?) FormError(error),
          CarliButton(label: _adding ? 'Aportar' : 'Retirar', loading: _saving, onPressed: _save),
        ],
      ),
    );
  }
}
