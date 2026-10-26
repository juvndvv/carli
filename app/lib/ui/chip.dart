import 'package:flutter/widgets.dart';

import '../core/theme/tokens.dart';
import '../core/theme/typography.dart';
import 'icon.dart';
import 'pressable.dart';

class CarliChip extends StatelessWidget {
  const CarliChip({super.key, this.label, this.icon, this.selected = false, this.onTap, this.semanticLabel});

  final String? label;
  final CarliIconData? icon;
  final bool selected;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final foreground = selected ? colors.onPrimary : colors.text;
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      excludeSemantics: semanticLabel != null,
      child: Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: CarliMotion.hover,
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s12),
          decoration: BoxDecoration(
            color: selected ? colors.primary : colors.surface,
            borderRadius: BorderRadius.circular(CarliRadius.chip),
            border: Border.all(color: selected ? colors.primary : colors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: CarliSpace.s4,
            children: [
              if (icon case final icon?) CarliIcon(icon, size: 16, color: foreground),
              if (label case final label?)
                Text(
                  label,
                  style: CarliType.small.copyWith(fontWeight: FontWeight.w500, color: foreground),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
