import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_queue_system/model/role.dart';
import 'package:smart_queue_system/pages/appointment_page.dart';
import 'package:smart_queue_system/pages/verify_page.dart';
import 'package:smart_queue_system/pages/widgets/clinic_widgets.dart';
import 'package:smart_queue_system/services/api_service.dart';
import 'role_screens_test.dart' as fixtures;

void main() {
  testWidgets('Patient waits for staff approval before appointment check-in', (
    tester,
  ) async {
    final api = _AppointmentApi(Role.patient);
    await _open(tester, api);
    await tester.ensureVisible(find.text('Awaiting staff verification.'));
    await tester.pumpAndSettle();
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('Confirmed'), findsNothing);
    expect(find.text('Check In'), findsNothing);
    expect(find.text('Cancel Appointment'), findsOneWidget);
    expect(api.posts, isEmpty);
  });

  testWidgets('Confirmed appointments offer check-in on the appointment date', (
    tester,
  ) async {
    final api = _AppointmentApi(Role.patient)..status = 'confirmed';
    await _open(tester, api);
    await tester.ensureVisible(find.text('Check In'));
    await tester.pumpAndSettle();
    expect(find.text('Confirmed'), findsOneWidget);
    expect(find.text('Awaiting staff verification.'), findsNothing);
    expect(api.posts, isEmpty);
  });

  testWidgets(
    'Staff explicitly verifies an appointment after reviewing details',
    (tester) async {
      final api = _AppointmentApi(Role.staff);
      await _open(tester, api);
      expect(find.text('Appointments Awaiting Verification'), findsOneWidget);
      expect(find.text('PAT001'), findsOneWidget);
      expect(find.text('Dental checkup'), findsOneWidget);
      expect(api.posts, isEmpty);
      await tester.ensureVisible(find.text('Verify Appointment'));
      await tester.tap(find.text('Verify Appointment'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(api.posts, isEmpty);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(api.posts, isEmpty);
      await tester.tap(find.text('Verify Appointment'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(api.posts, hasLength(1));
      expect(api.posts.single.$1, '/appointments/42/verify');
      expect(api.posts.single.$2, isEmpty);
      expect(api.status, 'confirmed');
      expect(find.text('Verify Appointment'), findsNothing);
      expect(
        find.text('No appointments awaiting verification.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('Failed staff verification leaves the appointment pending', (
    tester,
  ) async {
    final api = _AppointmentApi(Role.staff)..failVerification = true;
    await _open(tester, api);
    await tester.ensureVisible(find.text('Verify Appointment'));
    await tester.tap(find.text('Verify Appointment'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(api.status, 'pending');
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('Verify Appointment'), findsOneWidget);
    expect(find.text('Unable to verify appointment.'), findsOneWidget);
  });
}

Future<void> _open(WidgetTester tester, _AppointmentApi api) async {
  tester.view.physicalSize = const Size(390, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final controller = WorkspaceController(api);
  addTearDown(controller.dispose);
  await controller.refresh();
  await tester.pumpWidget(
    MaterialApp(
      home: ClinicScope(
        controller: controller,
        role: api.role.name,
        navigate: (_) {},
        child: Scaffold(
          body: api.role == Role.staff
              ? const VerifyPage()
              : const AppointmentPage(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _AppointmentApi extends fixtures.FixtureApi {
  _AppointmentApi(super.role);
  String status = 'pending';
  bool failVerification = false;

  @override
  Future<Map<String, dynamic>> get(String path) async {
    final data = await super.get(path);
    if (path == '/workspace') {
      data['queues'] = <Record>[];
      data['appointments'] = [
        {
          'appointment_id': 42,
          'appointment_status': status,
          'patient_name': 'Test Patient',
          'user_identifier': 'PAT001',
          'department_name': 'Dental Clinic',
          'doctor_name': 'Dr. Test',
          'appointment_date': DateTime.now().toIso8601String().substring(0, 10),
          'appointment_time': '16:00:00',
          'reason_for_visit': 'Dental checkup',
        },
      ];
    }
    return data;
  }

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    if (path != '/appointments/42/verify') {
      throw StateError('Unexpected POST $path');
    }
    posts.add((path, body));
    if (failVerification) {
      throw const ApiException('Unable to verify appointment.');
    }
    status = 'confirmed';
    return {'message': 'Appointment verified and confirmed.'};
  }
}
