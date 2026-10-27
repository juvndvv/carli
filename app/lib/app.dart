import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/auth/auth_controller.dart';
import 'core/auth/biometric_lock.dart';
import 'core/lifecycle/home_quick_actions.dart';
import 'core/lifecycle/session_refresh.dart';
import 'core/push/push_bootstrap.dart';
import 'core/router/router.dart';
import 'core/theme/theme.dart';
import 'core/theme/theme_preference.dart';
import 'shell/launch/launch_overlay.dart';
import 'shell/lock/lock_screen.dart';
import 'ui/toast.dart';

class CarliApp extends ConsumerWidget {
  const CarliApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(pushBootstrapProvider);
    ref.watch(homeQuickActionsProvider);
    return MaterialApp.router(
      title: 'carli',
      debugShowCheckedModeBanner: false,
      theme: carliTheme(Brightness.light),
      darkTheme: carliTheme(Brightness.dark),
      themeMode: themeModeOf(ref.watch(themePreferenceProvider)),
      locale: const Locale('es', 'ES'),
      supportedLocales: const [Locale('es', 'ES')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => SessionRefresher(child: _LockGate(child: child!)),
    );
  }
}

class _LockGate extends ConsumerWidget {
  const _LockGate({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(authControllerProvider) is SignedIn;
    final locked = ref.watch(biometricLockProvider.select((lock) => lock.locked));
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          child,
          const ToastHost(),
          if (signedIn && locked) const Positioned.fill(child: LockScreen()),
          const Positioned.fill(child: LaunchOverlay()),
        ],
      ),
    );
  }
}
