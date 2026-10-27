import 'package:flutter/widgets.dart';

import '../../../core/theme/tokens.dart';
import '../data/habits_models.dart';
import 'habit_ring.dart';

/// One day of a habit as a small mark: filled when met, outlined when missed, ringed today.
class DayDot extends StatelessWidget {
  const DayDot({super.key, required this.state, this.size = 14, this.square = false});

  final DayState state;
  final double size;
  final bool square;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ember = habitRingColor(context);
    final faint = colors.text3.withValues(alpha: 0.35);
    final radius = square ? BorderRadius.circular(size * 0.3) : BorderRadius.circular(size);
    final decoration = switch (state) {
      DayState.done => BoxDecoration(color: ember, borderRadius: radius),
      DayState.miss => BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: colors.text3, width: 1.5),
      ),
      DayState.today => BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: ember, width: 2),
      ),
      DayState.rest => BoxDecoration(
        color: colors.surface2,
        borderRadius: radius,
        border: Border.all(color: faint),
      ),
      DayState.future || DayState.off || DayState.none => null,
    };
    return Semantics(
      label: state.label,
      child: SizedBox.square(
        dimension: size,
        child: Center(
          child: switch (state) {
            DayState.future => Container(
              width: size * 0.4,
              height: size * 0.4,
              decoration: BoxDecoration(color: faint, shape: BoxShape.circle),
            ),
            DayState.off =>
              square
                  ? Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(color: colors.surface2, borderRadius: radius),
                    )
                  : Container(width: size * 0.55, height: 2, color: faint),
            DayState.none => const SizedBox.shrink(),
            _ => Container(width: size, height: size, decoration: decoration),
          },
        ),
      ),
    );
  }
}
