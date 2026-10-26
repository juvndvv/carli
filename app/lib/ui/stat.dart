import 'package:flutter/widgets.dart';

import '../core/theme/tokens.dart';
import '../core/theme/typography.dart';
import 'card.dart';
import 'icon.dart';

enum CarliTone { normal, positive, warning, negative, muted }

extension CarliToneColor on CarliTone {
  Color resolve(CarliColors colors) => switch (this) {
    CarliTone.normal => colors.text,
    CarliTone.positive => colors.positive,
    CarliTone.warning => colors.warning,
    CarliTone.negative => colors.negative,
    CarliTone.muted => colors.text2,
  };
}

class CarliStat extends StatelessWidget {
  const CarliStat({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.tone = CarliTone.normal,
    this.delta,
    this.deltaIcon,
    this.deltaTone = CarliTone.muted,
    this.card = true,
  });

  final String label;
  final String value;
  final CarliIconData? icon;
  final CarliTone tone;
  final String? delta;
  final CarliIconData? deltaIcon;
  final CarliTone deltaTone;
  final bool card;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final deltaColor = deltaTone.resolve(colors);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: CarliSpace.s4,
      children: [
        Row(
          spacing: CarliSpace.s4,
          children: [
            if (icon case final icon?) CarliIcon(icon, size: 14, color: colors.text2),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: CarliType.small.copyWith(color: colors.text2),
              ),
            ),
          ],
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: CarliType.money(
              CarliType.h1.copyWith(fontSize: 24, height: 30 / 24, fontWeight: FontWeight.w600, letterSpacing: -0.4),
            ).copyWith(color: tone.resolve(colors)),
          ),
        ),
        if (delta case final delta?)
          Row(
            spacing: CarliSpace.s4,
            children: [
              if (deltaIcon case final deltaIcon?) CarliIcon(deltaIcon, size: 14, color: deltaColor, strokeWidth: 2),
              Flexible(
                child: Text(delta, style: CarliType.small.copyWith(color: deltaColor)),
              ),
            ],
          ),
      ],
    );
    return Semantics(container: true, child: card ? CarliCard(child: content) : content);
  }
}
