import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../ui/card.dart';

class TaskGroup extends StatelessWidget {
  const TaskGroup({super.key, required this.children, this.indent = 50});

  final List<Widget> children;
  final double indent;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return CarliCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(CarliRadius.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (index, child) in children.indexed) ...[
              if (index > 0) Divider(height: 1, thickness: 1, indent: indent, color: colors.border),
              child,
            ],
          ],
        ),
      ),
    );
  }
}
