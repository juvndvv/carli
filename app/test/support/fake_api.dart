import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

typedef FakeRoute = (int, Object?) Function(RequestOptions options);

class FakeApi implements HttpClientAdapter {
  FakeApi(this.routes);

  final Map<String, FakeRoute> routes;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final route = routes['${options.method} ${options.path}'];
    if (route == null) return ResponseBody.fromString('{"message":"Not found"}', 404, headers: _json);
    final (status, body) = route(options);
    return ResponseBody.fromString(body == null ? '' : jsonEncode(body), status, headers: _json);
  }

  @override
  void close({bool force = false}) {}

  static const _json = {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  };
}

const testUser = {'id': 'user-1', 'name': 'Juanda', 'email': 'juanda@example.com'};
