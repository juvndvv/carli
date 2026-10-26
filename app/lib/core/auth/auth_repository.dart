import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import 'current_user.dart';
import 'token_store.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(dioProvider), ref.watch(tokenStoreProvider)),
);

sealed class LoginResult {
  const LoginResult();
}

final class LoginSucceeded extends LoginResult {
  const LoginSucceeded(this.user);

  final CurrentUser user;
}

final class TwoFactorRequired extends LoginResult {
  const TwoFactorRequired();
}

class Credentials {
  const Credentials({required this.email, required this.password, this.code, this.recoveryCode});

  final String email;
  final String password;
  final String? code;
  final String? recoveryCode;

  Credentials withCode({String? code, String? recoveryCode}) =>
      Credentials(email: email, password: password, code: code, recoveryCode: recoveryCode);
}

class AuthRepository {
  AuthRepository(this._dio, this._tokens);

  static const deviceName = 'carli iOS';

  final Dio _dio;
  final TokenStore _tokens;

  Future<bool> hasToken() async => await _tokens.read() != null;

  Future<LoginResult> login(Credentials credentials) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/auth/token',
      data: {
        'email': credentials.email,
        'password': credentials.password,
        'device_name': deviceName,
        if (credentials.code != null) 'code': credentials.code,
        if (credentials.recoveryCode != null) 'recovery_code': credentials.recoveryCode,
      },
    );
    final body = response.data!;
    if (body['two_factor'] == true) return const TwoFactorRequired();

    await _tokens.write(body['token'] as String);
    return LoginSucceeded(CurrentUser.fromJson(body['user'] as Map<String, dynamic>));
  }

  Future<CurrentUser> me() async {
    final response = await _dio.get<Map<String, dynamic>>('/v1/me');
    return CurrentUser.fromJson(response.data!['data'] as Map<String, dynamic>);
  }

  Future<void> logout() async {
    try {
      await _dio.delete<void>('/v1/auth/token');
    } on DioException catch (_) {
    } finally {
      await _tokens.clear();
    }
  }

  Future<void> forget() => _tokens.clear();
}
