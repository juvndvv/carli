enum ThemePreference {
  system('system', 'Sistema'),
  light('light', 'Claro'),
  dark('dark', 'Oscuro');

  const ThemePreference(this.api, this.label);

  final String api;
  final String label;

  static ThemePreference of(Object? value) =>
      values.firstWhere((preference) => preference.api == value, orElse: () => system);
}

class CurrentUser {
  const CurrentUser({
    required this.id,
    required this.name,
    required this.email,
    this.twoFactorEnabled = false,
    this.twoFactorPending = false,
    this.theme = ThemePreference.system,
    this.createdAt,
  });

  factory CurrentUser.fromJson(Map<String, dynamic> json) => CurrentUser(
    id: json['id'] as String,
    name: json['name'] as String,
    email: json['email'] as String,
    twoFactorEnabled: json['two_factor_enabled'] as bool? ?? false,
    twoFactorPending: json['two_factor_pending'] as bool? ?? false,
    theme: ThemePreference.of((json['preferences'] as Map<String, dynamic>?)?['theme']),
    createdAt: json['created_at'] is String ? DateTime.tryParse(json['created_at'] as String)?.toLocal() : null,
  );

  final String id;
  final String name;
  final String email;
  final bool twoFactorEnabled;
  final bool twoFactorPending;
  final ThemePreference theme;
  final DateTime? createdAt;
}
