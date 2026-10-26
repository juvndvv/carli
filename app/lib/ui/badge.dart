import 'package:flutter/widgets.dart';

import '../core/theme/tokens.dart';
import '../core/theme/typography.dart';
import 'icon.dart';

enum CarliBadgeTone { neutral, primary, positive, warning, negative }

class CarliBadge extends StatelessWidget {
  const CarliBadge(this.label, {super.key, this.tone = CarliBadgeTone.neutral, this.icon});

  final String label;
  final CarliBadgeTone tone;
  final CarliIconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (background, foreground) = switch (tone) {
      CarliBadgeTone.neutral => (colors.surface2, colors.text2),
      CarliBadgeTone.primary => (colors.primarySoft, colors.brandInk),
      CarliBadgeTone.positive => (colors.positiveSoft, colors.positive),
      CarliBadgeTone.warning => (colors.warningSoft, colors.warning),
      CarliBadgeTone.negative => (colors.negativeSoft, colors.negative),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s8, vertical: 3),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(CarliRadius.full)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: CarliSpace.s4,
        children: [
          if (icon case final icon?) CarliIcon(icon, size: 12, color: foreground, strokeWidth: 2),
          Text(label, style: CarliType.caption.copyWith(color: foreground)),
        ],
      ),
    );
  }
}
