import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_queue_system/services/api_service.dart';
import 'package:smart_queue_system/services/auth_service.dart';
import 'package:smart_queue_system/model/role.dart';

void main() {
  test('Login maps role, sends token and clears it after logout', () async {
    final requests = <http.Request>[];
    final api = HttpApiService(
      baseUrl: 'http://localhost/api',
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/login')) {
          expect(jsonDecode(request.body)['user_identifier'], 'CB23094');
          return http.Response(
            jsonEncode({
              'token': 'test-token',
              'user': {
                'id': 9,
                'name': 'Test Patient',
                'email': 'p@example.test',
                'role': 'patient',
              },
            }),
            200,
          );
        }
        expect(request.headers['Authorization'], 'Bearer test-token');
        return http.Response('{"message":"Signed out."}', 200);
      }),
    );
    addTearDown(api.close);
    final service = LaravelAuthService(api);
    expect(
      (await service.login(userId: 'CB23094', password: 'password')).role,
      Role.patient,
    );
    await service.logout();
    expect(api.token, isNull);
    expect(requests, hasLength(2));
  });
  test(
    'Incorrect credentials preserve the API message and create no session',
    () async {
      final api = HttpApiService(
        baseUrl: 'http://localhost/api',
        client: MockClient(
          (_) async =>
              http.Response('{"message":"Invalid user ID or password."}', 401),
        ),
      );
      addTearDown(api.close);
      await expectLater(
        LaravelAuthService(api).login(userId: 'bad', password: 'bad'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'Invalid user ID or password.',
          ),
        ),
      );
      expect(api.token, isNull);
    },
  );
}
