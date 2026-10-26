import 'package:flutter/widgets.dart';

import '../core/theme/tokens.dart';
import '../core/theme/typography.dart';
import 'icon.dart';
import 'pressable.dart';

class CarliCategory {
  const CarliCategory({required this.id, required this.name, required this.icon});

  final String id;
  final String name;
  final CarliIconData icon;
}

class CarliCategoryPicker extends StatelessWidget {
  const CarliCategoryPicker({
    super.key,
    required this.categories,
    required this.value,
    required this.onChanged,
    this.columns = 4,
  });

  final List<CarliCategory> categories;
  final String? value;
  final ValueChanged<String> onChanged;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - CarliSpace.s8 * (columns - 1)) / columns;
        return Wrap(
          spacing: CarliSpace.s8,
          runSpacing: CarliSpace.s12,
          children: [
            for (final category in categories)
              SizedBox(
                width: width,
                child: Semantics(
                  inMutuallyExclusiveGroup: true,
                  checked: category.id == value,
                  button: true,
                  label: category.name,
                  excludeSemantics: true,
                  child: Pressable(
                    onTap: () => onChanged(category.id),
                    child: Column(
                      spacing: CarliSpace.s4,
                      children: [
                        AnimatedContainer(
                          duration: CarliMotion.hover,
                          width: 48,
                          height: 48,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: category.id == value ? colors.primary : colors.surface2,
                            shape: BoxShape.circle,
                          ),
                          child: CarliIcon(
                            category.icon,
                            size: 22,
                            color: category.id == value ? colors.onPrimary : colors.text,
                          ),
                        ),
                        Text(
                          category.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: CarliType.caption.copyWith(
                            color: category.id == value ? colors.text : colors.text2,
                            fontWeight: category.id == value ? FontWeight.w600 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
