import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_queue_system/controller/chat_controller.dart';
import 'package:smart_queue_system/pages/widgets/chat_companion.dart';
import 'package:smart_queue_system/services/api_service.dart';

class ChatApi implements ApiService {
  bool fail = false;
  Map<String, dynamic>? payload;
  @override
  Future<Map<String, dynamic>> get(String path) async => {};
  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    payload = body;
    if (fail) throw const ApiException('Ask SQS is not connected yet.');
    return {
      'reply':
          'Your appointment is tomorrow at 8:30 AM. Scan the clinic QR code when you arrive.',
      'context': {
        'next_appointment': {
          'department_name': 'General Consultation',
          'appointment_date': '2026-10-14',
          'appointment_time': '08:30',
          'appointment_status': 'confirmed',
        },
      },
    };
  }
}

void main() {
  const render = bool.fromEnvironment('RENDER_SQS');
  setUpAll(() async {
    if (render) {
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      final font = File('.tmp/Roboto-Regular.ttf');
      if (await font.exists()) {
        await (FontLoader('Roboto')..addFont(
              Future.value(ByteData.sublistView(await font.readAsBytes())),
            ))
            .load();
      }
    }
  });
  test(
    'Failed requests can retry without duplicated messages or forged context',
    () async {
      final api = ChatApi()..fail = true;
      final c = ChatController(api);
      await c.send('Hello');
      expect(c.error, isNotNull);
      api.fail = false;
      await c.retry();
      expect(c.messages.length, 2);
      expect(api.payload!['history'], isEmpty);
      c.minimize();
      c.open();
      expect(c.messages.length, 2);
      c.clear();
      expect(c.messages, isEmpty);
      c.dispose();
    },
  );
  for (final width in [390.0, 1000.0]) {
    testWidgets(
      'Companion drags, chats, minimizes and survives keyboard at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        final c = ChatController(ChatApi());
        addTearDown(c.dispose);
        final boundary = GlobalKey();
        String? page;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
            ),
            home: RepaintBoundary(
              key: boundary,
              child: Scaffold(
                appBar: AppBar(title: const Text('SQS')),
                body: ChatCompanion(
                  controller: c,
                  navigate: (value) => page = value,
                  child: const Center(child: Text('Patient Home')),
                ),
              ),
            ),
          ),
        );
        final initial = tester.getTopLeft(find.byKey(const Key('chat-bubble')));
        await tester.drag(
          find.byKey(const Key('chat-bubble')),
          const Offset(-120, -100),
        );
        await tester.pumpAndSettle();
        expect(
          tester.getTopLeft(find.byKey(const Key('chat-bubble'))),
          isNot(initial),
        );
        await tester.tap(find.byKey(const Key('chat-bubble')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('chat-input')),
          'When is my next appointment?',
        );
        await tester.tap(find.byTooltip('Send message'));
        await tester.pumpAndSettle();
        expect(c.messages.length, 2);
        expect(tester.takeException(), isNull);
        if (render) {
          await tester.runAsync(
            () => precacheImage(
              const AssetImage('assets/images/sqs_robot.png'),
              boundary.currentContext!,
            ),
          );
          await tester.pumpAndSettle();
          await tester.runAsync(() async {
            final image =
                await (boundary.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await Directory('.tmp/screenshots').create(recursive: true);
            await File(
              '.tmp/screenshots/chat-$width.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
          });
        }
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip('Minimize chat'));
        await tester.pumpAndSettle();
        tester.view.resetViewInsets();
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('chat-bubble')));
        await tester.pumpAndSettle();
        expect(c.messages.length, 2);
        await tester.scrollUntilVisible(
          find.text('View appointment'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('View appointment'));
        await tester.pumpAndSettle();
        expect(page, 'Appts');
        expect(c.opened, false);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
