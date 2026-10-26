abstract final class ApiConfig {
  static const baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://MacBook-Pro-van-Yurest.local:8180/api',
  );
}
