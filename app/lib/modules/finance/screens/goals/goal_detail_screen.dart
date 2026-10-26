import 'package:flutter/material.dart';

import '../../../../ui/placeholder_view.dart';

class GoalDetailScreen extends StatelessWidget {
  const GoalDetailScreen({super.key, required this.goalId});

  final String goalId;

  @override
  Widget build(BuildContext context) => const PlaceholderView(title: 'Objetivo');
}
