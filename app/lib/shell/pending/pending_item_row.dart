import 'package:flutter/widgets.dart';

import '../../core/format/dates.dart';
import '../../core/format/money.dart';
import '../../core/pending/pending_models.dart';
import '../../core/pending/pending_types.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../ui/button.dart';
import '../../ui/icon.dart';
import '../../ui/icon_names.dart';

String pendingItemSubtitle(PendingItem item, {DateTime? now}) => [
  formatRelativeDay(item.date, now: now, style: RelativeDateStyle.title),
  ?item.subtitle,
].where((part) => part.isNotEmpty).join(' · ');

class PendingItemRow extends StatelessWidget {
  const PendingItemRow({super.key, required this.item, required this.descriptor, this.action, this.onReview});

  final PendingItem item;
  final PendingTypeDescriptor descriptor;
  final Widget? action;
  final VoidCallback? onReview;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final amount = item.amountCents;
    final trailingAction =
        action ??
        (onReview == null
            ? null
            : CarliButton(
                label: 'Revisar',
                variant: CarliButtonVariant.secondary,
                size: CarliButtonSize.sm,
                block: false,
                onPressed: onReview,
              ));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16, vertical: CarliSpace.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: CarliSpace.s8,
        children: [
          Row(
            spacing: CarliSpace.s12,
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: colors.surface2, shape: BoxShape.circle),
                child: CarliIcon(carliIconNamed(descriptor.icon), size: 18, color: colors.text2),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CarliType.body.copyWith(fontWeight: FontWeight.w500, color: colors.text),
                    ),
                    Text(
                      pendingItemSubtitle(item),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CarliType.small.copyWith(color: colors.text2),
                    ),
                  ],
                ),
              ),
              if (amount != null)
                Text(
                  formatMoney(amount, display: MoneyDisplay.signed),
                  style: CarliType.money(CarliType.body)
                      .copyWith(fontWeight: FontWeight.w500, color: amount > 0 ? colors.positive : colors.text),
                ),
            ],
          ),
          if (trailingAction != null) Padding(padding: const EdgeInsets.only(left: 48), child: trailingAction),
        ],
      ),
    );
  }
}
