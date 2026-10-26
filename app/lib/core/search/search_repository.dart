import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import 'search_result.dart';

const minSearchQueryLength = 2;

final searchRepositoryProvider = Provider<SearchRepository>((ref) => SearchRepository(ref.watch(dioProvider)));

final searchResultsProvider = FutureProvider.autoDispose.family<List<SearchResult>, String>((ref, query) async {
  final term = query.trim();
  if (term.length < minSearchQueryLength) return const [];
  try {
    return await ref.watch(searchRepositoryProvider).search(term);
  } on DioException {
    return const [];
  }
});

class SearchRepository {
  SearchRepository(this._dio);

  final Dio _dio;

  Future<List<SearchResult>> search(String query) async {
    final response = await _dio.get<Object?>('/v1/search', queryParameters: {'q': query});
    final body = response.data;
    final items = body is Map ? body['results'] ?? body['data'] : body;
    return [
      if (items is List)
        for (final item in items)
          if (item is Map) SearchResult.fromJson(Map<String, dynamic>.from(item)),
    ];
  }
}
