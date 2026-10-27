import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carli/app.dart';
import 'package:carli/core/push/push_platform.dart';
import 'package:carli/core/router/router.dart';

import '../../support/fake_api.dart';
import '../../support/fake_push_platform.dart';
import '../../support/test_app.dart';

Future<(ProviderContainer, FakeApi)> pumpWithPush(
  WidgetTester tester,
  FakePushPlatform platform, {
  Map<String, String> storage = const {'auth_token': 'stored'},
}) async {
  final api = FakeApi({
    'GET /v1/me': (_) => (200, {'data': testUser}),
    'POST /v1/push-devices': (_) => (
      201,
      {
        'data': {'id': 'device', 'environment': 'sandbox'},
        'push_configured': true,
      },
    ),
  });
  final container = testContainer(api, storage: storage, overrides: [pushPlatformProvider.overrideWithValue(platform)]);
  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const CarliApp()));
  await tester.pumpAndSettle();
  return (container, api);
}

String locationOf(ProviderContainer container) =>
    container.read(routerProvider).routeInformationProvider.value.uri.path;

void main() {
  testWidgets('asks for permission once signed in and registers the device token', (tester) async {
    final platform = FakePushPlatform();
    final (_, api) = await pumpWithPush(tester, platform);

    expect(platform.permissionRequests, 1);
    expect(api.requests.where((request) => request.path == '/v1/push-devices').single.data, {
      'token': FakePushPlatform.token,
      'environment': 'sandbox',
    });
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('opens the screen a tapped push points to', (tester) async {
    final platform = FakePushPlatform(currentPermission: PushPermission.granted);
    final (container, _) = await pumpWithPush(tester, platform);

    platform.tap('/pendientes');
    await tester.pump(const Duration(milliseconds: 500));
    expect(locationOf(container), Routes.pending);

    platform.tap('/somewhere-unknown');
    await tester.pump(const Duration(milliseconds: 500));
    expect(locationOf(container), Routes.notifications);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('opens the push that launched the app after signing in', (tester) async {
    final platform = FakePushPlatform(
      currentPermission: PushPermission.granted,
      launchedFrom: const PushTap('/finanzas/recurrentes'),
    );
    final (container, _) = await pumpWithPush(tester, platform);

    expect(locationOf(container), '/mas/recurrentes');
    await tester.pump(const Duration(seconds: 5));
  });
}
