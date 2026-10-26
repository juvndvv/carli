import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../notifications/notifications_providers.dart';
import '../pending/pending_providers.dart';

const sessionRefreshInterval = Duration(seconds: 120);

class SessionRefresher extends ConsumerStatefulWidget {
  const SessionRefresher({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SessionRefresher> createState() => _SessionRefresherState();
}

class _SessionRefresherState extends ConsumerState<SessionRefresher> {
  late final AppLifecycleListener _lifecycle;
  Timer? _timer;
  var _foreground = true;

  bool get _signedIn => ref.read(authControllerProvider) is SignedIn;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () {
        _foreground = true;
        _refresh();
      },
      onHide: () => _foreground = false,
    );
    if (_signedIn) _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(sessionRefreshInterval, (_) => _refresh());
  }

  void _refresh() {
    if (!_signedIn || !_foreground) return;
    ref.read(pendingSummaryProvider.notifier).refreshIfStale().ignore();
    ref.read(unreadNotificationsCountProvider.notifier).refresh().ignore();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider, (previous, next) {
      if (next is SignedIn && previous is! SignedIn) {
        _start();
        _refresh();
      }
      if (next is SignedOut && previous is SignedIn) {
        _timer?.cancel();
        ref.invalidate(pendingSummaryProvider);
        ref.invalidate(notificationsProvider);
        ref.invalidate(unreadNotificationsCountProvider);
      }
    });
    return widget.child;
  }
}
