import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/biometric_lock.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../ui/card.dart';
import '../../../ui/switch.dart';
import '../../../ui/toast.dart';

final biometricAvailabilityProvider = FutureProvider.autoDispose<bool>((ref) async {
  try {
    return await ref.read(biometricLockProvider.notifier).isAvailable();
  } catch (_) {
    return false;
  }
});

class BiometricLockCard extends ConsumerStatefulWidget {
  const BiometricLockCard({super.key});

  @override
  ConsumerState<BiometricLockCard> createState() => _BiometricLockCardState();
}

class _BiometricLockCardState extends ConsumerState<BiometricLockCard> {
  bool? _requested;

  Future<void> _toggle(bool enabled) async {
    setState(() => _requested = enabled);
    final lock = ref.read(biometricLockProvider.notifier);
    await lock.setEnabled(enabled);
    if (!mounted) return;
    setState(() => _requested = null);
    if (ref.read(biometricLockProvider).enabled == enabled) {
      ref.read(toastControllerProvider.notifier).show(enabled ? 'Bloqueo activado' : 'Bloqueo desactivado');
    }
  }

  @override
  Widget build(BuildContext context) {
    final lock = ref.watch(biometricLockProvider);
    final available = ref.watch(biometricAvailabilityProvider).value;
    final colors = context.colors;
    if (available == null) return const SizedBox.shrink();
    final usable = available || lock.enabled;
    return CarliCard(
      child: Row(
        spacing: CarliSpace.s12,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: CarliSpace.s4,
              children: [
                Text(
                  'Bloqueo con ${lock.label}',
                  style: CarliType.body.copyWith(fontWeight: FontWeight.w500, color: colors.text),
                ),
                Text(
                  usable
                      ? 'Pide ${lock.label} al abrir la app y al volver a ella.'
                      : 'Configura Face ID o Touch ID en los Ajustes del iPhone para poder bloquear carli.',
                  style: CarliType.small.copyWith(color: colors.text2),
                ),
              ],
            ),
          ),
          if (usable)
            CarliSwitch(
              value: _requested ?? lock.enabled,
              semanticLabel: 'Bloqueo con ${lock.label}',
              onChanged: _requested != null || lock.busy ? null : _toggle,
            ),
        ],
      ),
    );
  }
}
