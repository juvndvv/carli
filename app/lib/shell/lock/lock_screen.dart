import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:hugeicons/styles/stroke_rounded.dart';

import '../../core/auth/biometric_lock.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../ui/button.dart';

class LockScreen extends ConsumerWidget {
  const LockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final lock = ref.watch(biometricLockProvider);
    return Material(
      color: colors.bg,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(CarliSpace.s24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                spacing: CarliSpace.s16,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(color: colors.primary, shape: BoxShape.circle),
                    child: HugeIcon(icon: HugeIconsStrokeRounded.scanFace, size: 40, color: colors.onPrimary),
                  ),
                  Semantics(
                    header: true,
                    child: Text('carli está bloqueada', style: CarliType.h2.copyWith(fontSize: 20, color: colors.text)),
                  ),
                  Text(
                    'Usa ${lock.label} para continuar.',
                    textAlign: TextAlign.center,
                    style: CarliType.small.copyWith(color: colors.text2),
                  ),
                  CarliButton(
                    label: 'Desbloquear',
                    loading: lock.busy,
                    icon: HugeIconsStrokeRounded.scanFace,
                    onPressed: ref.read(biometricLockProvider.notifier).unlock,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
