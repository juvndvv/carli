import 'package:flutter/widgets.dart';

import '../../../core/theme/tokens.dart';
import '../../../ui/icon.dart';
import '../../../ui/icon_names.dart';
import '../../../ui/pressable.dart';

/// Round check from the mockups: hollow ring while open, filled with a tick once done, dashed for planned occurrences.
class TaskCheck extends StatelessWidget {
  const TaskCheck({super.key, required this.done, this.onTap, this.planned = false, this.label, this.size = 22});

  final bool done;
  final bool planned;
  final VoidCallback? onTap;
  final String? label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final circle = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done ? colors.primary : null,
        border: done ? null : Border.all(color: planned ? colors.border : colors.text3, width: 1.5),
      ),
      child: done ? CarliIcon(carliIconNamed('check'), size: size * 0.64, color: colors.onPrimary) : null,
    );
    if (onTap == null) return circle;
    return Semantics(
      container: true,
      button: true,
      checked: done,
      label: label ?? (done ? 'Marcar como pendiente' : 'Marcar como hecha'),
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(CarliSpace.s8), child: circle),
      ),
    );
  }
}
