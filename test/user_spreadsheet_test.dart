import 'dart:convert';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_queue_system/services/user_spreadsheet.dart';

void main() {
  List<Map<String, dynamic>> csv(String value) => UserSpreadsheet.parse(
    'users.csv',
    Uint8List.fromList(utf8.encode(value)),
  );
  test('CSV handles quoted names, BOM, blank rows and leading zeros', () {
    final rows = csv(
      '\uFEFFname,email,user_identifier,phone_no\r\n"Student, One",one@example.test,00123,0123456789\r\n,,,\r\n',
    );
    expect(rows.single['name'], 'Student, One');
    expect(rows.single['user_identifier'], '00123');
    expect(rows.single['phone_no'], '0123456789');
    expect(rows.single['row'], 2);
  });
  test(
    'rejects missing headers, extra cells, empty template and excessive rows',
    () {
      expect(() => csv('name,email\nA,a@example.test'), throwsFormatException);
      expect(
        () => csv('name,email,user_identifier\nA,a@example.test,ID,extra'),
        throwsFormatException,
      );
      expect(
        () => UserSpreadsheet.parse('template.csv', UserSpreadsheet.template),
        throwsFormatException,
      );
      expect(
        () => csv(
          'name,email,user_identifier\n${List.filled(501, 'A,a@example.test,ID').join('\n')}',
        ),
        throwsFormatException,
      );
    },
  );
  test('reads Excel text IDs and rejects formulas', () {
    final excel = Excel.createExcel();
    final sheet = excel.tables.values.first;
    sheet.appendRow(
      ['name', 'email', 'user_identifier'].map(TextCellValue.new).toList(),
    );
    sheet.appendRow(
      [
        'Student',
        'student@example.test',
        '0001',
      ].map(TextCellValue.new).toList(),
    );
    final rows = UserSpreadsheet.parse(
      'batch.xlsx',
      Uint8List.fromList(excel.encode()!),
    );
    expect(rows.single['user_identifier'], '0001');
    sheet.cell(CellIndex.indexByString('A2')).value = FormulaCellValue('1+1');
    expect(
      () => UserSpreadsheet.parse(
        'batch.xlsx',
        Uint8List.fromList(excel.encode()!),
      ),
      throwsFormatException,
    );
  });
}
