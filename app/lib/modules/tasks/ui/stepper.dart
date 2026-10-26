import 'package:flutter/widgets.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../ui/icon.dart';
import '../../../ui/icon_names.dart';
import '../../../ui/pressable.dart';

class CountStepper extends StatelessWidget {
  const CountStepper({
    super.key,
    required this.value,
    required this.label,
    required this.onChanged,
    this.min = 1,
    this.max = 365,
    this.semanticName = 'valor',
  });

  final int value;
  final String label;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final String semanticName;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    Widget button(String icon, String semantic, int? next) => Semantics(
      button: true,
      enabled: next != null,
      label: semantic,
      excludeSemantics: true,
      child: Pressable(
        onTap: next == null ? null : () => onChanged(next),
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: colors.surface2, shape: BoxShape.circle),
          child: CarliIcon(carliIconNamed(icon), size: 16, color: next == null ? colors.text3 : colors.text),
        ),
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: CarliSpace.s12,
      children: [
        button('minus', 'Menos $semanticName', value > min ? value - 1 : null),
        Text(label, style: CarliType.money(CarliType.bodyStrong).copyWith(color: colors.text)),
        button('plus', 'Más $semanticName', value < max ? value + 1 : null),
      ],
    );
  }
}
