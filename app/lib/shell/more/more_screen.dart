import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/router/router.dart';
import '../../core/theme/tokens.dart';
import '../../ui/button.dart';
import '../../ui/placeholder_view.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PlaceholderView(
      title: 'Más',
      children: [
        const SizedBox(height: CarliSpace.s32),
        CarliButton(
          label: 'Cerrar sesión',
          variant: CarliButtonVariant.secondary,
          size: CarliButtonSize.md,
          onPressed: () => ref.read(authControllerProvider.notifier).logout(),
        ),
        if (kDebugMode) ...[
          const SizedBox(height: CarliSpace.s8),
          CarliButton(
            label: 'Catálogo de componentes',
            variant: CarliButtonVariant.ghost,
            size: CarliButtonSize.md,
            onPressed: () => context.push(Routes.catalog),
          ),
        ],
      ],
    );
  }
}
