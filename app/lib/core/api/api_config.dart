abstract final class ApiConfig {
  static const baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://carli.jotade.io/api',
  );
}
