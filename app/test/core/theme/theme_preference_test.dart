import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:carli/core/auth/auth_controller.dart';
import 'package:carli/core/auth/auth_repository.dart';
import 'package:carli/core/auth/current_user.dart';
import 'package:carli/core/theme/theme_preference.dart';

import '../../support/fake_api.dart';
import '../../support/test_app.dart';

Map<String, Object?> userWithTheme(String theme) => {
  ...testUser,
  'preferences': {'theme': theme},
};

Future<ProviderContainer> start(FakeApi api, {Map<String, String> storage = const {}}) async {
  final container = testContainer(api, storage: storage);
  container.listen(themePreferenceProvider, (_, _) {});
  container.read(authControllerProvider);
  await pumpEventQueue();
  return container;
}

Future<String?> storedTheme() async => (await SharedPreferences.getInstance()).getString(themeStorageKey);

List<Object?> preferenceWrites(FakeApi api) => [
  for (final request in api.requests)
    if (request.method == 'PATCH' && request.path == '/v1/me/preferences') request.data,
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('maps every preference to a theme mode', () {
    expect(themeModeOf(ThemePreference.system), ThemeMode.system);
    expect(themeModeOf(ThemePreference.light), ThemeMode.light);
    expect(themeModeOf(ThemePreference.dark), ThemeMode.dark);
  });

  test('restores the locally stored preference', () async {
    SharedPreferences.setMockInitialValues({themeStorageKey: 'dark'});
    final container = await start(FakeApi({}));

    expect(container.read(themePreferenceProvider), ThemePreference.dark);
  });

  test('defaults to the system preference without a stored value', () async {
    SharedPreferences.setMockInitialValues({});
    final container = await start(FakeApi({}));

    expect(container.read(themePreferenceProvider), ThemePreference.system);
  });

  test('adopts the server preference after restoring the session', () async {
    SharedPreferences.setMockInitialValues({themeStorageKey: 'dark'});
    final api = FakeApi({
      'GET /v1/me': (_) => (200, {'data': userWithTheme('light')}),
    });
    final container = await start(api, storage: {'auth_token': 'stored'});

    expect(container.read(themePreferenceProvider), ThemePreference.light);
    expect(await storedTheme(), 'light');
    expect(preferenceWrites(api), isEmpty);
  });

  test('pushes an unsynced local change to the server on login', () async {
    SharedPreferences.setMockInitialValues({});
    final api = FakeApi({
      'POST /v1/auth/token': (_) => (201, {'token': '1|plain', 'user': userWithTheme('light')}),
      'PATCH /v1/me/preferences': (_) => (200, {'data': userWithTheme('dark')}),
    });
    final container = await start(api);

    await container.read(themePreferenceProvider.notifier).select(ThemePreference.dark);
    expect(preferenceWrites(api), isEmpty);

    await container
        .read(authControllerProvider.notifier)
        .login(const Credentials(email: 'juanda@example.com', password: 'password'));
    await pumpEventQueue();

    expect(container.read(themePreferenceProvider), ThemePreference.dark);
    expect(preferenceWrites(api), [
      {'theme': 'dark'},
    ]);
  });

  test('stores and syncs a choice made while signed in', () async {
    SharedPreferences.setMockInitialValues({});
    final api = FakeApi({
      'GET /v1/me': (_) => (200, {'data': userWithTheme('system')}),
      'PATCH /v1/me/preferences': (_) => (200, {'data': userWithTheme('dark')}),
    });
    final container = await start(api, storage: {'auth_token': 'stored'});

    await container.read(themePreferenceProvider.notifier).select(ThemePreference.dark);
    await pumpEventQueue();

    expect(container.read(themePreferenceProvider), ThemePreference.dark);
    expect(await storedTheme(), 'dark');
    expect(preferenceWrites(api), [
      {'theme': 'dark'},
    ]);
    final auth = container.read(authControllerProvider) as SignedIn;
    expect(auth.user?.theme, ThemePreference.dark);
  });

  test('keeps the local choice when the server write fails', () async {
    SharedPreferences.setMockInitialValues({});
    final api = FakeApi({
      'GET /v1/me': (_) => (200, {'data': userWithTheme('system')}),
      'PATCH /v1/me/preferences': (_) => (500, {'message': 'Server Error'}),
    });
    final container = await start(api, storage: {'auth_token': 'stored'});

    await container.read(themePreferenceProvider.notifier).select(ThemePreference.light);
    await pumpEventQueue();

    expect(container.read(themePreferenceProvider), ThemePreference.light);
    expect(await storedTheme(), 'light');
  });

  test('cycles through light, dark and system', () async {
    SharedPreferences.setMockInitialValues({themeStorageKey: 'light'});
    final container = await start(FakeApi({}));
    final controller = container.read(themePreferenceProvider.notifier);

    await controller.cycle();
    expect(container.read(themePreferenceProvider), ThemePreference.dark);
    await controller.cycle();
    expect(container.read(themePreferenceProvider), ThemePreference.system);
    await controller.cycle();
    expect(container.read(themePreferenceProvider), ThemePreference.light);
  });
}
