import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../auth/auth_controller.dart';
import '../auth/current_user.dart';

const themeStorageKey = 'pa-theme';

ThemeMode themeModeOf(ThemePreference preference) => switch (preference) {
  ThemePreference.system => ThemeMode.system,
  ThemePreference.light => ThemeMode.light,
  ThemePreference.dark => ThemeMode.dark,
};

const themePreferenceOrder = [ThemePreference.light, ThemePreference.dark, ThemePreference.system];

final themePreferenceProvider = NotifierProvider<ThemePreferenceController, ThemePreference>(
  ThemePreferenceController.new,
);

class ThemePreferenceController extends Notifier<ThemePreference> {
  var _unsyncedLocalChange = false;
  var _chosenThisSession = false;
  Future<void> _restored = Future.value();
  Future<void> _pendingWrite = Future.value();

  @override
  ThemePreference build() {
    _restored = _restore();
    ref.listen(authControllerProvider, (_, next) {
      if (next case SignedIn(user: final user?)) _reconcileWithServer(user.theme);
    }, fireImmediately: true);
    return ThemePreference.system;
  }

  Future<void> select(ThemePreference preference) async {
    _chosenThisSession = true;
    state = preference;
    final stored = _store(preference);
    final auth = ref.read(authControllerProvider);
    if (auth is SignedIn) {
      _unsyncedLocalChange = false;
      if (auth.user case final user?) {
        ref.read(authControllerProvider.notifier).updateUser(_withTheme(user, preference));
      }
      _sendToServer(preference);
    } else {
      _unsyncedLocalChange = true;
    }
    await stored;
  }

  Future<void> cycle() =>
      select(themePreferenceOrder[(themePreferenceOrder.indexOf(state) + 1) % themePreferenceOrder.length]);

  Future<void> _restore() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final stored = preferences.getString(themeStorageKey);
      if (!_chosenThisSession && stored != null) state = ThemePreference.of(stored);
    } catch (_) {
      return;
    }
  }

  Future<void> _reconcileWithServer(ThemePreference server) async {
    await _restored;
    final local = state;
    if (server != local && _unsyncedLocalChange) {
      _sendToServer(local);
    } else if (server != local) {
      state = server;
      await _store(server);
    }
    _unsyncedLocalChange = false;
  }

  void _sendToServer(ThemePreference preference) {
    final dio = ref.read(dioProvider);
    _pendingWrite = _pendingWrite.then(
      (_) => dio.patch<void>('/v1/me/preferences', data: {'theme': preference.api}).then((_) {}, onError: (_) {}),
    );
  }

  Future<void> _store(ThemePreference preference) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(themeStorageKey, preference.api);
    } catch (_) {
      return;
    }
  }

  CurrentUser _withTheme(CurrentUser user, ThemePreference theme) => CurrentUser(
    id: user.id,
    name: user.name,
    email: user.email,
    twoFactorEnabled: user.twoFactorEnabled,
    twoFactorPending: user.twoFactorPending,
    theme: theme,
    createdAt: user.createdAt,
  );
}
