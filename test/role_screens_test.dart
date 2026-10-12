import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_queue_system/main.dart';
import 'package:smart_queue_system/model/role.dart';
import 'package:smart_queue_system/model/user.dart';
import 'package:smart_queue_system/services/api_service.dart';
import 'package:smart_queue_system/services/auth_service.dart';

const render = bool.fromEnvironment('RENDER_SQS');
void main() {
  setUpAll(() async {
    if (render) {
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
      final font = File('.tmp/Roboto-Regular.ttf');
      if (await font.exists()) {
        final loader = FontLoader('Roboto')
          ..addFont(
            Future.value(ByteData.sublistView(await font.readAsBytes())),
          );
        await loader.load();
      }
    }
  });
  for (final role in Role.values) {
    for (final width in [390.0, 1200.0]) {
      testWidgets('${role.name} screens render and navigate at $width px', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final boundary = GlobalKey();
        final api = FixtureApi(role);
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: MyApp(authService: FixtureAuth(role), apiService: api),
          ),
        );
        await tester.enterText(find.byType(TextField).first, 'TEST001');
        await tester.enterText(find.byType(TextField).last, 'Password123!');
        await tester.ensureVisible(find.widgetWithText(FilledButton, 'Log in'));
        await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
        await tester.pumpAndSettle();
        final tabs = switch (role) {
          Role.patient => [
            'Home',
            'Scan',
            'My Queue',
            'Appts',
            'Alerts',
            'Profile',
          ],
          Role.staff => ['Monitor', 'Verify', 'Assign', 'QR Code', 'Profile'],
          Role.doctor => ['Call', 'Consult', 'Profile'],
          Role.administrator => [
            'Home',
            'Users',
            'Depts',
            'Rooms',
            'Reports',
            'Profile',
          ],
        };
        for (final tab in tabs) {
          api.queueStatusOverride = tab == 'Assign'
              ? 'verified'
              : tab == 'Consult'
              ? 'called'
              : null;
          await tester.tap(find.text(tab).last);
          await tester.pumpAndSettle();
          if (tab == 'QR Code') {
            expect(find.byTooltip('Refresh'), findsNothing);
          } else {
            await tester.tap(find.byTooltip('Refresh').first);
            await tester.pumpAndSettle();
          }
          expect(
            tester.takeException(),
            isNull,
            reason: '${role.name}: $tab at $width',
          );
          if (render) {
            await tester.runAsync(() async {
              final box =
                  boundary.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              final image = await box.toImage(pixelRatio: 1);
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final directory = Directory('.tmp/screenshots');
              await directory.create(recursive: true);
              await File(
                '${directory.path}/${role.name}-${tab.replaceAll(' ', '-')}-${width.toInt()}.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
        }
        // Ensure navigation preserves the authenticated role, with no other-role tabs.
        if (role != Role.administrator) {
          expect(find.text('Users'), findsNothing);
        }
        await tester.pumpWidget(const SizedBox());
      });
    }
  }

  testWidgets(
    'Staff verification submits the selected queue only after confirmation',
    (tester) async {
      final api = FixtureApi(Role.staff);
      await tester.pumpWidget(
        MyApp(authService: FixtureAuth(Role.staff), apiService: api),
      );
      await tester.enterText(find.byType(TextField).first, 'STAFF001');
      await tester.enterText(find.byType(TextField).last, 'Password123!');
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Log in'));
      await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Verify').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Verify Patient'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Verify Patient'));
      await tester.pumpAndSettle();
      expect(api.posts, isEmpty);
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(api.posts.single.$1, '/queues/1');
      expect(api.posts.single.$2, {'action': 'verify'});
      await tester.pumpWidget(const SizedBox());
    },
  );
}

class FixtureAuth implements AuthService {
  FixtureAuth(this.role);
  final Role role;
  @override
  Future<User> login({
    required String userId,
    required String password,
  }) async => User(
    id: 1,
    name: 'Muhammad Amin',
    email: 'patient@example.test',
    role: role,
  );
  @override
  Future<void> logout() async {}
  @override
  Future<void> requestPasswordReset(String email) async {}
}

class FixtureApi implements ApiService {
  FixtureApi(this.role);
  final Role role;
  final posts = <(String, Map<String, dynamic>)>[];
  String? queueStatusOverride;
  @override
  Future<Map<String, dynamic>> get(String path) async {
    if (path == '/clinic/qr') {
      return {'token': 'static-clinic-qr-fixture', 'expires_at': null};
    }
    if (path.startsWith('/reports')) {
      return {
        'start': '2026-10-05',
        'end': '2026-10-05',
        'total': 7,
        'active': 3,
        'completed': 4,
        'average_wait_minutes': 12,
        'departments': [
          {'name': 'General Consultation', 'count': 6},
          {'name': 'Dental Clinic', 'count': 1},
        ],
      };
    }
    return {
      'user': {
        'name': 'Muhammad Amin',
        'email': 'patient@example.test',
        'phone_no': '012-9998888',
        'user_identifier': 'CB20001',
      },
      'queues': [
        {
          'queue_id': 1,
          'queue_number': 'A001',
          'user_id': 1,
          'patient_name': 'Muhammad Amin',
          'user_identifier': 'CB20001',
          'department_id': 1,
          'department_name': 'General Consultation',
          'doctor_id': 2,
          'doctor_name': 'Dr. Siti binti Ali',
          'room_id': 1,
          'room_name': 'Consultation Room 1',
          'queue_status':
              queueStatusOverride ??
              (role == Role.staff
                  ? 'waiting'
                  : role == Role.doctor
                  ? 'assigned'
                  : 'verified'),
          'registered_at': '2026-10-05 08:00:00',
          'reason_for_visit': 'General Checkup',
          'priority': 0,
          'estimated_waiting_time': 6,
          'people_ahead': 1,
          'estimate_method':
              'Configured average (learning needs 10 completed consultations)',
        },
      ],
      'departments': [
        {
          'department_id': 1,
          'department_name': 'General Consultation',
          'department_code': 'GC',
          'status': 'active',
        },
        {
          'department_id': 2,
          'department_name': 'Dental Clinic',
          'department_code': 'DEN',
          'status': 'active',
        },
        {
          'department_id': 3,
          'department_name': 'Health Screening',
          'department_code': 'HS',
          'status': 'active',
        },
        {
          'department_id': 4,
          'department_name': 'Pharmacy',
          'department_code': 'PH',
          'status': 'active',
        },
      ],
      'rooms': [
        {
          'room_id': 1,
          'room_name': 'Consultation Room 1',
          'room_number': 'R101',
          'department_id': 1,
          'doctor_id': 2,
          'status': 'available',
        },
      ],
      'doctors': [
        {'user_id': 2, 'name': 'Dr. Siti binti Ali'},
      ],
      'appointments': [],
      'notifications': [
        {
          'notification_id': 1,
          'notification_title': 'Your queue position has been updated',
          'notification_message':
              'You have 1 patient ahead. Please remain near the consultation area.',
          'notification_status': 'sent',
          'sent_at': '2026-10-05 08:10:00',
        },
      ],
      'users': [
        {
          'user_id': 1,
          'name': 'Muhammad Amin',
          'email': 'patient@example.test',
          'phone_no': '012-9998888',
          'user_identifier': 'CB20001',
          'role_id': 1,
          'role_name': 'patient',
          'status': 'active',
        },
      ],
      'roles': [
        {'role_id': 1, 'role_name': 'patient'},
        {'role_id': 2, 'role_name': 'staff'},
        {'role_id': 3, 'role_name': 'doctor'},
        {'role_id': 4, 'role_name': 'administrator'},
      ],
      'settings': {
        'average_minutes': 15,
        'slot_minutes': 30,
        'slot_capacity': 4,
        'opening_time': '08:00',
        'closing_time': '17:00',
        'registration_open': true,
      },
      'summary': {
        'total': 7,
        'active': 3,
        'completed': 4,
        'average_wait_minutes': 12,
        'users': 13,
        'active_departments': 4,
      },
      'logs': [],
    };
  }

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    posts.add((path, body));
    return {'message': 'Saved'};
  }
}
