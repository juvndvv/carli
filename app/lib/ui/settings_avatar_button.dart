import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_controller.dart';
import '../core/router/router.dart';
import 'avatar.dart';
import 'pressable.dart';

/// Avatar at the top right, as in Fitness: opens Ajustes.
class SettingsAvatarButton extends ConsumerWidget {
  const SettingsAvatarButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = switch (ref.watch(authControllerProvider)) {
      SignedIn(:final user?) => user.name,
      _ => '',
    };
    return Semantics(
      button: true,
      label: 'Ajustes',
      excludeSemantics: true,
      child: Pressable(
        onTap: () => context.push(Routes.settings),
        child: CarliAvatar(name: name, size: 32),
      ),
    );
  }
}
