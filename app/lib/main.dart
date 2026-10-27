import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'app.dart';
import 'core/api/api_client.dart';
import 'core/auth/auth_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'es_ES';
  await initializeDateFormatting('es_ES');

  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      unauthorizedHandlerProvider.overrideWith(
        (ref) =>
            () => ref.read(authControllerProvider.notifier).handleUnauthorized(),
      ),
    ],
  );
  runApp(UncontrolledProviderScope(container: container, child: const CarliApp()));
}
