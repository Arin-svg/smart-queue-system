import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_queue_system/main.dart';
import 'package:smart_queue_system/services/auth_service.dart';
import 'package:smart_queue_system/model/user.dart';
import 'package:smart_queue_system/model/role.dart';
import 'package:smart_queue_system/services/api_service.dart';

void main() {
  testWidgets('Successful login shows role and logout returns to login', (
    tester,
  ) async {
    await tester.pumpWidget(
      MyApp(authService: _SuccessfulAuthService(), apiService: _WorkspaceApi()),
    );
    await tester.enterText(find.byType(TextField).first, 'CB23094');
    await tester.enterText(find.byType(TextField).last, 'test-password');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Log in'));
    await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
    await tester.pumpAndSettle();
    expect(find.text('Get Queue Number'), findsOneWidget);
    await tester.tap(find.byTooltip('Account menu'));
    await tester.pumpAndSettle();
    expect(find.text('Test Patient'), findsOneWidget);
    await tester.tap(find.text('Sign Out'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Log in'), findsOneWidget);
  });
  testWidgets('Login and password recovery validate input and navigate', (
    tester,
  ) async {
    await tester.pumpWidget(MyApp(authService: _UnavailableAuthService()));
    expect(find.text('Smart Queue System'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
    await tester.pump();
    expect(find.text('Enter your user ID and password.'), findsOneWidget);
    await tester.tap(find.text('Forgot Password?'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FilledButton, 'Send Reset Instructions'),
    );
    await tester.pump();
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'patient@example.com');
    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Send Reset Instructions'),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FilledButton, 'Send Reset Instructions'),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Password reset is unavailable. Please try again later.'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.byTooltip('Back to login'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back to login'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Log in'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Small screen supports keyboard and enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MyApp(authService: _UnavailableAuthService()));
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Forgot Password?'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 250);
    addTearDown(tester.view.resetViewInsets);
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Send Reset Instructions'),
    );
    expect(tester.takeException(), isNull);
  });
}

class _UnavailableAuthService implements AuthService {
  @override
  Future<User> login({
    required String userId,
    required String password,
  }) async => throw StateError("Unavailable");
  @override
  Future<void> logout() async {}
  @override
  Future<void> requestPasswordReset(String email) async =>
      throw StateError("Unavailable");
}

class _SuccessfulAuthService extends _UnavailableAuthService {
  @override
  Future<User> login({
    required String userId,
    required String password,
  }) async => const User(
    id: 1,
    name: 'Test Patient',
    email: 'p@example.test',
    role: Role.patient,
  );
}

class _WorkspaceApi implements ApiService {
  @override
  Future<Map<String, dynamic>> get(String path) async => {
    'user': {'name': 'Test Patient', 'email': 'p@example.test'},
    'departments': [],
  };
  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async => {};
}
