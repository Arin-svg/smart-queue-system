import '../model/user.dart';
import 'api_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class AuthService {
  Future<User> login({required String userId, required String password});
  Future<void> logout();
  Future<void> requestPasswordReset(String email);
}

abstract interface class RestorableAuthService {
  Future<User?> restoreSession();
}

class LaravelAuthService implements AuthService, RestorableAuthService {
  LaravelAuthService(this.api, {FlutterSecureStorage? storage})
    : storage = storage ?? const FlutterSecureStorage();
  final HttpApiService api;
  final FlutterSecureStorage storage;
  String get sessionKey => 'sqs.session.${Uri.encodeComponent(api.baseUrl)}';

  @override
  Future<User?> restoreSession() async {
    final token = await storage.read(key: sessionKey);
    if (token == null || token.isEmpty) return null;
    api.token = token;
    try {
      final response = await api.get('me');
      return User.fromJson(response['user'] as Map<String, dynamic>);
    } on ApiException catch (error) {
      if (error.statusCode != 401 && error.statusCode != 403) rethrow;
      await storage.delete(key: sessionKey);
      api.token = null;
      return null;
    }
  }

  @override
  Future<User> login({required String userId, required String password}) async {
    final response = await api.post('login', {
      'user_identifier': userId,
      'password': password,
    });
    final user = User.fromJson(response['user'] as Map<String, dynamic>);
    final token = response['token'] as String;
    if (token.isEmpty) {
      throw const ApiException('The server did not create a session.');
    }
    await storage.write(key: sessionKey, value: token);
    api.token = token;
    return user;
  }

  @override
  Future<void> logout() async {
    try {
      await api.post('logout', {});
    } on ApiException catch (error) {
      if (error.statusCode != 401 && error.statusCode != 403) rethrow;
    }
    await storage.delete(key: sessionKey);
    api.token = null;
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    await api.post('forgot-password', {'email': email});
  }
}
