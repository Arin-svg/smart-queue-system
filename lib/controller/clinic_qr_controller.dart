import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

/// Loads the shared clinic code. Only an explicit administrator action replaces it.
class ClinicQrController extends ChangeNotifier {
  ClinicQrController(this.api);

  final ApiService api;
  String? token;
  String? error;
  bool loading = false;
  bool saving = false;
  bool _disposed = false;

  bool get busy => loading || saving;
  bool get canExport => token != null && !busy && error == null;

  Future<void> load() async {
    if (busy || _disposed) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final result = await api.get('/clinic/qr');
      if (!_disposed) token = _readToken(result);
    } catch (e) {
      // Do not let a failed refresh export a code an administrator may have replaced.
      token = null;
      error = e is ApiException
          ? e.message
          : 'Unable to load the clinic QR code. Please retry.';
    } finally {
      loading = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<Map<String, dynamic>> replace() async {
    if (busy || _disposed) {
      throw const ApiException('Please wait for the current request.');
    }
    saving = true;
    error = null;
    notifyListeners();
    try {
      final result = await api.post('/clinic/qr', {});
      final value = _readToken(result);
      if (value == null) {
        throw const ApiException('The server did not return a clinic QR code.');
      }
      if (!_disposed) token = value;
      return result;
    } catch (e) {
      token = null;
      error = e is ApiException
          ? e.message
          : 'Unable to replace the clinic QR code. Please retry loading the current code.';
      rethrow;
    } finally {
      saving = false;
      if (!_disposed) notifyListeners();
    }
  }

  String? _readToken(Map<String, dynamic> result) {
    if (!result.containsKey('token')) {
      throw const ApiException(
        'The server returned an unexpected QR response.',
      );
    }
    final value = result['token'];
    if (value == null) return null;
    if (value is! String || value.isEmpty) {
      throw const ApiException(
        'The server returned an invalid clinic QR code.',
      );
    }
    return value;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
