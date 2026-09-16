/// Configure with --dart-define=API_BASE_URL=your-url.
abstract final class ApiConfig {
  static const baseUrl = String.fromEnvironment('API_BASE_URL');
  static const timeout = Duration(seconds: 30);
}
