import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/current_user.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) => ProfileRepository(ref.watch(dioProvider)));

class ProfileRepository {
  ProfileRepository(this._dio);

  final Dio _dio;

  Future<CurrentUser> update({required String name, required String email}) async {
    final response = await _dio.patch<Map<String, dynamic>>('/v1/me', data: {'name': name, 'email': email});
    return CurrentUser.fromJson(response.data!['data'] as Map<String, dynamic>);
  }
}
