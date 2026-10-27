import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum PushPermission { granted, denied, notDetermined }

enum PushEnvironment { sandbox, production }

@immutable
class PushRegistration {
  const PushRegistration({required this.token, required this.environment});

  final String token;
  final PushEnvironment environment;
}

@immutable
class PushTap {
  const PushTap(this.url);

  final String? url;
}

abstract interface class PushPlatform {
  Stream<PushTap> get taps;

  Future<PushTap?> launchTap();

  Future<PushPermission> permission();

  Future<bool> requestPermission();

  Future<PushRegistration> register();
}

class NativePushPlatform implements PushPlatform {
  NativePushPlatform() {
    _channel.setMethodCallHandler(_handle);
  }

  static const _channel = MethodChannel('carli/push');

  final _taps = StreamController<PushTap>.broadcast();

  Future<void> _handle(MethodCall call) async {
    if (call.method == 'opened') _taps.add(PushTap(_url(call.arguments)));
  }

  static String? _url(Object? arguments) => arguments is Map ? arguments['url'] as String? : null;

  @override
  Stream<PushTap> get taps => _taps.stream;

  @override
  Future<PushTap?> launchTap() async {
    final arguments = await _channel.invokeMethod<Object?>('launchTap');
    return arguments is Map ? PushTap(_url(arguments)) : null;
  }

  @override
  Future<PushPermission> permission() async => switch (await _channel.invokeMethod<String>('permission')) {
    'granted' => PushPermission.granted,
    'denied' => PushPermission.denied,
    _ => PushPermission.notDetermined,
  };

  @override
  Future<bool> requestPermission() async => await _channel.invokeMethod<bool>('requestPermission') ?? false;

  @override
  Future<PushRegistration> register() async {
    final result = (await _channel.invokeMapMethod<String, Object?>('register'))!;
    return PushRegistration(
      token: result['token']! as String,
      environment: result['environment'] == 'production' ? PushEnvironment.production : PushEnvironment.sandbox,
    );
  }

  void dispose() => _taps.close();
}

final pushPlatformProvider = Provider<PushPlatform>((ref) {
  final platform = NativePushPlatform();
  ref.onDispose(platform.dispose);
  return platform;
});
