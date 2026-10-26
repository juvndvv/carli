import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import 'token_store.dart';

final localAuthProvider = Provider<LocalAuthentication>((ref) => LocalAuthentication());

final biometricLockProvider = NotifierProvider<BiometricLock, BiometricLockState>(BiometricLock.new);

@immutable
class BiometricLockState {
  const BiometricLockState({
    this.enabled = false,
    this.locked = false,
    this.busy = false,
    this.ready = false,
    this.label = 'Face ID',
  });

  final bool enabled;
  final bool locked;
  final bool busy;
  final bool ready;
  final String label;

  BiometricLockState copyWith({bool? enabled, bool? locked, bool? busy, bool? ready, String? label}) =>
      BiometricLockState(
        enabled: enabled ?? this.enabled,
        locked: locked ?? this.locked,
        busy: busy ?? this.busy,
        ready: ready ?? this.ready,
        label: label ?? this.label,
      );
}

class BiometricLock extends Notifier<BiometricLockState> {
  static const _enabledKey = 'biometric_lock_enabled';

  FlutterSecureStorage get _storage => ref.read(secureStorageProvider);
  LocalAuthentication get _auth => ref.read(localAuthProvider);

  @override
  BiometricLockState build() {
    final listener = AppLifecycleListener(onHide: lock, onShow: _unlockIfLocked);
    ref.onDispose(listener.dispose);
    Future.microtask(_restore);
    return const BiometricLockState();
  }

  Future<void> _restore() async {
    if (await _storage.read(key: _enabledKey) != 'true') {
      state = state.copyWith(ready: true);
      return;
    }
    state = state.copyWith(enabled: true, locked: true, label: await _label());
    await unlock();
    state = state.copyWith(ready: true);
  }

  Future<bool> isAvailable() async => await _auth.isDeviceSupported() && await _auth.canCheckBiometrics;

  Future<void> setEnabled(bool enabled) async {
    if (enabled && !await _authenticate('Activa el bloqueo de carli')) return;
    await _storage.write(key: _enabledKey, value: '$enabled');
    state = state.copyWith(enabled: enabled, locked: false, label: enabled ? await _label() : null);
  }

  void lock() {
    if (state.enabled) state = state.copyWith(locked: true);
  }

  void _unlockIfLocked() {
    if (state.locked) unlock();
  }

  Future<void> unlock() async {
    if (state.busy) return;
    state = state.copyWith(busy: true);
    final passed = await _authenticate('Desbloquea carli');
    state = state.copyWith(busy: false, locked: !passed);
  }

  Future<bool> _authenticate(String reason) async {
    try {
      return await _auth.authenticate(localizedReason: reason, persistAcrossBackgrounding: true);
    } on LocalAuthException {
      return false;
    }
  }

  Future<String> _label() async {
    try {
      final types = await _auth.getAvailableBiometrics();
      if (types.contains(BiometricType.fingerprint)) return 'Touch ID';
    } on LocalAuthException {
      return 'Face ID';
    }
    return 'Face ID';
  }
}
