import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/token_store.dart';
import 'api_config.dart';

typedef UnauthorizedHandler = void Function();

final unauthorizedHandlerProvider = Provider<UnauthorizedHandler>((ref) => () {});

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      headers: {'Accept': 'application/json'},
    ),
  );
  dio.interceptors.add(
    AuthInterceptor(
      tokens: ref.watch(tokenStoreProvider),
      onUnauthorized: () => ref.read(unauthorizedHandlerProvider)(),
    ),
  );
  return dio;
});

class AuthInterceptor extends Interceptor {
  AuthInterceptor({required this.tokens, required this.onUnauthorized});

  final TokenStore tokens;
  final UnauthorizedHandler onUnauthorized;

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await tokens.read();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final sentToken = err.requestOptions.headers.containsKey('Authorization');
    if (err.response?.statusCode == 401 && sentToken) {
      onUnauthorized();
    }
    handler.next(err);
  }
}
