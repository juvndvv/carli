import 'package:flutter/widgets.dart';

import '../core/theme/tokens.dart';
import '../core/theme/typography.dart';

String initialsOf(String name) {
  final words = name.trim().split(RegExp(r'\s+')).where((word) => word.isNotEmpty).toList();
  if (words.isEmpty) return '?';
  final letters = words.length == 1
      ? words.first.characters.take(2)
      : [words.first.characters.first, words.last.characters.first];
  return letters.join().toUpperCase();
}

class CarliAvatar extends StatelessWidget {
  const CarliAvatar({super.key, required this.name, this.size = 36});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      label: name,
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: colors.surface2, shape: BoxShape.circle),
        child: Text(
          initialsOf(name),
          style: CarliType.caption.copyWith(fontSize: size * 0.36, fontWeight: FontWeight.w600, color: colors.text2),
        ),
      ),
    );
  }
}
