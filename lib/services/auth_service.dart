import '../model/user.dart';
import 'api_service.dart';

abstract interface class AuthService {
  Future<User> login({required String userId, required String password});
  Future<void> logout();
  Future<void> requestPasswordReset(String email);
}

class LaravelAuthService implements AuthService {
  LaravelAuthService(this.api);
  final HttpApiService api;

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
    api.token = null;
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    await api.post('forgot-password', {'email': email});
  }
}
