import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carli/core/auth/auth_controller.dart';
import 'package:carli/core/auth/auth_repository.dart';
import 'package:carli/core/api/api_client.dart';
import 'package:carli/core/auth/token_store.dart';

import '../support/fake_api.dart';
import '../support/test_app.dart';

Future<AuthState> settled(ProviderContainer container) async {
  container.read(authControllerProvider);
  await pumpEventQueue();
  return container.read(authControllerProvider);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('starts signed out without a stored token', () async {
    final container = testContainer(FakeApi({}));

    expect(await settled(container), isA<SignedOut>());
  });

  test('restores the session with a stored token', () async {
    final api = FakeApi({
      'GET /v1/me': (_) => (200, {'data': testUser}),
    });
    final container = testContainer(api, storage: {'auth_token': 'stored'});

    final state = await settled(container);

    expect(state, isA<SignedIn>());
    expect((state as SignedIn).user?.name, 'Juanda');
    expect(api.requests.single.headers['Authorization'], 'Bearer stored');
    expect(api.requests.single.headers['Accept'], 'application/json');
  });

  test('forgets a stored token the server rejects', () async {
    final api = FakeApi({
      'GET /v1/me': (_) => (401, {'message': 'Unauthenticated.'}),
    });
    final container = testContainer(api, storage: {'auth_token': 'revoked'});

    expect(await settled(container), isA<SignedOut>());
    expect(await container.read(tokenStoreProvider).read(), isNull);
  });

  test('stays signed in offline with a stored token', () async {
    final api = FakeApi({'GET /v1/me': (_) => (503, null)});
    final container = testContainer(api, storage: {'auth_token': 'stored'});

    expect(await settled(container), isA<SignedIn>());
  });

  test('stores the token after logging in', () async {
    final api = FakeApi({
      'POST /v1/auth/token': (_) => (201, {'token': '1|plain', 'user': testUser}),
    });
    final container = testContainer(api);
    await settled(container);

    final result = await container
        .read(authControllerProvider.notifier)
        .login(const Credentials(email: 'juanda@example.com', password: 'password'));

    expect(result, isA<LoginSucceeded>());
    expect(container.read(authControllerProvider), isA<SignedIn>());
    expect(await container.read(tokenStoreProvider).read(), '1|plain');
    expect(api.requests.single.data, containsPair('device_name', AuthRepository.deviceName));
  });

  test('reports a two factor challenge without storing a token', () async {
    final api = FakeApi({
      'POST /v1/auth/token': (_) => (200, {'two_factor': true}),
    });
    final container = testContainer(api);
    await settled(container);

    final result = await container
        .read(authControllerProvider.notifier)
        .login(const Credentials(email: 'juanda@example.com', password: 'password'));

    expect(result, isA<TwoFactorRequired>());
    expect(container.read(authControllerProvider), isA<SignedOut>());
  });

  test('signs out when an authenticated request answers 401', () async {
    final api = FakeApi({
      'GET /v1/me': (_) => (200, {'data': testUser}),
      'GET /v1/modules': (_) => (401, {'message': 'Unauthenticated.'}),
    });
    final container = testContainer(api, storage: {'auth_token': 'stored'});
    await settled(container);

    await expectLater(container.read(dioProvider).get<void>('/v1/modules'), throwsA(anything));
    await pumpEventQueue();

    expect(container.read(authControllerProvider), isA<SignedOut>());
    expect(await container.read(tokenStoreProvider).read(), isNull);
  });

  test('revokes the token on logout', () async {
    final api = FakeApi({
      'GET /v1/me': (_) => (200, {'data': testUser}),
      'DELETE /v1/auth/token': (_) => (204, null),
    });
    final container = testContainer(api, storage: {'auth_token': 'stored'});
    await settled(container);

    await container.read(authControllerProvider.notifier).logout();

    expect(api.requests.last.method, 'DELETE');
    expect(api.requests.last.headers['Authorization'], 'Bearer stored');
    expect(container.read(authControllerProvider), isA<SignedOut>());
    expect(await container.read(tokenStoreProvider).read(), isNull);
  });
}
