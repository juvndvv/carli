import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/auth/current_user.dart';
import '../../core/modules/app_module.dart';
import '../../core/modules/modules_provider.dart';
import '../../core/theme/theme_preference.dart';
import '../../core/theme/tokens.dart';
import '../../ui/avatar.dart';
import '../../ui/card.dart';
import '../../ui/icon.dart';
import '../../ui/icon_names.dart';
import '../../ui/list_item.dart';
import '../../ui/page.dart';

abstract final class SettingsPaths {
  static const root = '/mas/ajustes';
  static const profile = '$root/perfil';
  static const security = '$root/seguridad';
  static const notifications = '$root/avisos';
  static const modules = '$root/modulos';
  static const appearance = '$root/apariencia';
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final user = auth is SignedIn ? auth.user : null;
    final theme = ref.watch(themePreferenceProvider);
    final moduleSettings = [
      for (final module in ref.watch(modulesProvider).value ?? const <AppModule>[])
        if (module.enabled && moduleSettingsLocationOf(module.id) != null) module,
    ];

    return CarliPage(
      title: 'Ajustes',
      onRefresh: () async {
        ref.invalidate(modulesProvider);
        await ref.read(authControllerProvider.notifier).refreshUser();
      },
      slivers: [
        SliverList.list(
          children: [
            SettingsGroup(
              title: 'Cuenta',
              children: [
                CarliListItem(
                  title: 'Perfil',
                  subtitle: user?.email,
                  leading: user == null ? null : CarliAvatar(name: user.name, size: 40),
                  icon: carliIconNamed('user'),
                  trailing: const SettingsChevron(),
                  onTap: () => context.push(SettingsPaths.profile),
                ),
                CarliListItem(
                  title: 'Seguridad',
                  icon: carliIconNamed('shield'),
                  trailing: const SettingsChevron(),
                  onTap: () => context.push(SettingsPaths.security),
                ),
                CarliListItem(
                  title: 'Avisos',
                  icon: carliIconNamed('bell'),
                  trailing: const SettingsChevron(),
                  onTap: () => context.push(SettingsPaths.notifications),
                ),
                CarliListItem(
                  title: 'Apariencia',
                  subtitle: theme.label,
                  icon: carliIconNamed(themeIconName(theme)),
                  trailing: const SettingsChevron(),
                  onTap: () => context.push(SettingsPaths.appearance),
                ),
              ],
            ),
            SettingsGroup(
              title: 'Módulos',
              children: [
                CarliListItem(
                  title: 'Módulos',
                  icon: carliIconNamed('layout-dashboard'),
                  trailing: const SettingsChevron(),
                  onTap: () => context.push(SettingsPaths.modules),
                ),
                for (final module in moduleSettings)
                  CarliListItem(
                    title: module.name,
                    subtitle: 'Ajustes del módulo',
                    icon: carliIconNamed(module.icon),
                    trailing: const SettingsChevron(),
                    onTap: () => context.push(moduleSettingsLocationOf(module.id)!),
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

String themeIconName(ThemePreference preference) => switch (preference) {
  ThemePreference.light => 'sun',
  ThemePreference.dark => 'moon',
  ThemePreference.system => 'monitor',
};

class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, this.title, required this.children, this.dividerIndent = 68});

  final String? title;
  final List<Widget> children;
  final double dividerIndent;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return CarliSection(
      title: title,
      child: CarliCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (final (index, child) in children.indexed) ...[
              if (index > 0) Divider(indent: dividerIndent, color: colors.border),
              child,
            ],
          ],
        ),
      ),
    );
  }
}

class SettingsChevron extends StatelessWidget {
  const SettingsChevron({super.key});

  @override
  Widget build(BuildContext context) =>
      CarliIcon(carliIconNamed('chevron-right'), size: 18, color: context.colors.text3);
}
