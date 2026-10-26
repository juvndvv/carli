import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../ui/button.dart';
import '../../../ui/page.dart';
import 'biometric_section.dart';
import 'data/security_repository.dart';
import 'password_section.dart';
import 'sessions_section.dart';
import 'two_factor_section.dart';

class SecuritySettingsScreen extends ConsumerWidget {
  const SecuritySettingsScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(activeSessionsProvider);
    ref.invalidate(biometricAvailabilityProvider);
    await Future.wait([
      ref.read(authControllerProvider.notifier).refreshUser(),
      ref.read(activeSessionsProvider.future).then<void>((_) {}, onError: (_) {}),
    ]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CarliPage(
      title: 'Seguridad',
      onRefresh: () => _refresh(ref),
      slivers: [
        SliverList.list(
          children: [
            const CarliSection(title: 'Contraseña', child: ChangePasswordCard()),
            const CarliSection(title: 'Verificación en dos pasos', child: TwoFactorCard()),
            const CarliSection(title: 'Bloqueo de la app', child: BiometricLockCard()),
            CarliSection(
              title: 'Sesiones activas',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: CarliSpace.s8,
                children: [
                  const ActiveSessionsCard(),
                  Row(
                    spacing: CarliSpace.s12,
                    children: [
                      Expanded(
                        child: Text(
                          'Cierra la sesión en el resto de dispositivos y navegadores.',
                          style: CarliType.small.copyWith(color: context.colors.text3),
                        ),
                      ),
                      CarliButton(
                        label: 'Cerrar las demás',
                        variant: CarliButtonVariant.ghost,
                        size: CarliButtonSize.sm,
                        block: false,
                        onPressed: () => logoutOtherSessions(context, ref),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
