import 'package:flutter/foundation.dart';

typedef NotificationJson = Map<String, dynamic>;

@immutable
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.createdAt,
    this.module,
    this.body,
    this.url,
    this.readAt,
  });

  factory AppNotification.fromJson(NotificationJson json) => AppNotification(
    id: json['id'] as String,
    module: json['module'] as String?,
    type: json['type'] as String? ?? '',
    title: json['title'] as String? ?? '',
    body: json['body'] as String?,
    url: json['url'] as String?,
    readAt: _parseInstant(json['read_at']),
    createdAt: _parseInstant(json['created_at']),
  );

  final String id;
  final String? module;
  final String type;
  final String title;
  final String? body;
  final String? url;
  final DateTime? readAt;
  final DateTime? createdAt;

  bool get unread => readAt == null;

  AppNotification markedRead(DateTime at) => _withReadAt(at);

  AppNotification markedUnread() => _withReadAt(null);

  AppNotification _withReadAt(DateTime? at) => AppNotification(
    id: id,
    module: module,
    type: type,
    title: title,
    body: body,
    url: url,
    readAt: at,
    createdAt: createdAt,
  );
}

DateTime? _parseInstant(Object? value) => value is String ? DateTime.tryParse(value) : null;

@immutable
class NotificationsPage {
  const NotificationsPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.unreadCount,
  });

  factory NotificationsPage.fromJson(NotificationJson json) {
    final meta = json['meta'] as NotificationJson? ?? const {};
    final data = json['data'];
    return NotificationsPage(
      items: data is List ? [for (final item in data) AppNotification.fromJson(item as NotificationJson)] : const [],
      currentPage: (meta['current_page'] as num?)?.toInt() ?? 1,
      lastPage: (meta['last_page'] as num?)?.toInt() ?? 1,
      unreadCount: (meta['unread_count'] as num?)?.toInt() ?? 0,
    );
  }

  final List<AppNotification> items;
  final int currentPage;
  final int lastPage;
  final int unreadCount;

  int? get nextPage => currentPage < lastPage ? currentPage + 1 : null;
}
