import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../ui/icon.dart';
import '../../../ui/icon_names.dart';
import '../../../ui/pressable.dart';
import '../data/finance_format.dart';
import '../data/models.dart';

class UncategorizedNotice extends StatelessWidget {
  const UncategorizedNotice({super.key, required this.summary, required this.onReview});

  final UncategorizedSummary? summary;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final message = uncategorizedMessage(summary);
    if (message == null) return const SizedBox.shrink();
    final colors = context.colors;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.all(CarliSpace.s12),
        decoration: BoxDecoration(color: colors.surface2, borderRadius: BorderRadius.circular(CarliRadius.md)),
        child: Row(
          spacing: CarliSpace.s12,
          children: [
            CarliIcon(carliIconNamed('circle-dashed'), size: 20, color: colors.text2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.amount,
                    style: CarliType.money(CarliType.small).copyWith(fontWeight: FontWeight.w600, color: colors.text),
                  ),
                  Text(message.detail, style: CarliType.small.copyWith(color: colors.text2)),
                ],
              ),
            ),
            Semantics(
              button: true,
              child: Pressable(
                onTap: onReview,
                child: Text(
                  'Revisar',
                  style: CarliType.small.copyWith(fontWeight: FontWeight.w600, color: colors.brandInk),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
