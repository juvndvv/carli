import 'package:flutter/widgets.dart';

import '../core/format/money.dart';
import '../core/theme/tokens.dart';
import '../core/theme/typography.dart';

enum AmountKind { expense, income, transfer, neutral }

AmountKind amountKindOf(int cents) => cents < 0 ? AmountKind.expense : AmountKind.income;

class CarliAmount extends StatelessWidget {
  const CarliAmount(this.cents, {super.key, this.kind, this.style});

  final int cents;
  final AmountKind? kind;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final resolved = cents == 0 ? AmountKind.neutral : kind ?? amountKindOf(cents);
    final (text, color) = switch (resolved) {
      AmountKind.expense => ('$minusSign${formatMoney(cents.abs())}', colors.text),
      AmountKind.income => (formatMoney(cents.abs(), display: MoneyDisplay.signed), colors.positive),
      AmountKind.transfer => (formatMoney(cents.abs()), colors.text2),
      AmountKind.neutral => (formatMoney(cents), colors.text),
    };
    final base = style ?? CarliType.body.copyWith(fontWeight: FontWeight.w600);
    return Text(text, style: CarliType.money(base).copyWith(color: color));
  }
}
