import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../finance/data/json.dart';
import 'habits_models.dart';

final habitsApiProvider = Provider<HabitsApi>((ref) => HabitsApi(ref.watch(dioProvider)));

class HabitsApi {
  HabitsApi(this._dio);

  final Dio _dio;

  static const _base = '/v1/habits';

  Future<Json> _get(String path, [Map<String, Object?> query = const {}]) async {
    final response = await _dio.get<Json>(
      path.isEmpty ? _base : '$_base/$path',
      queryParameters: {
        for (final MapEntry(:key, :value) in query.entries)
          if (value != null && value != '') key: '$value',
      },
    );
    return response.data!;
  }

  Future<Json> _send(String method, String path, [Json? data]) async {
    final response = await _dio.request<Json>(
      path.isEmpty ? _base : '$_base/$path',
      data: data,
      options: Options(method: method),
    );
    return response.data ?? const {};
  }

  Future<HabitsTodayView> today() async => HabitsTodayView.fromJson((await _get('today'))['data'] as Json);

  Future<List<HabitListItem>> list() async => parseList((await _get(''))['data'], HabitListItem.fromJson);

  Future<HabitDetail> habit(String id) async => HabitDetail.fromJson((await _get(id))['data'] as Json);

  Future<HabitDetail> create(Json input) async =>
      HabitDetail.fromJson((await _send('POST', '', input))['data'] as Json);

  Future<HabitDetail> update(String id, Json input) async =>
      HabitDetail.fromJson((await _send('PATCH', id, input))['data'] as Json);

  Future<HabitDetail> transition(String id, String action) async =>
      HabitDetail.fromJson((await _send('POST', '$id/$action'))['data'] as Json);

  Future<void> delete(String id) => _send('DELETE', id);

  Future<void> reorder(List<String> ids) => _send('PUT', 'order', {'ids': ids});

  Future<List<CalendarDay>> calendar(String id, DateTime month) async => parseList(
    ((await _get('$id/calendar', {'month': isoDate(month).substring(0, 7)}))['data'] as Json)['days'],
    CalendarDay.fromJson,
  );

  Future<HabitToday?> log(String id, DateTime date, double value, {String? note}) async {
    final data = (await _send('PUT', '$id/entries/${isoDate(date)}', {'value': value, 'note': ?note}))['data'] as Json;
    return data['today'] is Map ? HabitToday.fromJson(data['today'] as Json) : null;
  }

  Future<HabitsProgress> progress(ProgressRange range, {DateTime? date}) async => HabitsProgress.fromJson(
    (await _get('progress', {'range': range.name, 'date': date == null ? null : isoDate(date)}))['data'] as Json,
  );

  Future<List<HabitBreak>> breaks() async => parseList((await _get('breaks'))['data'], HabitBreak.fromJson);

  Future<HabitBreak> createBreak(DateTime from, DateTime to, {String? habitId}) async => HabitBreak.fromJson(
    (await _send('POST', 'breaks', {'from_date': isoDate(from), 'to_date': isoDate(to), 'habit_id': ?habitId}))['data']
        as Json,
  );

  Future<void> endBreak(String id) => _send('POST', 'breaks/$id/end');

  Future<void> deleteBreak(String id) => _send('DELETE', 'breaks/$id');

  Future<ConversionPreview> conversionPreview(String templateId) async =>
      ConversionPreview.fromJson((await _get('conversions/$templateId'))['data'] as Json);

  Future<HabitDetail> convert(String templateId) async =>
      HabitDetail.fromJson((await _send('POST', 'conversions', {'template_id': templateId}))['data'] as Json);
}
