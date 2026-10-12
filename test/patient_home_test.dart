import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_queue_system/pages/patient_home_page.dart';
import 'package:smart_queue_system/pages/widgets/clinic_widgets.dart';
import 'package:smart_queue_system/model/role.dart';
import 'role_screens_test.dart' show FixtureApi;

void main() {
  testWidgets('Home selects earliest upcoming visit and updates verification', (tester) async {
    final c = WorkspaceController(FixtureApi(Role.patient));
    addTearDown(c.dispose);
    c.data = {
      'user': {'name': 'Patient'},
      'appointments': [
        {'appointment_date': '2099-12-02', 'appointment_time': '09:00:00', 'appointment_status': 'confirmed', 'department_name': 'Later visit'},
        {'appointment_date': '2099-12-01', 'appointment_time': '08:30:00', 'appointment_status': 'pending', 'department_name': 'Dental'},
        {'appointment_date': '2000-01-01', 'appointment_time': '08:00:00', 'appointment_status': 'confirmed', 'department_name': 'Past visit'},
        {'appointment_date': '2099-11-01', 'appointment_time': '08:00:00', 'appointment_status': 'cancelled', 'department_name': 'Cancelled visit'},
      ],
    };
    String? destination;
    await tester.pumpWidget(MaterialApp(home: ClinicScope(
      controller: c, navigate: (value) => destination = value, role: 'patient',
      child: const Scaffold(body: PatientHomePage()),
    )));
    expect(find.text('No active queue'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Dental'), 200);
    expect(find.text('08:30'), findsOneWidget);
    expect(find.text('Later visit'), findsNothing);
    expect(find.textContaining('Awaiting staff verification'), findsOneWidget);
    (c.data['appointments'] as List)[1]['appointment_status'] = 'confirmed';
    c.notifyListeners();
    await tester.pump();
    expect(find.text('Confirmed. Scan the clinic QR code when you arrive.'), findsOneWidget);
    await tester.ensureVisible(find.text('Manage appointments'));
    await tester.tap(find.text('Manage appointments'));
    expect(destination, 'Appts');
    expect(tester.takeException(), isNull);
  });
}
