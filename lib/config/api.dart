import 'package:flutter/foundation.dart';

abstract final class ApiConfig {
  /// Override for a physical device or a deployed API.
  static const _configured = String.fromEnvironment('API_BASE_URL');
  static String get baseUrl {
    if (_configured.isNotEmpty) return _configured;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000/api';
    }
    return 'http://127.0.0.1:8000/api';
  }

  static const timeout = Duration(seconds: 30);
}
