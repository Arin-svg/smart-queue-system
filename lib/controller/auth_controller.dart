import 'package:flutter/foundation.dart';
import '../model/user.dart';
import '../services/auth_service.dart';

class AuthController extends ChangeNotifier {
  AuthController(this._service);
  final AuthService _service;
  User? _user;
  bool _isLoading = false;
  String? _error;
  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;

  bool _isResetting = false;
  bool _resetSucceeded = false;
  String? _resetMessage;
  bool get isResetting => _isResetting;
  bool get resetSucceeded => _resetSucceeded;
  String? get resetMessage => _resetMessage;

  void clearResetFeedback() {
    _resetMessage = null;
    _resetSucceeded = false;
    notifyListeners();
  }

  Future<void> requestPasswordReset(String email) async {
    if (_isResetting) return;
    _resetSucceeded = false;
    final address = email.trim();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(address)) {
      _resetMessage = 'Enter a valid email address.';
      notifyListeners();
      return;
    }
    _isResetting = true;
    _resetMessage = null;
    notifyListeners();
    try {
      await _service.requestPasswordReset(address);
      _resetSucceeded = true;
      _resetMessage =
          'If an account exists for this email, reset instructions have been sent.';
    } catch (_) {
      _resetMessage = 'Password reset is unavailable. Please try again later.';
    } finally {
      _isResetting = false;
      notifyListeners();
    }
  }

  Future<void> login(String userId, String password) async {
    if (_isLoading) return;
    if (userId.trim().isEmpty || password.isEmpty) {
      _error = 'Enter your user ID and password.';
      notifyListeners();
      return;
    }
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _user = await _service.login(userId: userId.trim(), password: password);
    } catch (_) {
      _error = 'Sign-in is unavailable. Authentication has not been connected.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
