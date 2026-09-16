import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
}

abstract interface class ApiService {
  Future<Map<String, dynamic>> get(String path);
  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body);
}

class HttpApiService implements ApiService {
  HttpApiService({required this.baseUrl, http.Client? client})
    : _client = client ?? http.Client();
  final String baseUrl;
  final http.Client _client;
  String? token;

  @override
  Future<Map<String, dynamic>> get(String path) => _request('GET', path);
  @override
  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) =>
      _request('POST', path, body);

  Future<Map<String, dynamic>> _request(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final uri = Uri.parse(
      '${baseUrl.replaceAll(RegExp(r'/+$'), '')}/${path.replaceAll(RegExp(r'^/+'), '')}',
    );
    final headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    try {
      final response =
          await (method == 'GET'
                  ? _client.get(uri, headers: headers)
                  : _client.post(uri, headers: headers, body: jsonEncode(body)))
              .timeout(ApiConfig.timeout);
      Map<String, dynamic> data;
      try {
        data = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        throw const ApiException('The server returned an unexpected response.');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final message = response.statusCode >= 500 && response.statusCode != 503
            ? 'The server is unavailable. Please try again later.'
            : data['message'] as String? ?? 'Request failed. Please try again.';
        throw ApiException(message, statusCode: response.statusCode);
      }
      return data;
    } on TimeoutException {
      throw const ApiException(
        'The server took too long to respond. Please try again.',
      );
    } on http.ClientException {
      throw const ApiException(
        'Cannot reach the server. Check your connection and API address.',
      );
    }
  }

  void close() => _client.close();
}
