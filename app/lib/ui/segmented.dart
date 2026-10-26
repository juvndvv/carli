import 'package:flutter/cupertino.dart';

import '../core/theme/tokens.dart';
import '../core/theme/typography.dart';

class CarliSegment<T> {
  const CarliSegment(this.value, this.label);

  final T value;
  final String label;
}

class CarliSegmented<T extends Object> extends StatelessWidget {
  const CarliSegmented({super.key, required this.segments, required this.value, required this.onChanged});

  final List<CarliSegment<T>> segments;
  final T value;
  final ValueChanged<T> onChanged;

  static const _activeText = Color(0xFF1F1F1F);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      width: double.infinity,
      child: CupertinoSlidingSegmentedControl<T>(
        groupValue: value,
        backgroundColor: colors.surface2,
        thumbColor: const Color(0xFFFFFFFF),
        padding: const EdgeInsets.all(3),
        onValueChanged: (selected) {
          if (selected != null) onChanged(selected);
        },
        children: {
          for (final segment in segments)
            segment.value: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                segment.label,
                style: CarliType.small.copyWith(
                  fontWeight: FontWeight.w600,
                  color: segment.value == value ? _activeText : colors.text2,
                ),
              ),
            ),
        },
      ),
    );
  }
}
