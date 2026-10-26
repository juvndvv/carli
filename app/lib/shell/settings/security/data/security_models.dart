class TwoFactorSetup {
  const TwoFactorSetup({required this.qrCodeUrl, this.secretKey});

  factory TwoFactorSetup.fromJson(Map<String, dynamic> json) =>
      TwoFactorSetup(qrCodeUrl: json['qr_code_url'] as String, secretKey: json['secret_key'] as String?);

  final String qrCodeUrl;
  final String? secretKey;
}

class AppToken {
  const AppToken({required this.id, required this.name, required this.isCurrent, this.lastUsedAt, this.createdAt});

  factory AppToken.fromJson(Map<String, dynamic> json) => AppToken(
    id: (json['id'] as num).toInt(),
    name: json['name'] as String,
    isCurrent: json['is_current'] as bool? ?? false,
    lastUsedAt: _date(json['last_used_at']),
    createdAt: _date(json['created_at']),
  );

  final int id;
  final String name;
  final bool isCurrent;
  final DateTime? lastUsedAt;
  final DateTime? createdAt;
}

class WebSession {
  const WebSession({
    required this.id,
    required this.device,
    required this.isMobile,
    required this.isCurrent,
    this.ipAddress,
    this.lastActiveAt,
  });

  factory WebSession.fromJson(Map<String, dynamic> json) => WebSession(
    id: json['id'] as String,
    device: json['device'] as String? ?? 'Dispositivo desconocido',
    isMobile: json['is_mobile'] as bool? ?? false,
    isCurrent: json['is_current'] as bool? ?? false,
    ipAddress: json['ip_address'] as String?,
    lastActiveAt: _date(json['last_active_at']),
  );

  final String id;
  final String device;
  final bool isMobile;
  final bool isCurrent;
  final String? ipAddress;
  final DateTime? lastActiveAt;
}

class ActiveSessions {
  const ActiveSessions({required this.tokens, required this.webSessions});

  final List<AppToken> tokens;
  final List<WebSession> webSessions;

  bool get hasOthers => tokens.any((token) => !token.isCurrent) || webSessions.any((session) => !session.isCurrent);
}

DateTime? _date(Object? value) => value is String ? DateTime.tryParse(value)?.toLocal() : null;
