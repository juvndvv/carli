abstract final class ApiConfig {
  static const baseUrl = String.fromEnvironment('API_URL', defaultValue: 'http://192.168.0.20:8180/api');
}
