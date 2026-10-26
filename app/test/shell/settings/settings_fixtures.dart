import 'package:carli/core/modules/app_module.dart';

Map<String, Object?> moduleJson({
  String id = AppModuleIds.finance,
  String name = 'Finanzas',
  String icon = 'wallet',
  String route = '/finanzas',
  String? description = 'Cuentas, movimientos, presupuestos, suscripciones, objetivos y deudas.',
  bool available = true,
  bool enabled = true,
}) => {
  'id': id,
  'name': name,
  'icon': icon,
  'route': route,
  'description': description,
  'available': available,
  'coming_soon': !available,
  'enabled': enabled,
  'settings': <String, Object?>{},
};

List<Map<String, Object?>> modulesJson({bool financeEnabled = true}) => [
  moduleJson(enabled: financeEnabled),
  moduleJson(
    id: 'tasks',
    name: 'Tareas',
    icon: 'list-checks',
    route: '/tareas',
    description: 'Listas, recordatorios y proyectos personales.',
    available: false,
    enabled: false,
  ),
];
