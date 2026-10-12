import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_queue_system/pages/user_import_dialog.dart';
import 'package:smart_queue_system/controller/workspace_controller.dart';
import 'package:smart_queue_system/services/api_service.dart';

final class MemoryFile extends PlatformFile {
  @override
  String get name => 'batch.csv';
  final bytes = Uint8List.fromList(
    utf8.encode('name,email,user_identifier\nStudent,student@example.test,001'),
  );
  @override
  Future<int?> length() async => bytes.length;
  @override
  Future<Uint8List> readAsBytes() async => bytes;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class Picker extends FilePickerPlatform {
  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async => MemoryFile();
}

class ImportApi implements ApiService {
  ImportApi({this.fail = false});
  final bool fail;
  int creations = 0;
  @override
  Future<Record> get(String path) async => {};
  @override
  Future<Record> post(String path, Record body) async {
    if (path.endsWith('/preview')) {
      return {
        'rows': [
          for (var i = 0; i < 2; i++)
            {
              'row': i + 2,
              'status': 'ready',
              'role': 'patient',
              'message': 'Ready',
              'data': {
                'name': 'Student $i',
                'email': 'student$i@example.test',
                'user_identifier': '00$i',
                'role_id': 1,
                'status': 'active',
              },
            },
        ],
      };
    }
    creations++;
    if (fail) throw const ApiException('Connection timed out.');
    return {'message': 'Created'};
  }
}

void main() {
  for (final fail in [false, true]) {
    testWidgets('Import requires confirmation and handles failure=$fail', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final original = FilePickerPlatform.instance;
      FilePickerPlatform.instance = Picker();
      addTearDown(() => FilePickerPlatform.instance = original);
      final api = ImportApi(fail: fail);
      final c = WorkspaceController(api);
      addTearDown(c.dispose);
      await tester.pumpWidget(
        MaterialApp(home: UserImportDialog(controller: c)),
      );
      await tester.tap(find.text('Choose spreadsheet'));
      await tester.pumpAndSettle();
      expect(api.creations, 0);
      await tester.tap(find.text('Import 2 users & send emails'));
      await tester.pumpAndSettle();
      expect(api.creations, 0);
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(api.creations, fail ? 1 : 2);
      expect(
        find.textContaining(fail ? '0 created' : '2 created'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
