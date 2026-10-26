import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../finance/data/json.dart';
import 'models.dart';
import 'notes_store.dart';

final notesApiProvider = Provider<NotesApi>((ref) => NotesApi(ref.watch(dioProvider)));

enum OperationStatus { applied, duplicate, stale, rejected }

class SyncResult {
  const SyncResult({required this.statuses, required this.snapshot});

  final Map<String, OperationStatus> statuses;
  final Json snapshot;
}

class NoteSearchHit {
  const NoteSearchHit({
    required this.id,
    required this.type,
    required this.title,
    this.snippet,
    this.folderPath = const [],
    this.archived = false,
  });

  factory NoteSearchHit.fromJson(Json json) => NoteSearchHit(
    id: json['id'] as String,
    type: NoteType.parse(json['type'] as String?),
    title: json['title'] as String? ?? '',
    snippet: json['snippet'] as String?,
    folderPath: [for (final name in json['folder_path'] as List? ?? const []) '$name'],
    archived: json['archived'] == true,
  );

  final String id;
  final NoteType type;
  final String title;
  final String? snippet;
  final List<String> folderPath;
  final bool archived;
}

class NotesApi {
  NotesApi(this._dio);

  final Dio _dio;

  static const _base = '/v1/notes';

  Future<Json> snapshot() async => (await _dio.get<Json>('$_base/snapshot')).data!['data'] as Json;

  Future<SyncResult> sync(List<NoteOperation> operations) async {
    final response = await _dio.post<Json>(
      '$_base/sync',
      data: {
        'operations': [for (final operation in operations) operation.toJson()],
      },
    );
    final body = response.data!;
    return SyncResult(
      statuses: {
        for (final result in body['results'] as List? ?? const [])
          result['id'] as String: OperationStatus.values.firstWhere(
            (status) => status.name == result['status'],
            orElse: () => OperationStatus.rejected,
          ),
      },
      snapshot: body['data'] as Json,
    );
  }

  Future<List<NoteSearchHit>> search(String query) async {
    final response = await _dio.get<Json>('$_base/search', queryParameters: {'q': query});
    return parseList(response.data!['data'], NoteSearchHit.fromJson);
  }
}
