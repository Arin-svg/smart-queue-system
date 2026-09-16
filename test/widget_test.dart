import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_queue_system/main.dart';

void main() {
  testWidgets('Login and password recovery validate input and navigate', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
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
    await tester.tap(
      find.widgetWithText(FilledButton, 'Send Reset Instructions'),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Password reset is unavailable. Please try again later.'),
      findsOneWidget,
    );
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
    await tester.pumpWidget(const MyApp());
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
