import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../finance/data/json.dart';
import 'tasks_models.dart';

final tasksApiProvider = Provider<TasksApi>((ref) => TasksApi(ref.watch(dioProvider)));

class TasksApi {
  TasksApi(this._dio);

  final Dio _dio;

  static const _base = '/v1/tasks';

  Future<Json> _get(String path, [Map<String, Object?> query = const {}]) async {
    final response = await _dio.get<Json>(
      '$_base/$path',
      queryParameters: {
        for (final MapEntry(:key, :value) in query.entries)
          if (value != null && value != '') key: '$value',
      },
    );
    return response.data!;
  }

  Future<Json> _send(String method, String path, [Json? data]) async {
    final response = await _dio.request<Json>(
      '$_base/$path',
      data: data,
      options: Options(method: method),
    );
    return response.data ?? const {};
  }

  Future<TodayView> today() async => TodayView.fromJson((await _get('today'))['data'] as Json);

  Future<List<UpcomingDay>> upcoming() async => parseList((await _get('upcoming'))['data'], UpcomingDay.fromJson);

  Future<List<TaskList>> lists({bool archived = false}) async =>
      parseList((await _get('lists', {'archived': archived ? 1 : null}))['data'], TaskList.fromJson);

  Future<TaskList> createList(String name) async =>
      TaskList.fromJson((await _send('POST', 'lists', {'name': name}))['data'] as Json);

  Future<TaskList> updateList(String id, Json input) async =>
      TaskList.fromJson((await _send('PATCH', 'lists/$id', input))['data'] as Json);

  Future<void> reorderLists(List<String> ids) => _send('PUT', 'lists/order', {'ids': ids});

  Future<void> deleteList(String id) => _send('DELETE', 'lists/$id');

  Future<List<TaskItem>> tasks({String? listId, String status = 'open', String? query, int page = 1}) async =>
      parseList(
        (await _get('tasks', {
          'list_id': listId,
          'status': status,
          'q': query,
          'page': page > 1 ? page : null,
        }))['data'],
        TaskItem.fromJson,
      );

  Future<TaskItem> task(String id) async => TaskItem.fromJson((await _get('tasks/$id'))['data'] as Json);

  Future<TaskItem> createTask(Json input) async =>
      TaskItem.fromJson((await _send('POST', 'tasks', input))['data'] as Json);

  Future<TaskItem> updateTask(String id, Json input) async =>
      TaskItem.fromJson((await _send('PATCH', 'tasks/$id', input))['data'] as Json);

  Future<TaskItem> complete(String id) async =>
      TaskItem.fromJson((await _send('POST', 'tasks/$id/complete'))['data'] as Json);

  Future<TaskItem> reopen(String id) async =>
      TaskItem.fromJson((await _send('POST', 'tasks/$id/reopen'))['data'] as Json);

  Future<TaskItem> skip(String id) async => TaskItem.fromJson((await _send('POST', 'tasks/$id/skip'))['data'] as Json);

  Future<TaskItem> postpone(String id, DateTime date) async =>
      TaskItem.fromJson((await _send('POST', 'tasks/$id/postpone', {'date': isoDate(date)}))['data'] as Json);

  Future<void> deleteTask(String id) => _send('DELETE', 'tasks/$id');

  Future<Subtask> addSubtask(String taskId, String title) async =>
      Subtask.fromJson((await _send('POST', 'tasks/$taskId/subtasks', {'title': title}))['data'] as Json);

  Future<Subtask> updateSubtask(String taskId, String subtaskId, Json input) async =>
      Subtask.fromJson((await _send('PATCH', 'tasks/$taskId/subtasks/$subtaskId', input))['data'] as Json);

  Future<void> deleteSubtask(String taskId, String subtaskId) => _send('DELETE', 'tasks/$taskId/subtasks/$subtaskId');

  Future<List<TaskTemplate>> templates() async => parseList((await _get('templates'))['data'], TaskTemplate.fromJson);

  Future<TaskTemplate> template(String id) async =>
      TaskTemplate.fromJson((await _get('templates/$id'))['data'] as Json);

  Future<TaskTemplate> createTemplate(Json input) async =>
      TaskTemplate.fromJson((await _send('POST', 'templates', input))['data'] as Json);

  Future<TaskTemplate> updateTemplate(String id, Json input) async =>
      TaskTemplate.fromJson((await _send('PATCH', 'templates/$id', input))['data'] as Json);

  Future<void> deleteTemplate(String id, {required bool deleteOpen}) =>
      _send('DELETE', 'templates/$id${deleteOpen ? '?delete_open=1' : ''}');

  Future<TaskTemplate> setPaused(String id, bool paused) async =>
      TaskTemplate.fromJson((await _send('POST', 'templates/$id/${paused ? 'pause' : 'resume'}'))['data'] as Json);

  Future<TaskTemplate> skipOccurrence(String id, DateTime date) async =>
      TaskTemplate.fromJson((await _send('POST', 'templates/$id/skip', {'date': isoDate(date)}))['data'] as Json);

  Future<TaskTemplate> unskipOccurrence(String id, DateTime date) async =>
      TaskTemplate.fromJson((await _send('POST', 'templates/$id/unskip', {'date': isoDate(date)}))['data'] as Json);

  Future<TemplateHistory> history(String id) async =>
      TemplateHistory.fromJson((await _get('templates/$id/history'))['data'] as Json);

  Future<FrequencyPreview> preview(Json frequency) async =>
      FrequencyPreview.fromJson((await _send('POST', 'templates/preview', frequency))['data'] as Json);
}
