import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import 'notification.dart';

final notificationsApiProvider = Provider<NotificationsApi>((ref) => NotificationsApi(ref.watch(dioProvider)));

class NotificationsApi {
  NotificationsApi(this._dio);

  final Dio _dio;

  static const _base = '/v1/notifications';

  Future<NotificationsPage> page(int page) async {
    final response = await _dio.get<NotificationJson>(_base, queryParameters: {'page': page});
    return NotificationsPage.fromJson(response.data!);
  }

  Future<int> unreadCount() async {
    final response = await _dio.get<NotificationJson>('$_base/unread-count');
    return (response.data!['unread_count'] as num).toInt();
  }

  Future<List<String>> sendTest() async {
    final response = await _dio.post<NotificationJson>('$_base/test');
    return [for (final channel in response.data!['channels'] as List? ?? const []) channel as String];
  }

  Future<int> markRead({List<String>? ids}) async {
    final response = await _dio.post<NotificationJson>('$_base/read', data: ids == null ? {'all': true} : {'ids': ids});
    return (response.data!['unread_count'] as num).toInt();
  }

  Future<int> markUnread(List<String> ids) async {
    final response = await _dio.post<NotificationJson>('$_base/unread', data: {'ids': ids});
    return (response.data!['unread_count'] as num).toInt();
  }

  /// Deletes [ids], every read notification with [onlyRead], or everything when neither is given.
  Future<int> delete({List<String>? ids, bool onlyRead = false}) async {
    final data = ids != null
        ? {'ids': ids}
        : onlyRead
        ? {'read': true}
        : {'all': true};
    final response = await _dio.post<NotificationJson>('$_base/delete', data: data);
    return (response.data!['unread_count'] as num).toInt();
  }
}
