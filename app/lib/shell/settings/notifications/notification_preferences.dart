import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';

enum NotificationChannel { push, inApp }

@immutable
class NotificationPreference {
  const NotificationPreference({
    required this.module,
    required this.type,
    required this.label,
    this.description,
    required this.push,
    required this.inApp,
  });

  factory NotificationPreference.fromJson(String module, Map<String, dynamic> json) {
    final type = json['type'] as String;
    final label = (json['label'] as String?)?.trim() ?? '';
    final description = (json['description'] as String?)?.trim() ?? '';
    return NotificationPreference(
      module: module,
      type: type,
      label: label.isEmpty ? type.split('.').last.replaceAll('_', ' ') : label,
      description: description.isEmpty ? null : description,
      push: json['push'] == true,
      inApp: json['in_app'] == true,
    );
  }

  final String module;
  final String type;
  final String label;
  final String? description;
  final bool push;
  final bool inApp;

  bool enabledOn(NotificationChannel channel) => switch (channel) {
    NotificationChannel.push => push,
    NotificationChannel.inApp => inApp,
  };

  NotificationPreference toggled(NotificationChannel channel, bool value) => NotificationPreference(
    module: module,
    type: type,
    label: label,
    description: description,
    push: channel == NotificationChannel.push ? value : push,
    inApp: channel == NotificationChannel.inApp ? value : inApp,
  );

  Map<String, dynamic> toJson() => {'module': module, 'type': type, 'push': push, 'in_app': inApp};
}

@immutable
class NotificationPreferenceGroup {
  const NotificationPreferenceGroup({required this.module, required this.name, required this.types});

  factory NotificationPreferenceGroup.fromJson(Map<String, dynamic> json) {
    final module = json['module'] as String;
    return NotificationPreferenceGroup(
      module: module,
      name: json['name'] as String? ?? module,
      types: [
        for (final type in (json['types'] as List? ?? const []).cast<Map<String, dynamic>>())
          NotificationPreference.fromJson(module, type),
      ],
    );
  }

  final String module;
  final String name;
  final List<NotificationPreference> types;

  NotificationPreferenceGroup replacing(NotificationPreference preference) => NotificationPreferenceGroup(
    module: module,
    name: name,
    types: [for (final type in types) type.type == preference.type ? preference : type],
  );
}

final notificationPreferencesApiProvider = Provider<NotificationPreferencesApi>(
  (ref) => NotificationPreferencesApi(ref.watch(dioProvider)),
);

class NotificationPreferencesApi {
  NotificationPreferencesApi(this._dio);

  final Dio _dio;

  static const _path = '/v1/notification-preferences';

  Future<List<NotificationPreferenceGroup>> fetch() async =>
      _groups((await _dio.get<Map<String, dynamic>>(_path)).data!);

  Future<List<NotificationPreferenceGroup>> save(List<NotificationPreference> preferences) async {
    final response = await _dio.put<Map<String, dynamic>>(
      _path,
      data: {
        'preferences': [for (final preference in preferences) preference.toJson()],
      },
    );
    return _groups(response.data!);
  }

  List<NotificationPreferenceGroup> _groups(Map<String, dynamic> body) => [
    for (final group in (body['data'] as List? ?? const []).cast<Map<String, dynamic>>())
      NotificationPreferenceGroup.fromJson(group),
  ];
}

final notificationPreferencesProvider =
    AsyncNotifierProvider.autoDispose<NotificationPreferencesController, List<NotificationPreferenceGroup>>(
      NotificationPreferencesController.new,
    );

class NotificationPreferencesController extends AsyncNotifier<List<NotificationPreferenceGroup>> {
  NotificationPreferencesApi get _api => ref.read(notificationPreferencesApiProvider);

  @override
  Future<List<NotificationPreferenceGroup>> build() => ref.watch(notificationPreferencesApiProvider).fetch();

  Future<void> toggle(NotificationPreference preference, NotificationChannel channel, bool value) async {
    final previous = state.value;
    if (previous == null) return;
    final updated = preference.toggled(channel, value);
    state = AsyncData([
      for (final group in previous) group.module == preference.module ? group.replacing(updated) : group,
    ]);
    try {
      final saved = await _api.save([updated]);
      if (ref.mounted) state = AsyncData(saved);
    } on Object {
      if (ref.mounted) state = AsyncData(previous);
      rethrow;
    }
  }
}
