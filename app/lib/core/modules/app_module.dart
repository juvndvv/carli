import 'package:flutter/foundation.dart';

@immutable
class AppModule {
  const AppModule({
    required this.id,
    required this.name,
    required this.icon,
    required this.route,
    this.description,
    this.available = true,
    this.enabled = true,
    this.settings = const {},
  });

  factory AppModule.fromJson(Map<String, dynamic> json) => AppModule(
    id: json['id'] as String,
    name: json['name'] as String? ?? json['id'] as String,
    icon: json['icon'] as String? ?? 'circle-dashed',
    route: json['route'] as String? ?? '/',
    description: json['description'] as String?,
    available: json['available'] as bool? ?? !(json['coming_soon'] as bool? ?? false),
    enabled: json['enabled'] as bool? ?? false,
    settings: json['settings'] is Map ? Map<String, dynamic>.from(json['settings'] as Map) : const {},
  );

  final String id;
  final String name;
  final String icon;
  final String route;
  final String? description;
  final bool available;
  final bool enabled;
  final Map<String, dynamic> settings;

  bool get comingSoon => !available;

  AppModule copyWith({bool? enabled}) => AppModule(
    id: id,
    name: name,
    icon: icon,
    route: route,
    description: description,
    available: available,
    enabled: enabled ?? this.enabled,
    settings: settings,
  );
}

abstract final class AppModuleIds {
  static const finance = 'finance';
}

const moduleSettingsLocations = {AppModuleIds.finance: '/mas/ajustes-finanzas'};

String? moduleSettingsLocationOf(String moduleId) => moduleSettingsLocations[moduleId];
