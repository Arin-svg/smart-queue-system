import '../model/user.dart';

abstract interface class AuthService {
  Future<User> login({required String userId, required String password});
  Future<void> logout();
  Future<void> requestPasswordReset(String email);
}

/// No credentials are accepted until the backend is connected.
class UnconfiguredAuthService implements AuthService {
  Never _unavailable() =>
      throw StateError('Authentication is not connected yet.');
  @override
  Future<User> login({
    required String userId,
    required String password,
  }) async => _unavailable();
  @override
  Future<void> logout() async => _unavailable();
  @override
  Future<void> requestPasswordReset(String email) async => _unavailable();
}
