import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_error.dart';
import '../../../../core/format/dates.dart';
import '../../../../core/format/money.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../../../ui/badge.dart';
import '../../../../ui/button.dart';
import '../../../../ui/date_picker.dart';
import '../../../../ui/field.dart';
import '../../../../ui/icon_names.dart';
import '../../../../ui/list_item.dart';
import '../../../../ui/money_input.dart';
import '../../../../ui/progress.dart';
import '../../../../ui/select.dart';
import '../../../../ui/sheet.dart';
import '../../../../ui/skeleton.dart';
import '../../../../ui/toast.dart';
import '../../data/debts.dart';
import '../../data/finance_providers.dart';
import '../../data/json.dart';
import '../../data/models.dart';
import '../../data/transactions_repository.dart';
import '../goals/full_sheet.dart';
import 'debt_sheet.dart';
import 'debts_screen.dart';

Future<void> showDebtDetailSheet(BuildContext context, Debt debt) =>
    showFullSheet<void>(context, (context) => DebtDetailSheet(debt: debt));

class DebtDetailSheet extends ConsumerStatefulWidget {
  const DebtDetailSheet({super.key, required this.debt});

  final Debt debt;

  @override
  ConsumerState<DebtDetailSheet> createState() => _DebtDetailSheetState();
}

class _DebtDetailSheetState extends ConsumerState<DebtDetailSheet> {
  late Debt _debt = widget.debt;
  late int? _amount = widget.debt.installmentCents;
  String? _accountId;
  var _date = today();
  var _saving = false;
  String? _error;

  String get _paymentHeading => _debt.owesMe ? 'Registrar cobro' : 'Registrar pago';

  ToastController get _toasts => ref.read(toastControllerProvider.notifier);

  void _replace(Debt debt) {
    if (mounted) setState(() => _debt = debt);
  }

  Future<void> _addPayment(String? accountId) async {
    final toasts = _toasts;
    final amount = _amount;
    if (amount == null || amount <= 0 || accountId == null) {
      setState(() => _error = 'Indica el importe y la cuenta.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await ref.read(debtsRepositoryProvider).addPayment(_debt.id, <String, Object?>{
        'account_id': accountId,
        'amount_cents': amount,
        'date': isoDate(_date),
      });
      _replace(result.debt);
      toasts.show(
        result.debt.closed
            ? '${result.debt.name} saldada'
            : '$_paymentHeading: ${formatMoney(result.payment.amountCents, display: MoneyDisplay.signed)}',
      );
    } catch (error) {
      if (mounted) setState(() => _error = apiErrorMessage(error, fallback: 'No se ha podido registrar el pago.'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _removePayment(Transaction payment) async {
    final transactions = ref.read(transactionsRepositoryProvider);
    final toasts = _toasts;
    try {
      await transactions.remove(payment.id);
      toasts.withUndo('Pago borrado', () async {
        try {
          await transactions.restore(payment.id);
        } catch (error) {
          toasts.error(apiErrorMessage(error, fallback: 'No se ha podido restaurar el pago.'));
        }
      });
    } catch (error) {
      toasts.error(apiErrorMessage(error, fallback: 'No se ha podido borrar el pago.'));
    }
  }

  Future<void> _toggleClosed() async {
    final repository = ref.read(debtsRepositoryProvider);
    final toasts = _toasts;
    final closing = !_debt.closed;
    try {
      final updated = await repository.setClosed(_debt.id, closing);
      _replace(updated);
      if (closing) {
        toasts.withUndo('${updated.name} marcada como saldada', () async {
          try {
            _replace(await repository.setClosed(updated.id, false));
          } catch (error) {
            toasts.error(apiErrorMessage(error, fallback: 'No se ha podido actualizar la deuda.'));
          }
        });
      }
    } catch (error) {
      toasts.error(apiErrorMessage(error, fallback: 'No se ha podido actualizar la deuda.'));
    }
  }

  Future<void> _edit() async {
    final updated = await showDebtSheet(context, debt: _debt);
    if (updated != null) _replace(updated);
  }

  Future<void> _remove() async {
    final debt = _debt;
    final confirmed = await confirmCarli(
      context,
      title: '¿Eliminar ${debt.name}?',
      message:
          'Los pagos ya registrados se mantienen como movimientos. Si tenía cuotas, se elimina también su recurrente.',
      confirmLabel: 'Eliminar',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final toasts = _toasts;
    try {
      await ref.read(debtsRepositoryProvider).remove(debt.id);
      toasts.show('${debt.name} eliminada');
      if (mounted) Navigator.pop(context);
    } catch (error) {
      toasts.error(apiErrorMessage(error, fallback: 'No se ha podido eliminar la deuda.'));
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(debtsProvider, (_, next) {
      if (next.value?.find(_debt.id) case final fresh?) _replace(fresh);
    });
    final colors = context.colors;
    final debt = _debt;
    final accounts = ref.watch(accountsProvider).value?.all ?? const <Account>[];
    final accountId = _accountId ?? preferredDebtAccountId(accounts);
    final payments = ref.watch(debtPaymentsProvider(debt.id));
    final next = debt.closed ? null : debtNextDateLabel(debt);

    return Column(
      children: [
        FullSheetHeader(
          title: debt.name,
          subtitle: debt.subtitle,
          leadingLabel: 'Cerrar',
          onLeading: () => Navigator.pop(context),
          trailing: CarliButton.icon(
            icon: carliIconNamed('pencil'),
            semanticLabel: 'Editar deuda',
            size: CarliButtonSize.sm,
            onPressed: _edit,
          ),
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              CarliSpace.s16,
              CarliSpace.s16,
              CarliSpace.s16,
              CarliSpace.s32 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            children: [
              Row(
                children: [
                  debtDirectionBadge(debt),
                  const Spacer(),
                  if (debt.closed)
                    CarliBadge('Saldada', tone: CarliBadgeTone.positive, icon: carliIconNamed('check'))
                  else if (next != null)
                    Text(next, style: CarliType.small.copyWith(color: colors.text3)),
                ],
              ),
              const SizedBox(height: CarliSpace.s12),
              DebtFigures(debt: debt, trailing: '${debt.percent} %'),
              const SizedBox(height: CarliSpace.s8),
              CarliProgress(ratio: debt.ratio, tone: ProgressTone.goal, label: 'Pagado de ${debt.name}'),
              if (debt.notes case final notes?) ...[
                const SizedBox(height: CarliSpace.s12),
                Text(notes, style: CarliType.small.copyWith(color: colors.text2)),
              ],
              if (!debt.closed) ...[
                const SizedBox(height: CarliSpace.s20),
                Container(
                  padding: const EdgeInsets.all(CarliSpace.s16),
                  decoration: BoxDecoration(
                    border: Border.all(color: colors.border),
                    borderRadius: BorderRadius.circular(CarliRadius.md),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: CarliSpace.s12,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(_paymentHeading, style: CarliType.h2.copyWith(color: colors.text)),
                      ),
                      CarliField(
                        label: 'Importe',
                        child: CarliMoneyInput(
                          value: _amount,
                          appearance: MoneyInputAppearance.field,
                          semanticLabel: 'Importe del pago',
                          onChanged: (value) => setState(() => _amount = value),
                        ),
                      ),
                      CarliField(
                        label: 'Cuenta',
                        child: CarliSelect<String>(
                          title: 'Cuenta',
                          placeholder: 'Elige una cuenta',
                          options: debtAccountOptions(accounts),
                          value: accountId,
                          onChanged: (id) => setState(() => _accountId = id),
                        ),
                      ),
                      CarliField(
                        label: 'Fecha',
                        child: CarliDatePicker(value: _date, onChanged: (date) => setState(() => _date = date)),
                      ),
                      if (_error case final error?) FormError(error),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        spacing: CarliSpace.s8,
                        children: [
                          CarliButton(
                            label: 'Todo lo pendiente',
                            variant: CarliButtonVariant.ghost,
                            size: CarliButtonSize.sm,
                            block: false,
                            onPressed: () => setState(() => _amount = debt.pendingCents),
                          ),
                          CarliButton(
                            label: _paymentHeading,
                            icon: carliIconNamed('plus'),
                            size: CarliButtonSize.sm,
                            block: false,
                            loading: _saving,
                            onPressed: () => _addPayment(accountId),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: CarliSpace.s20),
              Semantics(
                header: true,
                child: Text(debt.owesMe ? 'Cobros' : 'Pagos', style: CarliType.h2.copyWith(color: colors.text)),
              ),
              const SizedBox(height: CarliSpace.s8),
              switch (payments) {
                AsyncValue(hasValue: true, :final value?) when value.isNotEmpty => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (index, payment) in value.indexed) ...[
                      if (index > 0) Divider(indent: 56, color: colors.border),
                      _PaymentRow(debt: debt, payment: payment, onRemove: () => _removePayment(payment)),
                    ],
                  ],
                ),
                AsyncValue(hasValue: true) || AsyncValue(hasError: true) => Text(
                  'Aún no hay ${debt.owesMe ? 'cobros' : 'pagos'} registrados.',
                  style: CarliType.small.copyWith(color: colors.text2),
                ),
                _ => const CarliSkeleton(height: 40),
              },
              const SizedBox(height: CarliSpace.s24),
              CarliButton(
                label: debt.closed ? 'Reabrir' : 'Marcar como saldada',
                icon: carliIconNamed(debt.closed ? 'undo-2' : 'check'),
                variant: CarliButtonVariant.secondary,
                size: CarliButtonSize.md,
                onPressed: _toggleClosed,
              ),
              const SizedBox(height: CarliSpace.s8),
              CarliButton(
                label: 'Eliminar',
                icon: carliIconNamed('trash'),
                variant: CarliButtonVariant.danger,
                size: CarliButtonSize.md,
                onPressed: _remove,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.debt, required this.payment, required this.onRemove});

  final Debt debt;
  final Transaction payment;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final title = [
      payment.description,
      payment.payee,
    ].firstWhere((value) => value != null && value.isNotEmpty, orElse: () => debt.name)!;
    return CarliListItem(
      title: title,
      subtitle: '${formatRelativeDay(payment.date, style: RelativeDateStyle.title)} · ${payment.account.name}',
      icon: carliIconNamed(debt.owesMe ? 'arrow-down-left' : 'arrow-up-right'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: CarliSpace.s4,
        children: [
          if (payment.status == TransactionStatus.pending)
            CarliBadge('Pendiente', tone: CarliBadgeTone.warning, icon: carliIconNamed('clock')),
          Text(
            formatMoney(payment.amountCents, display: MoneyDisplay.signed),
            style: CarliType.money(CarliType.body)
                .copyWith(fontWeight: FontWeight.w600, color: payment.amountCents > 0 ? colors.positive : colors.text),
          ),
          CarliButton.icon(
            icon: carliIconNamed('trash'),
            semanticLabel: 'Borrar pago del ${formatShortDate(payment.date)}',
            size: CarliButtonSize.sm,
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
