import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef PendingCountReader = Future<int?> Function();

final pendingCountReaderProvider = Provider<PendingCountReader>(
  (ref) =>
      () async => null,
);
