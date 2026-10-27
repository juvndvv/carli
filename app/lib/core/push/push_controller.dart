import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../notifications/notifications_api.dart';
import 'push_devices_api.dart';
import 'push_platform.dart';

@immutable
class PushState {
  const PushState({
    required this.permission,
    this.token,
    this.serverConfigured = false,
    this.registrationFailed = false,
  });

  final PushPermission permission;
  final String? token;
  final bool serverConfigured;
  final bool registrationFailed;

  bool get registered => permission == PushPermission.granted && token != null;

  bool get active => registered && serverConfigured;
}

final pushControllerProvider = AsyncNotifierProvider<PushController, PushState>(PushController.new);

class PushController extends AsyncNotifier<PushState> {
  Future<void> _tail = Future.value();

  PushPlatform get _platform => ref.read(pushPlatformProvider);
  PushDevicesApi get _api => ref.read(pushDevicesApiProvider);

  @override
  Future<PushState> build() async => PushState(permission: await ref.watch(pushPlatformProvider).permission());

  Future<void> activate() => _serialized(() async {
    var permission = await _platform.permission();
    if (permission == PushPermission.notDetermined) {
      await _platform.requestPermission();
      permission = await _platform.permission();
    }
    if (permission != PushPermission.granted) {
      state = AsyncData(PushState(permission: permission));
      return;
    }
    try {
      final registration = await _platform.register();
      final configured = await _api.register(registration);
      state = AsyncData(PushState(permission: permission, token: registration.token, serverConfigured: configured));
    } on Object {
      state = AsyncData(PushState(permission: permission, registrationFailed: true));
    }
  });

  Future<void> forget() => _serialized(() async {
    final current = state.value;
    final token = current?.token;
    if (current == null || token == null) return;
    try {
      await _api.unregister(token);
    } on Object {
      return;
    }
    state = AsyncData(PushState(permission: current.permission));
  });

  Future<bool> sendTest() async {
    final channels = await ref.read(notificationsApiProvider).sendTest();
    return channels.any((channel) => channel != 'database');
  }

  Future<void> _serialized(Future<void> Function() action) {
    final run = _tail.then((_) => action());
    _tail = run.then((_) {}, onError: (_) {});
    return run;
  }
}
