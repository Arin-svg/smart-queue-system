/// Boundary for future Laravel transport, authentication and error handling.
abstract interface class ApiService {
  Future<Map<String, dynamic>> get(String path);
  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body);
}
