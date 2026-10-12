import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_queue_system/pages/profile_page.dart';
import 'package:smart_queue_system/pages/widgets/clinic_widgets.dart';
import 'package:smart_queue_system/services/api_service.dart';

class PhoneApi implements ApiService {
  String phone = '';
  @override
  Future<Record> get(String path) async => {
    'user': {'name': 'Patient', 'phone_no': phone},
  };
  @override
  Future<Record> post(String path, Record body) async {
    if (body.containsKey('phone_no')) phone = body['phone_no'] as String;
    return {'message': 'Profile updated.'};
  }
}

void main() {
  testWidgets(
    'Focused phone editor saves and can reopen without lifecycle errors',
    (tester) async {
      final api = PhoneApi();
      final c = WorkspaceController(api);
      await c.refresh();
      addTearDown(c.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: ClinicScope(
            controller: c,
            role: 'patient',
            navigate: (_) {},
            child: const Scaffold(body: ProfilePage()),
          ),
        ),
      );
      for (final action in ['Save', 'Cancel']) {
        await tester.ensureVisible(find.byTooltip('Edit phone number'));
        await tester.tap(find.byTooltip('Edit phone number'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), '0123456789');
        await tester.tap(find.text(action));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      expect(api.phone, '0123456789');
      expect(find.text('0123456789'), findsOneWidget);
    await tester.ensureVisible(find.text('Change'));
    await tester.tap(find.text('Change'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'OldPassword123!');
    await tester.enterText(find.byType(TextFormField).at(1), 'NewPassword123!');
    await tester.enterText(find.byType(TextFormField).at(2), 'NewPassword123!');
    await tester.tap(find.text('Update Password'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    },
  );
}
