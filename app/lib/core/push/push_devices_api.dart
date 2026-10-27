import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import 'push_platform.dart';

final pushDevicesApiProvider = Provider<PushDevicesApi>((ref) => PushDevicesApi(ref.watch(dioProvider)));

class PushDevicesApi {
  PushDevicesApi(this._dio);

  final Dio _dio;

  static const _path = '/v1/push-devices';

  Future<bool> register(PushRegistration registration) async {
    final response = await _dio.post<Map<String, dynamic>>(
      _path,
      data: {'token': registration.token, 'environment': registration.environment.name},
    );
    return response.data?['push_configured'] == true;
  }

  Future<void> unregister(String token) => _dio.delete<void>(_path, data: {'token': token});
}
