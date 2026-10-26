import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../ui/badge.dart';
import '../../../ui/icon.dart';
import '../../../ui/icon_names.dart';
import '../../../ui/pressable.dart';
import '../data/finance_format.dart';
import '../data/finance_providers.dart';
import '../data/models.dart';

class TransactionRow extends StatelessWidget {
  const TransactionRow({
    super.key,
    required this.transaction,
    this.accounts,
    this.onTap,
    this.showAccount = true,
    this.selectable = false,
    this.selected = false,
  });

  final Transaction transaction;
  final AccountsData? accounts;
  final VoidCallback? onTap;
  final bool showAccount;
  final bool selectable;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final soft = transactionNeedsCategory(transaction);
    final amountColor = switch (transaction) {
      Transaction(kind: TransactionKind.transfer) => colors.text2,
      Transaction(amountCents: > 0) => colors.positive,
      _ => colors.text,
    };
    final badges = [
      if (transaction.uncategorized) CarliBadge('Por revisar', icon: carliIconNamed('circle-dashed')),
      if (transaction.transferSource == TransferSource.auto) CarliBadge('Detectada', icon: carliIconNamed('sparkles')),
      if (transaction.status == TransactionStatus.pending) CarliBadge('Pendiente', icon: carliIconNamed('clock')),
      if (transaction.shares.isNotEmpty)
        CarliBadge('Compartido', tone: CarliBadgeTone.primary, icon: carliIconNamed('users')),
      if (transaction.isSplit) CarliBadge('Dividido', icon: carliIconNamed('split')),
      for (final tag in transaction.tags) CarliBadge('#$tag'),
    ];
    final title = transactionTitle(transaction);
    final subtitle = transactionSubtitle(transaction, accounts: accounts, showAccount: showAccount);
    final amount = transactionAmountLabel(transaction);

    return Semantics(
      button: onTap != null,
      checked: selectable ? selected : null,
      label: '$title, $amount, $subtitle${transaction.fromBank ? ', importado del banco' : ''}',
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        pressedOpacity: 0.5,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16, vertical: CarliSpace.s12),
          child: Row(
            spacing: CarliSpace.s12,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selectable && selected ? colors.primary : colors.surface2,
                  border: soft && !selectable ? Border.all(color: colors.border) : null,
                ),
                child: selectable
                    ? CarliIcon(
                        carliIconNamed(selected ? 'check' : 'circle'),
                        size: 20,
                        strokeWidth: 2,
                        color: selected ? colors.onPrimary : colors.text3,
                      )
                    : CarliIcon(
                        carliIconNamed(transactionIconName(transaction)),
                        size: 20,
                        color: soft ? colors.text2 : colors.text,
                      ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Row(
                      spacing: CarliSpace.s4,
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: CarliType.body.copyWith(fontWeight: FontWeight.w500, color: colors.text),
                          ),
                        ),
                        if (transaction.fromBank) CarliIcon(carliIconNamed('landmark'), size: 13, color: colors.text3),
                      ],
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CarliType.small.copyWith(color: colors.text2),
                    ),
                    if (badges.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Wrap(spacing: CarliSpace.s4, runSpacing: CarliSpace.s4, children: badges),
                      ),
                  ],
                ),
              ),
              Text(
                amount,
                style: CarliType.money(CarliType.body).copyWith(fontWeight: FontWeight.w600, color: amountColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
