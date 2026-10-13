import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_queue_system/services/auth_service.dart';
import 'package:smart_queue_system/services/api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const user = {'id': 1, 'name': 'Patient', 'email': 'test@example.test', 'role': 'patient'};
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test('login persists token, new service restores, logout clears token', () async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('login')) return http.Response(jsonEncode({'user': user, 'token': 'saved-token'}), 200);
      expect(request.headers['Authorization'], 'Bearer saved-token');
      return http.Response(jsonEncode({'user': user}), 200);
    });
    final first = LaravelAuthService(HttpApiService(baseUrl: 'http://test/api', client: client));
    await first.login(userId: 'P1', password: 'password');
    final second = LaravelAuthService(HttpApiService(baseUrl: 'http://test/api', client: client));
    expect((await second.restoreSession())?.name, 'Patient');
    await second.logout();
    expect(await second.restoreSession(), isNull);
  });
  test('invalid token removed, transient error keeps saved session', () async {
    var status = 503;
    final service = LaravelAuthService(HttpApiService(baseUrl: 'http://test/api', client: MockClient((_) async => http.Response('{"message":"Unavailable"}', status))));
    await service.storage.write(key: service.sessionKey, value: 'saved-token');
    await expectLater(service.restoreSession(), throwsA(isA<ApiException>()));
    expect(await service.storage.read(key: service.sessionKey), 'saved-token');
    status = 401;
    expect(await service.restoreSession(), isNull);
    expect(await service.storage.read(key: service.sessionKey), isNull);
  });
}
