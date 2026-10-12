import 'dart:convert';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/user_spreadsheet.dart';
import 'widgets/clinic_widgets.dart';

class UserImportDialog extends StatefulWidget {
  const UserImportDialog({super.key, required this.controller});
  final WorkspaceController controller;
  @override
  State<UserImportDialog> createState() => _UserImportDialogState();
}

class _UserImportDialogState extends State<UserImportDialog> {
  List<Record> rows = [];
  String? filename, error;
  bool busy = false, importing = false, stop = false, started = false;
  int completed = 0;
  int get ready => rows.where((r) => r['status'] == 'ready').length;

  Future<void> pick() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'csv'],
      );
      if (file == null) return;
      if ((await file.length() ?? 0) > 2 * 1024 * 1024) {
        throw const FormatException('Choose a file smaller than 2 MB.');
      }
      final records = UserSpreadsheet.parse(
        file.name,
        await file.readAsBytes(),
      );
      final result = await widget.controller.api.post(
        '/admin/users/import/preview',
        {'rows': records},
      );
      if (!mounted) return;
      setState(() {
        filename = file.name;
        rows = (result['rows'] as List).map((r) => Record.from(r)).toList();
        started = false;
        completed = 0;
      });
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is ApiException
              ? e.message
              : e is FormatException
              ? e.message
              : 'Unable to read this file. Use the template and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> saveTemplate() async {
    try {
      await FilePicker.saveFile(
        fileName: 'sqs-users-template.csv',
        bytes: UserSpreadsheet.template,
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Could not save the template. Please try again.',
        );
      }
    }
  }

  Future<void> runImport() async {
    if (!await confirm(
      context,
      'Import $ready users?',
      'Create $ready accounts and send a temporary password to each user’s email? Other rows will be skipped. Keep this screen open until finished.',
    )) {
      return;
    }
    if (!mounted) return;
    setState(() {
      busy = true;
      importing = true;
      started = true;
      stop = false;
      error = null;
    });
    final pending = rows.where((r) => r['status'] == 'ready').toList();
    for (final row in pending) {
      if (stop) break;
      try {
        await widget.controller.api.post(
          '/admin/users',
          Record.from(row['data']),
        );
        row['status'] = 'created';
        row['message'] =
            'Created; temporary password submitted to the email service.';
      } on ApiException catch (e) {
        row['status'] = e.statusCode == 422 ? 'failed' : 'check';
        row['message'] = e.message;
        if (e.statusCode != 422) {
          stop = true;
          error =
              'Import stopped. Review this row in Users before retrying; a timed-out request may still finish. Upload the file again to check existing accounts.';
        }
      } catch (_) {
        row['status'] = 'check';
        row['message'] = 'Result unknown. Check Users before retrying.';
        stop = true;
        error = 'Import stopped because the result could not be confirmed.';
      }
      completed++;
      if (mounted) setState(() {});
    }
    await widget.controller.refresh();
    if (mounted) {
      setState(() {
        busy = false;
        importing = false;
      });
    }
  }

  Future<void> exportResults() async {
    String safe(dynamic value) {
      final text = '$value';
      return RegExp(r'^[=+@\-\t\r]').hasMatch(text) ? "'$text" : text;
    }

    final contents = const ListToCsvConverter().convert([
      ['row', 'name', 'email', 'user_identifier', 'result', 'message'],
      for (final r in rows)
        [
          r['row'],
          r['data']['name'],
          r['data']['email'],
          r['data']['user_identifier'],
          r['status'],
          r['message'],
        ].map(safe).toList(),
    ]);
    try {
      await FilePicker.saveFile(
        fileName: 'sqs-import-results.csv',
        bytes: Uint8List.fromList(utf8.encode(contents)),
      );
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not save the results. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Import users'),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              tooltip: 'Close',
              onPressed: busy ? null : () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * .55,
                  ),
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Add a student batch',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text('Excel or CSV · Up to 500 users · 2 MB'),
                          const ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            title: Text('Spreadsheet format & instructions'),
                            children: [
                              Padding(
                                padding: EdgeInsets.only(bottom: 12),
                                child: Text(
                                  'Required columns: name, email, user_identifier. Optional: phone_no, role, status. Blank role and status become patient and active. Use one data sheet or UTF-8 CSV. Format IDs and phone numbers as Text to preserve leading zeros. Existing accounts are skipped.',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: busy ? null : saveTemplate,
                                icon: const Icon(Icons.download_outlined),
                                label: const Text('CSV template'),
                              ),
                              FilledButton.icon(
                                onPressed: busy ? null : pick,
                                icon: const Icon(Icons.upload_file),
                                label: const Text('Choose spreadsheet'),
                              ),
                              if (rows.isNotEmpty)
                                OutlinedButton(
                                  onPressed: busy ? null : exportResults,
                                  child: const Text('Save results'),
                                ),
                            ],
                          ),
                          if (filename != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                filename!,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          if (rows.isNotEmpty)
                            Text(
                              started
                                  ? '${rows.where((r) => r['status'] == 'created').length} created · $completed processed · $ready not processed'
                                  : '$ready ready · ${rows.length - ready} skipped / need correction',
                            ),
                          if (error != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                error!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                          if (busy)
                            const Padding(
                              padding: EdgeInsets.only(top: 12),
                              child: LinearProgressIndicator(),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: rows.isEmpty
                      ? const Center(
                          child: Text(
                            'Choose a file to preview users before importing.',
                          ),
                        )
                      : ListView.builder(
                          itemCount: rows.length,
                          itemBuilder: (context, index) {
                            final row = rows[index];
                            final data = row['data'];
                            return ListTile(
                              isThreeLine: true,
                              leading: CircleAvatar(
                                child: Text('${row['row']}'),
                              ),
                              title: Text(
                                '${data['name']} · ${label(row['status'])}',
                              ),
                              subtitle: Text(
                                '${data['email']}\n${data['user_identifier']} · ${row['role']} · ${data['status']}\n${row['message']}',
                              ),
                            );
                          },
                        ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: importing
                          ? OutlinedButton(
                              onPressed: stop
                                  ? null
                                  : () => setState(() => stop = true),
                              child: Text(
                                stop
                                    ? 'Stopping after current user…'
                                    : 'Stop after current user',
                              ),
                            )
                          : FilledButton(
                              onPressed: busy || ready == 0 || started
                                  ? null
                                  : runImport,
                              child: Text(
                                started
                                    ? 'Finished — review results above'
                                    : 'Import $ready users & send emails',
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
