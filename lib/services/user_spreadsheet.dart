import 'dart:convert';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';

/// Spreadsheet input is converted to plain records; the API validates each row.
abstract final class UserSpreadsheet {
  static const headers = [
    'name',
    'email',
    'user_identifier',
    'phone_no',
    'role',
    'status',
  ];
  static Uint8List get template =>
      Uint8List.fromList(utf8.encode('${headers.join(',')}\r\n'));

  static List<Map<String, dynamic>> parse(String filename, Uint8List bytes) {
    if (bytes.length > 2 * 1024 * 1024) {
      throw const FormatException('Choose a file smaller than 2 MB.');
    }
    final List<List<String>> table;
    if (filename.toLowerCase().endsWith('.csv')) {
      final source = utf8.decode(bytes).replaceFirst('\uFEFF', '');
      table =
          const CsvToListConverter(
                shouldParseNumbers: false,
                allowInvalid: false,
              )
              .convert(source, eol: source.contains('\r\n') ? '\r\n' : '\n')
              .map((row) => row.map((v) => '$v').toList())
              .toList();
    } else if (filename.toLowerCase().endsWith('.xlsx')) {
      final workbook = Excel.decodeBytes(bytes);
      final sheets = workbook.tables.values
          .where((s) => s.maxRows > 0)
          .toList();
      if (sheets.isEmpty) throw const FormatException('The workbook is empty.');
      if (sheets.length > 1) {
        throw const FormatException(
          'Use a workbook with one data sheet, or export the required sheet as CSV.',
        );
      }
      table = sheets.single.rows
          .map(
            (row) => row.map((cell) {
              if (cell?.value is FormulaCellValue) {
                throw const FormatException(
                  'Replace formulas with plain values before importing.',
                );
              }
              return cell?.value?.toString() ?? '';
            }).toList(),
          )
          .toList();
    } else {
      throw const FormatException('Choose an .xlsx or UTF-8 .csv file.');
    }
    if (table.isEmpty) throw const FormatException('The spreadsheet is empty.');
    final columns = table.first.map((v) => v.trim().toLowerCase()).toList();
    if (!['name', 'email', 'user_identifier'].every(columns.contains)) {
      throw const FormatException(
        'Required headers: name, email, user_identifier. Download the template for the correct format.',
      );
    }
    final named = columns.where((v) => v.isNotEmpty).toList();
    if (named.toSet().length != named.length ||
        named.any((v) => !headers.contains(v))) {
      throw const FormatException(
        'Use the template headers without extra or duplicate columns.',
      );
    }
    final result = <Map<String, dynamic>>[];
    for (var i = 1; i < table.length; i++) {
      final row = table[i];
      if (row.every((value) => value.trim().isEmpty)) continue;
      if (row.asMap().entries.any(
        (entry) =>
            entry.value.trim().isNotEmpty &&
            (entry.key >= columns.length || columns[entry.key].isEmpty),
      )) {
        throw FormatException(
          'Row ${i + 1} has data outside the named columns.',
        );
      }
      result.add({
        'row': i + 1,
        for (var j = 0; j < columns.length; j++)
          if (headers.contains(columns[j]))
            columns[j]: j < row.length ? row[j].trim() : '',
      });
    }
    if (result.isEmpty || result.length > 500) {
      throw const FormatException('Include between 1 and 500 users per file.');
    }
    return result;
  }
}
