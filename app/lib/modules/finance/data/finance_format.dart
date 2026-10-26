import '../../../core/format/dates.dart';
import '../../../core/format/money.dart';
import 'finance_providers.dart';
import 'models.dart';

String _decimalComma(num value, {int maxFraction = 1}) {
  final fixed = value.toStringAsFixed(maxFraction);
  final trimmed = fixed.contains('.') ? fixed.replaceFirst(RegExp(r'\.?0+$'), '') : fixed;
  return trimmed.replaceAll('.', ',');
}

String formatBasisPoints(BasisPoints? value, {bool signed = false}) {
  if (value == null) return '—';
  final sign = value < 0 ? minusSign : (signed && value > 0 ? '+' : '');
  return '$sign${_decimalComma(value.abs() / 100)} %';
}

String formatPercentRounded(BasisPoints? value) => value == null ? '—' : '${(value / 100).round()} %';

Cents budgetLimit(BudgetRow row) => row.rolloverInCents < 0 ? row.amountCents : row.availableCents;

Cents budgetConsumed(BudgetRow row) => row.spentCents - (row.rolloverInCents < 0 ? row.rolloverInCents : 0);

double? budgetUsageRatio(BudgetRow row) {
  final limit = budgetLimit(row);
  return limit > 0 ? budgetConsumed(row) / limit : null;
}

double budgetBarRatio(BudgetRow row) => budgetUsageRatio(row) ?? (budgetConsumed(row) > 0 ? 1.01 : 0);

String budgetUsageLabel(BudgetRow row) {
  final ratio = budgetUsageRatio(row);
  if (ratio == null) return budgetConsumed(row) > 0 ? 'Excedido' : '0 %';
  return formatPercentRounded((ratio * 10000).round());
}

String budgetNote(BudgetStatus status, Cents remaining) => status == BudgetStatus.exceeded || remaining < 0
    ? 'Excedido en ${formatMoney(remaining.abs())}'
    : 'Te quedan ${formatMoney(remaining)}';

String inDaysLabel(int days) => switch (days) {
  <= 0 => 'hoy',
  1 => 'mañana',
  2 => 'pasado mañana',
  _ => 'en $days días',
};

String daysLeftLabel(int days) => days <= 0 ? 'último día' : (days == 1 ? 'queda 1 día' : 'quedan $days días');

String periodButtonLabel(Period period) =>
    '${period.name} · ${period.isCurrent ? period.rangeLabel.replaceFirst(RegExp(r'–.*$'), '– hoy') : period.rangeLabel}';

String transactionAmountLabel(Transaction transaction) => transaction.kind == TransactionKind.transfer
    ? formatMoney(transaction.amountCents, display: MoneyDisplay.absolute)
    : formatMoney(transaction.amountCents, display: MoneyDisplay.signed);

String transactionTitle(Transaction transaction) {
  if (transaction.payee case final payee? when payee.isNotEmpty) return payee;
  if (transaction.description case final description? when description.isNotEmpty) return description;
  return switch (transaction.kind) {
    TransactionKind.transfer => transaction.amountCents < 0 ? 'Transferencia enviada' : 'Transferencia recibida',
    TransactionKind.adjustment => 'Ajuste de saldo',
    _ when transaction.isSplit => 'Movimiento dividido',
    _ => transaction.category?.name ?? 'Sin categoría',
  };
}

String transactionIconName(Transaction transaction) => switch (transaction.kind) {
  TransactionKind.transfer => 'arrow-left-right',
  TransactionKind.adjustment => 'scale',
  _ when transaction.isSplit => 'split',
  _ => transaction.category?.icon ?? fallbackCategoryIcon,
};

bool transactionNeedsCategory(Transaction transaction) =>
    transaction.kind == TransactionKind.transfer ||
    transaction.kind == TransactionKind.adjustment ||
    (transaction.category == null && !transaction.isSplit);

String? sharedSummary(Transaction transaction) {
  final pending = [
    for (final share in transaction.shares)
      if (!share.settled) share,
  ];
  if (pending.isEmpty) return null;
  final total = pending.fold<int>(0, (sum, share) => sum + share.amountCents);
  return pending.length == 1
      ? '${pending.single.name} te debe ${formatMoney(total)}'
      : 'Te deben ${formatMoney(total)}';
}

String transactionSubtitle(Transaction transaction, {AccountsData? accounts, bool showAccount = true}) {
  final parts = <String>[];
  if (transaction.kind == TransactionKind.transfer) {
    final other = accounts?.find(transaction.transferAccountId)?.name;
    final route = other == null
        ? transaction.account.name
        : transaction.amountCents < 0
        ? '${transaction.account.name} → $other'
        : '$other → ${transaction.account.name}';
    parts.addAll(['Transferencia', route]);
  } else {
    parts.add(switch (transaction.kind) {
      TransactionKind.adjustment => 'Ajuste',
      _ when transaction.isSplit => '${transaction.splitCount} categorías',
      _ => transaction.category?.name ?? 'Sin categoría',
    });
    if (showAccount) parts.add(transaction.account.name);
    if ((transaction.payee?.isNotEmpty ?? false) && (transaction.description?.isNotEmpty ?? false)) {
      parts.add(transaction.description!);
    }
  }
  if (sharedSummary(transaction) case final shared?) parts.add(shared);
  return parts.join(' · ');
}

({String amount, String detail})? uncategorizedMessage(UncategorizedSummary? summary) {
  if (summary == null || summary.expenseCents == 0) return null;
  final movements = summary.count == 1 ? '1 gasto' : '${summary.count} gastos';
  return (
    amount: '${formatMoney(summary.expenseCents)} sin categorizar',
    detail: '$movements aún no cuenta${summary.count == 1 ? '' : 'n'} en ningún presupuesto.',
  );
}

String greetingFor(int hour) => switch (hour) {
  >= 6 && < 14 => 'Buenos días',
  >= 14 && < 21 => 'Buenas tardes',
  _ => 'Buenas noches',
};

String movementsCount(int count) => count == 1 ? '1 movimiento' : '$count movimientos';

String upcomingSubtitle(UpcomingCharge charge, {DateTime? now}) =>
    '${formatShortDate(charge.date)} · ${inDaysLabel(daysBetween(today(now), charge.date))}';
