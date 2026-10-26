import 'package:flutter_test/flutter_test.dart';

import 'package:carli/core/auth/auth_controller.dart';
import 'package:carli/core/router/router.dart';

void main() {
  test('holds every route on the launch screen while the session is unknown', () {
    expect(authRedirect(const AuthUnknown(), Routes.budgets), Routes.launch);
    expect(authRedirect(const AuthUnknown(), Routes.launch), isNull);
  });

  test('sends signed out users to login', () {
    expect(authRedirect(const SignedOut(), Routes.home), Routes.login);
    expect(authRedirect(const SignedOut(), Routes.login), isNull);
  });

  test('keeps signed in users out of login and launch', () {
    expect(authRedirect(const SignedIn(null), Routes.login), Routes.home);
    expect(authRedirect(const SignedIn(null), Routes.launch), Routes.home);
    expect(authRedirect(const SignedIn(null), Routes.transactions), isNull);
  });
}
