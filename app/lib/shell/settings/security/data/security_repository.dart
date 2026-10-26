import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';
import 'security_models.dart';

final securityRepositoryProvider = Provider<SecurityRepository>((ref) => SecurityRepository(ref.watch(dioProvider)));

final activeSessionsProvider = FutureProvider.autoDispose<ActiveSessions>((ref) async {
  final repository = ref.watch(securityRepositoryProvider);
  final (tokens, webSessions) = await (repository.tokens(), repository.webSessions()).wait;
  return ActiveSessions(tokens: tokens, webSessions: webSessions);
});

class SecurityRepository {
  SecurityRepository(this._dio);

  final Dio _dio;

  Future<void> updatePassword({
    required String currentPassword,
    required String password,
    required String confirmation,
  }) => _dio.put<void>(
    '/v1/me/password',
    data: {'current_password': currentPassword, 'password': password, 'password_confirmation': confirmation},
  );

  Future<TwoFactorSetup> enableTwoFactor(String password) async {
    final response = await _dio.post<Map<String, dynamic>>('/v1/me/two-factor', data: {'password': password});
    return TwoFactorSetup.fromJson(response.data!);
  }

  Future<List<String>> confirmTwoFactor(String code) =>
      _codes(_dio.post<Map<String, dynamic>>('/v1/me/two-factor/confirm', data: {'code': code}));

  Future<void> disableTwoFactor(String password) =>
      _dio.delete<void>('/v1/me/two-factor', data: {'password': password});

  Future<List<String>> recoveryCodes(String password) =>
      _codes(_dio.post<Map<String, dynamic>>('/v1/me/two-factor/recovery-codes', data: {'password': password}));

  Future<List<String>> regenerateRecoveryCodes(String password) => _codes(
    _dio.post<Map<String, dynamic>>('/v1/me/two-factor/recovery-codes/regenerate', data: {'password': password}),
  );

  Future<List<AppToken>> tokens() async {
    final response = await _dio.get<Map<String, dynamic>>('/v1/me/tokens');
    return [for (final token in response.data!['data'] as List) AppToken.fromJson(token as Map<String, dynamic>)];
  }

  Future<void> revokeToken(int id) => _dio.delete<void>('/v1/me/tokens/$id');

  Future<List<WebSession>> webSessions() async {
    final response = await _dio.get<Map<String, dynamic>>('/v1/me/sessions');
    return [for (final session in response.data!['data'] as List) WebSession.fromJson(session as Map<String, dynamic>)];
  }

  Future<void> revokeWebSession(String id) => _dio.delete<void>('/v1/me/sessions/$id');

  Future<void> logoutOthers(String password) =>
      _dio.post<void>('/v1/me/tokens/logout-others', data: {'password': password});

  Future<List<String>> _codes(Future<Response<Map<String, dynamic>>> request) async {
    final response = await request;
    return [for (final code in response.data!['recovery_codes'] as List) code as String];
  }
}
