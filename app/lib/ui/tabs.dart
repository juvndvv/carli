import 'package:flutter/widgets.dart';

import '../core/theme/tokens.dart';
import '../core/theme/typography.dart';
import 'pressable.dart';

class CarliTabs<T> extends StatelessWidget {
  const CarliTabs({super.key, required this.tabs, required this.value, required this.onChanged});

  final List<(T, String)> tabs;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          spacing: CarliSpace.s20,
          children: [
            for (final (tab, label) in tabs)
              Semantics(
                selected: tab == value,
                button: true,
                child: Pressable(
                  onTap: () => onChanged(tab),
                  child: AnimatedContainer(
                    duration: CarliMotion.hover,
                    padding: const EdgeInsets.symmetric(vertical: CarliSpace.s12),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: tab == value ? colors.text : const Color(0x00000000), width: 2),
                      ),
                    ),
                    child: Text(
                      label,
                      style: CarliType.body.copyWith(
                        fontWeight: tab == value ? FontWeight.w600 : FontWeight.w500,
                        color: tab == value ? colors.text : colors.text2,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
