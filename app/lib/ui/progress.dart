import 'package:flutter/widgets.dart';
import 'package:hugeicons/styles/stroke_rounded.dart';

import '../core/format/money.dart';
import '../core/theme/tokens.dart';
import '../core/theme/typography.dart';
import 'icon.dart';

enum ProgressState { ok, warn, over }

enum ProgressTone { budget, goal }

ProgressState progressState(double ratio, {double warnAt = 0.8}) {
  if (ratio > 1) return ProgressState.over;
  return ratio >= warnAt ? ProgressState.warn : ProgressState.ok;
}

String progressStateLabel(ProgressState state) => switch (state) {
  ProgressState.ok => 'En margen',
  ProgressState.warn => 'Cerca del límite',
  ProgressState.over => 'Excedido',
};

double ratioOf(num value, num max) => max == 0 ? 0 : value / max;

class CarliProgress extends StatelessWidget {
  const CarliProgress({super.key, required this.ratio, this.tone = ProgressTone.budget, this.label});

  final double ratio;
  final ProgressTone tone;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final percent = (ratio * 100).round();
    return Semantics(
      label: label,
      value: tone == ProgressTone.budget ? '$percent %, ${progressStateLabel(progressState(ratio))}' : '$percent %',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(CarliRadius.full),
        child: SizedBox(
          height: 8,
          child: Stack(
            children: [
              Positioned.fill(child: ColoredBox(color: colors.surface2)),
              Positioned.fill(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: ratio.clamp(0, 1).toDouble()),
                  duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : CarliMotion.enter,
                  curve: Curves.easeOut,
                  builder: (context, value, _) => FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: value,
                    heightFactor: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: tone == ProgressTone.budget ? colors.text : colors.primaryStrong,
                        borderRadius: BorderRadius.circular(CarliRadius.full),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CarliProgressFigure extends StatelessWidget {
  const CarliProgressFigure({super.key, required this.spent, required this.limit, this.warnAt = 0.8});

  final int spent;
  final int limit;
  final double warnAt;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final state = progressState(ratioOf(spent, limit), warnAt: warnAt);
    final (color, icon) = switch (state) {
      ProgressState.ok => (colors.text, null),
      ProgressState.warn => (colors.warning, HugeIconsStrokeRounded.alert02),
      ProgressState.over => (colors.negative, HugeIconsStrokeRounded.alertCircle),
    };
    final style = CarliType.money(CarliType.small)
        .copyWith(color: color, fontWeight: state == ProgressState.ok ? FontWeight.w400 : FontWeight.w600);
    return Semantics(
      label: '${formatMoney(spent)} de ${formatMoney(limit)}, ${progressStateLabel(state)}',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: CarliSpace.s4,
        children: [
          if (icon != null) CarliIcon(icon, size: 14, color: color, strokeWidth: 2),
          Text('${formatMoneyFigure(spent, currency: false)} / ${formatMoneyFigure(limit)}', style: style),
        ],
      ),
    );
  }
}
