import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:carli/core/api/api_client.dart';
import 'package:carli/core/auth/auth_controller.dart';

import 'fake_api.dart';

ProviderContainer testContainer(FakeApi api, {Map<String, String> storage = const {}}) {
  FlutterSecureStorage.setMockInitialValues(Map.of(storage));
  final container = ProviderContainer.test(
    retry: (_, _) => null,
    overrides: [
      unauthorizedHandlerProvider.overrideWith(
        (ref) =>
            () => ref.read(authControllerProvider.notifier).handleUnauthorized(),
      ),
    ],
  );
  container.read(dioProvider).httpClientAdapter = api;
  return container;
}
