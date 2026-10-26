import '../../support/fake_api.dart';

Map<String, Object?> notificationJson(
  String id, {
  String? type = 'upcoming_charge',
  String? title = 'Netflix 13,99 € pasado mañana',
  String? body = 'Cargo recurrente previsto.',
  String? url = '/finanzas/recurrentes',
  String? readAt,
  String createdAt = '2026-10-24T09:00:00+02:00',
}) => {
  'id': id,
  'module': 'finance',
  'type': type,
  'title': title,
  'body': body,
  'url': url,
  'read_at': readAt,
  'created_at': createdAt,
};

Map<String, Object?> notificationsPageJson(
  List<Map<String, Object?>> items, {
  int currentPage = 1,
  int lastPage = 1,
  int unreadCount = 0,
}) => {
  'data': items,
  'links': {'first': null, 'last': null, 'prev': null, 'next': null},
  'meta': {'current_page': currentPage, 'last_page': lastPage, 'per_page': 20, 'unread_count': unreadCount},
};

Map<String, FakeRoute> notificationRoutes({
  List<Map<String, Object?>> items = const [],
  int lastPage = 1,
  int? unreadCount,
  Map<int, List<Map<String, Object?>>> pages = const {},
  int markedUnreadCount = 0,
}) {
  final unread = unreadCount ?? items.where((item) => item['read_at'] == null).length;
  return {
    'GET /v1/notifications': (options) {
      final page = int.parse('${options.queryParameters['page'] ?? 1}');
      return (
        200,
        notificationsPageJson(
          page == 1 ? items : pages[page] ?? const [],
          currentPage: page,
          lastPage: lastPage,
          unreadCount: unread,
        ),
      );
    },
    'GET /v1/notifications/unread-count': (_) => (200, {'unread_count': unread}),
    'POST /v1/notifications/read': (_) => (200, {'marked': 1, 'unread_count': markedUnreadCount}),
  };
}
