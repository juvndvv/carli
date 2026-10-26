import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:carli/core/api/api_client.dart';
import 'package:carli/core/auth/auth_controller.dart';

import 'fake_api.dart';

ProviderContainer testContainer(
  FakeApi api, {
  Map<String, String> storage = const {},
  List<Override> overrides = const [],
}) {
  FlutterSecureStorage.setMockInitialValues(Map.of(storage));
  final container = ProviderContainer.test(
    retry: (_, _) => null,
    overrides: [
      unauthorizedHandlerProvider.overrideWith(
        (ref) =>
            () => ref.read(authControllerProvider.notifier).handleUnauthorized(),
      ),
      ...overrides,
    ],
  );
  container.read(dioProvider).httpClientAdapter = api;
  return container;
}
