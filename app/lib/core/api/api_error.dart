import 'package:dio/dio.dart';

String apiErrorMessage(Object error, {required String fallback}) {
  if (error is! DioException) return fallback;

  final response = error.response;
  if (response == null) return 'No se puede conectar con el servidor.';
  if (response.statusCode == 429) return 'Demasiados intentos. Espera un minuto y vuelve a probar.';

  final body = response.data;
  if (body is Map) {
    final errors = body['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final first = errors.values.first;
      if (first is List && first.isNotEmpty) return first.first.toString();
    }
    final message = body['message'];
    if (message is String && message.isNotEmpty && response.statusCode != 500) return message;
  }
  return fallback;
}
