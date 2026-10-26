import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const fallbackPendingIcon = 'inbox';

@immutable
class PendingTypeDescriptor {
  const PendingTypeDescriptor({required this.label, required this.icon, required this.countLabel});

  final String label;
  final String icon;
  final String Function(int count) countLabel;
}

@immutable
class PendingModuleInfo {
  const PendingModuleInfo({required this.name, required this.icon, this.types = const {}});

  final String name;
  final String icon;
  final Map<String, PendingTypeDescriptor> types;
}

String _genericCountLabel(int count) => count == 1 ? '1 pendiente' : '$count pendientes';

PendingTypeDescriptor fallbackPendingDescriptor(String type) {
  final words = type.replaceAll(RegExp(r'[_.\-]+'), ' ').trim();
  final label = words.isEmpty ? 'Pendientes' : words[0].toUpperCase() + words.substring(1);
  return PendingTypeDescriptor(label: label, icon: fallbackPendingIcon, countLabel: _genericCountLabel);
}

abstract final class FinancePendingTypes {
  static const module = 'finance';
  static const uncategorized = 'uncategorized_transaction';
  static const recurring = 'recurring_to_confirm';
}

final financePendingModule = PendingModuleInfo(
  name: 'Finanzas',
  icon: 'wallet',
  types: {
    FinancePendingTypes.uncategorized: PendingTypeDescriptor(
      label: 'Movimientos por categorizar',
      icon: 'circle-dashed',
      countLabel: (count) => count == 1 ? '1 movimiento por categorizar' : '$count movimientos por categorizar',
    ),
    FinancePendingTypes.recurring: PendingTypeDescriptor(
      label: 'Recurrentes por confirmar',
      icon: 'repeat',
      countLabel: (count) => count == 1 ? '1 recurrente por confirmar' : '$count recurrentes por confirmar',
    ),
  },
);

class PendingTypeRegistry {
  const PendingTypeRegistry(this.modules);

  final Map<String, PendingModuleInfo> modules;

  PendingModuleInfo? module(String id) => modules[id];

  PendingTypeDescriptor describe(String module, String type) =>
      modules[module]?.types[type] ?? fallbackPendingDescriptor(type);
}

final pendingTypeRegistryProvider = Provider<PendingTypeRegistry>(
  (ref) => PendingTypeRegistry({FinancePendingTypes.module: financePendingModule}),
);
