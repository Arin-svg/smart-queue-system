import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:smart_queue_system/pages/qr_code_page.dart';
import 'package:smart_queue_system/pages/widgets/clinic_widgets.dart';
import 'package:smart_queue_system/services/api_service.dart';

void main() {
  testWidgets('Staff sees a persistent code with no refresh controls', (
    tester,
  ) async {
    final api = _ClinicQrApi();
    final controller = await _openPage(tester, api);

    expect(api.qrReads, 1);
    expect(_displayedToken(tester), 'stable-code');
    expect(find.textContaining('Expires:'), findsNothing);
    expect(find.text('Generate QR Code'), findsNothing);
    expect(find.text('Replace QR Code'), findsNothing);
    expect(_button(tester, 'Print').onPressed, isNotNull);
    expect(_button(tester, 'Download QR Code').onPressed, isNotNull);

    expect(find.text('Refresh'), findsNothing);
    expect(find.byTooltip('Refresh'), findsNothing);
    expect(find.byIcon(Icons.refresh), findsNothing);
    expect(find.byType(RefreshIndicator), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_page(controller));
    await tester.pumpAndSettle();
    expect(api.qrReads, 2);
    expect(_displayedToken(tester), 'stable-code');

    await controller.refresh();
    await tester.pumpAndSettle();
    expect(_displayedToken(tester), 'stable-code');
    expect(api.posts, isEmpty);
  });

  testWidgets('Staff automatically sees a code replaced by an administrator', (
    tester,
  ) async {
    final api = _ClinicQrApi();
    final controller = await _openPage(tester, api);
    expect(_displayedToken(tester), 'stable-code');

    api.token = 'changed-by-administrator';
    await controller.refresh();
    await tester.pumpAndSettle();

    expect(_displayedToken(tester), 'changed-by-administrator');
    expect(api.posts, isEmpty);
  });

  testWidgets('Only administrators can create a missing clinic QR code', (
    tester,
  ) async {
    final api = _ClinicQrApi()..token = null;
    final controller = await _openPage(tester, api);

    expect(find.byType(QrImageView), findsNothing);
    expect(find.text('Generate QR Code'), findsNothing);
    expect(find.text('Replace QR Code'), findsNothing);
    expect(
      find.textContaining(RegExp('administrator', caseSensitive: false)),
      findsWidgets,
    );
    expect(_button(tester, 'Print').onPressed, isNull);
    expect(_button(tester, 'Download QR Code').onPressed, isNull);
    expect(api.posts, isEmpty);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_page(controller, role: 'administrator'));
    await tester.pumpAndSettle();
    expect(find.text('Generate QR Code'), findsOneWidget);
    expect(find.text('Replace QR Code'), findsNothing);

    await tester.ensureVisible(find.text('Generate QR Code'));
    await tester.tap(find.text('Generate QR Code'));
    await tester.pumpAndSettle();
    if (find.byType(AlertDialog).evaluate().isNotEmpty) {
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
    }

    expect(api.posts, hasLength(1));
    expect(api.posts.single.$1, '/clinic/qr');
    expect(api.posts.single.$2, isEmpty);
    expect(_displayedToken(tester), 'replacement-code-1');
    expect(find.text('Replace QR Code'), findsOneWidget);
    expect(find.text('Generate QR Code'), findsNothing);
  });

  testWidgets('Administrator replacement requires confirmation', (
    tester,
  ) async {
    final api = _ClinicQrApi();
    await _openPage(tester, api, role: 'administrator');
    expect(find.text('Replace QR Code'), findsOneWidget);
    expect(find.text('Generate QR Code'), findsNothing);

    await tester.ensureVisible(find.text('Replace QR Code'));
    await tester.tap(find.text('Replace QR Code'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(api.posts, isEmpty);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(api.posts, isEmpty);
    expect(_displayedToken(tester), 'stable-code');

    await tester.tap(find.text('Replace QR Code'));
    await tester.pumpAndSettle();
    expect(api.posts, isEmpty);
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(api.posts, hasLength(1));
    expect(api.posts.single.$1, '/clinic/qr');
    expect(api.posts.single.$2, isEmpty);
    expect(_displayedToken(tester), 'replacement-code-1');
    expect(find.textContaining('Expires:'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Failed automatic load hides stale code and disables exports', (
    tester,
  ) async {
    final api = _ClinicQrApi();
    final controller = await _openPage(tester, api);
    expect(_displayedToken(tester), 'stable-code');

    api.failReads = true;
    await controller.refresh();
    await tester.pumpAndSettle();

    expect(find.byType(QrImageView), findsNothing);
    expect(find.textContaining('Offline'), findsWidgets);
    expect(_button(tester, 'Print').onPressed, isNull);
    expect(_button(tester, 'Download QR Code').onPressed, isNull);

    api.failReads = false;
    api.token = 'current-code-after-reconnect';
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(_displayedToken(tester), 'current-code-after-reconnect');
    expect(_button(tester, 'Print').onPressed, isNotNull);
    expect(_button(tester, 'Download QR Code').onPressed, isNotNull);
    expect(api.posts, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Initial QR load failure offers a retry', (tester) async {
    final api = _ClinicQrApi()..failReads = true;
    await _openPage(tester, api);

    expect(find.byType(QrImageView), findsNothing);
    expect(find.textContaining('Offline'), findsWidgets);
    expect(_button(tester, 'Print').onPressed, isNull);
    expect(_button(tester, 'Download QR Code').onPressed, isNull);

    api.failReads = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(api.qrReads, 2);
    expect(_displayedToken(tester), 'stable-code');
    expect(api.posts, isEmpty);
    expect(tester.takeException(), isNull);
  });
}

Future<WorkspaceController> _openPage(
  WidgetTester tester,
  _ClinicQrApi api, {
  String role = 'staff',
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final controller = WorkspaceController(api);
  addTearDown(controller.dispose);
  await tester.pumpWidget(_page(controller, role: role));
  await tester.pumpAndSettle();
  return controller;
}

Widget _page(WorkspaceController controller, {String role = 'staff'}) =>
    MaterialApp(
      home: ClinicScope(
        controller: controller,
        role: role,
        navigate: (_) {},
        child: const Scaffold(body: QrCodePage()),
      ),
    );

String _displayedToken(WidgetTester tester) =>
    (tester.widget<QrImageView>(find.byType(QrImageView)).key
            as ValueKey<String?>)
        .value!;

ButtonStyleButton _button(WidgetTester tester, String label) =>
    tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate(
          (widget) => widget is ButtonStyleButton,
        ),
      ),
    );

class _ClinicQrApi implements ApiService {
  String? token = 'stable-code';
  bool failReads = false;
  int qrReads = 0;
  final posts = <(String, Map<String, dynamic>)>[];

  @override
  Future<Map<String, dynamic>> get(String path) async {
    if (path == '/workspace') return {};
    if (path != '/clinic/qr') {
      throw StateError('Unexpected GET $path');
    }
    qrReads++;
    if (failReads) throw const ApiException('Offline');
    return {'token': token, 'expires_at': null};
  }

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    if (path != '/clinic/qr') {
      throw StateError('Unexpected POST $path');
    }
    posts.add((path, Map<String, dynamic>.from(body)));
    token = 'replacement-code-${posts.length}';
    return {'token': token, 'expires_at': null};
  }
}
