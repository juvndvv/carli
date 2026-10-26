import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_repository.dart';
import 'current_user.dart';

sealed class AuthState {
  const AuthState();
}

final class AuthUnknown extends AuthState {
  const AuthUnknown();
}

final class SignedOut extends AuthState {
  const SignedOut();
}

final class SignedIn extends AuthState {
  const SignedIn(this.user);

  final CurrentUser? user;
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);

class AuthController extends Notifier<AuthState> {
  AuthRepository get _repository => ref.read(authRepositoryProvider);

  @override
  AuthState build() {
    Future.microtask(_restore);
    return const AuthUnknown();
  }

  Future<void> _restore() async {
    if (!await _repository.hasToken()) {
      state = const SignedOut();
      return;
    }
    try {
      state = SignedIn(await _repository.me());
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        await _repository.forget();
        state = const SignedOut();
      } else {
        state = const SignedIn(null);
      }
    }
  }

  Future<LoginResult> login(Credentials credentials) async {
    final result = await _repository.login(credentials);
    if (result is LoginSucceeded) state = SignedIn(result.user);
    return result;
  }

  void updateUser(CurrentUser user) {
    if (state is SignedIn) state = SignedIn(user);
  }

  Future<void> refreshUser() async {
    if (state is! SignedIn) return;
    try {
      state = SignedIn(await _repository.me());
    } on DioException {
      return;
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const SignedOut();
  }

  Future<void> handleUnauthorized() async {
    if (state is! SignedIn) return;
    await _repository.forget();
    state = const SignedOut();
  }
}
