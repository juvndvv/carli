import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../ui/logo.dart';

class LaunchScreen extends StatelessWidget {
  const LaunchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.colors.bg,
      child: const Center(child: CarliLogo(size: 96)),
    );
  }
}
