import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

typedef RouteQueryCallback = void Function(BuildContext context, WidgetRef ref, Map<String, List<String>> query);

class RouteQueryHandler extends ConsumerStatefulWidget {
  const RouteQueryHandler({super.key, required this.query, required this.onQuery, required this.child});

  final Map<String, List<String>> query;
  final RouteQueryCallback onQuery;
  final Widget child;

  @override
  ConsumerState<RouteQueryHandler> createState() => _RouteQueryHandlerState();
}

class _RouteQueryHandlerState extends ConsumerState<RouteQueryHandler> {
  @override
  void initState() {
    super.initState();
    _handle();
  }

  @override
  void didUpdateWidget(RouteQueryHandler oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.query, widget.query)) _handle();
  }

  void _handle() {
    final query = widget.query;
    if (query.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final router = GoRouter.maybeOf(context);
      final path = router?.routeInformationProvider.value.uri.path;
      if (router != null && path != null) router.go(path);
      widget.onQuery(context, ref, query);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
