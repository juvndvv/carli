typedef _RouteRule = ({RegExp pattern, String Function(RegExpMatch match) target, bool keepQuery});

const _id = r'([^/]+)';

final List<_RouteRule> _rules = [
  (pattern: RegExp(r'^/$'), target: (_) => '/', keepQuery: false),
  (pattern: RegExp(r'^/finanzas$'), target: (_) => '/finanzas', keepQuery: true),
  (pattern: RegExp(r'^/finanzas/movimientos$'), target: (_) => '/finanzas/movimientos', keepQuery: true),
  (pattern: RegExp(r'^/finanzas/movimientos/nuevo$'), target: (_) => '/finanzas/movimientos', keepQuery: false),
  (pattern: RegExp(r'^/finanzas/presupuestos$'), target: (_) => '/finanzas/presupuestos', keepQuery: true),
  (pattern: RegExp(r'^/finanzas/cuentas$'), target: (_) => '/mas/cuentas', keepQuery: true),
  (pattern: RegExp('^/finanzas/cuentas/$_id\$'), target: (match) => '/mas/cuentas/${match[1]}', keepQuery: true),
  (pattern: RegExp(r'^/finanzas/categorias$'), target: (_) => '/mas/categorias', keepQuery: true),
  (pattern: RegExp(r'^/finanzas/recurrentes$'), target: (_) => '/mas/recurrentes', keepQuery: true),
  (pattern: RegExp(r'^/finanzas/objetivos$'), target: (_) => '/mas/objetivos', keepQuery: true),
  (pattern: RegExp('^/finanzas/objetivos/$_id\$'), target: (match) => '/mas/objetivos/${match[1]}', keepQuery: true),
  (pattern: RegExp(r'^/finanzas/deudas$'), target: (_) => '/mas/deudas', keepQuery: true),
  (pattern: RegExp(r'^/finanzas/compartidos$'), target: (_) => '/mas/compartidos', keepQuery: true),
  (
    pattern: RegExp('^/finanzas/compartidos/$_id\$'),
    target: (match) => '/mas/compartidos/${match[1]}',
    keepQuery: true,
  ),
  (pattern: RegExp(r'^/finanzas/ajustes$'), target: (_) => '/mas/ajustes-finanzas', keepQuery: true),
  (pattern: RegExp(r'^/finanzas/ajustes/bancos$'), target: (_) => '/mas/ajustes-finanzas/bancos', keepQuery: true),
  (
    pattern: RegExp('^/finanzas/ajustes/bancos/$_id/vincular\$'),
    target: (match) => '/mas/ajustes-finanzas/bancos/${match[1]}/vincular',
    keepQuery: true,
  ),
  (pattern: RegExp(r'^/pendientes$'), target: (_) => '/pendientes', keepQuery: true),
  (pattern: RegExp(r'^/notificaciones$'), target: (_) => '/notificaciones', keepQuery: false),
  (pattern: RegExp(r'^/ajustes/notificaciones$'), target: (_) => '/mas/ajustes/avisos', keepQuery: false),
  (pattern: RegExp(r'^/ajustes(/.*)?$'), target: (_) => '/mas/ajustes', keepQuery: false),
  (
    pattern: RegExp(
      r'^/mas(/cuentas(/[^/]+)?|/categorias|/recurrentes|/objetivos(/[^/]+)?|/deudas|/compartidos(/[^/]+)?|/ajustes-finanzas(/bancos(/[^/]+/vincular)?)?)?$',
    ),
    target: (match) => match[0]!,
    keepQuery: true,
  ),
];

String? nativeNotificationRoute(String? url) {
  if (url == null || url.trim().isEmpty) return null;
  final uri = Uri.tryParse(url.trim());
  if (uri == null || uri.hasScheme || uri.hasAuthority) return null;
  final path = uri.path.length > 1 && uri.path.endsWith('/') ? uri.path.substring(0, uri.path.length - 1) : uri.path;
  for (final rule in _rules) {
    final match = rule.pattern.firstMatch(path);
    if (match == null) continue;
    final target = rule.target(match);
    return rule.keepQuery && uri.hasQuery ? '$target?${uri.query}' : target;
  }
  return null;
}
