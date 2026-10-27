import 'dart:async';

import 'package:carli/core/auth/auth_controller.dart';
import 'package:carli/core/push/push_platform.dart';

class FakePushPlatform implements PushPlatform {
  FakePushPlatform({
    this.currentPermission = PushPermission.notDetermined,
    this.grantOnRequest = true,
    this.failRegistration = false,
    this.launchedFrom,
  });

  PushPermission currentPermission;
  bool grantOnRequest;
  bool failRegistration;
  PushTap? launchedFrom;
  int permissionRequests = 0;
  int registrations = 0;
  final _taps = StreamController<PushTap>.broadcast();

  static const token = 'a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90';

  void tap(String? url) => _taps.add(PushTap(url));

  @override
  Stream<PushTap> get taps => _taps.stream;

  @override
  Future<PushTap?> launchTap() async => launchedFrom;

  @override
  Future<PushPermission> permission() async => currentPermission;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    currentPermission = grantOnRequest ? PushPermission.granted : PushPermission.denied;
    return grantOnRequest;
  }

  @override
  Future<PushRegistration> register() async {
    registrations++;
    if (failRegistration) throw StateError('APNs unavailable');
    return const PushRegistration(token: token, environment: PushEnvironment.sandbox);
  }
}

class FixedAuthController extends AuthController {
  FixedAuthController(this._initial);

  final AuthState _initial;

  @override
  AuthState build() => _initial;

  void emit(AuthState next) => state = next;
}
