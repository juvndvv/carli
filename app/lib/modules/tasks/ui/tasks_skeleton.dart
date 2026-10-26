import 'package:flutter/widgets.dart';

import '../../../core/theme/tokens.dart';
import '../../../ui/skeleton.dart';
import 'task_group.dart';

class TasksSkeleton extends StatelessWidget {
  const TasksSkeleton({super.key, this.rows = 4});

  final int rows;

  @override
  Widget build(BuildContext context) => TaskGroup(
    children: [
      for (var index = 0; index < rows; index++)
        const Padding(
          padding: EdgeInsets.all(CarliSpace.s16),
          child: Row(
            spacing: CarliSpace.s12,
            children: [
              CarliSkeleton.circle(size: 22),
              Expanded(child: CarliSkeleton(height: 14)),
            ],
          ),
        ),
    ],
  );
}
