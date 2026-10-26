import 'package:flutter/material.dart';

import '../core/theme/tokens.dart';
import '../core/theme/typography.dart';
import 'page.dart';

class PlaceholderView extends StatelessWidget {
  const PlaceholderView({super.key, required this.title, this.children = const []});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return CarliPage(
      title: title,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16),
          sliver: SliverList.list(
            children: [
              Text('Pronto aquí.', style: CarliType.body.copyWith(color: colors.text2)),
              ...children,
            ],
          ),
        ),
      ],
    );
  }
}
