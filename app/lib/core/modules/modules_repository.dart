import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import 'app_module.dart';

final modulesRepositoryProvider = Provider<ModulesRepository>((ref) => ModulesRepository(ref.watch(dioProvider)));

class ModulesRepository {
  ModulesRepository(this._dio);

  final Dio _dio;

  Future<List<AppModule>> list() async {
    final response = await _dio.get<Object?>('/v1/modules');
    final body = response.data;
    final items = body is Map ? body['data'] : body;
    return [
      if (items is List)
        for (final item in items)
          if (item is Map) AppModule.fromJson(Map<String, dynamic>.from(item)),
    ];
  }

  Future<AppModule> updateSettings(String id, Map<String, Object?> settings) async {
    final response = await _dio.patch<Map<String, dynamic>>('/v1/modules/$id', data: {'settings': settings});
    return AppModule.fromJson(response.data!['data'] as Map<String, dynamic>);
  }

  Future<AppModule> setEnabled(String id, bool enabled) async {
    final response = await _dio.patch<Map<String, dynamic>>('/v1/modules/$id', data: {'enabled': enabled});
    return AppModule.fromJson(response.data!['data'] as Map<String, dynamic>);
  }
}
