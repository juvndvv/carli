import 'package:flutter/widgets.dart';

import '../core/theme/tokens.dart';
import 'pressable.dart';

class CarliCard extends StatelessWidget {
  const CarliCard({super.key, required this.child, this.padding = const EdgeInsets.all(CarliSpace.s16), this.onTap});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(CarliRadius.lg),
        border: Border.all(color: colors.cardBorder),
      ),
      child: child,
    );
    return onTap == null ? card : Pressable(onTap: onTap, pressedOpacity: 0.7, child: card);
  }
}
