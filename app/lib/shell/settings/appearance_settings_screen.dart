import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/current_user.dart';
import '../../core/theme/theme_preference.dart';
import '../../core/theme/tokens.dart';
import '../../ui/card.dart';
import '../../ui/field.dart';
import '../../ui/page.dart';
import '../../ui/segmented.dart';

class AppearanceSettingsScreen extends ConsumerWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preference = ref.watch(themePreferenceProvider);
    return CarliPage(
      title: 'Apariencia',
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(CarliSpace.s16),
          sliver: SliverToBoxAdapter(
            child: CarliCard(
              child: CarliField(
                label: 'Tema',
                hint: '«Sistema» sigue el modo claro u oscuro de tu dispositivo.',
                child: CarliSegmented<ThemePreference>(
                  value: preference,
                  onChanged: (value) => ref.read(themePreferenceProvider.notifier).select(value),
                  segments: [for (final option in themePreferenceOrder) CarliSegment(option, option.label)],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
