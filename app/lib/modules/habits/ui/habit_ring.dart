import 'package:flutter/widgets.dart';

import '../../../core/theme/tokens.dart';
import '../../../ui/icon.dart';
import '../../../ui/icon_names.dart';
import '../../../ui/ring.dart';

/// Every habit ring is ember; the icon in the middle stays neutral.
Color habitRingColor(BuildContext context) => context.colors.rings.first;

class HabitRing extends StatelessWidget {
  const HabitRing({
    super.key,
    required this.icon,
    required this.progress,
    required this.semanticLabel,
    this.size = 48,
    this.stroke = 6,
  });

  final String icon;
  final double progress;
  final String semanticLabel;
  final double size;
  final double stroke;

  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    children: [
      CarliRings(
        rings: [CarliRingValue(progress, habitRingColor(context))],
        size: size,
        stroke: stroke,
        semanticLabel: semanticLabel,
      ),
      ExcludeSemantics(
        child: CarliIcon(carliIconNamed(icon), size: size * 0.4, color: context.colors.text),
      ),
    ],
  );
}

class HabitRingButton extends StatelessWidget {
  const HabitRingButton({
    super.key,
    required this.icon,
    required this.progress,
    required this.label,
    required this.onTap,
    this.onLongPress,
    this.size = 48,
    this.stroke = 6,
  });

  final String icon;
  final double progress;
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final double size;
  final double stroke;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    onLongPressHint: onLongPress == null ? null : 'Registrar una cantidad',
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
      child: SizedBox.square(
        dimension: size < 44 ? 44 : size,
        child: Center(
          child: HabitRing(icon: icon, progress: progress, semanticLabel: label, size: size, stroke: stroke),
        ),
      ),
    ),
  );
}
